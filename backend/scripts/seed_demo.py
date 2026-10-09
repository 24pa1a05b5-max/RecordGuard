import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path
from sqlalchemy.orm import Session
from backend.app.core.config import settings
from backend.app.db.session import engine, Base, SessionLocal
from backend.app.models.domain import User, Patient, Document, Comparison, Finding, ReviewDecision, AuditEvent
from backend.app.services.document_extraction import (
    calculate_file_hash, extract_pages_from_pdf, extract_pages_from_txt
)
from backend.app.services.comparison_service import run_document_comparison
from backend.app.services.review_service import apply_human_review

SAMPLE_DIR = Path(__file__).resolve().parent.parent.parent / "sample_documents"

def seed_demo_data(db: Session = None):
    own_session = False
    if db is None:
        db = SessionLocal()
        own_session = True
        
    try:
        # Re-create tables
        Base.metadata.drop_all(bind=engine)
        Base.metadata.create_all(bind=engine)
        
        now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
        
        # 1. Demo User
        demo_user = User(
            id="USR-DEMO-01",
            username="clinician.demo",
            full_name="Dr. Alex Rivera, MD",
            role="Attending Physician / Clinical Reviewer",
            is_demo=True,
            created_at=now_utc
        )
        db.add(demo_user)
        
        # 2. Patients
        patients_data = [
            {
                "id": "PAT-88201",
                "full_name": "Eleanor Vance",
                "birth_date": "1968-04-12",
                "gender": "Female",
                "mrn": "SYN-88201",
                "notes": "Scenario 1: Allergy conflict between hospital discharge and outpatient intake."
            },
            {
                "id": "PAT-44910",
                "full_name": "Arthur Pendelton",
                "birth_date": "1957-09-22",
                "gender": "Male",
                "mrn": "SYN-44910",
                "notes": "Scenario 2: Medication discontinuation chronological timeline."
            },
            {
                "id": "PAT-11029",
                "full_name": "Grace Hopper",
                "birth_date": "1972-11-05",
                "gender": "Female",
                "mrn": "SYN-11029",
                "notes": "Scenario 3: Longitudinal HbA1c diabetic monitoring."
            },
            {
                "id": "PAT-99034",
                "full_name": "Marcus Brody",
                "birth_date": "1980-03-18",
                "gender": "Male",
                "mrn": "SYN-99034",
                "notes": "Scenario 4: Missing allergy record in acute urgent care encounter."
            },
            {
                "id": "PAT-33421",
                "full_name": "Clara Oswald",
                "birth_date": "1989-11-23",
                "gender": "Female",
                "mrn": "SYN-33421",
                "notes": "Scenario 5: Equivalent dosage representations (0.05 mg vs 50 mcg)."
            }
        ]
        
        for p in patients_data:
            db.add(Patient(
                id=p["id"],
                full_name=p["full_name"],
                birth_date=p["birth_date"],
                gender=p["gender"],
                mrn=p["mrn"],
                is_synthetic=True,
                notes=p["notes"],
                created_at=now_utc
            ))
        db.commit()
        
        # Helper to ingest document
        def ingest_file(patient_id, file_path, provider, doc_type, doc_date):
            content = open(file_path, "rb").read()
            ext = file_path.suffix.lstrip(".").lower()
            file_hash = calculate_file_hash(content)
            doc_id = str(uuid.uuid4())
            safe_name = f"{doc_id}_{file_path.name}"
            dest = settings.UPLOAD_DIR / safe_name
            with open(dest, "wb") as f:
                f.write(content)
                
            if ext == "pdf":
                pages, ocr_used, _ = extract_pages_from_pdf(content)
            else:
                pages, ocr_used, _ = extract_pages_from_txt(content)
                
            combined = "\n\n--- PAGE BREAK ---\n\n".join([p["text"] for p in pages])
            doc = Document(
                id=doc_id,
                patient_id=patient_id,
                filename=safe_name,
                original_name=file_path.name,
                file_path=str(dest),
                file_hash=file_hash,
                file_type=ext.upper(),
                file_size_bytes=len(content),
                provider_name=provider,
                provider_specialty="Medicine",
                document_type=doc_type,
                document_date=doc_date,
                total_pages=len(pages),
                ocr_applied=ocr_used,
                raw_text=combined,
                created_at=now_utc
            )
            db.add(doc)
            db.commit()
            db.refresh(doc)
            return doc

        # Ingest Scenarios
        # Scenario 1
        d1a = ingest_file("PAT-88201", SAMPLE_DIR / "scenario1_docA_metro_discharge.pdf", "Metro General - Dr. Vance", "Discharge Summary", "2026-03-12")
        d1b = ingest_file("PAT-88201", SAMPLE_DIR / "scenario1_docB_pinecrest_intake.pdf", "Pinecrest Clinic - Dr. Lin", "Intake Form", "2026-03-15")
        comp1 = run_document_comparison(db, "PAT-88201", d1a.id, d1b.id, "Hospital Discharge vs Clinic Intake Reconciliation")

        # Scenario 2
        d2a = ingest_file("PAT-44910", SAMPLE_DIR / "scenario2_docA_endocrinology_jan.pdf", "Summit Endocrinology - Dr. Thorne", "Consultation Note", "2026-01-10")
        d2b = ingest_file("PAT-44910", SAMPLE_DIR / "scenario2_docB_cardiology_mar.pdf", "Harborview Cardiology - Dr. Rostova", "Progress Note", "2026-03-12")
        run_document_comparison(db, "PAT-44910", d2a.id, d2b.id, "Endocrinology vs Cardiology Longitudinal Regimen")

        # Scenario 3
        d3a = ingest_file("PAT-11029", SAMPLE_DIR / "scenario3_docA_lab_january.pdf", "Quest Labs", "Lab Report", "2026-01-15")
        d3b = ingest_file("PAT-11029", SAMPLE_DIR / "scenario3_docB_lab_march.pdf", "Quest Labs", "Lab Report", "2026-03-20")
        run_document_comparison(db, "PAT-11029", d3a.id, d3b.id, "Serial Diabetic Panel Reconciliation")

        # Scenario 4
        d4a = ingest_file("PAT-99034", SAMPLE_DIR / "scenario4_docA_allergy_record.txt", "St. Jude Clinic", "Patient Summary", "2026-02-05")
        d4b = ingest_file("PAT-99034", SAMPLE_DIR / "scenario4_docB_urgentcare_visit.txt", "Westside Urgent Care", "Encounter Note", "2026-02-18")
        run_document_comparison(db, "PAT-99034", d4a.id, d4b.id, "Primary Clinic vs Urgent Care Reconciliation")

        # Scenario 5
        d5a = ingest_file("PAT-33421", SAMPLE_DIR / "scenario5_docA_endocrinology.pdf", "Midwest Thyroid - Dr. Song", "Clinic Note", "2026-02-02")
        d5b = ingest_file("PAT-33421", SAMPLE_DIR / "scenario5_docB_pharmacy_dispense.pdf", "HealthCare Pharmacy", "Dispense Record", "2026-02-04")
        run_document_comparison(db, "PAT-33421", d5a.id, d5b.id, "Thyroid Rx vs Pharmacy Dispense Record")

        # Demonstrate one reviewed finding with an audit trail
        finding_to_review = db.query(Finding).filter(Finding.comparison_id == comp1.id, Finding.category == "ALLERGY").first()
        if finding_to_review:
            apply_human_review(
                db=db,
                finding_id=finding_to_review.id,
                reviewer_id="USR-DEMO-01",
                reviewer_name="Dr. Alex Rivera, MD",
                new_status="CONFIRMED",
                decision_reason="Re-interviewed patient; confirmed severe penicillin rash in childhood. Pinecrest intake was incorrectly recorded.",
                clinical_notes="Updated EHR allergy alert to Penicillin (Anaphylaxis/Urticaria).",
                verified_conclusion="Clinically verified active allergy to Penicillin. Intake record was discordant due to patient omission during intake.",
                clinically_verified=True
            )

        print("Database seeded with 5 fictional patients, 10 documents, comparisons, and audit records!")
    finally:
        if own_session:
            db.close()

if __name__ == "__main__":
    seed_demo_data()
