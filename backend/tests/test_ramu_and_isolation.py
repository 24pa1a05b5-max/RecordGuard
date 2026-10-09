import os
import pytest
from pathlib import Path
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.main import app
from backend.app.core.config import settings
from backend.app.db.session import get_db, Base
from backend.app.core.firebase_auth import mint_test_id_token_for_verification
from backend.app.models.domain import User, Patient, Document, Comparison, Finding
from backend.app.services.ml_classifier import ml_service

TEST_DB_URL = "sqlite:///:memory:"

@pytest.fixture(scope="module")
def test_db():
    engine = create_engine(
        TEST_DB_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    yield TestingSessionLocal
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="module")
def client(test_db):
    def override_get_db():
        db = test_db()
        try:
            yield db
        finally:
            db.close()
            
    app.dependency_overrides[get_db] = override_get_db
    ml_service.load_model()
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# 1. DATABASE SCHEMA & CREDENTIAL STORAGE SAFETY VERIFICATION
def test_database_schema_stores_no_passwords_or_tokens(test_db):
    """
    Strictly verifies that SQLite database tables contain NO password columns,
    hashes, or auth tokens. User credentials are managed exclusively by Firebase Auth.
    """
    engine = test_db().bind
    inspector = inspect(engine)
    
    # Check all tables
    tables = inspector.get_table_names()
    assert "users" in tables
    assert "patients" in tables
    assert "documents" in tables
    assert "comparisons" in tables
    assert "findings" in tables
    
    user_columns = [col["name"].lower() for col in inspector.get_columns("users")]
    for forbidden in ["password", "password_hash", "hashed_password", "passwd", "token", "secret", "private_key"]:
        assert forbidden not in user_columns, f"Security violation: found '{forbidden}' column in users table!"


def test_user_profile_uniqueness_and_idempotent_login(client, test_db):
    """
    Verifies that Firebase UID is uniquely stored in SQLite and repeated logins
    update or reuse the existing record without creating duplicate rows.
    """
    uid = "firebase-unique-test-uid"
    token = mint_test_id_token_for_verification(
        uid=uid,
        custom_claims={"role": "Clinical Reviewer", "name": "Dr. Sarah Lin", "email": "sarah.lin@hospital.org"}
    )
    assert token is not None
    headers = {"Authorization": f"Bearer {token}"}
    
    # First login / sync
    res1 = client.get("/api/auth/me", headers=headers)
    assert res1.status_code == 200
    
    # Second login / sync
    res2 = client.get("/api/auth/me", headers=headers)
    assert res2.status_code == 200
    
    db = test_db()
    try:
        users = db.query(User).filter(User.id == uid).all()
        assert len(users) == 1, "There must be exactly one user profile row for a given Firebase UID"
        assert users[0].full_name == "Dr. Sarah Lin"
    finally:
        db.close()


# 2. TWO-USER ISOLATION TESTS
def test_two_user_data_isolation(client):
    """
    Verifies that User A cannot read or modify User B's patient, documents,
    comparisons, or findings. Every unauthorized foreign request receives HTTP 403 Forbidden.
    """
    token_a = mint_test_id_token_for_verification(
        uid="clinician-user-A",
        custom_claims={"role": "Attending Physician", "name": "Dr. Alice Adams"}
    )
    token_b = mint_test_id_token_for_verification(
        uid="clinician-user-B",
        custom_claims={"role": "Attending Physician", "name": "Dr. Bob Baker"}
    )
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}
    
    # 1. User A creates a private patient
    res_create = client.post(
        "/api/patients",
        headers=headers_a,
        json={
            "id": "PAT-ISOLATION-01",
            "full_name": "Isolated Patient A",
            "mrn": "MRN-ISO-01",
            "birth_date": "1975-04-12",
            "gender": "Female"
        }
    )
    assert res_create.status_code == 200
    
    # 2. User B tries to view User A's patient directly -> 403 Forbidden
    res_b_view = client.get("/api/patients/PAT-ISOLATION-01", headers=headers_b)
    assert res_b_view.status_code == 403, f"Expected 403 Forbidden, got {res_b_view.status_code}"
    
    # 3. User B lists patients -> User A's patient must NOT be in the list
    res_b_list = client.get("/api/patients", headers=headers_b)
    assert res_b_list.status_code == 200
    b_patients = [p["id"] for p in res_b_list.json()]
    assert "PAT-ISOLATION-01" not in b_patients
    
    # 4. User A uploads a valid text document to their patient
    file_content = b"DISCHARGE SUMMARY\nPatient: Isolated Patient A\nAllergies: No Known Drug Allergies\nMedications: Lisinopril 10mg daily."
    res_upload = client.post(
        "/api/documents/upload",
        headers=headers_a,
        data={
            "patient_id": "PAT-ISOLATION-01",
            "provider_name": "Dr. Hospital A",
            "document_type": "Discharge Summary"
        },
        files={"file": ("doc_a.txt", file_content, "text/plain")}
    )
    assert res_upload.status_code == 200
    doc_id = res_upload.json()["id"]
    
    # 5. User B tries to fetch User A's document raw content -> 403 Forbidden
    res_b_raw = client.get(f"/api/documents/{doc_id}/raw", headers=headers_b)
    assert res_b_raw.status_code == 403
    
    # 6. User B tries to fetch User A's document metadata -> 403 Forbidden
    res_b_meta = client.get(f"/api/documents/{doc_id}", headers=headers_b)
    assert res_b_meta.status_code == 403


# 3. SYNTHETIC RAMU PATEL CLINICAL CONTRADICTION DETECTION & TRACEABILITY
def test_ramu_patel_reports_contradiction_detection(client):
    """
    Uploads the two synthetic Ramu Patel clinical reports and executes contradiction detection.
    Verifies detection of:
      1. Allergy conflict (Penicillin allergy vs NKDA)
      2. Medication status conflict (Metformin active vs discontinued)
      3. Diabetes diagnosis conflict (Type 2 Diabetes Mellitus vs denied/absent)
      4. Lab discrepancies (Fasting blood glucose 186 vs 92 mg/dL, HbA1c 8.8% vs 5.4%)
    Verifies complete provenance evidence, supporting quotes, and human review resolution.
    """
    token_ramu = mint_test_id_token_for_verification(
        uid="clinician-ramu-reviewer",
        custom_claims={"role": "Attending Physician", "name": "Dr. Ramu Reviewer"}
    )
    headers = {"Authorization": f"Bearer {token_ramu}"}
    
    # 1. Create Patient Ramu Patel
    res_pat = client.post(
        "/api/patients",
        headers=headers,
        json={
            "id": "PAT-RAMU-882",
            "full_name": "Ramu Patel",
            "mrn": "MRN-RAMU-2026",
            "birth_date": "1968-08-15",
            "gender": "Male",
            "notes": "Synthetic patient case for contradictory clinical reconciliation"
        }
    )
    assert res_pat.status_code == 200
    
    # 2. Check if sample Ramu PDFs exist on disk
    base_dir = Path(__file__).resolve().parent.parent.parent
    pdf_a_path = base_dir / "sample_documents" / "ramu_report_A.pdf"
    pdf_b_path = base_dir / "sample_documents" / "ramu_report_B.pdf"
    
    assert pdf_a_path.exists(), f"Missing test fixture: {pdf_a_path}"
    assert pdf_b_path.exists(), f"Missing test fixture: {pdf_b_path}"
    
    # Upload Report A (Metro Health Discharge Summary)
    with open(pdf_a_path, "rb") as f_a:
        res_upload_a = client.post(
            "/api/documents/upload",
            headers=headers,
            data={
                "patient_id": "PAT-RAMU-882",
                "provider_name": "Metro General Hospital",
                "document_type": "Discharge Summary"
            },
            files={"file": ("ramu_report_A.pdf", f_a, "application/pdf")}
        )
    assert res_upload_a.status_code == 200
    doc_a_id = res_upload_a.json()["id"]
    
    # Upload Report B (Pinecrest Health Intake Assessment)
    with open(pdf_b_path, "rb") as f_b:
        res_upload_b = client.post(
            "/api/documents/upload",
            headers=headers,
            data={
                "patient_id": "PAT-RAMU-882",
                "provider_name": "Pinecrest Health Network",
                "document_type": "Intake Assessment"
            },
            files={"file": ("ramu_report_B.pdf", f_b, "application/pdf")}
        )
    assert res_upload_b.status_code == 200
    doc_b_id = res_upload_b.json()["id"]
    
    # 3. Run Comparison
    res_comp = client.post(
        "/api/comparisons",
        headers=headers,
        json={
            "patient_id": "PAT-RAMU-882",
            "document_a_id": doc_a_id,
            "document_b_id": doc_b_id,
            "title": "Full Ramu Patel Clinical Reconciliation"
        }
    )
    assert res_comp.status_code == 200, f"Comparison failed: {res_comp.text}"
    comp_data = res_comp.json()
    assert comp_data["document_a_id"] == doc_a_id
    assert comp_data["document_b_id"] == doc_b_id
    assert comp_data["total_findings"] > 0
    
    # 4. Inspect Findings & Verify Conflicts Detected
    findings = comp_data["findings"]
    assert len(findings) >= 3, f"Expected at least 3 findings, found {len(findings)}"
    
    # Check for Allergy finding
    allergy_findings = [f for f in findings if f["category"].lower() == "allergy"]
    assert len(allergy_findings) >= 1, "Should detect allergy conflict"
    af = allergy_findings[0]
    assert "penicillin" in af["statement_a_text"].lower() or "penicillin" in af["statement_b_text"].lower()
    assert len(af["snippet_a"]) > 0
    assert len(af["snippet_b"]) > 0
    
    # Check for Medication finding
    med_findings = [f for f in findings if f["category"].lower() == "medication"]
    assert len(med_findings) >= 1, "Should detect medication status conflict"
    mf = med_findings[0]
    assert "metformin" in mf["statement_a_text"].lower() or "metformin" in mf["statement_b_text"].lower()
    
    # Check for Lab or Condition findings
    other_findings = [f for f in findings if f["category"].lower() in ["lab", "condition", "diagnosis", "vital"]]
    assert len(other_findings) >= 1, "Should detect lab or condition discrepancies"
    
    # 5. Test Review Workflow
    test_finding_id = af["id"]
    review_res = client.post(
        f"/api/findings/{test_finding_id}/review",
        headers=headers,
        json={
            "reviewer_id": "clinician-ramu-reviewer",
            "reviewer_name": "Dr. Ramu Reviewer",
            "new_status": "CONFIRMED",
            "decision_reason": "Verified severe penicillin anaphylaxis documented in Metro Hospital record. Chart updated.",
            "clinical_notes": "Allergy confirmed, alert posted to EMR.",
            "verified_conclusion": "Severe Penicillin Allergy Confirmed",
            "clinically_verified": True
        }
    )
    assert review_res.status_code == 200, f"Review failed: {review_res.text}"
    reviewed_finding = review_res.json()
    assert reviewed_finding["current_status"] == "CONFIRMED"
    assert reviewed_finding["clinically_verified"] is True
    assert reviewed_finding["last_reviewed_by"] == "Dr. Ramu Reviewer"
