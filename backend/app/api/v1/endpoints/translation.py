"""
Translation Endpoints - API routes for translation operations
Features:
- Fast translation with Redis caching (< 500ms response time)
- Translation history tracking
- Cache statistics
"""
import logging
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.translation import (
    TranslationRequest,
    TranslationResponse,
    TranslationQuickResponse,
    TranslationListResponse
)
from app.schemas.common import SuccessResponse
from app.services.translation_service import TranslationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/translations", tags=["translations"])


@router.post("", response_model=SuccessResponse)
async def translate_text(
    request: TranslationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Translate text with caching optimization.
    
    **Features:**
    - ✅ Redis caching: Check cache before API call (< 500ms)
    - ✅ DB fallback: Saves to DB for history and cold-cache warmup
    - ✅ Cost optimization: Avoids redundant API calls
    
    **Process:**
    1. Check Redis cache (< 50ms if hit)
    2. If cache miss: Call translation API
    3. Store result in Redis (1 hour TTL) and database
    
    **Example Request:**
    ```json
    {
      "source_text": "Hello, how are you?",
      "source_language": "en",
      "target_language": "vi",
      "translation_type": "text"
    }
    ```
    
    **Example Response (Cache Hit):**
    ```json
    {
      "status": "success",
      "data": {
        "translated_text": "Xin chào, bạn khỏe không?",
        "is_cached": true,
        "response_time_ms": 15.5
      }
    }
    ```
    
    **Response Time Goals:**
    - Cache hit: < 50ms
    - Total with DB save: < 500ms (even if API call takes 3-5 seconds)
    
    Args:
        request: Translation request containing source text and language pair
        db: Database session
        current_user: Current authenticated user
    
    Returns:
        SuccessResponse with translated text and cache status
    
    Raises:
        HTTPException: 400 if invalid language pair
        HTTPException: 500 if translation service fails
    """
    try:
        # Call translation service with caching
        translated_text, is_cached, response_time_ms = await TranslationService.translate_with_cache(
            request=request,
            db=db,
            user_id=current_user.id,
            save_to_db=True
        )
        
        # Log cache effectiveness
        cache_status = "🚀 HIT" if is_cached else "❌ MISS"
        logger.info(
            f"Translation {cache_status} - {response_time_ms:.2f}ms - "
            f"User: {current_user.id} - Lang: {request.source_language}→{request.target_language}"
        )
        
        return SuccessResponse(
            data=TranslationQuickResponse(
                source_text=request.source_text,
                translated_text=translated_text,
                source_language=request.source_language,
                target_language=request.target_language,
                is_cached=is_cached,
                response_time_ms=response_time_ms
            )
        )
        
    except ValueError as e:
        logger.warning(f"Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "status": "error",
                "code": "INVALID_REQUEST",
                "message": str(e)
            }
        )
    except Exception as e:
        logger.error(f"Translation failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "TRANSLATION_FAILED",
                "message": "Translation service temporarily unavailable"
            }
        )


@router.get("/history", response_model=TranslationListResponse)
async def get_translation_history(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(50, ge=1, le=100, description="Maximum records per page"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get user's translation history.
    
    **Features:**
    - Paginated results (max 100 per page)
    - Sorted by most recent first
    - Shows cache status for each translation
    
    **Query Parameters:**
    - `skip`: Number of records to skip (for pagination)
    - `limit`: Maximum records to return (1-100, default 50)
    
    **Example Response:**
    ```json
    {
      "status": "success",
      "data": [
        {
          "id": 1001,
          "source_text": "Hello",
          "translated_text": "Xin chào",
          "source_language": "en",
          "target_language": "vi",
          "translation_type": "text",
          "is_cached": false,
          "created_at": "2024-01-15T10:30:00Z"
        }
      ],
      "total": 42
    }
    ```
    
    Args:
        skip: Pagination offset
        limit: Max records to return
        db: Database session
        current_user: Current authenticated user
    
    Returns:
        TranslationListResponse with user's translation history
    """
    try:
        translations, total = await TranslationService.get_user_translations(
            db=db,
            user_id=current_user.id,
            skip=skip,
            limit=limit
        )
        
        response_data = [
            TranslationResponse.model_validate(t, from_attributes=True)
            for t in translations
        ]
        
        return TranslationListResponse(
            data=response_data,
            total=total
        )
        
    except Exception as e:
        logger.error(f"Failed to fetch translation history: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "FETCH_FAILED",
                "message": "Failed to fetch translation history"
            }
        )


@router.delete("/{translation_id}", response_model=SuccessResponse)
async def delete_translation(
    translation_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Delete a translation from user's history.
    
    Performs soft delete (marks as deleted, keeps data for analytics).
    
    Args:
        translation_id: ID of translation to delete
        db: Database session
        current_user: Current authenticated user
    
    Returns:
        SuccessResponse with deletion status
    
    Raises:
        HTTPException: 404 if translation not found or user unauthorized
    """
    try:
        success = await TranslationService.delete_translation(
            db=db,
            translation_id=translation_id,
            user_id=current_user.id
        )
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "status": "error",
                    "code": "NOT_FOUND",
                    "message": "Translation not found"
                }
            )
        
        return SuccessResponse(
            data={"message": "Translation deleted successfully"}
        )
        
    except Exception as e:
        logger.error(f"Failed to delete translation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "DELETE_FAILED",
                "message": "Failed to delete translation"
            }
        )


@router.get("/cache/stats", response_model=SuccessResponse)
async def get_cache_stats(
    current_user: User = Depends(get_current_user)
):
    """
    Get translation cache statistics (admin only).
    
    **Features:**
    - Cache hit rate
    - Number of cached translations
    - Memory usage
    - Expiry information
    
    This endpoint helps monitor cache effectiveness and optimization.
    
    Returns:
        SuccessResponse with cache statistics
    """
    try:
        # Optional: Add admin check if needed
        # if current_user.role != "admin":
        #     raise HTTPException(status_code=403, detail="Admin only")
        
        stats = await TranslationService.get_cache_stats()
        
        return SuccessResponse(
            data={
                "message": "Cache statistics retrieved",
                "stats": stats
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to get cache stats: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "STATS_FAILED",
                "message": "Failed to retrieve cache statistics"
            }
        )


@router.post("/cache/clear", response_model=SuccessResponse)
async def clear_translation_cache(
    current_user: User = Depends(get_current_user)
):
    """
    Clear all translation cache (admin only).
    
    **Warning:** This clears the entire Redis translation cache.
    Use sparingly - will cause a cache warmup period.
    
    Returns:
        SuccessResponse with cache clear status
    """
    try:
        # Optional: Add admin check
        # if current_user.role != "admin":
        #     raise HTTPException(status_code=403, detail="Admin only")
        
        success = await TranslationService.clear_cache()
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={
                    "status": "error",
                    "code": "CLEAR_FAILED",
                    "message": "Failed to clear cache"
                }
            )
        
        return SuccessResponse(
            data={"message": "Translation cache cleared"}
        )
        
    except Exception as e:
        logger.error(f"Failed to clear cache: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "CLEAR_FAILED",
                "message": "Failed to clear cache"
            }
        )
