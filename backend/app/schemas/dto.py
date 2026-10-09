from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict

# Auth
class UserLoginRequest(BaseModel):
    username: str
    password: Optional[str] = None

class FirebaseAuthVerifyRequest(BaseModel):
    id_token: str

class FirebaseAuthVerifyResponse(BaseModel):
    uid: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    is_valid: bool = True
    project_id: str

class UserProfileUpdate(BaseModel):
    full_name: str
    role: Optional[str] = None

class UserResponse(BaseModel):
    id: str
    username: str
    full_name: str
    role: str
    is_demo: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Patients
class PatientCreate(BaseModel):
    id: str
    full_name: str
    birth_date: Optional[str] = None
    gender: Optional[str] = None
    mrn: str
    notes: Optional[str] = None

class PatientResponse(BaseModel):
    id: str
    full_name: str
    birth_date: Optional[str] = None
    gender: Optional[str] = None
    mrn: str
    is_synthetic: bool
    notes: Optional[str] = None
    document_count: Optional[int] = 0
    comparison_count: Optional[int] = 0
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Documents
class DocumentResponse(BaseModel):
    id: str
    patient_id: str
    filename: str
    original_name: str
    file_type: str
    file_size_bytes: int
    provider_name: str
    provider_specialty: str
    document_type: str
    document_date: Optional[str] = None
    total_pages: int
    ocr_applied: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class PageResponse(BaseModel):
    document_id: str
    page_number: int
    total_pages: int
    page_text: str

# Extracted Statements
class ExtractedStatementDTO(BaseModel):
    id: str
    document_id: str
    category: str
    raw_statement: str
    normalized_field: str
    normalized_value: Optional[str] = None
    normalized_unit: Optional[str] = None
    normalized_frequency: Optional[str] = None
    status: str
    page_number: Optional[int] = None
    char_offset_start: int
    char_offset_end: int
    extraction_method: str
    extraction_confidence: float
    model_config = ConfigDict(from_attributes=True)

class DocumentRawResponse(BaseModel):
    id: str
    patient_id: str
    filename: str
    original_name: str
    file_type: str
    file_size_bytes: int
    provider_name: str
    provider_specialty: str
    document_type: str
    document_date: Optional[str] = None
    total_pages: int
    ocr_applied: bool
    raw_text: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Findings & Reviews
class FindingReviewRequest(BaseModel):
    reviewer_id: str
    reviewer_name: str
    new_status: str # CONFIRMED, DISMISSED, REVIEWED, REQUIRES_MORE_INFO, PENDING_REVIEW (or legacy aliases RESOLVED, REQUESTED_DOCS, UNRESOLVED)
    decision_reason: str
    clinical_notes: Optional[str] = None
    verified_conclusion: Optional[str] = None
    clinically_verified: Optional[bool] = None

class ReviewDecisionResponse(BaseModel):
    id: str
    finding_id: str
    reviewer_name: str
    previous_status: str
    new_status: str
    decision_reason: str
    clinical_notes: Optional[str] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class FindingResponse(BaseModel):
    id: str
    comparison_id: str
    patient_id: str
    document_a_id: Optional[str] = None
    document_b_id: Optional[str] = None
    statement_a_id: Optional[str] = None
    statement_b_id: Optional[str] = None
    category: str
    field_compared: str
    statement_a_text: str
    statement_b_text: str
    doc_a_name: str
    doc_b_name: str
    provider_a: str
    provider_b: str
    date_a: Optional[str] = None
    date_b: Optional[str] = None
    page_a: Optional[int] = None
    page_b: Optional[int] = None
    unit_a: Optional[str] = None
    unit_b: Optional[str] = None
    status_a: Optional[str] = None
    status_b: Optional[str] = None
    snippet_a: str
    snippet_b: str
    classification: str
    priority_level: str
    priority_reason: Optional[str] = None
    rule_triggered: Optional[str] = None
    model_confidence: Optional[float] = None
    evidence_completeness: float
    traceability_score: float
    temporal_context: Optional[str] = None
    uncertainty_notes: Optional[str] = None
    explanation: str
    recommendation: str
    current_status: str
    last_reviewed_by: Optional[str] = None
    last_reviewed_at: Optional[datetime] = None
    clinically_verified: bool = False
    verified_conclusion: Optional[str] = None
    created_at: datetime
    reviews: Optional[List[ReviewDecisionResponse]] = []
    model_config = ConfigDict(from_attributes=True)

# Comparisons
class ComparisonCreateRequest(BaseModel):
    patient_id: str
    document_a_id: str
    document_b_id: str
    title: Optional[str] = None
    force_refresh: Optional[bool] = False

class ComparisonResponse(BaseModel):
    id: str
    patient_id: str
    document_a_id: str
    document_b_id: str
    document_a_name: Optional[str] = None
    document_b_name: Optional[str] = None
    title: str
    status: str
    total_findings: int
    contradiction_count: int
    created_at: datetime
    findings: Optional[List[FindingResponse]] = []
    model_config = ConfigDict(from_attributes=True)

# Audit
class AuditResponse(BaseModel):
    id: str
    entity_type: str
    entity_id: str
    action: str
    actor: str
    details: Dict[str, Any]
    created_at: datetime

# Model Info
class ModelStatusResponse(BaseModel):
    is_available: bool
    model_type: str
    model_version: str
    is_trained: bool
    last_trained: Optional[str] = None
    disclosure: str

class ModelMetricsResponse(BaseModel):
    model_type: str
    model_version: str
    trained_at: str
    dataset_size: int
    train_size: int
    val_size: int
    test_size: int
    class_distribution: Dict[str, int]
    accuracy: float
    macro_f1: float
    per_class_metrics: Dict[str, Dict[str, float]]
    confusion_matrix: Dict[str, Any]
    limitations: List[str]
    disclosure: str

# Health
class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    database: str
    ocr_available: bool
    model_available: bool
    demo_mode: bool
    firebase_connected: bool = False
    firebase_project_id: Optional[str] = None

# Saved Reports
class SavedReportCreate(BaseModel):
    patient_id: Optional[str] = None
    patient_name: Optional[str] = "General Clinical Review"
    report_title: str
    report_type: Optional[str] = "CLINICAL_RECONCILIATION"
    summary: Optional[str] = None
    total_findings: Optional[int] = 0
    contradictions_count: Optional[int] = 0
    verified_count: Optional[int] = 0
    report_data: Optional[str] = "{}"
    file_format: Optional[str] = "PDF"

class SavedReportResponse(BaseModel):
    id: str
    user_id: Optional[str] = None
    user_name: str
    patient_id: Optional[str] = None
    patient_name: str
    report_title: str
    report_type: str
    summary: Optional[str] = None
    total_findings: int = 0
    contradictions_count: int = 0
    verified_count: int = 0
    report_data: Optional[str] = None
    file_format: str = "PDF"
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class UserRoleUpdateRequest(BaseModel):
    role: str

class UserCreateAdminRequest(BaseModel):
    username: str
    full_name: str
    role: str = "Clinical Reviewer"
    email: Optional[str] = None

