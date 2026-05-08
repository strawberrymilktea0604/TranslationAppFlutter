"""
Audio Translation Endpoints - /audio/translate
"""
import logging
import time
from typing import Optional

from fastapi import APIRouter, File, UploadFile, Form, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user_optional
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.schemas.translation import (
    AudioTranslationResponse,
    TranslationRequest,
)
from app.services.stt_service import STTService, STTError
from app.services.translation_service import TranslationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/audio", tags=["audio"])


async def _check_audio_rate_limit(identifier: str, max_requests: int) -> dict:
    """Check rate limit via Redis counter"""
    try:
        from app.core.redis_client import get_redis_client
        from app.core.config import settings
        
        client = await get_redis_client()
        rate_key = f"rate_limit:audio_translate:{identifier}"

        current_count = await client.get(rate_key)

        if current_count is None:
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

        await client.incr(rate_key)
        ttl = await client.ttl(rate_key)
        return {
            "allowed": True,
            "remaining": max_requests - current_count - 1,
            "reset_in_seconds": max(ttl, 0),
        }

    except Exception as e:
        logger.warning(f"Rate limit check failed: {e}. Allowing request (fail-open).")
        return {
            "allowed": True,
            "remaining": -1,
            "reset_in_seconds": 0,
        }


async def _get_rate_limit_key(
    request: Request,
    current_user: Optional[User] = None
) -> tuple[str, int]:
    """Get rate limit identifier and max requests based on user type"""
    if current_user:
        return f"user:{current_user.id}", 100  # 100 req/hour
    else:
        client_ip = request.client.host if request.client else "unknown"
        return f"guest:{client_ip}", 10  # 10 req/hour


@router.post("/translate", response_model=SuccessResponse)
async def translate_audio(
    request: Request,
    source_language: Optional[str] = Form(None, description="Source language code. If not provided, it will be auto-detected."),
    target_language: str = Form(..., description="Target language code"),
    file: UploadFile = File(..., description="Audio file (WAV, MP3, etc.)"),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Translate audio endpoint - Complete STT and translation pipeline.
    """
    pipeline_start = time.time()
    
    try:
        # ==================== RATE LIMITING ====================
        rate_limit_key, max_requests = await _get_rate_limit_key(request, current_user)
        rate_check = await _check_audio_rate_limit(rate_limit_key, max_requests)
        
        if not rate_check["allowed"]:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Reset in {rate_check['reset_in_seconds']}s"
            )
        
        user_type = "authenticated" if current_user else "guest"
        logger.info(
            f"🎙️ Audio translation started - User: {user_type} - "
            f"Languages: {source_language or 'auto'}→{target_language}"
        )
        
        # ==================== STEP 1: READ AUDIO ====================
        audio_bytes = await file.read()
        
        if not audio_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Empty audio file provided"
            )
            
        logger.info(
            f"📥 Audio received: {len(audio_bytes)/1024:.1f}KB, "
            f"format: {file.content_type}"
        )
        
        # ==================== STEP 2: STT PROCESSING ====================
        stt_start = time.time()
        try:
            stt_result = await STTService.transcribe_audio(
                audio_bytes,
                language=source_language,
            )
        except STTError as e:
            logger.error(f"❌ STT failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Audio processing failed: {str(e)}"
            )
        
        stt_time = (time.time() - stt_start) * 1000
        extracted_text = stt_result["text"]
        detected_language = stt_result["language"]
        language_probability = stt_result["language_probability"]
        
        if not extracted_text or len(extracted_text.strip()) == 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No text could be extracted from the audio"
            )
            
        logger.info(
            f"👁️ STT completed: {len(extracted_text)} chars, "
            f"detected lang: {detected_language} ({language_probability:.2f}), "
            f"time: {stt_time:.1f}ms"
        )
        
        # Determine actual source language (fallback to detected if none provided)
        actual_source_language = source_language if source_language else detected_language
        
        # ==================== STEP 3: TRANSLATE TEXT ====================
        try:
            translation_request = TranslationRequest(
                source_text=extracted_text,
                source_language=actual_source_language,
                target_language=target_language,
                translation_type="voice"
            )
            
            translated_text, is_cached, translate_response_time = await TranslationService.translate_with_cache(
                request=translation_request,
                db=db,
                user_id=current_user.id if current_user else None,
                save_to_db=True
            )
            
        except Exception as e:
            logger.error(f"❌ Translation failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Translation failed: {str(e)}"
            )
            
        cache_status = "🚀 HIT" if is_cached else "❌ MISS"
        logger.info(
            f"🔄 Translation {cache_status}: "
            f"response_time: {translate_response_time:.1f}ms"
        )
        
        # ==================== STEP 4: BUILD RESPONSE ====================
        total_time = (time.time() - pipeline_start) * 1000
        
        response_data = AudioTranslationResponse(
            source_text=extracted_text,
            translated_text=translated_text,
            source_language=actual_source_language,
            target_language=target_language,
            stt_language_probability=language_probability,
            is_cached=is_cached,
            response_time_ms=total_time,
            translation_type="voice",
        )
        
        logger.info(
            f"✅ Audio translation completed - "
            f"Total time: {total_time:.1f}ms - "
            f"User: {current_user.email if current_user else 'guest'}"
        )
        
        return SuccessResponse(data=response_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"❌ Unexpected error in audio translation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during audio translation"
        )
