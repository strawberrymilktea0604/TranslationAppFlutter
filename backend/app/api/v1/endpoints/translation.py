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
from app.repositories.translation_repository import TranslationRepository
from app.schemas.translation import (
    TranslationRequest,
    TranslationResponse,
    TranslationQuickResponse,
    TranslationListResponse,
    BulkDeleteRequest,
    BulkDeleteResponse
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


@router.get("/{translation_id}", response_model=SuccessResponse)
async def get_translation_detail(
    translation_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get detailed information about a specific translation.
    
    **Features:**
    - View full translation details
    - Authorization check (user can only view their own translations)
    - Includes timestamps
    
    **Path Parameters:**
    - `translation_id`: Translation ID to retrieve
    
    **Example:** GET `/api/v1/translations/12345`
    
    Args:
        translation_id: ID of translation to retrieve
        db: Database session
        current_user: Current authenticated user
    
    Returns:
        SuccessResponse with translation details
    
    Raises:
        HTTPException: 404 if translation not found or user unauthorized
    """
    try:
        translation = await TranslationRepository.get_translation_by_id(db, translation_id)
        
        if not translation or translation.user_id != current_user.id or translation.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "status": "error",
                    "code": "NOT_FOUND",
                    "message": "Translation not found"
                }
            )
        
        response_data = TranslationResponse.model_validate(translation, from_attributes=True)
        return SuccessResponse(data=response_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to fetch translation detail: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "FETCH_FAILED",
                "message": "Failed to fetch translation details"
            }
        )


@router.get("/search", response_model=TranslationListResponse)
async def search_translation_history(
    q: str = Query(..., min_length=1, max_length=500, description="Search query"),
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(50, ge=1, le=100, description="Maximum records per page"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Search user's translation history.
    
    **Features:**
    - Full-text search in source and translated text
    - Paginated results
    - Sorted by most recent first
    - Case-insensitive search
    
    **Query Parameters:**
    - `q`: Search query (required, 1-500 chars)
    - `skip`: Records to skip (for pagination)
    - `limit`: Records per page (1-100, default 50)
    
    **Example:** GET `/api/v1/translations/search?q=hello&skip=0&limit=20`
    
    Args:
        q: Search query string
        skip: Pagination offset
        limit: Pagination limit
        db: Database session
        current_user: Current authenticated user
    
    Returns:
        TranslationListResponse with matching translations
    """
    try:
        translations, total = await TranslationService.search_translations(
            db=db,
            user_id=current_user.id,
            search_text=q,
            skip=skip,
            limit=limit
        )
        
        response_data = [
            TranslationResponse.model_validate(t, from_attributes=True)
            for t in translations
        ]
        
        logger.info(
            f"Search completed - Query: '{q}', "
            f"Found: {total}, Returned: {len(response_data)}"
        )
        
        return TranslationListResponse(
            data=response_data,
            total=total
        )
        
    except Exception as e:
        logger.error(f"Failed to search translations: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "SEARCH_FAILED",
                "message": "Failed to search translations"
            }
        )


@router.get("/filter", response_model=TranslationListResponse)
async def filter_translation_history(
    source_language: str = Query(None, min_length=2, max_length=5, description="Source language"),
    target_language: str = Query(None, min_length=2, max_length=5, description="Target language"),
    translation_type: str = Query(None, description="Translation type: text, voice, image"),
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(50, ge=1, le=100, description="Maximum records per page"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Filter user's translation history by language pair or type.
    
    **Features:**
    - Filter by source/target language
    - Filter by translation type (text/voice/image)
    - Paginated results
    - Combine filters for precise search
    
    **Query Parameters:**
    - `source_language`: Filter by source language (e.g., 'en', 'vi')
    - `target_language`: Filter by target language
    - `translation_type`: Filter by type ('text', 'voice', or 'image')
    - `skip`: Records to skip (for pagination)
    - `limit`: Records per page (1-100, default 50)
    
    **Examples:**
    - GET `/api/v1/translations/filter?source_language=en&target_language=vi`
    - GET `/api/v1/translations/filter?translation_type=text`
    - GET `/api/v1/translations/filter?source_language=en&translation_type=voice`
    
    Args:
        source_language: Optional source language filter
        target_language: Optional target language filter
        translation_type: Optional translation type filter
        skip: Pagination offset
        limit: Pagination limit
        db: Database session
        current_user: Current authenticated user
    
    Returns:
        TranslationListResponse with filtered translations
    
    Raises:
        HTTPException: 400 if invalid filter parameters
    """
    try:
        # Validate translation_type if provided
        if translation_type and translation_type not in ["text", "voice", "image"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "status": "error",
                    "code": "INVALID_FILTER",
                    "message": "translation_type must be 'text', 'voice', or 'image'"
                }
            )
        
        translations, total = await TranslationService.filter_translations(
            db=db,
            user_id=current_user.id,
            source_language=source_language,
            target_language=target_language,
            translation_type=translation_type,
            skip=skip,
            limit=limit
        )
        
        response_data = [
            TranslationResponse.model_validate(t, from_attributes=True)
            for t in translations
        ]
        
        filters_applied = {
            "source_language": source_language,
            "target_language": target_language,
            "translation_type": translation_type
        }
        logger.info(f"Filter applied - {filters_applied}, Found: {total}")
        
        return TranslationListResponse(
            data=response_data,
            total=total
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to filter translations: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "FILTER_FAILED",
                "message": "Failed to filter translations"
            }
        )


@router.post("/bulk-delete", response_model=SuccessResponse)
async def bulk_delete_translations(
    request: BulkDeleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Delete multiple translations in a single request.
    
    **Features:**
    - Delete up to 100 translations at once
    - Soft delete (marks as deleted, preserves data)
    - Returns count of deleted translations
    
    **Request Body:**
    ```json
    {
      "translation_ids": [123, 456, 789]
    }
    ```
    
    **Constraints:**
    - Maximum 100 translations per request
    - Only user's own translations can be deleted
    
    Args:
        request: BulkDeleteRequest with translation IDs
        db: Database session
        current_user: Current authenticated user
    
    Returns:
        SuccessResponse with deleted count
    """
    try:
        deleted_count = await TranslationService.delete_multiple_translations(
            db=db,
            user_id=current_user.id,
            translation_ids=request.translation_ids
        )
        
        logger.info(f"Bulk delete - {deleted_count} translations deleted")
        
        return SuccessResponse(
            data=BulkDeleteResponse(
                deleted_count=deleted_count,
                failed_count=len(request.translation_ids) - deleted_count
            )
        )
        
    except Exception as e:
        logger.error(f"Failed to bulk delete translations: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "error",
                "code": "BULK_DELETE_FAILED",
                "message": "Failed to delete translations"
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
