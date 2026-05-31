"""
Admin-only Pydantic schemas.

These schemas are intentionally separate from the public user schemas to make
it impossible to accidentally expose admin-only fields (e.g. is_deleted) on
user-facing endpoints.
"""
from datetime import datetime
from typing import Any, List, Optional

from pydantic import BaseModel, ConfigDict, Field


# ─────────────────────────────────────────────
# User schemas
# ─────────────────────────────────────────────

class AdminUserRead(BaseModel):
    """Full user record for admin endpoints — includes is_deleted and all timestamps."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    avatar_url: Optional[str] = None
    role: str
    status: str
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class AdminUserListResponse(BaseModel):
    """Paginated list of users for the admin user-list endpoint."""

    items: List[AdminUserRead]
    total: int
    page: int
    page_size: int
    total_pages: int
    has_next: bool
    has_prev: bool


class BanUserResponse(BaseModel):
    """Response after successfully banning a user."""

    user: AdminUserRead
    revoked_tokens_count: int


class AdminAnalyticsSummaryResponse(BaseModel):
    """All-time metrics for the initial admin dashboard."""

    total_users: int
    total_quiz_attempts: int
    total_ai_requests: int
    average_quiz_score: float


# ─────────────────────────────────────────────
# Question-bank schemas
# ─────────────────────────────────────────────

class AdminBankSummary(BaseModel):
    """Question-bank summary for the admin bank-list endpoint."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: Optional[str] = None
    duration_minutes: Optional[int] = None
    is_deleted: bool
    question_count: int
    created_at: datetime
    updated_at: datetime


class AdminBankListResponse(BaseModel):
    """Paginated list of question banks for the admin endpoint."""

    items: List[AdminBankSummary]
    total: int
    page: int
    page_size: int
    total_pages: int
    has_next: bool
    has_prev: bool


# ─────────────────────────────────────────────
# Question-bank mutation schemas
# ─────────────────────────────────────────────

class QuestionBankCreateRequest(BaseModel):
    """Request body for creating a new question bank."""

    title: str = Field(..., min_length=1, max_length=255, description="Bank title")
    description: Optional[str] = Field(None, description="Optional description")
    duration_minutes: Optional[int] = Field(
        None, ge=1, description="Time limit in minutes (None = no limit)"
    )


class QuestionBankUpdateRequest(BaseModel):
    """Request body for partially updating a question bank (PATCH semantics)."""

    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    duration_minutes: Optional[int] = Field(None, ge=1)


class QuestionBankResponse(BaseModel):
    """Response schema returned after creating or updating a question bank."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: Optional[str] = None
    duration_minutes: Optional[int] = None
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class QuestionBankDeleteResponse(BaseModel):
    """Response schema returned after deleting/disabling a question bank."""

    id: int
    permanent: bool
    message: str


# ─────────────────────────────────────────────
# Question mutation schemas
# ─────────────────────────────────────────────

class QuestionCreateRequest(BaseModel):
    """Request body for adding a question to a bank."""

    content: str = Field(..., min_length=1, description="Question text")
    choices: Any = Field(
        ...,
        description="Answer choices — list of strings or dict (stored as JSONB)",
    )
    correct_answer: str = Field(
        ..., min_length=1, description="The correct answer value"
    )


class QuestionUpdateRequest(BaseModel):
    """Request body for partially updating a question (PATCH semantics)."""

    content: Optional[str] = Field(None, min_length=1)
    choices: Optional[Any] = None
    correct_answer: Optional[str] = Field(None, min_length=1)


class QuestionResponse(BaseModel):
    """Admin-only question response — includes correct_answer and bank_id."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    bank_id: int
    content: str
    choices: Any
    correct_answer: str
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class QuestionDeleteResponse(BaseModel):
    """Response schema returned after deleting/disabling a question."""

    id: int
    permanent: bool
    message: str



class QuestionBankCreate(BaseModel):
    """Payload for creating a new question bank."""

    title: str
    description: Optional[str] = None
    duration_minutes: Optional[int] = None


class QuestionBankUpdate(BaseModel):
    """Payload for updating an existing question bank (all fields optional)."""

    title: Optional[str] = None
    description: Optional[str] = None
    duration_minutes: Optional[int] = None


class QuestionBankToggleResponse(BaseModel):
    """Response after toggling a question bank active/inactive."""

    id: int
    title: str
    is_deleted: bool
    message: str


# ─────────────────────────────────────────────
# Question schemas
# ─────────────────────────────────────────────

class QuestionCreate(BaseModel):
    """Payload for creating a new question in a question bank."""

    content: str
    choices: dict  # e.g., {"A": "Option A", "B": "Option B", ...}
    correct_answer: str  # e.g., "A"


class QuestionUpdate(BaseModel):
    """Payload for updating a question (all fields optional)."""

    content: Optional[str] = None
    choices: Optional[dict] = None
    correct_answer: Optional[str] = None


class AdminQuestionSummary(BaseModel):
    """Question summary for list endpoints."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    bank_id: int
    content: str
    choices: dict
    correct_answer: str
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class AdminQuestionListResponse(BaseModel):
    """Paginated list of questions for a bank."""

    items: List[AdminQuestionSummary]
    total: int
    page: int
    page_size: int
    total_pages: int
    has_next: bool
    has_prev: bool


class QuestionToggleResponse(BaseModel):
    """Response after toggling a question active/inactive."""

    id: int
    bank_id: int
    is_deleted: bool
    message: str
