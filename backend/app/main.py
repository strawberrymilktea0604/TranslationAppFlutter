from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import asyncio
import os

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.logging_config import configure_logging
from app.core.redis_client import get_redis_client, close_redis, health_check
from app.api.v1.endpoints import quota, management
from app.services.stt_service import STTService
from app.services.backup_service import DatabaseBackupService, BackupScheduler

configure_logging()
logger = logging.getLogger(__name__)

# Global backup scheduler
backup_scheduler: BackupScheduler = None


# ==================== LIFESPAN MANAGEMENT ====================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context manager for startup and shutdown events.
    Replaces deprecated @app.on_event() syntax.
    """
    global backup_scheduler
    
    # ==================== STARTUP ====================
    logger.info("🚀 Application starting up...")
    try:
        await get_redis_client()
        logger.info("✅ Redis client initialized successfully")
    except Exception as e:
        logger.warning(f"⚠️  Redis initialization failed: {e}")
        logger.warning("Application will continue without Redis caching (using DB fallback)")
    
    try:
        logger.info("⏳ Preloading STT Model in background thread...")
        await asyncio.to_thread(STTService.preload_model)
        logger.info("✅ STT Model preloaded successfully")
    except Exception as e:
        logger.error(f"❌ Failed to preload STT Model: {e}")
        logger.warning("Application will try to load the model on first request")
    
    # ==================== INITIALIZE BACKUP SCHEDULER ====================
    try:
        backup_dir = os.getenv("BACKUP_DIR", "/backups/database")
        backup_service = DatabaseBackupService(
            db_url=settings.DATABASE_URL,
            backup_dir=backup_dir,
            max_backups=7,
            compress=True,
        )
        
        backup_scheduler = BackupScheduler(backup_service)
        backup_scheduler.initialize_scheduler()
        backup_scheduler.start()
        logger.info("✅ Database backup scheduler initialized and started")
    except Exception as e:
        logger.warning(f"⚠️  Backup scheduler initialization failed: {e}")
        logger.warning("Backups can still be triggered manually via API")

    # ==================== SEED DEFAULT DATA ====================
    try:
        from app.core.database import async_session_maker
        from app.models.user import User
        from app.core.security import hash_password
        from app.core.config import settings
        from sqlalchemy.future import select

        async with async_session_maker() as session:
            # Check if admin exists
            result = await session.execute(select(User).where(User.email == settings.DEFAULT_ADMIN_EMAIL))
            admin_user = result.scalars().first()
            if not admin_user:
                logger.info("🌱 Creating default admin account...")
                new_admin = User(
                    email=settings.DEFAULT_ADMIN_EMAIL,
                    password_hash=hash_password(settings.DEFAULT_ADMIN_PASSWORD),
                    first_name="Super",
                    last_name="Admin",
                    role="admin",
                    status="active"
                )
                session.add(new_admin)
                await session.commit()
                logger.info(f"✅ Default admin account created: {settings.DEFAULT_ADMIN_EMAIL}")
    except Exception as e:
        logger.error(f"❌ Failed to seed default data: {e}")

    yield
    
    # ==================== SHUTDOWN ====================
    logger.info("🛑 Application shutting down...")
    
    # Stop backup scheduler
    if backup_scheduler:
        try:
            backup_scheduler.stop()
            logger.info("✅ Backup scheduler stopped")
        except Exception as e:
            logger.warning(f"⚠️  Backup scheduler shutdown error: {e}")
    
    try:
        await close_redis()
        logger.info("✅ Redis connection closed successfully")
    except Exception as e:
        logger.warning(f"⚠️  Redis shutdown failed: {e}")


# ==================== APP CONFIGURATION ====================
app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=settings.BACKEND_CORS_ALLOW_CREDENTIALS,
    allow_methods=settings.BACKEND_CORS_ALLOW_METHODS,
    allow_headers=settings.BACKEND_CORS_ALLOW_HEADERS,
)

# ==================== API ROUTERS ====================
app.include_router(api_router, prefix=settings.API_V1_STR)
app.include_router(quota.router, prefix="/api/quotas", tags=["AI Quotas"])
app.include_router(management.router, tags=["management"])

# ==================== HEALTH CHECK ====================
@app.get("/health", tags=["health"])
async def health_check_endpoint():
    """Health check endpoint for monitoring"""
    redis_status = "ok" if await health_check() else "unavailable"
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT,
        "project": settings.PROJECT_NAME,
        "redis": redis_status
    }

