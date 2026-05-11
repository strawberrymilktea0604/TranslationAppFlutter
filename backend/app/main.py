from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.logging_config import configure_logging
from app.core.redis_client import get_redis_client, close_redis, health_check
from app.api.v1.endpoints import quota

configure_logging()
logger = logging.getLogger(__name__)


# ==================== LIFESPAN MANAGEMENT ====================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context manager for startup and shutdown events.
    Replaces deprecated @app.on_event() syntax.
    """
    # ==================== STARTUP ====================
    logger.info("🚀 Application starting up...")
    try:
        await get_redis_client()
        logger.info("✅ Redis client initialized successfully")
    except Exception as e:
        logger.warning(f"⚠️  Redis initialization failed: {e}")
        logger.warning("Application will continue without Redis caching (using DB fallback)")
    
    yield
    
    # ==================== SHUTDOWN ====================
    logger.info("🛑 Application shutting down...")
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

