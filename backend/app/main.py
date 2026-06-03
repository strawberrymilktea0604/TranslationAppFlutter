import asyncio
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.api import api_router
from app.api.v1.endpoints import management, quota
from app.core.config import settings
from app.core.logging_config import configure_logging
from app.core.redis_client import close_redis, get_redis_client, health_check
from app.services.backup_service import BackupScheduler, DatabaseBackupService
from app.services.stt_service import STTService

configure_logging()
logger = logging.getLogger(__name__)

# Global backup scheduler
backup_scheduler: BackupScheduler | None = None


async def ensure_default_admin_account() -> None:
    """Create or repair the default admin account on every backend startup."""
    from sqlalchemy.exc import IntegrityError, SQLAlchemyError
    from sqlalchemy.future import select

    from app.core.database import async_session_maker
    from app.core.security import hash_password
    from app.models.user import User

    max_attempts = 12
    delay_seconds = 5

    for attempt in range(1, max_attempts + 1):
        try:
            async with async_session_maker() as session:
                result = await session.execute(
                    select(User).where(User.email == settings.DEFAULT_ADMIN_EMAIL)
                )
                admin_user = result.scalars().first()

                if admin_user is None:
                    logger.info("Creating default admin account...")
                    session.add(
                        User(
                            email=settings.DEFAULT_ADMIN_EMAIL,
                            password_hash=hash_password(
                                settings.DEFAULT_ADMIN_PASSWORD
                            ),
                            first_name="Super",
                            last_name="Admin",
                            role="admin",
                            status="active",
                        )
                    )
                    try:
                        await session.commit()
                    except IntegrityError:
                        await session.rollback()
                        logger.info(
                            "Default admin was created concurrently: %s",
                            settings.DEFAULT_ADMIN_EMAIL,
                        )
                    else:
                        logger.info(
                            "Default admin account created: %s",
                            settings.DEFAULT_ADMIN_EMAIL,
                        )
                    return

                changed = False
                if admin_user.role != "admin":
                    admin_user.role = "admin"
                    changed = True
                if admin_user.status != "active":
                    admin_user.status = "active"
                    changed = True

                if changed:
                    await session.commit()
                    logger.info(
                        "Default admin account repaired: %s",
                        settings.DEFAULT_ADMIN_EMAIL,
                    )
                else:
                    logger.info(
                        "Default admin account already exists: %s",
                        settings.DEFAULT_ADMIN_EMAIL,
                    )
                return
        except SQLAlchemyError as e:
            logger.warning(
                "Default admin seed attempt %s/%s failed: %s",
                attempt,
                max_attempts,
                e,
            )
        except Exception as e:
            logger.warning(
                "Default admin seed attempt %s/%s failed unexpectedly: %s",
                attempt,
                max_attempts,
                e,
            )

        if attempt < max_attempts:
            await asyncio.sleep(delay_seconds)

    raise RuntimeError("Failed to seed default admin account after startup retries")


# ==================== LIFESPAN MANAGEMENT ====================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context manager for startup and shutdown events.
    Replaces deprecated @app.on_event() syntax.
    """
    global backup_scheduler

    # ==================== STARTUP ====================
    logger.info("Application starting up...")
    # Create/repair the bootstrap admin before optional services. This must be
    # reliable on the first docker up, when Postgres may still be warming up.
    await ensure_default_admin_account()

    try:
        await get_redis_client()
        logger.info("Redis client initialized successfully")
    except Exception as e:
        logger.warning("Redis initialization failed: %s", e)
        logger.warning("Application will continue without Redis caching")

    if settings.STT_PRELOAD_ENABLED:
        try:
            logger.info("Preloading STT model in background thread...")
            await asyncio.wait_for(
                asyncio.to_thread(STTService.preload_model),
                timeout=settings.STT_PRELOAD_TIMEOUT_SECONDS,
            )
            logger.info("STT model preloaded successfully")
        except asyncio.TimeoutError:
            logger.error(
                "STT model preload timed out after %ss",
                settings.STT_PRELOAD_TIMEOUT_SECONDS,
            )
            raise
        except Exception as e:
            logger.error("Failed to preload STT model: %s", e)
            raise
    else:
        logger.warning("STT model preload disabled by configuration")

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
        logger.info("Database backup scheduler initialized and started")
    except Exception as e:
        logger.warning("Backup scheduler initialization failed: %s", e)
        logger.warning("Backups can still be triggered manually via API")

    yield

    # ==================== SHUTDOWN ====================
    logger.info("Application shutting down...")

    if backup_scheduler:
        try:
            backup_scheduler.stop()
            logger.info("Backup scheduler stopped")
        except Exception as e:
            logger.warning("Backup scheduler shutdown error: %s", e)

    try:
        await close_redis()
        logger.info("Redis connection closed successfully")
    except Exception as e:
        logger.warning("Redis shutdown failed: %s", e)


# ==================== APP CONFIGURATION ====================
app = FastAPI(title=settings.PROJECT_NAME, version="1.0.0", lifespan=lifespan)

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
    """Health check endpoint for monitoring."""
    redis_status = "ok" if await health_check() else "unavailable"
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT,
        "project": settings.PROJECT_NAME,
        "redis": redis_status,
    }
