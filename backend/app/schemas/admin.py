"""
Admin-only Pydantic schemas.

These schemas are intentionally separate from the public user schemas to make
it impossible to accidentally expose admin-only fields (e.g. is_deleted) on
user-facing endpoints.
"""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


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
