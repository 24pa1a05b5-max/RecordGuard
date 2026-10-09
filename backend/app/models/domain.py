import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, Float, Boolean, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from backend.app.db.session import Base

def generate_uuid() -> str:
    return str(uuid.uuid4())

def utc_now():
    return datetime.now(timezone.utc).replace(tzinfo=None)

class User(Base):
    __tablename__ = "users"
    id = Column(String(128), primary_key=True, default=generate_uuid)
    username = Column(String(128), unique=True, nullable=False)
    email = Column(String(128), nullable=True)
    full_name = Column(String(128), nullable=False)
    role = Column(String(64), default="Clinical Reviewer")
    is_demo = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utc_now)
    updated_at = Column(DateTime, default=utc_now, onupdate=utc_now)

class Patient(Base):
    __tablename__ = "patients"
    id = Column(String(64), primary_key=True) # e.g. PAT-2041
    user_id = Column(String(128), ForeignKey("users.id"), nullable=True)
    full_name = Column(String(128), nullable=False)
    birth_date = Column(String(32), nullable=True)
    gender = Column(String(16), nullable=True)
    mrn = Column(String(64), unique=True, nullable=False)
    is_synthetic = Column(Boolean, default=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utc_now)

    documents = relationship("Document", back_populates="patient", cascade="all, delete-orphan")
    comparisons = relationship("Comparison", back_populates="patient", cascade="all, delete-orphan")

class Document(Base):
    __tablename__ = "documents"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(128), ForeignKey("users.id"), nullable=True)
    patient_id = Column(String(64), ForeignKey("patients.id"), nullable=False)
    filename = Column(String(256), nullable=False)
    original_name = Column(String(256), nullable=False)
    file_path = Column(String(512), nullable=False)
    file_hash = Column(String(64), nullable=False)
    file_type = Column(String(16), nullable=False) # PDF, TXT
    file_size_bytes = Column(Integer, nullable=False)
    provider_name = Column(String(128), nullable=False)
    provider_specialty = Column(String(128), default="General Practice")
    document_type = Column(String(64), nullable=False) # Discharge Summary, Clinic Note, etc.
    document_date = Column(String(32), nullable=True)
    total_pages = Column(Integer, default=1)
    ocr_applied = Column(Boolean, default=False)
    raw_text = Column(Text, nullable=False)
    created_at = Column(DateTime, default=utc_now)

    patient = relationship("Patient", back_populates="documents")
    statements = relationship("ExtractedStatement", back_populates="document", cascade="all, delete-orphan")

class ExtractedStatement(Base):
    __tablename__ = "extracted_statements"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    document_id = Column(String(36), ForeignKey("documents.id"), nullable=False)
    patient_id = Column(String(64), ForeignKey("patients.id"), nullable=False)
    category = Column(String(64), nullable=False) # ALLERGY, MEDICATION, DIAGNOSIS, LAB_RESULT, TREATMENT_INSTRUCTION
    raw_statement = Column(Text, nullable=False)
    normalized_field = Column(String(128), nullable=False)
    normalized_value = Column(String(256), nullable=True)
    normalized_unit = Column(String(64), nullable=True)
    normalized_frequency = Column(String(64), nullable=True)
    status = Column(String(32), default="PRESENT") # PRESENT, NEGATED, DISCONTINUED, UNCERTAIN
    page_number = Column(Integer, nullable=True, default=None)
    char_offset_start = Column(Integer, default=0)
    char_offset_end = Column(Integer, default=0)
    extraction_method = Column(String(64), default="DETERMINISTIC_PARSER")
    extraction_confidence = Column(Float, default=1.0)
    created_at = Column(DateTime, default=utc_now)

    document = relationship("Document", back_populates="statements")

class Comparison(Base):
    __tablename__ = "comparisons"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(128), ForeignKey("users.id"), nullable=True)
    patient_id = Column(String(64), ForeignKey("patients.id"), nullable=False)
    document_a_id = Column(String(36), ForeignKey("documents.id"), nullable=False)
    document_b_id = Column(String(36), ForeignKey("documents.id"), nullable=False)
    title = Column(String(256), nullable=False)
    status = Column(String(32), default="COMPLETED")
    total_findings = Column(Integer, default=0)
    contradiction_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=utc_now)

    patient = relationship("Patient", back_populates="comparisons")
    document_a = relationship("Document", foreign_keys=[document_a_id])
    document_b = relationship("Document", foreign_keys=[document_b_id])
    findings = relationship("Finding", back_populates="comparison", cascade="all, delete-orphan")

class Finding(Base):
    __tablename__ = "findings"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(128), ForeignKey("users.id"), nullable=True)
    comparison_id = Column(String(36), ForeignKey("comparisons.id"), nullable=False)
    patient_id = Column(String(64), ForeignKey("patients.id"), nullable=False)
    document_a_id = Column(String(36), ForeignKey("documents.id"), nullable=True)
    document_b_id = Column(String(36), ForeignKey("documents.id"), nullable=True)
    statement_a_id = Column(String(36), ForeignKey("extracted_statements.id"), nullable=True)
    statement_b_id = Column(String(36), ForeignKey("extracted_statements.id"), nullable=True)
    
    category = Column(String(64), nullable=False)
    field_compared = Column(String(128), nullable=False)
    
    statement_a_text = Column(Text, nullable=False)
    statement_b_text = Column(Text, nullable=False)
    doc_a_name = Column(String(256), nullable=False)
    doc_b_name = Column(String(256), nullable=False)
    provider_a = Column(String(128), nullable=False)
    provider_b = Column(String(128), nullable=False)
    date_a = Column(String(32), nullable=True)
    date_b = Column(String(32), nullable=True)
    page_a = Column(Integer, nullable=True)
    page_b = Column(Integer, nullable=True)
    unit_a = Column(String(64), nullable=True)
    unit_b = Column(String(64), nullable=True)
    status_a = Column(String(32), nullable=True)
    status_b = Column(String(32), nullable=True)
    snippet_a = Column(Text, nullable=False)
    snippet_b = Column(Text, nullable=False)
    
    classification = Column(String(64), nullable=False) # POTENTIAL_CONTRADICTION, TEMPORAL_CHANGE, etc.
    priority_level = Column(String(64), default="STANDARD_REVIEW") # PRIORITY_REVIEW, STANDARD_REVIEW, LOW_PRIORITY, AWAITING_EVIDENCE
    priority_reason = Column(Text, nullable=True)
    rule_triggered = Column(String(128), nullable=True)
    
    model_confidence = Column(Float, nullable=True)
    evidence_completeness = Column(Float, default=1.0) # 0.0 - 1.0
    traceability_score = Column(Float, default=1.0)
    temporal_context = Column(Text, nullable=True)
    uncertainty_notes = Column(Text, nullable=True)
    explanation = Column(Text, nullable=False)
    recommendation = Column(Text, nullable=False)
    
    current_status = Column(String(32), default="PENDING_REVIEW") # PENDING_REVIEW, REVIEWED, CONFIRMED, DISMISSED, REQUIRES_MORE_INFO
    last_reviewed_by = Column(String(128), nullable=True)
    last_reviewed_at = Column(DateTime, nullable=True)
    clinically_verified = Column(Boolean, default=False)
    verified_conclusion = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utc_now)

    comparison = relationship("Comparison", back_populates="findings")
    document_a = relationship("Document", foreign_keys=[document_a_id])
    document_b = relationship("Document", foreign_keys=[document_b_id])
    statement_a = relationship("ExtractedStatement", foreign_keys=[statement_a_id])
    statement_b = relationship("ExtractedStatement", foreign_keys=[statement_b_id])
    reviews = relationship("ReviewDecision", back_populates="finding", cascade="all, delete-orphan")

class ReviewDecision(Base):
    __tablename__ = "review_decisions"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    finding_id = Column(String(36), ForeignKey("findings.id"), nullable=False)
    reviewer_id = Column(String(64), nullable=False)
    reviewer_name = Column(String(128), nullable=False)
    previous_status = Column(String(32), nullable=False)
    new_status = Column(String(32), nullable=False)
    decision_reason = Column(Text, nullable=False)
    clinical_notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utc_now)

    finding = relationship("Finding", back_populates="reviews")

class AuditEvent(Base):
    __tablename__ = "audit_events"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    entity_type = Column(String(64), nullable=False)
    entity_id = Column(String(64), nullable=False)
    action = Column(String(64), nullable=False)
    actor = Column(String(128), nullable=False)
    details_json = Column(Text, nullable=False)
    created_at = Column(DateTime, default=utc_now)

class ModelMetadataRecord(Base):
    __tablename__ = "model_metadata"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    model_version = Column(String(64), nullable=False)
    model_type = Column(String(128), nullable=False)
    trained_at = Column(DateTime, default=utc_now)
    dataset_size = Column(Integer, nullable=False)
    class_distribution_json = Column(Text, nullable=False)
    metrics_json = Column(Text, nullable=False)
    confusion_matrix_json = Column(Text, nullable=False)
    notes = Column(Text, nullable=True)

class SavedReport(Base):
    __tablename__ = "saved_reports"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(128), ForeignKey("users.id"), nullable=True, index=True)
    user_name = Column(String(128), nullable=False, index=True)
    patient_id = Column(String(64), ForeignKey("patients.id"), nullable=True)
    patient_name = Column(String(128), nullable=False)
    report_title = Column(String(256), nullable=False)
    report_type = Column(String(64), default="CLINICAL_RECONCILIATION")
    summary = Column(Text, nullable=True)
    total_findings = Column(Integer, default=0)
    contradictions_count = Column(Integer, default=0)
    verified_count = Column(Integer, default=0)
    report_data = Column(Text, nullable=False)
    file_format = Column(String(16), default="PDF")
    created_at = Column(DateTime, default=utc_now, index=True)

