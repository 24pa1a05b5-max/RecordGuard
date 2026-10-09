import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.services.normalization import (
    normalize_dose, normalize_frequency, is_no_known_allergies, parse_clinical_date
)
from backend.app.services.clinical_extraction import (
    extract_allergies_from_text, extract_medications_from_text, extract_labs_from_text
)
from backend.app.services.contradiction_rules import evaluate_statement_pair, check_missing_information_findings
from backend.app.services.evidence_service import verify_evidence_snippet, assess_evidence_quality
from backend.app.services.ml_classifier import ml_service

client = TestClient(app)

def test_health_endpoint():
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "sqlite_connected"
    assert "ocr_available" in data
    assert data["model_available"] is True

def test_demo_login():
    response = client.post("/api/auth/demo-login", json={"username": "clinician.demo"})
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "clinician.demo"
    assert data["is_demo"] is True

def test_patient_list_and_detail():
    response = client.get("/api/patients")
    assert response.status_code == 200
    patients = response.json()
    assert len(patients) >= 5
    first_id = patients[0]["id"]
    
    detail_res = client.get(f"/api/patients/{first_id}")
    assert detail_res.status_code == 200
    assert detail_res.json()["id"] == first_id

def test_normalization_rules():
    # Unit conversions
    val_mg, unit = normalize_dose("50", "mcg")
    assert val_mg == 0.05
    assert unit == "mg"
    
    val_mg2, unit2 = normalize_dose("0.5", "g")
    assert val_mg2 == 500.0
    assert unit2 == "mg"
    
    # Frequency
    assert normalize_frequency("BID") == "twice daily"
    assert normalize_frequency("QD") == "once daily"
    assert normalize_frequency("every morning") == "once daily"
    
    # Allergies
    assert is_no_known_allergies("Allergies: No known drug allergies (NKDA)") is True
    assert is_no_known_allergies("Patient denies all allergies") is True
    assert is_no_known_allergies("Penicillin allergy (hives)") is False

def test_extraction_provenance():
    text = "Patient has Penicillin allergy. Active: Metformin 500 mg twice daily. HbA1c: 7.5%."
    allergies = extract_allergies_from_text(text, page_num=1)
    assert len(allergies) == 1
    assert allergies[0]["normalized_value"] == "penicillin"
    assert allergies[0]["char_offset_start"] >= 0
    # Snippet presence
    verified, _ = verify_evidence_snippet(text, allergies[0]["raw_statement"])
    assert verified is True

    meds = extract_medications_from_text(text, page_num=1)
    assert len(meds) >= 1
    assert meds[0]["normalized_field"] == "metformin"

    labs = extract_labs_from_text(text, page_num=1)
    assert len(labs) >= 1
    assert labs[0]["normalized_field"] == "HbA1c"
    assert labs[0]["normalized_value"] == "7.5"

def test_contradiction_rules_allergy():
    stmt_a = {
        "category": "ALLERGY", "normalized_field": "allergies",
        "normalized_value": "penicillin", "status": "PRESENT", "raw_statement": "Penicillin allergy"
    }
    stmt_b = {
        "category": "ALLERGY", "normalized_field": "allergies",
        "normalized_value": "NO_KNOWN_ALLERGIES", "status": "NEGATED", "raw_statement": "NKDA"
    }
    eval_res = evaluate_statement_pair(stmt_a, stmt_b, {}, {})
    assert eval_res is not None
    assert eval_res["classification"] == "POTENTIAL_CONTRADICTION"
    assert eval_res["priority_level"] == "PRIORITY_REVIEW"

def test_missing_information_not_absence():
    stmts_a = [{
        "category": "ALLERGY", "normalized_field": "allergies",
        "normalized_value": "penicillin", "status": "PRESENT", "raw_statement": "Penicillin allergy", "page_number": 1
    }]
    stmts_b = [] # Doc B omits allergy section
    missing = check_missing_information_findings(stmts_a, stmts_b, {}, {})
    assert len(missing) == 1
    assert missing[0]["classification"] == "INSUFFICIENT_EVIDENCE"
    assert missing[0]["priority_level"] == "AWAITING_EVIDENCE"
    assert "omission" in missing[0]["explanation"].lower() or "omit" in missing[0]["explanation"].lower()

def test_evidence_service_assessment():
    doc_text_a = "Documented Penicillin allergy on page 1."
    doc_text_b = "No known drug allergies recorded."
    scores = assess_evidence_quality(
        snippet_a="Penicillin allergy",
        snippet_b="No known drug allergies",
        doc_a_text=doc_text_a,
        doc_b_text=doc_text_b,
        page_a=1,
        page_b=1,
        date_a="2026-03-12",
        date_b="2026-03-15"
    )
    assert scores["verified_a"] is True
    assert scores["verified_b"] is True
    assert scores["traceability_score"] >= 0.8
    assert scores["completeness_score"] == 1.0

def test_ml_model_prediction():
    assert ml_service.is_loaded is True
    pred, conf = ml_service.predict(
        category="ALLERGY",
        statement_a="Known allergy: Penicillin (hives).",
        statement_b="Allergies: No known drug allergies (NKDA).",
        norm_val_a="penicillin",
        norm_val_b="NO_KNOWN_ALLERGIES"
    )
    assert pred == "POTENTIAL_CONTRADICTION"
    assert conf is not None and conf > 0.5

def test_review_and_audit_trail():
    findings = client.get("/api/findings").json()
    assert len(findings) > 0
    target_finding = findings[0]
    fid = target_finding["id"]
    
    # Apply review
    rev_res = client.post(f"/api/findings/{fid}/review", json={
        "reviewer_id": "USR-TEST-01",
        "reviewer_name": "Dr. Test Reviewer",
        "new_status": "RESOLVED",
        "decision_reason": "Patient verified via telephone consultation; allergy resolved.",
        "clinical_notes": "Added telephone note in chart."
    })
    assert rev_res.status_code == 200
    assert rev_res.json()["current_status"] == "RESOLVED"
    
    # Verify audit trail
    audit_res = client.get(f"/api/findings/{fid}/audit")
    assert audit_res.status_code == 200
    trail = audit_res.json()
    assert len(trail) >= 1
    assert trail[0]["action"] == "REVIEW_DECISION"
    assert trail[0]["actor"] == "Dr. Test Reviewer"

def test_model_metrics_endpoint():
    res = client.get("/api/models/metrics")
    assert res.status_code == 200
    metrics = res.json()
    assert metrics["dataset_size"] >= 3000
    assert metrics["macro_f1"] > 0.85
    assert "confusion_matrix" in metrics
    assert "disclosure" in metrics
