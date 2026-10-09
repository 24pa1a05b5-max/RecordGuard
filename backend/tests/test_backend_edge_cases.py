import io
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app

client = TestClient(app)

def test_upload_empty_file():
    files = {"file": ("empty.pdf", b"", "application/pdf")}
    data = {
        "patient_id": "PAT-88201",
        "provider_name": "Dr. Test",
        "document_type": "Discharge Summary"
    }
    res = client.post("/api/documents/upload", data=data, files=files)
    assert res.status_code == 400
    assert "empty" in res.json()["detail"].lower()

def test_upload_unsupported_file_extension():
    files = {"file": ("malicious.exe", b"binarycontent", "application/octet-stream")}
    data = {
        "patient_id": "PAT-88201",
        "provider_name": "Dr. Test",
        "document_type": "Discharge Summary"
    }
    res = client.post("/api/documents/upload", data=data, files=files)
    assert res.status_code == 400
    assert "unsupported" in res.json()["detail"].lower()

from backend.app.core.config import settings

def test_upload_oversized_file():
    # File exceeding settings.MAX_UPLOAD_SIZE_MB
    large_content = b"0" * ((settings.MAX_UPLOAD_SIZE_MB + 1) * 1024 * 1024)
    files = {"file": ("huge.pdf", large_content, "application/pdf")}
    data = {
        "patient_id": "PAT-88201",
        "provider_name": "Dr. Test",
        "document_type": "Discharge Summary"
    }
    res = client.post("/api/documents/upload", data=data, files=files)
    assert res.status_code == 400
    assert "exceeds" in res.json()["detail"].lower()

def test_upload_corrupt_pdf():
    files = {"file": ("corrupt.pdf", b"NOT_A_REAL_PDF_HEADER_OR_BODY_1234567890", "application/pdf")}
    data = {
        "patient_id": "PAT-88201",
        "provider_name": "Dr. Test",
        "document_type": "Discharge Summary"
    }
    res = client.post("/api/documents/upload", data=data, files=files)
    assert res.status_code == 400
    assert "failed to parse" in res.json()["detail"].lower()

def test_upload_nonexistent_patient():
    files = {"file": ("doc.txt", b"Patient clinical note text.", "text/plain")}
    data = {
        "patient_id": "PAT-NONEXISTENT-99999",
        "provider_name": "Dr. Test",
        "document_type": "Progress Note"
    }
    res = client.post("/api/documents/upload", data=data, files=files)
    assert res.status_code == 404
    assert "patient id not found" in res.json()["detail"].lower()

def test_get_nonexistent_document():
    res = client.get("/api/documents/nonexistent-doc-uuid")
    assert res.status_code == 404

def test_get_document_page_out_of_range():
    # Get an existing document from seeded data
    docs = client.get("/api/patients/PAT-88201").json()
    # Find any document id
    patients = client.get("/api/patients").json()
    # Upload a valid txt doc first
    files = {"file": ("single_page.txt", b"Single page note content.", "text/plain")}
    data = {
        "patient_id": "PAT-88201",
        "provider_name": "Dr. Single",
        "document_type": "Progress Note"
    }
    upload_res = client.post("/api/documents/upload", data=data, files=files)
    assert upload_res.status_code == 200
    doc_id = upload_res.json()["id"]

    # Page 0 (out of range)
    res_zero = client.get(f"/api/documents/{doc_id}/pages/0")
    assert res_zero.status_code == 400

    # Page 99 (out of range)
    res_high = client.get(f"/api/documents/{doc_id}/pages/99")
    assert res_high.status_code == 400

    # Page 1 (valid)
    res_valid = client.get(f"/api/documents/{doc_id}/pages/1")
    assert res_valid.status_code == 200
    assert res_valid.json()["page_text"] == "Single page note content."

def test_review_invalid_status():
    findings = client.get("/api/findings").json()
    assert len(findings) > 0
    fid = findings[0]["id"]
    res = client.post(f"/api/findings/{fid}/review", json={
        "reviewer_id": "USR-TEST-01",
        "reviewer_name": "Dr. Test",
        "new_status": "SUPER_RESOLVED_INVALID",
        "decision_reason": "Justification text."
    })
    assert res.status_code == 400
    assert "invalid review status" in res.json()["detail"].lower()

def test_review_empty_reason():
    findings = client.get("/api/findings").json()
    assert len(findings) > 0
    fid = findings[0]["id"]
    res = client.post(f"/api/findings/{fid}/review", json={
        "reviewer_id": "USR-TEST-01",
        "reviewer_name": "Dr. Test",
        "new_status": "CONFIRMED",
        "decision_reason": "  "
    })
    assert res.status_code == 400
    assert "reason is required" in res.json()["detail"].lower()

def test_review_nonexistent_finding():
    res = client.post("/api/findings/nonexistent-finding-uuid/review", json={
        "reviewer_id": "USR-TEST-01",
        "reviewer_name": "Dr. Test",
        "new_status": "CONFIRMED",
        "decision_reason": "Valid reason."
    })
    assert res.status_code == 404

def test_create_duplicate_patient():
    res = client.post("/api/patients", json={
        "id": "PAT-88201",
        "full_name": "Duplicate Eleanor",
        "birth_date": "1968-04-12",
        "gender": "Female",
        "mrn": "MRN-DUPLICATE-01"
    })
    assert res.status_code == 400
    assert "already exists" in res.json()["detail"].lower()

def test_get_nonexistent_patient():
    res = client.get("/api/patients/PAT-DOES-NOT-EXIST")
    assert res.status_code == 404
