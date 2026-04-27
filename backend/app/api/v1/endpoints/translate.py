"""
Translate Text Endpoint - /translate/text
Public endpoint for plain text translation with Guest rate limiting.

Features:
- Guest users: allowed but limited (e.g., 10 requests/hour, max 500 chars)
- Authenticated users: higher limits (e.g., 100 requests/hour, max 5000 chars)
- Redis-based rate limiting per IP (Guest) or per user_id (authenticated)
- Leverages Google Translation API via TranslationService
"""
import logging
import time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import get_current_user_optional
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.schemas.translation import TranslationRequest
from app.services.translation_service import TranslationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/translate", tags=["translate"])

# ==================== RATE LIMIT CONFIG ====================
# These values are configurable via .env through app.core.config.Settings


async def _check_rate_limit(identifier: str, max_requests: int) -> dict:
    """
    Check rate limit via Redis counter.
    
    Args:
        identifier: Unique key (IP for guest, user_id for authenticated)
        max_requests: Maximum allowed requests per window
    
    Returns:
        dict with:
            - allowed: bool
            - remaining: int
            - reset_in_seconds: int
    
    Raises:
        None - returns allowed=True if Redis is unavailable (fail-open)
    """
    try:
        from app.core.redis_client import get_redis_client
        client = await get_redis_client()

        rate_key = f"rate_limit:translate:{identifier}"

        # Get current count
        current_count = await client.get(rate_key)

        if current_count is None:
            # First request in this window
            pipe = client.pipeline()
            pipe.incr(rate_key)
            pipe.expire(rate_key, settings.RATE_LIMIT_WINDOW_SECONDS)
            await pipe.execute()
            return {
                "allowed": True,
                "remaining": max_requests - 1,
                "reset_in_seconds": settings.RATE_LIMIT_WINDOW_SECONDS,
            }

        current_count = int(current_count)

        if current_count >= max_requests:
            ttl = await client.ttl(rate_key)
            return {
                "allowed": False,
                "remaining": 0,
                "reset_in_seconds": max(ttl, 0),
            }

        # Increment
        await client.incr(rate_key)
        ttl = await client.ttl(rate_key)
        return {
            "allowed": True,
            "remaining": max_requests - current_count - 1,
            "reset_in_seconds": max(ttl, 0),
        }

    except Exception as e:
        logger.warning(f"Rate limit check failed ({identifier}): {e}. Allowing request (fail-open).")
        return {
            "allowed": True,
            "remaining": -1,
            "reset_in_seconds": 0,
        }


def _get_client_ip(request: Request) -> str:
    """Extract client IP from request, respecting X-Forwarded-For."""
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


class TranslateTextRequest(BaseModel):
    """Request body for /translate/text endpoint."""
    text: str = Field(
        ...,
        min_length=1,
        max_length=5000,
        description="Text to translate (max length depends on Guest/User role)",
    )
    source_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        description="Source language code (ISO 639-1, e.g., 'en', 'vi', 'auto' for auto-detect)",
    )
    target_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        description="Target language code (ISO 639-1, e.g., 'vi', 'en', 'ja')",
    )


class TranslateTextResponse(BaseModel):
    """Response body for /translate/text endpoint."""
    translated_text: str = Field(..., description="The translated text result")
    source_text: str = Field(..., description="Original input text")
    source_language: str = Field(..., description="Source language used")
    target_language: str = Field(..., description="Target language used")
    detected_source_language: Optional[str] = Field(
        None,
        description="Auto-detected source language (if source_language was 'auto')",
    )
    is_cached: bool = Field(default=False, description="Whether result came from cache")
    response_time_ms: Optional[float] = Field(None, description="Response time in milliseconds")
    role: str = Field(..., description="Role used for this request: 'guest' or 'user'")
    rate_limit_remaining: Optional[int] = Field(
        None,
        description="Remaining requests in current rate limit window",
    )


@router.post("/text", response_model=SuccessResponse, summary="Translate plain text")
async def translate_text(
    body: TranslateTextRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Translate a text passage from source language to target language.
    
    **Access Control:**
    - ✅ **Guest** (no token): Allowed with limits (10 req/hour, max 500 chars)
    - ✅ **User** (Bearer token): Higher limits (100 req/hour, max 5000 chars)
    
    **Rate Limiting:**
    - Guest: tracked by IP address
    - User: tracked by user ID
    
    **Features:**
    - Redis caching for fast repeated queries
    - Google Translation API v2 backend
    - Auto language detection (`source_language: "auto"`)
    
    **Example Request:**
    ```json
    {
        "text": "Hello, how are you?",
        "source_language": "en",
        "target_language": "vi"
    }
    ```
    
    **Example Response:**
    ```json
    {
        "status": "success",
        "data": {
            "translated_text": "Xin chào, bạn khỏe không?",
            "source_text": "Hello, how are you?",
            "source_language": "en",
            "target_language": "vi",
            "is_cached": false,
            "response_time_ms": 245.3,
            "role": "guest",
            "rate_limit_remaining": 9
        }
    }
    ```
    """
    start_time = time.time()

    # ==================== DETERMINE ROLE & LIMITS ====================
    is_guest = current_user is None
    role = "guest" if is_guest else "user"
    max_chars = (
        settings.GUEST_MAX_CHAR_LENGTH if is_guest else settings.USER_MAX_CHAR_LENGTH
    )
    max_requests = (
        settings.GUEST_MAX_REQUESTS_PER_HOUR if is_guest else settings.USER_MAX_REQUESTS_PER_HOUR
    )

    # ==================== VALIDATE TEXT LENGTH BY ROLE ====================
    if len(body.text) > max_chars:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "status": "error",
                "code": "TEXT_TOO_LONG",
                "message": (
                    f"Text exceeds maximum length for {role}. "
                    f"Max {max_chars} characters (got {len(body.text)}). "
                    + ("Login for higher limits." if is_guest else "")
                ),
            },
        )

    # ==================== VALIDATE SAME LANGUAGE ====================
    if body.source_language == body.target_language and body.source_language != "auto":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "status": "error",
                "code": "SAME_LANGUAGE",
                "message": "Source and target languages must be different.",
            },
        )

    # ==================== RATE LIMITING ====================
    if is_guest:
        identifier = f"guest:{_get_client_ip(request)}"
    else:
        identifier = f"user:{current_user.id}"

    rate_result = await _check_rate_limit(identifier, max_requests)

    if not rate_result["allowed"]:
        reset_minutes = rate_result["reset_in_seconds"] // 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "status": "error",
                "code": "RATE_LIMIT_EXCEEDED",
                "message": (
                    f"Rate limit exceeded for {role}. "
                    f"Max {max_requests} requests per hour. "
                    f"Try again in ~{reset_minutes} minutes."
                    + (" Login for higher limits." if is_guest else "")
                ),
            },
            headers={
                "Retry-After": str(rate_result["reset_in_seconds"]),
                "X-RateLimit-Limit": str(max_requests),
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": str(rate_result["reset_in_seconds"]),
            },
        )

    # ==================== CALL TRANSLATION SERVICE ====================
    try:
        # Build the internal TranslationRequest
        translation_request = TranslationRequest(
            source_text=body.text,
            source_language=body.source_language,
            target_language=body.target_language,
            translation_type="text",
        )

        # Call translation with caching
        # Guest: don't save to DB (no user_id), User: save to history
        translated_text, is_cached, response_time_ms = await TranslationService.translate_with_cache(
            request=translation_request,
            db=db,
            user_id=current_user.id if current_user else None,
            save_to_db=not is_guest,  # Only save to DB for authenticated users
        )

        # Log request
        logger.info(
            f"📝 /translate/text [{role}] "
            f"{body.source_language}→{body.target_language} "
            f"({len(body.text)} chars, {response_time_ms:.1f}ms, cached={is_cached})"
        )

        return SuccessResponse(
            data=TranslateTextResponse(
                translated_text=translated_text,
                source_text=body.text,
                source_language=body.source_language,
                target_language=body.target_language,
                detected_source_language=None,  # TODO: populate if auto-detect used
                is_cached=is_cached,
                response_time_ms=round(response_time_ms, 2),
                role=role,
                rate_limit_remaining=rate_result["remaining"] if rate_result["remaining"] >= 0 else None,
            )
        )

    except HTTPException:
        raise

    except Exception as e:
        response_time_ms = (time.time() - start_time) * 1000
        logger.error(
            f"❌ /translate/text failed [{role}] after {response_time_ms:.1f}ms: {e}",
            exc_info=True,
        )

        # Map GoogleTranslateError to proper HTTP status
        from app.services.google_translate_service import GoogleTranslateError

        if isinstance(e, GoogleTranslateError):
            raise HTTPException(
                status_code=e.status_code,
                detail={
                    "status": "error",
                    "code": e.error_code,
                    "message": e.message,
                },
            )

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "TRANSLATION_FAILED",
                "message": "Translation service temporarily unavailable. Please try again later.",
            },
        )
