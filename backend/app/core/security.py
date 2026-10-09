import logging
from typing import Optional, List, Callable
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from backend.app.core.config import settings
from backend.app.core.firebase_auth import verify_firebase_id_token
from backend.app.db.session import get_db
from backend.app.models.domain import User

logger = logging.getLogger("recordguard.security")

# HTTPBearer with auto_error=False to allow graceful fallback when auth is optional/demo
security_bearer = HTTPBearer(auto_error=False)

def get_current_user(
    auth_header: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: Session = Depends(get_db)
) -> User:
    """
    FastAPI dependency that resolves the authenticated user from a Firebase ID token.
    Enforces user-level authorization and synchronizes authenticated identities into SQLite.
    
    If a Bearer token is provided:
        - Verifies signature, expiration, and audience via Firebase Admin SDK
        - Synchronizes/provisions user record in local SQLite database
        - Returns authenticated User
    
    If no Bearer token is provided:
        - If FIREBASE_AUTH_REQUIRED=True: raises 401 Unauthorized
        - If FIREBASE_AUTH_REQUIRED=False: returns the local clinician user for development/demo
    """
    if auth_header and auth_header.credentials:
        # Verify Firebase ID token
        token_str = auth_header.credentials
        claims = verify_firebase_id_token(token_str)
        
        firebase_uid = claims.get("uid") or claims.get("user_id") or claims.get("sub")
        email = claims.get("email") or f"{firebase_uid}@recordguard.local"
        name = claims.get("name") or claims.get("display_name") or f"Clinician {firebase_uid[:8]}"
        role = claims.get("role") or "Clinical Reviewer"
        
        # Synchronize with SQLite user database
        user = db.query(User).filter(User.id == firebase_uid).first()
        if not user:
            # Check by username/email
            user = db.query(User).filter(User.username == email).first()
            
        if not user:
            user = User(
                id=firebase_uid,
                username=email,
                full_name=name,
                role=role,
                is_demo=False
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            logger.info("Provisioned new authenticated Firebase user: %s (role: %s)", firebase_uid, role)
        else:
            # Update name/role if custom claims present
            if claims.get("role") and user.role != claims.get("role"):
                user.role = claims.get("role")
                db.commit()
                db.refresh(user)
                
        return user

    # No token provided
    if settings.FIREBASE_AUTH_REQUIRED:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required. Please provide a valid Firebase Bearer token.",
            headers={"WWW-Authenticate": "Bearer"}
        )

    # In demo/dev mode without token: return default clinician user
    user = db.query(User).filter(User.username == "demo_clinician").first()
    if not user:
        user = db.query(User).filter(User.is_demo == True).first()
    if not user:
        user = User(
            id="demo-dr-rivera",
            username="demo_clinician",
            full_name="Dr. Alex Rivera, MD",
            role="Attending Physician",
            is_demo=True
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        
    return user


def require_roles(allowed_roles: List[str]) -> Callable:
    """
    Dependency factory to enforce role-based authorization for clinical actions.
    Checks that the authenticated user possesses one of the allowed clinical roles.
    """
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        user_role = (current_user.role or "").strip().lower()
        allowed = [r.strip().lower() for r in allowed_roles]
        
        # Attending physician or admin usually has all reviewer permissions
        if user_role not in allowed and "admin" not in user_role and "attending physician" not in user_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Forbidden: insufficient clinical permissions. Required roles: {allowed_roles}, your role: {current_user.role}"
            )
        return current_user
        
    return role_checker
