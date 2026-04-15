from fastapi import FastAPI
import logging

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.redis_client import get_redis_client, close_redis, health_check
from app.api.v1.endpoints import quota
from app.api.v1.endpoints import auth

logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0"
)
app.include_router(api_router, prefix=settings.API_V1_STR)

# Include routers
# app.include_router(translate.router)
# app.include_router(user.router)

# Đăng ký API Quota
app.include_router(quota.router, prefix="/api/quotas", tags=["AI Quotas"])


@app.on_event("startup")
async def startup_event():
    """Initialize Redis connection on app startup"""
    try:
        await get_redis_client()
        logger.info("✅ Redis client initialized on startup")
    except Exception as e:
        logger.warning(f"⚠️  Redis initialization failed: {e}")
        logger.warning("Application will continue without Redis caching (using DB fallback)")


@app.on_event("shutdown")
async def shutdown_event():
    """Close Redis connection on app shutdown"""
    await close_redis()
    logger.info("✅ Redis connection closed on shutdown")


@app.get("/health")
async def health_check_endpoint():
    redis_status = "ok" if await health_check() else "unavailable"
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT,
        "project": settings.PROJECT_NAME,
        "redis": redis_status
    }

