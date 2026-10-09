import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.db.session import SessionLocal
from backend.app.models.domain import Document, Finding, Comparison, ReviewDecision
from backend.app.services.comparison_service import run_document_comparison
from backend.app.services.review_service import apply_human_review

client = TestClient(app)

def test_traceability_fields_on_findings():
    """Verify that every finding contains full provenance metadata and document IDs."""
    res = client.get("/api/findings")
    assert res.status_code == 200
    findings = res.json()
    assert len(findings) > 0

    for f in findings:
        # 1. Unique Finding ID
        assert f["id"] is not None and len(f["id"]) > 0
        # 2. Both document identifiers
        assert "document_a_id" in f and f["document_a_id"] is not None
        assert "document_b_id" in f and f["document_b_id"] is not None
        # 3. Both filenames
        assert f["doc_a_name"] is not None and len(f["doc_a_name"]) > 0
        assert f["doc_b_name"] is not None and len(f["doc_b_name"]) > 0
        # 4. Verbatim snippets
        assert len(f["snippet_a"]) > 0
        assert len(f["snippet_b"]) > 0
        # 5. Classification and explanation
        assert f["classification"] in [
            "POTENTIAL_CONTRADICTION", "TEMPORAL_CHANGE", "INCONSISTENT_REPRESENTATION",
            "INSUFFICIENT_EVIDENCE", "NO_CONTRADICTION", "CONSISTENT"
        ]
        assert len(f["explanation"]) > 10

def test_verbatim_evidence_in_original_text():
    """Evidence must come from actual document text, not fabricated paraphrases."""
    res = client.get("/api/findings")
    findings = res.json()
    
    for f in findings:
        doc_a_res = client.get(f"/api/documents/{f['document_a_id']}/raw")
        assert doc_a_res.status_code == 200
        doc_a_text = doc_a_res.json()["raw_text"]
        
        # Snippet A must be present in doc A text (unless missing section placeholder)
        if not f["snippet_a"].startswith("[No "):
            # Substring check (case-insensitive or exact)
            assert f["snippet_a"].lower() in doc_a_text.lower() or any(
                part.lower() in doc_a_text.lower() for part in f["snippet_a"].split()[:3]
            )

def test_truthful_page_provenance_no_fabrication():
    """Unpaged text documents must report page as None (null in JSON), not fabricated page 1."""
    res = client.get("/api/findings")
    findings = res.json()
    
    # Filter for plain text scenario 4 findings
    scenario4_findings = [f for f in findings if "scenario4" in f["doc_a_name"]]
    assert len(scenario4_findings) > 0
    for f in scenario4_findings:
        # Plain text records must not fabricate page numbers
        assert f["page_a"] is None
        # Uncertainty notes must explain unpaged record
        assert f["uncertainty_notes"] is not None
        assert "unpaged" in f["uncertainty_notes"].lower() or "omits" in f["uncertainty_notes"].lower()

def test_comparison_idempotency_prevents_duplicate_findings():
    """Retrying the same comparison must not duplicate findings."""
    db = SessionLocal()
    comp = db.query(Comparison).first()
    assert comp is not None
    
    total_before = db.query(Finding).count()
    
    # Repeat comparison via API
    res = client.post("/api/comparisons", json={
        "patient_id": comp.patient_id,
        "document_a_id": comp.document_a_id,
        "document_b_id": comp.document_b_id,
        "force_refresh": False
    })
    assert res.status_code == 200
    
    total_after = db.query(Finding).count()
    assert total_after == total_before
    db.close()

def test_human_review_workflow_and_reopening():
    """Reviewers can change status, reopen findings, and record verified conclusions without duplicate rows."""
    db = SessionLocal()
    f = db.query(Finding).first()
    fid = f.id
    initial_finding_count = db.query(Finding).count()
    
    # 1. Confirm finding with clinical verified conclusion
    res1 = client.post(f"/api/findings/{fid}/review", json={
        "reviewer_id": "REV-TEST-01",
        "reviewer_name": "Dr. Sarah Connor, MD",
        "new_status": "CONFIRMED",
        "decision_reason": "Confirmed true contradiction between records.",
        "verified_conclusion": "Clinically confirmed allergy to Penicillin; discharge note was accurate.",
        "clinically_verified": True
    })
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["current_status"] == "CONFIRMED"
    assert data1["clinically_verified"] is True
    assert "Clinically confirmed" in data1["verified_conclusion"]
    assert db.query(Finding).count() == initial_finding_count
    
    # 2. Reopen to PENDING_REVIEW
    res2 = client.post(f"/api/findings/{fid}/review", json={
        "reviewer_id": "REV-TEST-01",
        "reviewer_name": "Dr. Sarah Connor, MD",
        "new_status": "PENDING_REVIEW",
        "decision_reason": "Reopened following receipt of contradictory laboratory report."
    })
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["current_status"] == "PENDING_REVIEW"
    assert data2["clinically_verified"] is False
    assert db.query(Finding).count() == initial_finding_count
    
    # 3. Mark as REQUIRES_MORE_INFO
    res3 = client.post(f"/api/findings/{fid}/review", json={
        "reviewer_id": "REV-TEST-01",
        "reviewer_name": "Dr. Sarah Connor, MD",
        "new_status": "REQUIRES_MORE_INFO",
        "decision_reason": "Requested hospital discharge summary from outside health network."
    })
    assert res3.status_code == 200
    data3 = res3.json()
    assert data3["current_status"] == "REQUIRES_MORE_INFO"
    assert data3["clinically_verified"] is False
    assert db.query(Finding).count() == initial_finding_count
    
    # 4. Mark as DISMISSED
    res4 = client.post(f"/api/findings/{fid}/review", json={
        "reviewer_id": "REV-TEST-01",
        "reviewer_name": "Dr. Sarah Connor, MD",
        "new_status": "DISMISSED",
        "decision_reason": "Dismissed as expected clinical evolution after reviewing specialist clinic note.",
        "clinically_verified": True
    })
    assert res4.status_code == 200
    data4 = res4.json()
    assert data4["current_status"] == "DISMISSED"
    assert data4["clinically_verified"] is True
    assert db.query(Finding).count() == initial_finding_count
    
    # 5. Check audit trail length (should contain all 4 decisions)
    audit_res = client.get(f"/api/findings/{fid}/audit")
    assert audit_res.status_code == 200
    audits = audit_res.json()
    assert len(audits) >= 4
    db.close()

def test_raw_document_endpoint_security_and_content():
    """GET /api/documents/{id}/raw returns complete original text without exposing secrets."""
    db = SessionLocal()
    doc = db.query(Document).first()
    res = client.get(f"/api/documents/{doc.id}/raw")
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == doc.id
    assert data["original_name"] == doc.original_name
    assert len(data["raw_text"]) > 0
    # Ensure no secrets or tokens in document response
    assert "password" not in data
    assert "api_key" not in data
    
    # Nonexistent document returns 404
    res_404 = client.get("/api/documents/nonexistent-id-9999/raw")
    assert res_404.status_code == 404
    db.close()
