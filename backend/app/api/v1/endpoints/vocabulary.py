"""
Vocabulary Endpoints - /api/v1/vocabularies/
CRUD operations for managing vocabulary/flashcards

Features:
- Users can save translations they want to learn
- Full CRUD operations for vocabulary management
- Support for batch operations (add/remove multiple)
- Search and filtering capabilities
- Pagination support
- Statistics on vocabulary progress

Notes:
- Only authenticated users can use this endpoint (no guest access to cloud sync)
- Guest users would save vocabulary locally via Flutter
- All operations are per-user (automatic user_id from JWT token)
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.schemas.vocabulary import (
    VocabularyCreate,
    VocabularyCreateMultiple,
    VocabularyDetailResponse,
    VocabularyListResponse,
    VocabularyProgressUpdate,
)
from app.services.vocabulary_service import VocabularyService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/vocabularies", tags=["vocabulary"])


# ==================== CREATE ====================

@router.post(
    "",
    response_model=SuccessResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add a translation to vocabulary",
    description="""
    Add a translation to user's vocabulary/flashcards for learning.
    Only authenticated users can save to cloud (guest users save locally).
    """
)
async def add_to_vocabulary(
    req: VocabularyCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Add a translation to user's vocabulary.
    
    **Note:** Guest users cannot use this endpoint. They save vocabulary locally
    on their device. Only authenticated users can sync across devices.
    """
    try:
        result = await VocabularyService.add_to_vocabulary(
            db, current_user.id, req.translation_id, req.category_id
        )
        return SuccessResponse(
            success=True,
            message=result["message"],
            data=result
        )
    except ValueError as e:
        logger.warning(f"⚠️  Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error adding to vocabulary: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to add translation to vocabulary"
        )


@router.post(
    "/batch",
    response_model=SuccessResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add multiple translations to vocabulary",
    description="Add multiple translations at once (max 50)."
)
async def add_multiple_to_vocabulary(
    req: VocabularyCreateMultiple,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Add multiple translations to vocabulary in one request.
    Useful for batch importing or selecting multiple results.
    
    Max 50 translations per request.
    """
    try:
        result = await VocabularyService.add_multiple_to_vocabulary(
            db, current_user.id, req.translation_ids
        )
        return SuccessResponse(
            success=True,
            message=result["message"],
            data=result
        )
    except ValueError as e:
        logger.warning(f"⚠️  Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error adding multiple to vocabulary: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to add translations to vocabulary"
        )


# ==================== READ ====================

@router.get(
    "",
    response_model=VocabularyListResponse,
    summary="List user's vocabulary entries",
    description="Get paginated list of vocabulary entries with optional search."
)
async def list_vocabularies(
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page (max 100)"),
    search: Optional[str] = Query(None, description="Search in source or translated text"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get user's vocabulary list with pagination.
    
    **Features:**
    - Paginated results
    - Optional full-text search in source and translated text
    - Sort by most recently added
    - Only shows non-deleted entries
    """
    try:
        result = await VocabularyService.list_vocabularies(
            db, current_user.id, page, page_size, search
        )
        return result
    except Exception as e:
        logger.error(f"❌ Error listing vocabularies: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve vocabulary list"
        )


@router.get(
    "/{vocabulary_id}",
    response_model=VocabularyDetailResponse,
    summary="Get vocabulary entry details",
    description="Get full details of a vocabulary entry including translation info."
)
async def get_vocabulary_detail(
    vocabulary_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed information about a vocabulary entry.
    Includes the associated translation data (source, target, text, etc.).
    """
    try:
        result = await VocabularyService.get_vocabulary_detail(
            db, vocabulary_id, current_user.id
        )
        return result
    except PermissionError as e:
        logger.warning(f"⚠️  Forbidden: {e}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e)
        )
    except ValueError as e:
        logger.warning(f"⚠️  Not found: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error retrieving vocabulary detail: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve vocabulary entry"
        )


@router.patch(
    "/{vocabulary_id}",
    response_model=VocabularyDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Update flashcard learning progress",
    description="Update mastery_level and/or last_tested_at for a vocabulary entry. "
                "Text and language fields are immutable snapshots.",
)
async def update_vocabulary_progress(
    vocabulary_id: int,
    req: VocabularyProgressUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    PATCH a vocabulary entry's learning-progress fields only.
    Returns the full updated detail response.
    """
    try:
        result = await VocabularyService.update_vocabulary_progress(
            db, vocabulary_id, current_user.id, req
        )
        return result
    except PermissionError as e:
        logger.warning(f"⚠️  Forbidden: {e}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e)
        )
    except ValueError as e:
        logger.warning(f"⚠️  Not found: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error updating vocabulary progress: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update vocabulary entry"
        )


@router.get(
    "/stats/summary",
    response_model=SuccessResponse,
    summary="Get vocabulary statistics",
    description="Get statistics about user's vocabulary (total count, breakdown by type)."
)
async def get_vocabulary_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get statistics about user's vocabulary collection.
    
    **Returns:**
    - Total number of entries
    - Breakdown by translation type (text, voice, image)
    """
    try:
        stats = await VocabularyService.get_user_vocabulary_count(db, current_user.id)
        return SuccessResponse(
            success=True,
            message="Vocabulary statistics retrieved successfully",
            data=stats
        )
    except Exception as e:
        logger.error(f"❌ Error retrieving vocabulary stats: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve vocabulary statistics"
        )


# ==================== DELETE ====================

@router.delete(
    "/{vocabulary_id}",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
    summary="Remove vocabulary entry",
    description="Remove (soft delete) a vocabulary entry. Can be restored later."
)
async def remove_from_vocabulary(
    vocabulary_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Remove a vocabulary entry from user's collection.
    
    **Note:** This is a soft delete - the entry can be restored if needed.
    """
    try:
        result = await VocabularyService.remove_from_vocabulary(
            db, vocabulary_id, current_user.id
        )
        return SuccessResponse(
            success=True,
            message=result["message"],
            data=result
        )
    except ValueError as e:
        logger.warning(f"⚠️  Not found: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error removing from vocabulary: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to remove vocabulary entry"
        )


@router.delete(
    "/batch/remove",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
    summary="Remove multiple vocabulary entries",
    description="Remove multiple vocabulary entries at once (max 50)."
)
async def remove_multiple_from_vocabulary(
    req: VocabularyCreateMultiple,  # Reuse this schema as it has translation_ids
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Remove multiple vocabulary entries in one request.
    Max 50 entries per request.
    
    **Note:** This is a soft delete - entries can be restored.
    """
    try:
        result = await VocabularyService.remove_multiple_from_vocabulary(
            db, req.translation_ids, current_user.id
        )
        return SuccessResponse(
            success=True,
            message=result["message"],
            data=result
        )
    except ValueError as e:
        logger.warning(f"⚠️  Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error removing multiple from vocabulary: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to remove vocabulary entries"
        )


@router.post(
    "/{vocabulary_id}/restore",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
    summary="Restore deleted vocabulary entry",
    description="Restore a previously deleted vocabulary entry."
)
async def restore_vocabulary_entry(
    vocabulary_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Restore a previously deleted vocabulary entry.
    Only works on soft-deleted entries.
    """
    try:
        result = await VocabularyService.restore_vocabulary_entry(
            db, vocabulary_id, current_user.id
        )
        return SuccessResponse(
            success=True,
            message=result["message"],
            data=result
        )
    except ValueError as e:
        logger.warning(f"⚠️  Not found: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error restoring vocabulary entry: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to restore vocabulary entry"
        )
