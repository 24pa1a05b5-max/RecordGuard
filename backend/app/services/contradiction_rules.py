import re
from typing import Optional, Dict, Any, List
from backend.app.services.normalization import (
    parse_clinical_date, normalize_medication_name, normalize_dose, normalize_lab_value
)

OMISSION_REGEX = re.compile(
    r"\b(unreviewed|omitted|omits|absent|not documented|unmentioned|incomplete|no record|no mention|not assessed|deferred|pending|not evaluated|section absent|focused clinical encounter|focused encounter|cannot be determined|unknown)\b",
    re.IGNORECASE
)

def evaluate_statement_pair(
    stmt_a: Dict[str, Any],
    stmt_b: Dict[str, Any],
    doc_a_meta: Dict[str, Any],
    doc_b_meta: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """
    Evaluates two extracted statements from Document A and Document B.
    Returns a finding dictionary if a comparison is warranted, else None.
    Handles negation, dates, unit conversions, synonyms, omissions, and clinically compatible pairs.
    """
    cat_a = stmt_a.get("category")
    cat_b = stmt_b.get("category")
    if cat_a != cat_b:
        return None

    raw_a = stmt_a.get("raw_statement", "")
    raw_b = stmt_b.get("raw_statement", "")

    # Check for Omission / Insufficient Evidence in either statement
    if OMISSION_REGEX.search(raw_a) or OMISSION_REGEX.search(raw_b):
        return {
            "classification": "INSUFFICIENT_EVIDENCE",
            "priority_level": "AWAITING_EVIDENCE",
            "priority_reason": "Incomplete documentation or unreviewed section in one of the clinical records.",
            "rule_triggered": "DOCUMENTATION_INCOMPLETE_OR_UNREVIEWED",
            "temporal_context": "One or both documents note an unreviewed or omitted section.",
            "explanation": f"Documentation indicates an omission or unperformed clinical review ('{raw_a}' vs '{raw_b}'). Lack of documentation must not be conflated with clinical absence.",
            "recommendation": "Request complete records or direct verification with the patient or originating care team.",
            "evidence_completeness": 0.6,
            "traceability_score": 1.0
        }

    field_a = stmt_a.get("normalized_field", "").strip().lower()
    field_b = stmt_b.get("normalized_field", "").strip().lower()
    
    # Medication normalization for field matching
    if cat_a == "MEDICATION" or cat_a == "ALLERGY":
        norm_field_a = normalize_medication_name(field_a)
        norm_field_b = normalize_medication_name(field_b)
    else:
        norm_field_a = field_a
        norm_field_b = field_b

    # Check if they refer to the same clinical entity
    if norm_field_a != norm_field_b:
        # If both are distinct confirmed allergies (e.g. Penicillin and Sulfa), they are clinically compatible
        if cat_a == "ALLERGY" and stmt_a.get("status") == "PRESENT" and stmt_b.get("status") == "PRESENT":
            return None # Not a conflict, patient can have multiple allergies
        return None

    date_a_str = doc_a_meta.get("document_date")
    date_b_str = doc_b_meta.get("document_date")
    date_a = parse_clinical_date(date_a_str)
    date_b = parse_clinical_date(date_b_str)
    
    temporal_gap_days = None
    if date_a and date_b:
        temporal_gap_days = (date_b - date_a).days

    status_a = stmt_a.get("status", "PRESENT")
    status_b = stmt_b.get("status", "PRESENT")
    val_a = stmt_a.get("normalized_value")
    val_b = stmt_b.get("normalized_value")
    unit_a = stmt_a.get("normalized_unit")
    unit_b = stmt_b.get("normalized_unit")

    # CATEGORY 1: ALLERGIES
    if cat_a == "ALLERGY":
        # Case 1: One PRESENT, one NEGATED (e.g. Penicillin allergy vs NKDA)
        if (status_a == "PRESENT" and status_b == "NEGATED") or (status_a == "NEGATED" and status_b == "PRESENT"):
            return {
                "classification": "POTENTIAL_CONTRADICTION",
                "priority_level": "PRIORITY_REVIEW",
                "priority_reason": "Direct conflict regarding patient allergy profile. Risk of adverse drug reaction.",
                "rule_triggered": "ALLERGY_PRESENCE_VS_NEGATION",
                "temporal_context": f"Document A date: {date_a_str or 'Unknown'}, Document B date: {date_b_str or 'Unknown'}",
                "explanation": "Conflicting statements regarding patient allergy status. Document A notes a specific allergy while Document B indicates no known drug allergies. The text does not establish which statement is clinically valid.",
                "recommendation": "Perform immediate clinical re-verification of allergy history with patient before prescribing or administering medications.",
                "evidence_completeness": 1.0,
                "traceability_score": 1.0
            }
        elif status_a == "PRESENT" and status_b == "PRESENT":
            # Both corroborate the allergy
            return {
                "classification": "NO_CONTRADICTION",
                "priority_level": "LOW_PRIORITY",
                "priority_reason": "Concordant allergy records.",
                "rule_triggered": "ALLERGY_CONCORDANT",
                "temporal_context": "Both records corroborate known allergy.",
                "explanation": f"Both documents consistently document allergy to {norm_field_a}.",
                "recommendation": "Maintain allergy alert in electronic health record.",
                "evidence_completeness": 1.0,
                "traceability_score": 1.0
            }
        elif status_a == "NEGATED" and status_b == "NEGATED":
            return {
                "classification": "NO_CONTRADICTION",
                "priority_level": "LOW_PRIORITY",
                "priority_reason": "Concordant absence of allergies.",
                "rule_triggered": "ALLERGY_CONCORDANT_NEGATION",
                "temporal_context": "Both records corroborate no known allergies.",
                "explanation": "Both documents concordantly verify no known drug allergies (NKDA).",
                "recommendation": "Maintain standard allergy inquiry schedule.",
                "evidence_completeness": 1.0,
                "traceability_score": 1.0
            }

    # CATEGORY 2: MEDICATIONS
    if cat_a == "MEDICATION":
        # Case 1: Discontinuation over time
        if (status_a == "PRESENT" and status_b == "DISCONTINUED") or (status_a == "DISCONTINUED" and status_b == "PRESENT"):
            if temporal_gap_days is not None and temporal_gap_days > 0 and status_b == "DISCONTINUED":
                return {
                    "classification": "TEMPORAL_CHANGE",
                    "priority_level": "STANDARD_REVIEW",
                    "priority_reason": "Documented medication regimen modification over elapsed time.",
                    "rule_triggered": "MEDICATION_DISCONTINUATION_TIMELINE",
                    "temporal_context": f"Document B is dated {temporal_gap_days} days after Document A.",
                    "explanation": f"Medication {field_a} was active in earlier record ({date_a_str or 'Doc A'}) but documented as discontinued in subsequent record ({date_b_str or 'Doc B'}). This chronological sequence indicates clinical discontinuation rather than an error.",
                    "recommendation": "Confirm current medication list with the dispensing pharmacy or prescribing clinician.",
                    "evidence_completeness": 1.0,
                    "traceability_score": 1.0
                }
            else:
                return {
                    "classification": "POTENTIAL_CONTRADICTION",
                    "priority_level": "PRIORITY_REVIEW",
                    "priority_reason": "Conflicting active vs discontinued medication status without definitive timeline.",
                    "rule_triggered": "MEDICATION_STATUS_CONFLICT",
                    "temporal_context": "Dates are ambiguous or concurrent.",
                    "explanation": f"Document A reports {field_a} as {status_a} while Document B reports it as {status_b}.",
                    "recommendation": "Clarify active medication order with provider.",
                    "evidence_completeness": 0.9,
                    "traceability_score": 1.0
                }

        # Case 2: Dosage comparison with unit normalization
        if val_a and val_b:
            # Check unit normalization (e.g. 500 mcg vs 0.5 mg)
            dose_num_a, norm_u_a = normalize_dose(val_a, unit_a)
            dose_num_b, norm_u_b = normalize_dose(val_b, unit_b)

            is_dose_equal = False
            if dose_num_a is not None and dose_num_b is not None and norm_u_a == norm_u_b:
                if abs(dose_num_a - dose_num_b) < 1e-4:
                    is_dose_equal = True
            elif val_a == val_b:
                is_dose_equal = True

            if is_dose_equal:
                return {
                    "classification": "NO_CONTRADICTION",
                    "priority_level": "LOW_PRIORITY",
                    "priority_reason": "Identical normalized medication regimen.",
                    "rule_triggered": "MEDICATION_EQUIVALENT_DOSE",
                    "temporal_context": "Consistent across both encounters.",
                    "explanation": f"Both documents document {field_a} at equivalent dose ({val_a} {unit_a or ''}).",
                    "recommendation": "Continue standard reconciliation schedule.",
                    "evidence_completeness": 1.0,
                    "traceability_score": 1.0
                }
            else:
                # Different dosage
                if temporal_gap_days is not None and abs(temporal_gap_days) >= 7:
                    return {
                        "classification": "TEMPORAL_CHANGE",
                        "priority_level": "STANDARD_REVIEW",
                        "priority_reason": "Dose adjustment over elapsed encounter interval.",
                        "rule_triggered": "MEDICATION_DOSE_ADJUSTMENT_OVER_TIME",
                        "temporal_context": f"Document B is dated {temporal_gap_days} days relative to Document A.",
                        "explanation": f"Dose difference observed for {field_a} ({val_a} vs {val_b}). Given the {abs(temporal_gap_days)}-day interval, this may reflect an intentional therapeutic titration.",
                        "recommendation": "Verify whether dose modification was intentional.",
                        "evidence_completeness": 1.0,
                        "traceability_score": 1.0
                    }
                else:
                    return {
                        "classification": "POTENTIAL_CONTRADICTION",
                        "priority_level": "PRIORITY_REVIEW",
                        "priority_reason": "Conflicting dosages without sufficient chronological separation.",
                        "rule_triggered": "MEDICATION_DISCORDANT_DOSE",
                        "temporal_context": "Documents dated closely or without clear chronology.",
                        "explanation": f"Discrepant dosages recorded for {field_a}: '{raw_a}' vs '{raw_b}'.",
                        "recommendation": "Clarify correct prescribed dose before administering.",
                        "evidence_completeness": 1.0,
                        "traceability_score": 1.0
                    }

    # CATEGORY 3: DIAGNOSIS
    if cat_a == "DIAGNOSIS":
        if (status_a == "PRESENT" and status_b == "NEGATED") or (status_a == "NEGATED" and status_b == "PRESENT"):
            return {
                "classification": "POTENTIAL_CONTRADICTION",
                "priority_level": "STANDARD_REVIEW",
                "priority_reason": "Discordant presence and denial of chronic diagnosis.",
                "rule_triggered": "DIAGNOSIS_PRESENCE_VS_NEGATION",
                "temporal_context": f"Doc A: {date_a_str or 'N/A'}, Doc B: {date_b_str or 'N/A'}",
                "explanation": f"Document A affirms '{field_a}' ({status_a}) whereas Document B negates or denies it ({status_b}).",
                "recommendation": "Review diagnostic criteria, lab history, and clinician notes.",
                "evidence_completeness": 0.95,
                "traceability_score": 1.0
            }
        elif status_a == status_b:
            return {
                "classification": "NO_CONTRADICTION",
                "priority_level": "LOW_PRIORITY",
                "priority_reason": "Concordant diagnostic documentation.",
                "rule_triggered": "DIAGNOSIS_CONCORDANT",
                "temporal_context": "Both providers agree.",
                "explanation": f"Both documents corroborate diagnosis of {field_a}.",
                "recommendation": "No action needed.",
                "evidence_completeness": 1.0,
                "traceability_score": 1.0
            }

    # CATEGORY 4: LAB RESULTS
    if cat_a == "LAB_RESULT":
        if val_a and val_b:
            # Check unit conversion equivalence
            is_lab_equal = False
            try:
                num_a = float(re.search(r"[-+]?\d*\.?\d+", str(val_a)).group())
                num_b = float(re.search(r"[-+]?\d*\.?\d+", str(val_b)).group())
                norm_v_a, norm_u_a = normalize_lab_value(field_a, num_a, unit_a or "")
                norm_v_b, norm_u_b = normalize_lab_value(field_b, num_b, unit_b or "")
                if norm_u_a == norm_u_b and abs(norm_v_a - norm_v_b) <= max(0.05 * max(norm_v_a, 1.0), 0.1):
                    is_lab_equal = True
            except Exception:
                if str(val_a).strip().lower() == str(val_b).strip().lower():
                    is_lab_equal = True

            if is_lab_equal:
                return {
                    "classification": "NO_CONTRADICTION",
                    "priority_level": "LOW_PRIORITY",
                    "priority_reason": "Exact or unit-converted lab value concordance.",
                    "rule_triggered": "LAB_IDENTICAL_OR_UNIT_CONVERTED_VALUE",
                    "temporal_context": "Concordant result across reports.",
                    "explanation": f"Concordant laboratory result for {field_a}: {val_a} {unit_a or ''} is equivalent to {val_b} {unit_b or ''}.",
                    "recommendation": "File with lab flowsheets.",
                    "evidence_completeness": 1.0,
                    "traceability_score": 1.0
                }
            elif temporal_gap_days is not None and abs(temporal_gap_days) > 0:
                return {
                    "classification": "TEMPORAL_CHANGE",
                    "priority_level": "STANDARD_REVIEW",
                    "priority_reason": "Serial lab measurements across distinct collection dates.",
                    "rule_triggered": "LAB_SERIAL_MEASUREMENT",
                    "temporal_context": f"Interval of {abs(temporal_gap_days)} days between encounters ({date_a_str} vs {date_b_str}).",
                    "explanation": f"Different laboratory values for {field_a} ({val_a} {unit_a or ''} vs {val_b} {unit_b or ''}). Because samples were drawn on different dates, this reflects physiologic change over time rather than a document contradiction.",
                    "recommendation": "Review longitudinal trend in patient lab history.",
                    "evidence_completeness": 1.0,
                    "traceability_score": 1.0
                }
            else:
                return {
                    "classification": "INCONSISTENT_REPRESENTATION",
                    "priority_level": "STANDARD_REVIEW",
                    "priority_reason": "Different lab values on identical or unspecified collection dates.",
                    "rule_triggered": "LAB_CONCURRENT_DISCREPANCY",
                    "temporal_context": "Same date or missing timestamp.",
                    "explanation": f"Conflicting values for {field_a} ({val_a} {unit_a or ''} vs {val_b} {unit_b or ''}) without documented date difference.",
                    "recommendation": "Contact lab for accession clarification.",
                    "evidence_completeness": 0.9,
                    "traceability_score": 1.0
                }

    return None

def check_missing_information_findings(
    doc_a_statements: List[Dict[str, Any]],
    doc_b_statements: List[Dict[str, Any]],
    doc_a_meta: Dict[str, Any],
    doc_b_meta: Dict[str, Any]
) -> List[Dict[str, Any]]:
    """
    Checks for key clinical elements present in Document A but omitted in Document B
    (e.g., Document A documents an allergy, but Document B has NO allergy section).
    Explicitly labels this as INSUFFICIENT_EVIDENCE / MISSING INFO, NOT clinical absence!
    """
    findings = []
    
    allergies_a = [s for s in doc_a_statements if s.get("category") == "ALLERGY" and s.get("status") == "PRESENT"]
    allergies_b = [s for s in doc_b_statements if s.get("category") == "ALLERGY"]
    
    if allergies_a and not allergies_b:
        for a in allergies_a:
            findings.append({
                "statement_a": a,
                "statement_b": None,
                "category": "ALLERGY",
                "field_compared": "Allergies",
                "statement_a_text": a.get("raw_statement", ""),
                "statement_b_text": "[No allergy section or documentation present in Document B]",
                "snippet_a": a.get("raw_statement", ""),
                "snippet_b": "Section absent in Document B",
                "page_a": a.get("page_number"),
                "page_b": None,
                "classification": "INSUFFICIENT_EVIDENCE",
                "priority_level": "AWAITING_EVIDENCE",
                "priority_reason": "Incomplete documentation in receiving record. Omission is not proof of absence.",
                "rule_triggered": "OMITTED_ALLERGY_DOCUMENTATION",
                "temporal_context": "One document omits allergy record entirely.",
                "explanation": f"Document A notes '{a.get('raw_statement')}', but Document B contains no allergy section. In healthcare informatics, omission of an allergy entry does NOT establish that the allergy is absent.",
                "recommendation": "Request comprehensive allergy verification from the patient or originating provider.",
                "evidence_completeness": 0.5,
                "traceability_score": 1.0
            })
            
    return findings
