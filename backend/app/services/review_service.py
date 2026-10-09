from datetime import datetime, timezone
from typing import Optional
from fastapi import HTTPException
from sqlalchemy.orm import Session
from backend.app.models.domain import Finding, ReviewDecision
from backend.app.services.audit_service import log_audit_event

# Canonical status model as requested by clinical review requirements:
# PENDING_REVIEW, REVIEWED, CONFIRMED, DISMISSED, REQUIRES_MORE_INFO
STATUS_CANONICAL_MAP = {
    "CONFIRMED": "CONFIRMED",
    "DISMISSED": "DISMISSED",
    "RESOLVED": "RESOLVED",
    "REVIEWED": "REVIEWED",
    "REQUIRES_MORE_INFO": "REQUIRES_MORE_INFO",
    "REQUESTED_DOCS": "REQUIRES_MORE_INFO",
    "PENDING_REVIEW": "PENDING_REVIEW",
    "PENDING": "PENDING_REVIEW",
    "UNRESOLVED": "PENDING_REVIEW",
}

def apply_human_review(
    db: Session,
    finding_id: str,
    reviewer_id: str,
    reviewer_name: str,
    new_status: str,
    decision_reason: str,
    clinical_notes: Optional[str] = None,
    verified_conclusion: Optional[str] = None,
    clinically_verified: Optional[bool] = None
) -> Finding:
    """
    Applies a human review decision to a finding.
    Strictly distinguishes between:
      1. AI-detected potential contradiction (finding.classification)
      2. Human-reviewed finding (finding.current_status)
      3. Clinically verified conclusion (finding.clinically_verified, finding.verified_conclusion)
    Reopening or updating appends to the review audit trail without duplicating finding rows.
    """
    finding = db.query(Finding).filter(Finding.id == finding_id).first()
    if not finding:
        raise HTTPException(status_code=404, detail="Finding not found")
        
    status_key = new_status.upper().strip()
    if status_key not in STATUS_CANONICAL_MAP:
        valid_keys = list(STATUS_CANONICAL_MAP.keys())
        raise HTTPException(status_code=400, detail=f"Invalid review status '{new_status}'. Must be one of: {valid_keys}")
        
    canonical_status = STATUS_CANONICAL_MAP[status_key]
        
    if not decision_reason or len(decision_reason.strip()) < 3:
        raise HTTPException(status_code=400, detail="A substantive decision reason is required for clinical audit compliance.")
        
    previous_status = finding.current_status
    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    
    # Determine clinical verification status
    is_verified = False
    conclusion_text = None
    if canonical_status in ["CONFIRMED", "DISMISSED", "RESOLVED"]:
        if clinically_verified is not None:
            is_verified = clinically_verified
        else:
            is_verified = True
        conclusion_text = verified_conclusion or clinical_notes or f"Conclusion verified by {reviewer_name}: {decision_reason}"
    elif canonical_status == "PENDING_REVIEW":
        # Reopening finding resets clinically_verified flag
        is_verified = False
        conclusion_text = None
    else:
        # REVIEWED or REQUIRES_MORE_INFO
        is_verified = False
        conclusion_text = verified_conclusion
    
    # Create persistent review decision record in audit trail
    review_record = ReviewDecision(
        finding_id=finding.id,
        reviewer_id=reviewer_id,
        reviewer_name=reviewer_name,
        previous_status=previous_status,
        new_status=canonical_status,
        decision_reason=decision_reason.strip(),
        clinical_notes=clinical_notes.strip() if clinical_notes else None,
        created_at=now_utc
    )
    db.add(review_record)
    
    # Update finding in-place (no duplicates)
    finding.current_status = canonical_status
    finding.last_reviewed_by = reviewer_name
    finding.last_reviewed_at = now_utc
    finding.clinically_verified = is_verified
    finding.verified_conclusion = conclusion_text
    
    db.commit()
    db.refresh(finding)
    
    # Log immutable audit event
    log_audit_event(
        db=db,
        entity_type="FINDING",
        entity_id=finding.id,
        action="REVIEW_DECISION",
        actor=reviewer_name,
        details={
            "finding_id": finding.id,
            "field": finding.field_compared,
            "previous_status": previous_status,
            "new_status": canonical_status,
            "clinically_verified": is_verified,
            "verified_conclusion": conclusion_text,
            "reason": decision_reason,
            "notes": clinical_notes
        }
    )
    
    return finding
