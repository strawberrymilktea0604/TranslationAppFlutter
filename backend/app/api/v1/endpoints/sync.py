"""
Sync Endpoints — /api/v1/sync/

Handles offline-first batch synchronisation of vocabulary data.

Features:
- Batch sync with Last-Write-Wins strategy (§5.2)
- Requires authentication (UC09)
- Returns per-item sync status (created / updated / unchanged)
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.schemas.sync import SyncVocabularyRequest, SyncVocabularyResponse
from app.services.sync_service import SyncService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post(
    "/vocabulary",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
    summary="Batch sync vocabulary from client",
    description=(
        "Accepts a batch of unsynced vocabulary records from the client, "
        "upserts them using Last-Write-Wins, and returns the sync results."
    ),
)
async def sync_vocabulary(
    req: SyncVocabularyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Synchronise vocabulary data from the mobile client.

    **Strategy:** Last-Write-Wins based on `updated_at` (§5.2).

    **Flow:**
    1. For each record in `items`:
       - If NOT found on server → INSERT.
       - If found AND client `updated_at` > server → UPDATE.
       - If found AND client `updated_at` ≤ server → UNCHANGED (return server data).
    2. Client marks successfully synced items as `is_synced = true`.

    **Auth:** Requires a valid Bearer token.
    """
    try:
        result: SyncVocabularyResponse = await SyncService.sync_vocabulary(
            db=db,
            user_id=current_user.id,
            items=req.items,
        )

        logger.info(
            "✅ Sync completed for user %s: %d/%d items synced",
            current_user.id,
            result.synced_count,
            len(req.items),
        )

        return SuccessResponse(
            success=True,
            message=f"Synced {result.synced_count} of {len(req.items)} items",
            data=result.model_dump(),
        )

    except Exception as e:
        logger.error("❌ Sync failed for user %s: %s", current_user.id, e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Vocabulary sync failed. Please try again.",
        )
