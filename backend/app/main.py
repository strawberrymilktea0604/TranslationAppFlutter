from fastapi import FastAPI

from app.api.v1.api import api_router
from app.core.config import settings
from app.api.v1.endpoints import auth, translate, user
from app.api.endpoints import quota

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0"
)
app.include_router(api_router, prefix=settings.API_V1_STR)

# Include routers
app.include_router(auth.router)
app.include_router(translate.router)
app.include_router(user.router)

# Đăng ký API Quota
app.include_router(quota.router, prefix="/api/quotas", tags=["AI Quotas"])
@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT,
        "project": settings.PROJECT_NAME
    }
