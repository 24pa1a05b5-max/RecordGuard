import json
from datetime import datetime, timezone
from typing import Dict, Any, List
from sqlalchemy.orm import Session
from backend.app.models.domain import AuditEvent

def log_audit_event(
    db: Session,
    entity_type: str,
    entity_id: str,
    action: str,
    actor: str,
    details: Dict[str, Any]
) -> AuditEvent:
    event = AuditEvent(
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        actor=actor,
        details_json=json.dumps(details),
        created_at=datetime.now(timezone.utc).replace(tzinfo=None)
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event

def get_entity_audit_trail(db: Session, entity_id: str) -> List[AuditEvent]:
    return db.query(AuditEvent).filter(AuditEvent.entity_id == entity_id).order_by(AuditEvent.created_at.desc()).all()
