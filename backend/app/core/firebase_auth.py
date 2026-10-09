import os
import logging
from pathlib import Path
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
import firebase_admin
from firebase_admin import credentials, auth
from backend.app.core.config import settings

logger = logging.getLogger("recordguard.firebase")

_firebase_app: Optional[firebase_admin.App] = None

def get_firebase_app() -> Optional[firebase_admin.App]:
    """
    Safely retrieves the initialized Firebase Admin App or initializes it.
    Reuses existing initialization if already present.
    Strictly prevents exposing private keys or sensitive credentials in logs.
    """
    global _firebase_app
    
    # 1. Check if default app is already initialized in firebase_admin
    try:
        app = firebase_admin.get_app()
        _firebase_app = app
        return app
    except ValueError:
        pass
        
    # 2. Check for external credential path via GOOGLE_APPLICATION_CREDENTIALS
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or settings.GOOGLE_APPLICATION_CREDENTIALS
    
    if cred_path and os.path.exists(cred_path):
        try:
            # Initialize with certificate file outside the project directory
            cred = credentials.Certificate(cred_path)
            app = firebase_admin.initialize_app(cred, {
                "projectId": settings.FIREBASE_PROJECT_ID
            })
            _firebase_app = app
            logger.info("Firebase Admin SDK initialized successfully for project: %s", app.project_id)
            return app
        except Exception as e:
            logger.error("Failed to initialize Firebase Admin SDK with credentials file: %s", type(e).__name__)
            return None
            
    # 3. Fallback to default application credentials if available in environment
    try:
        app = firebase_admin.initialize_app()
        _firebase_app = app
        logger.info("Firebase Admin SDK initialized with Application Default Credentials.")
        return app
    except Exception as e:
        logger.warning("Firebase Admin SDK not initialized: credentials not found (%s)", type(e).__name__)
        return None


def verify_firebase_id_token(id_token: str) -> Dict[str, Any]:
    """
    Verifies a Firebase ID token sent from client applications.
    Returns decoded token payload (safe user claims).
    Raises HTTPException 401 on missing, expired, or invalid tokens.
    """
    app = get_firebase_app()
    if not app:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase Authentication service is currently unconfigured or unavailable."
        )
        
    if not id_token or not isinstance(id_token, str):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Bearer token."
        )
        
    # Strip any extraneous quotes or bearer prefix if passed directly
    token_str = id_token.strip()
    if token_str.lower().startswith("bearer "):
        token_str = token_str[7:].strip()
        
    try:
        decoded_token = auth.verify_id_token(token_str, app=app, check_revoked=False)
        return decoded_token
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase ID token has expired. Please refresh your session."
        )
    except auth.RevokedIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase ID token has been revoked."
        )
    except auth.InvalidIdTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase ID token."
        )
    except Exception as e:
        logger.warning("Token verification failure: %s", type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed: could not verify Firebase ID token."
        )


def mint_test_id_token_for_verification(
    uid: str = "test-clinician-reviewer",
    custom_claims: Optional[Dict[str, Any]] = None
) -> Optional[str]:
    """
    Utility for automated testing: exchanges a service-account signed custom token
    for a legitimate Firebase ID token through Google Identity Toolkit.
    Used exclusively in testing to rigorously verify token authentication end-to-end.
    """
    app = get_firebase_app()
    if not app:
        return None
        
    try:
        import requests
        from google.oauth2 import service_account
        from google.auth.transport.requests import Request
        
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or settings.GOOGLE_APPLICATION_CREDENTIALS
        if not cred_path or not os.path.exists(cred_path):
            return None
            
        claims = custom_claims or {"role": "Attending Physician", "name": "Dr. Alex Rivera"}
        custom_token = auth.create_custom_token(uid, claims, app=app)
        token_str = custom_token.decode() if isinstance(custom_token, bytes) else custom_token
        
        # Load credentials directly from external file path without metadata server dependency
        creds = service_account.Credentials.from_service_account_file(
            cred_path,
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        creds.refresh(Request())
        
        list_resp = requests.get(
            f"https://firebase.googleapis.com/v1beta1/projects/{app.project_id}/webApps",
            headers={"Authorization": f"Bearer {creds.token}"},
            timeout=10
        )
        if list_resp.status_code != 200:
            return None
            
        apps = list_resp.json().get("apps", [])
        if not apps:
            return None
            
        app_id = apps[0]["appId"]
        config_resp = requests.get(
            f"https://firebase.googleapis.com/v1beta1/projects/{app.project_id}/webApps/{app_id}/config",
            headers={"Authorization": f"Bearer {creds.token}"},
            timeout=10
        )
        if config_resp.status_code != 200:
            return None
            
        api_key = config_resp.json().get("apiKey")
        if not api_key:
            return None
            
        exchange_resp = requests.post(
            f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
            json={"token": token_str, "returnSecureToken": True},
            timeout=10
        )
        if exchange_resp.status_code == 200:
            return exchange_resp.json().get("idToken")
        return None
    except Exception as e:
        logger.warning("Could not mint test ID token: %s", str(e))
        return None
