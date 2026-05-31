"""Pydantic contracts for offline-first flashcard and quiz synchronization."""
from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


SyncResource = Literal["flashcard", "quiz_attempt"]


class SyncVocabularyItem(BaseModel):
    """Legacy vocabulary push item kept for existing mobile clients."""

    client_id: str
    word: str = Field(..., max_length=500)
    translation: str = Field(..., max_length=2000)
    source_language: str = Field(..., max_length=10)
    target_language: str = Field(..., max_length=10)
    category_id: Optional[int] = None
    category: Optional[str] = Field(default=None, max_length=100)
    mastery_level: int = Field(default=0, ge=0, le=5)
    last_tested_at: Optional[datetime] = None
    is_deleted: bool = False
    created_at: datetime
    updated_at: datetime


class SyncVocabularyRequest(BaseModel):
    items: list[SyncVocabularyItem] = Field(..., min_length=1, max_length=100)


class SyncError(BaseModel):
    code: str
    message: str


class SyncVocabularyResultItem(BaseModel):
    client_id: str
    server_id: int
    status: Literal["created", "updated", "unchanged"]
    server_updated_at: Optional[datetime] = None
    canonical: Optional[dict[str, Any]] = None


class SyncVocabularyFailureItem(BaseModel):
    client_id: str
    status: Literal["failed"] = "failed"
    error: SyncError


class SyncVocabularyResponse(BaseModel):
    synced_count: int
    failed_count: int = 0
    results: list[SyncVocabularyResultItem]
    failures: list[SyncVocabularyFailureItem] = Field(default_factory=list)


class FlashcardPushPayload(BaseModel):
    word: str = Field(..., max_length=500)
    translation: str = Field(..., max_length=2000)
    source_language: str = Field(..., max_length=10)
    target_language: str = Field(..., max_length=10)
    category_id: Optional[int] = None
    category: Optional[str] = Field(default=None, max_length=100)
    mastery_level: int = Field(default=0, ge=0, le=5)
    last_tested_at: Optional[datetime] = None
    is_deleted: bool = False
    created_at: Optional[datetime] = None


class QuizAttemptAnswer(BaseModel):
    question_id: int
    selected_answer: str


class QuizAttemptPushPayload(BaseModel):
    bank_id: int
    answers: list[QuizAttemptAnswer] = Field(..., min_length=1)
    time_spent_seconds: int = Field(..., ge=0)
    created_at: Optional[datetime] = None


class SyncPushItem(BaseModel):
    resource: SyncResource
    client_id: str = Field(..., min_length=1, max_length=255)
    server_id: Optional[int] = None
    updated_at: datetime
    payload: dict[str, Any]


class SyncPushRequest(BaseModel):
    items: list[SyncPushItem] = Field(..., min_length=1, max_length=100)


class SyncPushResultItem(BaseModel):
    resource: SyncResource
    client_id: str
    server_id: Optional[int] = None
    status: Literal["created", "updated", "unchanged", "failed"]
    server_updated_at: Optional[datetime] = None
    canonical: Optional[dict[str, Any]] = None
    error: Optional[SyncError] = None


class SyncPushResponse(BaseModel):
    succeeded_count: int
    failed_count: int
    results: list[SyncPushResultItem]


class SyncPullItem(BaseModel):
    resource: SyncResource
    server_id: int
    updated_at: datetime
    payload: dict[str, Any]


class SyncPullResponse(BaseModel):
    items: list[SyncPullItem]
    next_cursor: str
    has_more: bool
