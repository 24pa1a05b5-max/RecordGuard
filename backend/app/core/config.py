import os
from pathlib import Path
from typing import Optional

# Resolve base directories safely
BACKEND_DIR = Path(__file__).resolve().parent.parent.parent

class Settings:
    PROJECT_NAME: str = "RecordGuard AI"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "Healthcare Record Contradiction Detector & Provenance Audit Engine"
    API_V1_STR: str = "/api"
    
    # Storage & DB
    DATABASE_URL: str = os.getenv("DATABASE_URL", f"sqlite:///{BACKEND_DIR}/recordguard.db")
    UPLOAD_DIR: Path = BACKEND_DIR / "uploads"
    MODEL_PATH: Path = BACKEND_DIR / "models" / "contradiction_classifier.joblib"
    METRICS_PATH: Path = BACKEND_DIR / "models" / "model_metrics.json"
    SYNTHETIC_DATA_DIR: Path = BACKEND_DIR / "data" / "synthetic"
    
    MAX_UPLOAD_SIZE_MB: int = int(os.getenv("MAX_UPLOAD_SIZE_MB", "25"))
    DEMO_MODE: bool = os.getenv("DEMO_MODE", "true").lower() == "true"
    CORS_ORIGINS: list[str] = ["*"]

    # Firebase Admin SDK configuration (External credentials)
    GOOGLE_APPLICATION_CREDENTIALS: Optional[str] = os.getenv(
        "GOOGLE_APPLICATION_CREDENTIALS",
        r"C:\Users\jaswa\Downloads\prototype-b19c8-firebase-adminsdk-fbsvc-5c0436b61e.json"
        if os.path.exists(r"C:\Users\jaswa\Downloads\prototype-b19c8-firebase-adminsdk-fbsvc-5c0436b61e.json")
        else None
    )
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "prototype-b19c8")
    FIREBASE_AUTH_REQUIRED: bool = os.getenv("FIREBASE_AUTH_REQUIRED", "false").lower() == "true"
    
    def __init__(self):
        self.UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        self.MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
        self.SYNTHETIC_DATA_DIR.mkdir(parents=True, exist_ok=True)

settings = Settings()
