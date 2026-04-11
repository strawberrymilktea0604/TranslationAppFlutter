from fastapi import APIRouter
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/login")
async def login(credentials: dict):
    """
    Ví dụ sử dụng settings từ dependency
    """
    timeout = settings.TRANSLATION_SERVICE_TIMEOUT
    # ... logic login
    return {"token": "..."}