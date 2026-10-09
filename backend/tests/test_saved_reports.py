import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.core.firebase_auth import mint_test_id_token_for_verification

client = TestClient(app)

def test_save_report_under_user_name_and_fast_retrieval_and_download():
    # 1. Authenticate as Clinician
    clinician_name = "Dr. Eleanor Martinez, MD"
    token = mint_test_id_token_for_verification(
        uid="clinician-report-user-01",
        custom_claims={"role": "Attending Physician", "name": clinician_name}
    )
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Save report under user's name
    save_payload = {
        "patient_id": "PAT-88201",
        "patient_name": "Eleanor Vance",
        "report_title": "Allergy & Medication Reconciliation Audit",
        "report_type": "CLINICAL_RECONCILIATION",
        "summary": "Verified Penicillin anaphylaxis discrepancy between Metro Hospital and Clinic Intake.",
        "total_findings": 4,
        "contradictions_count": 2,
        "verified_count": 2,
        "report_data": "Penicillin anaphylaxis confirmed. Metformin 500mg daily verified.",
        "file_format": "PDF"
    }

    res_save = client.post("/api/reports/save", headers=headers, json=save_payload)
    assert res_save.status_code == 200, f"Save report failed: {res_save.text}"
    saved_data = res_save.json()
    assert saved_data["id"] is not None
    assert saved_data["user_name"] == clinician_name
    assert saved_data["report_title"] == "Allergy & Medication Reconciliation Audit"
    assert saved_data["patient_name"] == "Eleanor Vance"
    report_id = saved_data["id"]

    # 3. Fast retrieval of reports for this user
    res_list = client.get("/api/reports", headers=headers)
    assert res_list.status_code == 200
    reports = res_list.json()
    assert len(reports) >= 1
    found = [r for r in reports if r["id"] == report_id]
    assert len(found) == 1
    assert found[0]["user_name"] == clinician_name

    # 4. Filter by clinician user name
    res_filtered = client.get(f"/api/reports?user_name=Martinez", headers=headers)
    assert res_filtered.status_code == 200
    assert len(res_filtered.json()) >= 1

    # 5. Direct report download from database
    res_download = client.get(f"/api/reports/{report_id}/download", headers=headers)
    assert res_download.status_code == 200
    assert "Content-Disposition" in res_download.headers
    assert "attachment" in res_download.headers["Content-Disposition"]
    text_content = res_download.text
    assert "RECORDGUARD AI - CLINICAL RECONCILIATION & CONTRADICTION AUDIT REPORT" in text_content
    assert clinician_name in text_content
    assert "Eleanor Vance" in text_content
    assert "Penicillin anaphylaxis confirmed" in text_content

    # 6. Delete report
    res_delete = client.delete(f"/api/reports/{report_id}", headers=headers)
    assert res_delete.status_code == 200
