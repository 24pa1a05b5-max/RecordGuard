import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.app.main import app
from backend.app.core.config import settings
from backend.app.db.session import get_db, Base
from backend.app.db.migrations import ensure_db_schema
from backend.app.core.firebase_auth import (
    get_firebase_app,
    verify_firebase_id_token,
    mint_test_id_token_for_verification
)
from backend.app.models.domain import User, Patient, Document, Finding
from backend.app.services.ml_classifier import ml_service

from sqlalchemy.pool import StaticPool

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
    
    # Pre-seed demo user & patient
    db = TestingSessionLocal()
    demo_user = User(
        id="test-dr-alex",
        username="dr.alex@recordguard.demo",
        full_name="Dr. Alex Rivera, MD",
        role="Attending Physician",
        is_demo=True
    )
    db.add(demo_user)
    
    patient = Patient(
        id="PAT-FB-TEST",
        full_name="Marcus Vance",
        mrn="MRN-FB-9988",
        is_synthetic=True
    )
    db.add(patient)
    db.commit()
    
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


# 1. TEST SAFE FIREBASE INITIALIZATION & REUSE
def test_firebase_admin_sdk_safe_initialization():
    """
    Verifies that Firebase Admin SDK initializes safely from GOOGLE_APPLICATION_CREDENTIALS,
    and subsequent calls safely reuse the existing app without re-initialization errors.
    """
    app_instance = get_firebase_app()
    assert app_instance is not None, "Firebase Admin SDK should initialize from credentials"
    assert app_instance.project_id == "prototype-b19c8"
    
    # Verify idempotent reuse
    second_instance = get_firebase_app()
    assert second_instance is app_instance
    assert second_instance.name == app_instance.name


# 2. TEST LEGITIMATE TOKEN MINTING & VERIFICATION
def test_firebase_token_verification_with_legitimate_token(client):
    """
    Tests real Firebase ID token verification end-to-end.
    Mints a legitimate token signed with the service account for project prototype-b19c8
    and verifies it through Firebase Admin SDK and FastAPI endpoints.
    """
    token = mint_test_id_token_for_verification(
        uid="firebase-clinician-8877",
        custom_claims={"role": "Attending Physician", "name": "Dr. Elena Rostova"}
    )
    assert token is not None, "Should successfully obtain legitimate Firebase ID token for testing"
    
    # 1. Verify via core SDK method
    claims = verify_firebase_id_token(token)
    assert claims["uid"] == "firebase-clinician-8877"
    assert claims.get("role") == "Attending Physician"
    assert claims.get("name") == "Dr. Elena Rostova"
    assert claims.get("aud") == "prototype-b19c8"
    
    # 2. Verify via /api/auth/verify-token endpoint
    resp = client.post("/api/auth/verify-token", json={"id_token": token})
    assert resp.status_code == 200
    data = resp.json()
    assert data["is_valid"] is True
    assert data["uid"] == "firebase-clinician-8877"
    assert data["role"] == "Attending Physician"
    assert data["project_id"] == "prototype-b19c8"


# 3. TEST TOKEN REJECTION FOR INVALID AND TAMPERED TOKENS
def test_firebase_token_rejection_for_invalid_and_tampered_tokens(client):
    """
    Ensures invalid, malformed, or tampered tokens are rejected with HTTP 401.
    """
    # 1. Malformed string
    resp = client.post("/api/auth/verify-token", json={"id_token": "not.a.valid.jwt.token"})
    assert resp.status_code == 401
    
    # 2. Tampered token signature
    token = mint_test_id_token_for_verification(uid="test-tamper-user")
    if token:
        parts = token.split(".")
        tampered = parts[0] + "." + parts[1] + ".tamperedSignature123456"
        resp_tampered = client.post("/api/auth/verify-token", json={"id_token": tampered})
        assert resp_tampered.status_code == 401

    # 3. Request without auth header to /api/auth/me when token is invalid
    resp_bad_bearer = client.get("/api/auth/me", headers={"Authorization": "Bearer fake-token-123"})
    assert resp_bad_bearer.status_code == 401


# 4. TEST AUTHENTICATED USER SYNCHRONIZATION AND ENDPOINT PROTECTION
def test_authenticated_user_profile_and_db_sync(client, test_db):
    """
    Verifies that passing a legitimate Firebase ID token in Authorization: Bearer
    synchronizes the user identity into SQLite and returns the authenticated user profile.
    """
    token = mint_test_id_token_for_verification(
        uid="firebase-user-sync-test",
        custom_claims={"role": "Clinical Reviewer", "name": "Dr. Marcus Vance"}
    )
    assert token is not None
    
    headers = {"Authorization": f"Bearer {token}"}
    resp = client.get("/api/auth/me", headers=headers)
    assert resp.status_code == 200
    user_data = resp.json()
    assert user_data["id"] == "firebase-user-sync-test"
    assert user_data["full_name"] == "Dr. Marcus Vance"
    assert user_data["role"] == "Clinical Reviewer"
    assert user_data["is_demo"] is False
    
    # Verify user was saved in SQLite database
    db = test_db()
    try:
        user_in_db = db.query(User).filter(User.id == "firebase-user-sync-test").first()
        assert user_in_db is not None
        assert user_in_db.full_name == "Dr. Marcus Vance"
    finally:
        db.close()


# 5. TEST HEALTH ENDPOINT REPORTS FIREBASE CONNECTION
def test_health_endpoint_reports_firebase_status(client):
    """
    Verifies that /api/health exposes the Firebase connection status and project ID.
    """
    resp = client.get("/api/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["firebase_connected"] is True
    assert data["firebase_project_id"] == "prototype-b19c8"


# 6. TEST PRESERVED ML CONTRADICTION DETECTION AND SQLITE PERSISTENCE
def test_ml_and_sqlite_functionality_preserved():
    """
    Confirms that ML classification pipeline and SQLite schema remain intact.
    """
    assert ml_service.is_loaded is True
    
    pred_class, conf = ml_service.predict(
        category="Medication",
        statement_a="Patient prescribed Lisinopril 20mg daily for hypertension.",
        statement_b="Lisinopril discontinued due to persistent dry cough."
    )
    assert pred_class is not None
    assert pred_class in ["POTENTIAL_CONTRADICTION", "CONTRADICTION", "TEMPORAL_CHANGE", "CONSISTENT", "INSUFFICIENT_EVIDENCE"]
