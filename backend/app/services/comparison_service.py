from datetime import datetime
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from backend.app.models.domain import Document, ExtractedStatement, Comparison, Finding
from backend.app.services.clinical_extraction import extract_all_clinical_statements
from backend.app.services.contradiction_rules import evaluate_statement_pair, check_missing_information_findings
from backend.app.services.evidence_service import assess_evidence_quality
from backend.app.services.ml_classifier import ml_service
from backend.app.services.audit_service import log_audit_event

def run_document_comparison(
    db: Session,
    patient_id: str,
    document_a_id: str,
    document_b_id: str,
    title: Optional[str] = None,
    force_refresh: bool = False,
    user_id: Optional[str] = None
) -> Comparison:
    """
    Executes a clinical comparison between two documents for a specific patient.
    Enforces comparison idempotency: if a comparison already exists and force_refresh is False,
    returns the existing comparison to avoid duplicate findings.
    Sets complete traceability fields, document IDs, units, statuses, and uncertainty notes.
    """
    doc_a = db.query(Document).filter(Document.id == document_a_id).first()
    doc_b = db.query(Document).filter(Document.id == document_b_id).first()
    
    if not doc_a or not doc_b:
        raise ValueError("One or both documents not found")
        
    comp_title = title or f"Comparison: {doc_a.original_name} vs {doc_b.original_name}"
    
    # 0. Check for existing comparison for idempotency
    existing_comp = db.query(Comparison).filter(
        Comparison.patient_id == patient_id,
        (
            ((Comparison.document_a_id == document_a_id) & (Comparison.document_b_id == document_b_id)) |
            ((Comparison.document_a_id == document_b_id) & (Comparison.document_b_id == document_a_id))
        )
    ).first()

    if existing_comp and not force_refresh:
        return existing_comp

    if existing_comp and force_refresh:
        comparison = existing_comp
        comparison.title = comp_title
        comparison.status = "PROCESSING"
        # Preserve human reviewed findings, delete unreviewed pending findings
        db.query(Finding).filter(
            Finding.comparison_id == existing_comp.id,
            Finding.current_status == "PENDING_REVIEW",
            Finding.clinically_verified == False
        ).delete(synchronize_session=False)
        db.commit()
    else:
        comparison = Comparison(
            user_id=user_id or (doc_a.user_id if doc_a else None),
            patient_id=patient_id,
            document_a_id=document_a_id,
            document_b_id=document_b_id,
            title=comp_title,
            status="PROCESSING",
            total_findings=0,
            contradiction_count=0,
            created_at=datetime.utcnow()
        )
        db.add(comparison)
        db.commit()
        db.refresh(comparison)
    
    # Helper to extract statements with truthful page provenance
    def extract_document_statements(doc: Document) -> List[ExtractedStatement]:
        stmts = db.query(ExtractedStatement).filter(ExtractedStatement.document_id == doc.id).all()
        if stmts:
            return stmts
            
        stmts_created = []
        if doc.file_type == "PDF" and "\n\n--- PAGE BREAK ---\n\n" in doc.raw_text:
            pages = doc.raw_text.split("\n\n--- PAGE BREAK ---\n\n")
            for idx, p_text in enumerate(pages):
                raw_extracted = extract_all_clinical_statements(p_text, page_num=idx + 1)
                for s in raw_extracted:
                    db_s = ExtractedStatement(
                        document_id=doc.id,
                        patient_id=patient_id,
                        category=s["category"],
                        raw_statement=s["raw_statement"],
                        normalized_field=s["normalized_field"],
                        normalized_value=s.get("normalized_value"),
                        normalized_unit=s.get("normalized_unit"),
                        normalized_frequency=s.get("normalized_frequency"),
                        status=s.get("status", "PRESENT"),
                        page_number=s.get("page_number"),
                        char_offset_start=s.get("char_offset_start", 0),
                        char_offset_end=s.get("char_offset_end", 0),
                        extraction_method=s.get("extraction_method", "DETERMINISTIC_PARSER"),
                        extraction_confidence=s.get("extraction_confidence", 1.0),
                        created_at=datetime.utcnow()
                    )
                    db.add(db_s)
                    stmts_created.append(db_s)
        else:
            # Unpaged text or document where page numbers cannot be reliably inferred
            page_val = 1 if doc.file_type == "PDF" else None
            raw_extracted = extract_all_clinical_statements(doc.raw_text, page_num=page_val)
            for s in raw_extracted:
                db_s = ExtractedStatement(
                    document_id=doc.id,
                    patient_id=patient_id,
                    category=s["category"],
                    raw_statement=s["raw_statement"],
                    normalized_field=s["normalized_field"],
                    normalized_value=s.get("normalized_value"),
                    normalized_unit=s.get("normalized_unit"),
                    normalized_frequency=s.get("normalized_frequency"),
                    status=s.get("status", "PRESENT"),
                    page_number=s.get("page_number"),
                    char_offset_start=s.get("char_offset_start", 0),
                    char_offset_end=s.get("char_offset_end", 0),
                    extraction_method=s.get("extraction_method", "DETERMINISTIC_PARSER"),
                    extraction_confidence=s.get("extraction_confidence", 1.0),
                    created_at=datetime.utcnow()
                )
                db.add(db_s)
                stmts_created.append(db_s)
        db.commit()
        return stmts_created

    stmts_a_db = extract_document_statements(doc_a)
    stmts_b_db = extract_document_statements(doc_b)

    doc_a_meta = {
        "document_name": doc_a.original_name,
        "provider_name": doc_a.provider_name,
        "document_date": doc_a.document_date
    }
    doc_b_meta = {
        "document_name": doc_b.original_name,
        "provider_name": doc_b.provider_name,
        "document_date": doc_b.document_date
    }

    # Convert DB models to dict for evaluation
    def to_dict(s: ExtractedStatement) -> Dict[str, Any]:
        return {
            "id": s.id,
            "category": s.category,
            "raw_statement": s.raw_statement,
            "normalized_field": s.normalized_field,
            "normalized_value": s.normalized_value,
            "normalized_unit": s.normalized_unit,
            "status": s.status,
            "page_number": s.page_number
        }

    dict_stmts_a = [to_dict(s) for s in stmts_a_db]
    dict_stmts_b = [to_dict(s) for s in stmts_b_db]

    # Track existing finding keys if refreshing to avoid duplicates
    existing_keys = {
        (f.field_compared, f.category) for f in comparison.findings
    }

    findings_created = list(comparison.findings)
    contradiction_count = sum(1 for f in findings_created if f.classification == "POTENTIAL_CONTRADICTION")

    # Compare paired statements
    for s_a in dict_stmts_a:
        for s_b in dict_stmts_b:
            pair_key = (s_a["normalized_field"], s_a["category"])
            if pair_key in existing_keys:
                continue

            rule_eval = evaluate_statement_pair(s_a, s_b, doc_a_meta, doc_b_meta)
            if rule_eval:
                classification = rule_eval["classification"]
                if classification == "POTENTIAL_CONTRADICTION":
                    contradiction_count += 1
                
                # Predict ML confidence with cautious calibration
                ml_res = ml_service.predict_detailed(
                    category=s_a["category"],
                    statement_a=s_a["raw_statement"],
                    statement_b=s_b["raw_statement"],
                    norm_val_a=s_a["normalized_value"],
                    norm_val_b=s_b["normalized_value"],
                    date_a=doc_a.document_date,
                    date_b=doc_b.document_date
                )
                conf = ml_res["confidence"] if ml_res else 0.85
                is_uncertain = ml_res.get("is_uncertain", False) if ml_res else False

                priority_level = rule_eval["priority_level"]
                priority_reason = rule_eval["priority_reason"]
                if is_uncertain and priority_level != "PRIORITY_REVIEW":
                    priority_level = "PRIORITY_REVIEW"
                    priority_reason = f"{priority_reason} (Flagged for clinician verification: confidence {conf:.2f})"
                
                # Build explicit uncertainty notes
                uncert_notes = []
                if doc_a.ocr_applied or doc_b.ocr_applied:
                    uncert_notes.append("Extracted using Optical Character Recognition (OCR); verify character fidelity on source scan.")
                if s_a.get("page_number") is None or s_b.get("page_number") is None:
                    uncert_notes.append("Exact physical page provenance unavailable in source record (unpaged note or text format).")
                if not doc_a.document_date or not doc_b.document_date:
                    uncert_notes.append("Document date missing in one or both records; chronological order cannot be confirmed.")
                if is_uncertain:
                    uncert_notes.append(f"Model prediction confidence below decision threshold ({conf:.2f}); recommended for clinician re-verification.")
                uncertainty_notes_str = "; ".join(uncert_notes) if uncert_notes else None

                # Assess evidence quality
                ev_metrics = assess_evidence_quality(
                    snippet_a=s_a["raw_statement"],
                    snippet_b=s_b["raw_statement"],
                    doc_a_text=doc_a.raw_text,
                    doc_b_text=doc_b.raw_text,
                    page_a=s_a.get("page_number"),
                    page_b=s_b.get("page_number"),
                    date_a=doc_a.document_date,
                    date_b=doc_b.document_date
                )
                
                finding = Finding(
                    user_id=user_id or comparison.user_id,
                    comparison_id=comparison.id,
                    patient_id=patient_id,
                    document_a_id=doc_a.id,
                    document_b_id=doc_b.id,
                    statement_a_id=s_a["id"],
                    statement_b_id=s_b["id"],
                    category=s_a["category"],
                    field_compared=s_a["normalized_field"],
                    statement_a_text=s_a["raw_statement"],
                    statement_b_text=s_b["raw_statement"],
                    doc_a_name=doc_a.original_name,
                    doc_b_name=doc_b.original_name,
                    provider_a=doc_a.provider_name,
                    provider_b=doc_b.provider_name,
                    date_a=doc_a.document_date,
                    date_b=doc_b.document_date,
                    page_a=s_a.get("page_number"),
                    page_b=s_b.get("page_number"),
                    unit_a=s_a.get("normalized_unit"),
                    unit_b=s_b.get("normalized_unit"),
                    status_a=s_a.get("status"),
                    status_b=s_b.get("status"),
                    snippet_a=s_a["raw_statement"],
                    snippet_b=s_b["raw_statement"],
                    classification=classification,
                    priority_level=priority_level,
                    priority_reason=priority_reason,
                    rule_triggered=rule_eval["rule_triggered"],
                    model_confidence=conf if conf is not None else 0.85,
                    evidence_completeness=ev_metrics["completeness_score"],
                    traceability_score=ev_metrics["traceability_score"],
                    temporal_context=rule_eval.get("temporal_context"),
                    uncertainty_notes=uncertainty_notes_str,
                    explanation=rule_eval["explanation"],
                    recommendation=rule_eval["recommendation"],
                    current_status="PENDING_REVIEW",
                    clinically_verified=False,
                    created_at=datetime.utcnow()
                )
                db.add(finding)
                findings_created.append(finding)
                existing_keys.add(pair_key)

    # Check for missing info (e.g. Doc A has allergies, Doc B completely omits allergy section)
    missing_findings = check_missing_information_findings(dict_stmts_a, dict_stmts_b, doc_a_meta, doc_b_meta)
    for mf in missing_findings:
        s_a = mf["statement_a"]
        mf_key = (mf["field_compared"], mf["category"])
        if mf_key in existing_keys:
            continue

        finding = Finding(
            user_id=user_id or comparison.user_id,
            comparison_id=comparison.id,
            patient_id=patient_id,
            document_a_id=doc_a.id,
            document_b_id=doc_b.id,
            statement_a_id=s_a["id"] if s_a else None,
            statement_b_id=None,
            category=mf["category"],
            field_compared=mf["field_compared"],
            statement_a_text=mf["statement_a_text"],
            statement_b_text=mf["statement_b_text"],
            doc_a_name=doc_a.original_name,
            doc_b_name=doc_b.original_name,
            provider_a=doc_a.provider_name,
            provider_b=doc_b.provider_name,
            date_a=doc_a.document_date,
            date_b=doc_b.document_date,
            page_a=mf["page_a"],
            page_b=mf["page_b"],
            unit_a=s_a.get("normalized_unit") if s_a else None,
            unit_b=None,
            status_a=s_a.get("status") if s_a else None,
            status_b=None,
            snippet_a=mf["snippet_a"],
            snippet_b=mf["snippet_b"],
            classification=mf["classification"],
            priority_level=mf["priority_level"],
            priority_reason=mf["priority_reason"],
            rule_triggered=mf["rule_triggered"],
            model_confidence=0.92,
            evidence_completeness=mf["evidence_completeness"],
            traceability_score=mf["traceability_score"],
            temporal_context=mf["temporal_context"],
            uncertainty_notes="Receiving record omits section entirely. In healthcare informatics, omission does not establish clinical absence.",
            explanation=mf["explanation"],
            recommendation=mf["recommendation"],
            current_status="PENDING_REVIEW",
            clinically_verified=False,
            created_at=datetime.utcnow()
        )
        db.add(finding)
        findings_created.append(finding)
        existing_keys.add(mf_key)

    comparison.status = "COMPLETED"
    comparison.total_findings = len(findings_created)
    comparison.contradiction_count = contradiction_count
    db.commit()
    db.refresh(comparison)
    
    log_audit_event(
        db=db,
        entity_type="COMPARISON",
        entity_id=comparison.id,
        action="RUN_COMPARISON",
        actor="System",
        details={
            "comparison_id": comparison.id,
            "patient_id": patient_id,
            "doc_a": doc_a.original_name,
            "doc_b": doc_b.original_name,
            "total_findings": len(findings_created),
            "contradictions": contradiction_count
        }
    )
    
    return comparison
