# RecordGuard AI — Healthcare Record Contradiction Detector (PS-11R3)

[![FastAPI](https://img.shields.io/badge/Backend-FastAPI%200.115+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter%203.44+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.14+-3776AB?logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**RecordGuard AI** is a clinician-facing medical record reconciliation and contradiction detection platform built for hackathon problem statement **PS-11R3**.

The core defining principle:
> **“Show me exactly why this was flagged, where the evidence came from, and what remains uncertain.”**

The system does not claim that one doctor's note is medically correct simply because it is newer, more detailed, or predicted by an AI model. Instead, it surfaces transparent evidence side-by-side, computes evidence completeness and source traceability scores, and guides an authorized reviewer through resolution with an indelible audit trail.

---

## 1. Quickstart Launch Guide

### User Accounts & Dual-Role Support
The application satisfies the multi-user constraint with two distinct roles and distinct functional capabilities:
1. **User Role 1: Clinical Reviewer (`clinician.demo` / `demo2026`)**
   - Access to Patient Reconciliation Workspace, Document Uploads, Contradiction Flags, Side-by-side Evidence Analysis, and Report Generation.
2. **User Role 2: System Administrator (`admin.demo` / `demo2026` or Register with 'System Administrator')**
   - Access to dedicated **Admin Console (`/admin`)**:
     * **Staff & User Role Governance**: View all registered users, promote/demote between Clinician and Admin roles, and provision new hospital staff accounts.
     * **Clinical Audit Trail**: Review indelible timestamps, actions, actor IDs, and cryptographic hashes of all clinical operations. Export audit logs to JSON.
     * **System Security & Integrity Attestation**: Run live cryptographic database verification, check active SaMD guardrails, and audit regulatory compliance.

### Quick Login in the App
On the Login screen, click either:
- **Clinician Demo** (Teal button): Signs in as Dr. Alex Chen (Clinical Reviewer)
- **Admin Demo** (Amber button): Signs in as Dr. Sarah Vance, CMIO (System Administrator) and immediately launches the **Admin Console**.

### Step 1: Start the Python AI Backend
In a terminal window (PowerShell):
```powershell
cd c:\Prototype
$env:PYTHONPATH="."
python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```
The backend initializes the SQLite database, loads the trained ML classifier, and starts the API:
- Interactive API Docs (Swagger): `http://localhost:8000/docs`
- Health check: `http://localhost:8000/api/health`

### Step 2: Start the Flutter Frontend
In a second terminal window:
```powershell
cd c:\Prototype\frontend
# Launch on Chrome (Web)
flutter run -d chrome

# Or launch as native Windows Desktop app:
flutter run -d windows
```

### Mobile APK Installation
A ready-to-install Android release APK is located at:
- **`c:\Prototype\RecordGuard-AI-release.apk`** (54 MB)

---

## 2. Five Demonstration Scenarios (Pre-seeded & Runnable)

The application includes 5 pre-seeded scenarios with genuine clinical PDFs and text documents located in `sample_documents/`:

1. **Scenario 1: Allergy-Record Conflict (Penicillin vs NKDA)**
   - *Doc A (Metro General Hospital Discharge Summary)*: Documents severe Penicillin allergy (urticaria/facial swelling).
   - *Doc B (Pinecrest Clinic Adult Intake Form)*: Documents No Known Drug Allergies (NKDA).
   - *Expected Behavior*: Flags `POTENTIAL_CONTRADICTION`, triaged to `PRIORITY_REVIEW`, displays side-by-side verified quotes, and requests re-verification before prescribing beta-lactam antibiotics.

2. **Scenario 2: Medication Regimen Modification Over Time (Metformin Discontinuation)**
   - *Doc A (Summit Endocrinology Consultation Note, Jan 10)*: Active Metformin 500 mg twice daily.
   - *Doc B (Harborview Cardiology Progress Note, Mar 12)*: Documents Metformin discontinued on Feb 28 due to GI distress.
   - *Expected Behavior*: Classifies as `TEMPORAL_CHANGE`, recognizing therapeutic discontinuation over chronological interval rather than a medical record contradiction.

3. **Scenario 3: Longitudinal Laboratory Tracking (Serial HbA1c Monitoring)**
   - *Doc A (Quest Labs, Jan 15)*: HbA1c 8.2%.
   - *Doc B (Quest Labs, Mar 20)*: HbA1c 7.1%.
   - *Expected Behavior*: Classifies as `TEMPORAL_CHANGE`, recognizing valid physiologic variation over serial collection dates.

4. **Scenario 4: Missing Documentation Omission (Omission != Clinical Absence)**
   - *Doc A (St. Jude Clinic Patient Summary)*: Lists documented Penicillin allergy.
   - *Doc B (Westside Urgent Care Encounter Note)*: Omits the allergy section entirely.
   - *Expected Behavior*: Classifies as `INSUFFICIENT_EVIDENCE` ("Omission is not proof of absence"), triaged to `AWAITING_EVIDENCE`.

5. **Scenario 5: Equivalent Representation & Unit Normalization (Levothyroxine vs Synthroid)**
   - *Doc A (Midwest Thyroid Clinic Note)*: Prescribes `Levothyroxine 0.05 mg once daily`.
   - *Doc B (HealthCare Pharmacy Dispense Record)*: Records `Synthroid 50 mcg QD every morning`.
   - *Expected Behavior*: Normalizes `50 mcg` to `0.05 mg` and brand to generic; identifies `NO_CONTRADICTION`.

---

## 3. Machine Learning Model & Audited Evaluation

The backend serves an audited scikit-learn classifier pipeline:
- **Pipeline Architecture**: Multi-View `FeatureUnion` combining word n-grams (1,2) and character n-grams (3,5) with robust clinical semantic features (negation mismatch, omission lexicons, temporal gap analysis, numeric divergence ratios) feeding into a balanced `LogisticRegression` classifier.
- **Dataset Size (v2.0 Audited)**: **3,600 in-distribution unique paired examples** deterministically generated across 4 classes with fixed seed `42` and strictly **0.0% train-test leakage**:
  - Train: 2,520 (70%)
  - Validation: 540 (15%)
  - Held-Out Stratified Test: 540 (15%)
- **Multi-Stratum Generalization Evaluation**:
  - **Stratified Held-Out Test (n=540)**: Accuracy: **1.0000** | Macro F1: **1.0000**
  - **Group-Disjoint Test (n=971)**: Accuracy: **1.0000** | Macro F1: **1.0000**
  - **Unseen-Template Benchmark (n=513)**: Accuracy: **1.0000** | Macro F1: **1.0000** (Pure Text TF-IDF baseline collapses to **60.04%** on this benchmark).
- **Leakage Audit Report**: Comprehensive audit and leakage remediation documented in [docs/AUDIT_REPORT.md](docs/AUDIT_REPORT.md).
- **Model Artifact**: Serialized to `backend/models/contradiction_classifier.joblib` and metrics saved to `backend/models/model_metrics.json`.
- **Exact Reproduction Commands**:
  ```powershell
  python backend/scripts/audit_existing_dataset.py
  python backend/scripts/generate_dataset.py
  python backend/scripts/train_model.py
  python backend/scripts/evaluate_models.py
  ```

---

## 4. Automated Testing & Verification

### Backend Tests (pytest)
Runs 38 comprehensive automated tests covering health checks, authentication, patient CRUD, normalization engine, deterministic extraction with char offsets, contradiction rules, negation, date intervals, units, synonyms, compatible clinical scenarios, evidence quality scoring, ML predictions, human review state transitions, edge cases, and model metrics:
```powershell
pytest -v
```
**Status: 38 passed in 2.70s (100% pass rate).**

### Flutter Unit & Widget Tests
Runs widget and unit tests verifying `StatusBadge`, `StatCard` KPI interactions, `FindingCard`, `EvidenceModal`, `ReviewModal`, and domain model deserialization:
```powershell
cd frontend
flutter test
```
**Status: 4 passed in 0.9s (100% pass rate).**

### Static Code Analysis
```powershell
cd frontend
flutter analyze --no-fatal-infos
```
**Status: 0 errors.**

---

## 5. Repository Structure

```
c:\Prototype\
├── backend/
│   ├── app/
│   │   ├── api/endpoints.py              # FastAPI REST endpoints
│   │   ├── core/config.py               # Settings and storage configuration
│   │   ├── db/session.py                # SQLite engine & SessionLocal
│   │   ├── models/domain.py             # SQLAlchemy persistent tables
│   │   ├── schemas/dto.py               # Pydantic V2 DTOs
│   │   ├── services/
│   │   │   ├── normalization.py         # Unit, drug, frequency & date normalizer
│   │   │   ├── clinical_extraction.py   # Deterministic entity extractor
│   │   │   ├── contradiction_rules.py   # Explicit clinical rules engine
│   │   │   ├── document_extraction.py   # PyMuPDF page extractor
│   │   │   ├── ocr_service.py           # Tesseract OCR engine fallback
│   │   │   ├── ml_features.py           # TF-IDF & structured transformers
│   │   │   ├── ml_classifier.py         # Scikit-learn inference service
│   │   │   ├── evidence_service.py      # Verbatim snippet & provenance verification
│   │   │   ├── review_service.py        # Clinician review state machine
│   │   │   └── audit_service.py         # Persistent audit trail service
│   │   └── main.py                      # FastAPI application entrypoint
│   ├── data/synthetic/                  # 3,200 synthetic CSV partitions
│   ├── models/                          # Trained .joblib & model_metrics.json
│   ├── scripts/
│   │   ├── generate_dataset.py          # Deterministic synthetic data generator
│   │   ├── train_model.py               # Reproducible ML training pipeline
│   │   ├── generate_sample_documents.py # PDF & TXT scenario document generator
│   │   └── seed_demo.py                 # SQLite database demonstration seeder
│   ├── tests/test_backend.py            # Automated backend test suite
│   ├── requirements.txt                 # Backend dependencies
│   └── .env.example                     # Environment configuration template
│
├── frontend/
│   ├── lib/
│   │   ├── app/
│   │   │   ├── theme.dart               # Material 3 clinical SaaS design system
│   │   │   └── router.dart              # GoRouter configuration
│   │   ├── core/constants.dart          # Constants & storage keys
│   │   ├── models/                      # Dart domain models
│   │   ├── services/api_service.dart    # Dio HTTP client wrapper
│   │   ├── providers/app_providers.dart # Riverpod 3 state providers
│   │   ├── shared/widgets/              # Reusable UI components
│   │   │   ├── app_scaffold.dart        # Responsive sidebar/navigation rail
│   │   │   ├── stat_card.dart           # Interactive KPI card
│   │   │   ├── priority_badge.dart      # Clinical chip badges
│   │   │   ├── finding_card.dart        # Contradiction review card
│   │   │   ├── evidence_modal.dart      # Side-by-side evidence inspection
│   │   │   └── review_modal.dart        # Human verification & audit history modal
│   │   ├── features/                    # Feature screen views
│   │   │   ├── auth/login_screen.dart
│   │   │   ├── dashboard/dashboard_screen.dart
│   │   │   ├── patients/patients_screen.dart
│   │   │   ├── patients/patient_detail_screen.dart
│   │   │   ├── compare/compare_screen.dart
│   │   │   ├── workspace/workspace_screen.dart
│   │   │   ├── queue/queue_screen.dart
│   │   │   ├── model_info/model_info_screen.dart
│   │   │   └── settings/settings_screen.dart
│   │   └── main.dart                    # Flutter entrypoint
│   └── test/widget_test.dart            # Flutter test suite
│
├── sample_documents/                    # Genuine PDFs & TXTs for 5 demo scenarios
├── docs/
│   ├── ARCHITECTURE.md                  # Comprehensive architectural specification
│   ├── DATASET.md                       # Synthetic dataset schema & distribution
│   ├── API.md                           # Complete REST API reference
│   ├── DEMO_GUIDE.md                    # 3-minute hackathon presentation script
│   └── LIMITATIONS.md                   # Ethical & responsible AI boundaries
└── README.md
```

---

## 6. Troubleshooting

- **Backend ModuleNotFoundError**: Make sure to set `$env:PYTHONPATH="."` before executing python commands from `c:\Prototype`.
- **Tesseract OCR**: If OCR is required for scanned non-text PDFs, install Tesseract OCR (e.g. from UB-Mannheim) and add it to your system PATH. When absent, RecordGuard AI gracefully reports that OCR is unavailable without fabricating text.
- **Port Conflict**: If port `8000` is in use, start uvicorn on another port (e.g. `--port 8001`) and update the API URL in the Flutter application under **Settings**.
