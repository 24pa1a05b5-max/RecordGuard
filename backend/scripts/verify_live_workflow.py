import os
import sys
import json
import httpx

BASE_URL = "http://127.0.0.1:8000/api"

def run_workflow_audit():
    print("[1] Checking Health & Model Status...")
    h = httpx.get(f"{BASE_URL}/health").json()
    assert h["status"] == "healthy"
    assert h["model_available"] is True
    print(f" -> System Healthy, Model Available: {h['model_available']}")

    # 1. Register a test patient
    print("\n[2] Registering test patient PAT-LIVE-AUDIT-01...")
    pat_data = {
        "id": "PAT-LIVE-AUDIT-01",
        "full_name": "Audit Test Patient",
        "birth_date": "1970-01-01",
        "gender": "Other",
        "mrn": "MRN-LIVE-9999",
        "notes": "Patient created during live workflow verification."
    }
    # Check if patient exists or create
    pat_res = httpx.get(f"{BASE_URL}/patients/{pat_data['id']}")
    if pat_res.status_code == 404:
        create_res = httpx.post(f"{BASE_URL}/patients", json=pat_data)
        assert create_res.status_code == 200
        print(" -> Patient created successfully.")
    else:
        print(" -> Patient already exists.")

    # 2. Upload Document A (Discharge Summary with Penicillin allergy)
    print("\n[3] Uploading Document A (scenario1_docA_metro_discharge.pdf)...")
    doc_a_path = "sample_documents/scenario1_docA_metro_discharge.pdf"
    with open(doc_a_path, "rb") as f:
        files = {"file": ("scenario1_docA_metro_discharge.pdf", f, "application/pdf")}
        data = {
            "patient_id": "PAT-LIVE-AUDIT-01",
            "provider_name": "Metro General Hospital",
            "provider_specialty": "Internal Medicine",
            "document_type": "Discharge Summary",
            "document_date": "2026-03-12"
        }
        res_a = httpx.post(f"{BASE_URL}/documents/upload", data=data, files=files)
        assert res_a.status_code == 200, f"Upload A failed: {res_a.text}"
        doc_a = res_a.json()
        print(f" -> Doc A uploaded: ID={doc_a['id']}, pages={doc_a['total_pages']}")

    # 3. Upload Document B (Intake Form with No known drug allergies)
    print("\n[4] Uploading Document B (scenario1_docB_pinecrest_intake.pdf)...")
    doc_b_path = "sample_documents/scenario1_docB_pinecrest_intake.pdf"
    with open(doc_b_path, "rb") as f:
        files = {"file": ("scenario1_docB_pinecrest_intake.pdf", f, "application/pdf")}
        data = {
            "patient_id": "PAT-LIVE-AUDIT-01",
            "provider_name": "Pinecrest Medical Group",
            "provider_specialty": "Primary Care",
            "document_type": "Intake Form",
            "document_date": "2026-03-15"
        }
        res_b = httpx.post(f"{BASE_URL}/documents/upload", data=data, files=files)
        assert res_b.status_code == 200, f"Upload B failed: {res_b.text}"
        doc_b = res_b.json()
        print(f" -> Doc B uploaded: ID={doc_b['id']}, pages={doc_b['total_pages']}")

    # 4. Run Comparison
    print("\n[5] Executing Comparison between Doc A and Doc B...")
    comp_payload = {
        "patient_id": "PAT-LIVE-AUDIT-01",
        "document_a_id": doc_a["id"],
        "document_b_id": doc_b["id"],
        "title": "Live Workflow Reconciliation Test"
    }
    comp_res = httpx.post(f"{BASE_URL}/comparisons", json=comp_payload)
    assert comp_res.status_code == 200, f"Comparison failed: {comp_res.text}"
    comp = comp_res.json()
    print(f" -> Comparison ID={comp['id']}, Findings count={comp['total_findings']}")

    # 5. Inspect Findings
    print("\n[6] Inspecting Discrepancy Findings & Supporting Evidence...")
    findings = comp["findings"]
    assert len(findings) > 0, "Expected at least 1 finding!"
    allergy_finding = None
    for f in findings:
        print(f"   * [{f['priority_level']}] {f['category']} - {f['classification']}: {f['field_compared']}")
        print(f"     Doc A: \"{f['snippet_a']}\" (Page {f['page_a']}, {f['date_a']})")
        print(f"     Doc B: \"{f['snippet_b']}\" (Page {f['page_b']}, {f['date_b']})")
        print(f"     Traceability: {f['traceability_score']}, Completeness: {f['evidence_completeness']}")
        print(f"     Confidence: {f['model_confidence']}, Rule: {f['rule_triggered']}")
        if f["category"] == "ALLERGY":
            allergy_finding = f

    assert allergy_finding is not None, "Allergy conflict finding not found!"
    assert allergy_finding["classification"] == "POTENTIAL_CONTRADICTION"
    assert allergy_finding["priority_level"] == "PRIORITY_REVIEW"
    assert allergy_finding["traceability_score"] >= 0.8
    assert allergy_finding["evidence_completeness"] == 1.0
    print(" -> Provenance & Evidence Verification Passed!")

    # 6. Apply Review Decision
    print(f"\n[7] Applying Human Review on Finding {allergy_finding['id']}...")
    rev_payload = {
        "reviewer_id": "USR-DEMO-01",
        "reviewer_name": "Dr. Alex Rivera, MD",
        "new_status": "CONFIRMED",
        "decision_reason": "Verified genuine clinical contradiction: Metro General recorded Penicillin hives, Pinecrest intake incorrectly stated NKDA.",
        "clinical_notes": "Flagged in pharmacy dispatch to prevent penicillin class antibiotic administration."
    }
    rev_res = httpx.post(f"{BASE_URL}/findings/{allergy_finding['id']}/review", json=rev_payload)
    assert rev_res.status_code == 200, f"Review failed: {rev_res.text}"
    updated_finding = rev_res.json()
    assert updated_finding["current_status"] == "CONFIRMED"
    assert updated_finding["last_reviewed_by"] == "Dr. Alex Rivera, MD"
    print(f" -> Finding status successfully updated to: {updated_finding['current_status']}")

    # 7. Audit Trail Verification
    print(f"\n[8] Inspecting Persistent Audit Trail for Finding {allergy_finding['id']}...")
    audit_res = httpx.get(f"{BASE_URL}/findings/{allergy_finding['id']}/audit")
    assert audit_res.status_code == 200
    trail = audit_res.json()
    assert len(trail) >= 1
    latest_event = trail[0]
    print(f" -> Audit Event Found: Action={latest_event['action']}, Actor={latest_event['actor']}")
    print(f"    Details: {json.dumps(latest_event['details'])}")
    assert latest_event["action"] == "REVIEW_DECISION"
    assert latest_event["details"]["new_status"] == "CONFIRMED"

    print("\n[SUCCESS] Live end-to-end workflow fully verified against running server!")

if __name__ == "__main__":
    run_workflow_audit()
