# RecordGuard AI — REST API Documentation

The RecordGuard AI backend exposes a typed REST API documented via OpenAPI / Swagger. When the backend is running, interactive API exploration is accessible at:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

---

## 1. System & Authentication

### `GET /api/health`
Queries overall backend subsystem health.
- **Response `200 OK`**:
  ```json
  {
    "status": "healthy",
    "version": "1.0.0",
    "environment": "development",
    "database": "sqlite_connected",
    "ocr_available": false,
    "model_available": true,
    "demo_mode": true
  }
  ```

### `POST /api/auth/demo-login`
Authenticates an authorized clinician for demonstration purposes.
- **Request Body**:
  ```json
  { "username": "clinician.demo" }
  ```
- **Response `200 OK`**:
  ```json
  {
    "id": "USR-DEMO-01",
    "username": "clinician.demo",
    "full_name": "Dr. Alex Rivera, MD",
    "role": "Attending Physician / Clinical Reviewer",
    "is_demo": true,
    "created_at": "2026-03-12T10:00:00Z"
  }
  ```

---

## 2. Patient Cohort Management

### `GET /api/patients`
Lists all fictional patient profiles.

### `POST /api/patients`
Registers a new synthetic patient record.
- **Request Body**:
  ```json
  {
    "id": "PAT-901",
    "full_name": "Synthetic Patient",
    "birth_date": "1975-04-10",
    "gender": "Female",
    "mrn": "SYN-901",
    "notes": "Scenario testing"
  }
  ```

### `GET /api/patients/{patient_id}`
Retrieves details, document counts, and comparisons for a patient.

---

## 3. Document Ingestion & Page Extraction

### `POST /api/documents/upload`
Uploads a medical document (PDF or TXT) for text extraction with provenance.
- **Content-Type**: `multipart/form-data`
- **Fields**:
  - `patient_id`: String (Required)
  - `provider_name`: String (Required)
  - `provider_specialty`: String (Optional)
  - `document_type`: String (Required, e.g. "Discharge Summary")
  - `document_date`: String (Optional, e.g. "2026-03-12")
  - `file`: File binary (Required, `.pdf` or `.txt`, max 25MB)
- **Response `200 OK`**: Returns `DocumentResponse` with extracted page count and SHA-256 hash.

### `GET /api/documents/{document_id}`
Fetches document metadata.

### `GET /api/documents/{document_id}/pages/{page_number}`
Retrieves extracted text for a specific page.

---

## 4. Record Comparison & Surveillance

### `POST /api/comparisons`
Initiates comparative surveillance between two documents belonging to a patient.
- **Request Body**:
  ```json
  {
    "patient_id": "PAT-88201",
    "document_a_id": "doc-uuid-a",
    "document_b_id": "doc-uuid-b",
    "title": "Hospital Discharge vs Clinic Intake Reconciliation"
  }
  ```
- **Response `200 OK`**: Returns `ComparisonResponse` with total findings and contradictions flagged.

### `GET /api/comparisons/{comparison_id}`
Fetches comparison status and associated findings.

---

## 5. Findings, Verification & Audit

### `GET /api/findings`
Lists findings with optional query parameters: `patient_id`, `status`, `priority`.

### `GET /api/findings/{finding_id}`
Fetches finding details with side-by-side statements, provenance snippets, and review history.

### `POST /api/findings/{finding_id}/review`
Records an authorized clinician's review decision with mandatory rationale.
- **Request Body**:
  ```json
  {
    "reviewer_id": "USR-DEMO-01",
    "reviewer_name": "Dr. Alex Rivera, MD",
    "new_status": "CONFIRMED",
    "decision_reason": "Patient verified severe allergy history via direct telephone consultation.",
    "clinical_notes": "Allergy profile updated in EHR."
  }
  ```

### `GET /api/findings/{finding_id}/audit`
Retrieves chronological audit trail of all actions and state transitions on a finding.

---

## 6. Model Transparency & Demo Reset

### `GET /api/models/status`
Returns ML model availability, type, version, and training status.

### `GET /api/models/metrics`
Returns actual evaluation metrics on the held-out test set, confusion matrix, and disclosures.

### `POST /api/demo/reset`
Re-initializes SQLite database with standard demonstration scenarios and sample records.
