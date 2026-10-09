import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.app.core.config import settings
from backend.app.db.session import engine, Base
from backend.app.api.endpoints import router as api_router
from backend.app.services.ml_classifier import ml_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("recordguard")

from backend.app.db.migrations import ensure_db_schema

# Initialize database tables & migrations
Base.metadata.create_all(bind=engine)
ensure_db_schema()

from contextlib import asynccontextmanager
from backend.app.core.firebase_auth import get_firebase_app

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing RecordGuard AI Backend...")
    ensure_db_schema()
    ml_service.load_model()
    logger.info(f"Model loaded: {ml_service.is_loaded}")
    
    # Safe Firebase Admin initialization
    fb_app = get_firebase_app()
    if fb_app:
        logger.info(f"Firebase Admin SDK connected [Project: {fb_app.project_id}]")
    else:
        logger.info("Firebase Admin SDK running in unconfigured/offline mode")
        
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=settings.DESCRIPTION,
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/")
def root():
    return {
        "message": "Welcome to RecordGuard AI API",
        "version": settings.VERSION,
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=True)
