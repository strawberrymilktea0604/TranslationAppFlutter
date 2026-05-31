"""Offline-first synchronization endpoints."""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.websocket import manager as ws_manager
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.schemas.sync import (
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
    SyncVocabularyRequest,
    SyncVocabularyResponse,
)
from app.services.sync_service import SyncCursorError, SyncService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/sync", tags=["sync"])


async def _broadcast_sync_completed(user_id: int, synced_count: int) -> None:
    """Notify connected clients without failing the HTTP request."""
    try:
        await ws_manager.broadcast_sync_completed(
            user_id=user_id,
            synced_count=synced_count,
        )
    except Exception as exc:
        logger.warning("WebSocket sync broadcast failed for user %s: %s", user_id, exc)


@router.post(
    "/push",
    response_model=SyncPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Push offline learning changes",
)
async def push_changes(
    req: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyncPushResponse:
    """Push flashcard and quiz-attempt changes in one isolated batch."""
    result = await SyncService.push(db=db, user_id=current_user.id, items=req.items)
    await _broadcast_sync_completed(current_user.id, result.succeeded_count)
    return result


@router.get(
    "/pull",
    response_model=SyncPullResponse,
    status_code=status.HTTP_200_OK,
    summary="Pull offline learning changes",
)
async def pull_changes(
    cursor: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyncPullResponse:
    """Pull a stable delta page of flashcards and quiz attempts."""
    try:
        return await SyncService.pull(
            db=db,
            user_id=current_user.id,
            cursor=cursor,
            limit=limit,
        )
    except SyncCursorError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.post(
    "/vocabulary",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
    summary="Batch sync vocabulary from legacy clients",
)
async def sync_vocabulary(
    req: SyncVocabularyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuccessResponse:
    """Preserve the original vocabulary-only contract for existing clients."""
    try:
        result: SyncVocabularyResponse = await SyncService.sync_vocabulary(
            db=db,
            user_id=current_user.id,
            items=req.items,
        )
        await _broadcast_sync_completed(current_user.id, result.synced_count)
        return SuccessResponse(data=result.model_dump())
    except Exception as exc:
        logger.error("Vocabulary sync failed for user %s: %s", current_user.id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Vocabulary sync failed. Please try again.",
        ) from exc
