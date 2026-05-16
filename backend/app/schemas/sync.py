"""
Sync Schema - Pydantic models for offline-first vocabulary sync.

Implements Last-Write-Wins strategy based on updated_at (§5.2).
Client sends batch of unsynced vocabulary records;
server upserts and returns results with server-assigned IDs.
"""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SyncVocabularyItem(BaseModel):
    """A single vocabulary record sent from the client for sync."""

    client_id: str = Field(
        ...,
        description=(
            "Temporary local ID (e.g. 'local_1715875200000') "
            "or existing backend ID for updates."
        ),
    )
    word: str = Field(..., max_length=500)
    translation: str = Field(..., max_length=2000)
    source_language: str = Field(..., max_length=10)
    target_language: str = Field(..., max_length=10)
    is_deleted: bool = Field(default=False)
    created_at: datetime
    updated_at: datetime


class SyncVocabularyRequest(BaseModel):
    """Batch sync request containing multiple vocabulary items."""

    items: list[SyncVocabularyItem] = Field(
        ...,
        min_length=1,
        max_length=100,
        description="List of unsynced vocabulary records (max 100 per batch).",
    )


class SyncVocabularyResultItem(BaseModel):
    """Result for a single synced vocabulary record."""

    client_id: str = Field(
        ..., description="The client_id sent in the request."
    )
    server_id: int = Field(
        ..., description="Server-assigned ID (translation.id) for this record."
    )
    status: str = Field(
        ..., description="'created', 'updated', or 'unchanged'."
    )
    server_updated_at: Optional[datetime] = Field(
        None,
        description=(
            "Server's updated_at if status is 'unchanged' "
            "(client should adopt this value)."
        ),
    )


class SyncVocabularyResponse(BaseModel):
    """Response for a batch vocabulary sync."""

    synced_count: int = Field(..., description="Number of records synced.")
    results: list[SyncVocabularyResultItem]
