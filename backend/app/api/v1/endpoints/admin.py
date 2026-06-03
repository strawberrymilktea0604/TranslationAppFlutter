"""
Admin API endpoints — /api/v1/admin

All routes in this module require the caller to be an authenticated admin.
Unauthenticated requests receive 401; non-admin authenticated requests receive 403.
Role is resolved from the database (not from the JWT payload) so bans / role
changes take effect on the very next request.
"""
import math
import datetime
import logging
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.core.dependencies import DBSession, get_admin_user
from app.core.redis_client import invalidate_question_bank_cache, set_revoked_token
from app.models.learning import Question, QuestionBank, UserQuiz
from app.models.system import ApiMetric
from app.models.user import User, UserToken
from app.repositories.question_bank_repository import QuestionBankRepository
from app.schemas.admin import (
    AdminAnalyticsOverviewResponse,
    AdminAnalyticsSummaryResponse,
    AdminBankListResponse,
    AdminBankSummary,
    AdminLanguageUsageResponse,
    AdminQuestionListResponse,
    AdminQuestionSummary,
    AdminRecentActivitiesResponse,
    AdminServiceMetricsResponse,
    AdminServiceSummaryResponse,
    AdminTranslationTypeBreakdownResponse,
    AdminTranslationServiceListResponse,
    AdminUserCreateRequest,
    AdminUserListResponse,
    AdminUserRead,
    BanUserResponse,
    QuestionBankCreateRequest,
    QuestionBankDeleteResponse,
    QuestionBankResponse,
    QuestionBankUpdateRequest,
    QuestionCreateRequest,
    QuestionDeleteResponse,
    QuestionResponse,
    QuestionUpdateRequest,
)
from app.schemas.learning import QuestionAdminSchema, QuestionBankAdminDetail
from app.services.admin_dashboard_service import AdminDashboardService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["admin"])


# ─────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────

def _paginate(total: int, page: int, page_size: int) -> dict:
    total_pages = math.ceil(total / page_size) if total else 0
    return dict(
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_prev=page > 1,
    )


# ─────────────────────────────────────────────────────────────
# GET /admin/analytics/summary
# ─────────────────────────────────────────────────────────────

@router.get(
    "/analytics/summary",
    response_model=AdminAnalyticsSummaryResponse,
    summary="[Admin] Dashboard analytics summary",
)
async def admin_analytics_summary(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Return all-time aggregate metrics for the admin dashboard."""
    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0
    total_quiz_attempts = (
        await db.execute(select(func.count(UserQuiz.id)))
    ).scalar() or 0
    total_ai_requests = (
        await db.execute(
            select(func.count(ApiMetric.id)).where(ApiMetric.is_ai_request.is_(True))
        )
    ).scalar() or 0
    average_quiz_score = (
        await db.execute(select(func.avg(UserQuiz.score)))
    ).scalar() or 0.0

    return AdminAnalyticsSummaryResponse(
        total_users=total_users,
        total_quiz_attempts=total_quiz_attempts,
        total_ai_requests=total_ai_requests,
        average_quiz_score=round(float(average_quiz_score), 2),
    )


@router.get(
    "/activities/recent",
    response_model=AdminRecentActivitiesResponse,
    summary="[Admin] Recent dashboard activities",
)
async def admin_recent_activities(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    limit: int = Query(20, ge=1, le=100, description="Maximum activity rows"),
):
    """Return a merged recent-activity feed derived from existing tables."""
    return await AdminDashboardService.recent_activities(db, limit=limit)


@router.get(
    "/services/summary",
    response_model=AdminServiceSummaryResponse,
    summary="[Admin] Translation service counters",
)
async def admin_service_summary(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Return total/today/week/month translation counters and type breakdown."""
    return await AdminDashboardService.service_summary(db)


@router.get(
    "/services/translations",
    response_model=AdminTranslationServiceListResponse,
    summary="[Admin] List translation service records",
)
async def admin_list_translation_services(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Rows per page"),
    search: Optional[str] = Query(None, description="Search text, translation, or user"),
    translation_type: Optional[str] = Query(None, description="text, voice, image, ..."),
    source_language: Optional[str] = Query(None, description="Source language code"),
    target_language: Optional[str] = Query(None, description="Target language code"),
    user_id: Optional[int] = Query(None, ge=1, description="Filter by user id"),
    include_deleted: bool = Query(False, description="Include soft-deleted translations"),
):
    """Return paginated translations for the admin service-management screen."""
    items, total = await AdminDashboardService.list_translations(
        db,
        page=page,
        page_size=page_size,
        search=search,
        translation_type=translation_type,
        source_language=source_language,
        target_language=target_language,
        user_id=user_id,
        include_deleted=include_deleted,
    )
    return AdminTranslationServiceListResponse(
        items=items,
        **_paginate(total, page, page_size),
    )


@router.get(
    "/analytics/overview",
    response_model=AdminAnalyticsOverviewResponse,
    summary="[Admin] Period analytics overview",
)
async def admin_analytics_overview(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    days: int = Query(7, ge=1, le=365, description="Current period length in days"),
):
    """Return analytics cards for the current period vs the previous period."""
    return await AdminDashboardService.analytics_overview(db, days=days)


@router.get(
    "/analytics/translation-types",
    response_model=AdminTranslationTypeBreakdownResponse,
    summary="[Admin] Translation type breakdown",
)
async def admin_translation_type_breakdown(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    days: int = Query(7, ge=1, le=365, description="Current period length in days"),
):
    """Return translation counts grouped by service type."""
    return await AdminDashboardService.translation_type_breakdown(db, days=days)


@router.get(
    "/analytics/languages",
    response_model=AdminLanguageUsageResponse,
    summary="[Admin] Popular source and target languages",
)
async def admin_language_usage(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    days: int = Query(7, ge=1, le=365, description="Current period length in days"),
):
    """Return source and target language usage for the analytics dashboard."""
    return await AdminDashboardService.language_usage(db, days=days)


@router.get(
    "/analytics/services",
    response_model=AdminServiceMetricsResponse,
    summary="[Admin] API service metrics",
)
async def admin_service_metrics(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    days: int = Query(7, ge=1, le=365, description="Current period length in days"),
):
    """Return API metrics grouped by endpoint and AI model."""
    return await AdminDashboardService.service_metrics(db, days=days)


# GET /admin/users

@router.post(
    "/users",
    response_model=AdminUserRead,
    status_code=status.HTTP_201_CREATED,
    summary="[Admin] Create user",
)
async def admin_create_user(
    payload: AdminUserCreateRequest,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Create a user account from the admin panel."""
    try:
        user = await AdminDashboardService.create_user(db, payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    return AdminUserRead.model_validate(user)


@router.get("/users", response_model=AdminUserListResponse, summary="[Admin] List users")
async def admin_list_users(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Users per page (max 100)"),
    search: Optional[str] = Query(None, description="Search by email, first or last name"),
    role: Optional[str] = Query(None, description="Filter by role (e.g. 'user', 'admin')"),
    status: Optional[str] = Query(None, description="Filter by status ('active', 'locked')"),
    include_deleted: bool = Query(False, description="Include soft-deleted users"),
):
    """Return a paginated, optionally filtered list of all users."""
    stmt = select(User)

    if not include_deleted:
        stmt = stmt.where(User.is_deleted.is_(False))

    if search:
        pattern = f"%{search}%"
        stmt = stmt.where(
            User.email.ilike(pattern)
            | User.first_name.ilike(pattern)
            | User.last_name.ilike(pattern)
        )

    if role:
        stmt = stmt.where(User.role == role)

    if status:
        stmt = stmt.where(User.status == status)

    # Total count
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total: int = (await db.execute(count_stmt)).scalar() or 0

    # Paginated rows
    offset = (page - 1) * page_size
    rows = (await db.execute(stmt.offset(offset).limit(page_size))).scalars().all()

    return AdminUserListResponse(
        items=[AdminUserRead.model_validate(u) for u in rows],
        **_paginate(total, page, page_size),
    )


# ─────────────────────────────────────────────────────────────
# PATCH /admin/users/{user_id}/ban
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/users/{user_id}/ban",
    response_model=BanUserResponse,
    summary="[Admin] Ban a user",
)
async def admin_ban_user(
    user_id: int,
    db: DBSession,
    admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Set a user's status to 'locked' and immediately revoke all their active tokens.

    - Returns **400** if the admin tries to ban themselves.
    - Returns **400** if the target is another admin account (v1 restriction).
    - Returns **404** if the user does not exist or is soft-deleted.
    """
    # Self-ban guard
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot ban your own account.",
        )

    # Fetch target
    result = await db.execute(
        select(User).where(User.id == user_id, User.is_deleted.is_(False))
    )
    target = result.scalar_one_or_none()

    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    # Block banning other admins in v1
    if str(target.role) == "admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot ban an admin account in v1.",
        )

    # Lock the account
    target.status = "locked"

    # Revoke all active tokens — DB + Redis blacklist for immediate effect
    token_rows = (
        await db.execute(
            select(UserToken).where(
                UserToken.user_id == target.id,
                UserToken.is_revoked.is_(False),
            )
        )
    ).scalars().all()

    now = datetime.datetime.now(datetime.timezone.utc)
    for token in token_rows:
        token.is_revoked = True
        remaining = int((token.expires_at - now).total_seconds())
        if remaining > 0:
            try:
                await set_revoked_token(token.jti, remaining)
            except Exception:
                logger.warning(
                    "Redis unavailable; token %s will be blocked via DB only.", token.jti
                )

    await db.commit()
    await db.refresh(target)

    logger.info(
        "Admin %s banned user %s; revoked %d token(s).",
        admin.id,
        target.id,
        len(token_rows),
    )

    return BanUserResponse(
        user=AdminUserRead.model_validate(target),
        revoked_tokens_count=len(token_rows),
    )


# ─────────────────────────────────────────────────────────────
# PATCH /admin/users/{user_id}/unban
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/users/{user_id}/unban",
    response_model=AdminUserRead,
    summary="[Admin] Unban a user",
)
async def admin_unban_user(
    user_id: int,
    db: DBSession,
    admin: Annotated[User, Depends(get_admin_user)],
):
    """Set a user's status back to 'active'."""
    result = await db.execute(
        select(User).where(User.id == user_id, User.is_deleted.is_(False))
    )
    target = result.scalar_one_or_none()

    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    target.status = "active"
    await db.commit()
    await db.refresh(target)

    logger.info("Admin %s unbanned user %s.", admin.id, target.id)
    return AdminUserRead.model_validate(target)


# ─────────────────────────────────────────────────────────────
# GET /admin/question-banks
# ─────────────────────────────────────────────────────────────

@router.get(
    "/question-banks",
    response_model=AdminBankListResponse,
    summary="[Admin] List question banks",
)
async def admin_list_question_banks(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Banks per page (max 100)"),
    search: Optional[str] = Query(None, description="Search by title"),
    include_deleted: bool = Query(False, description="Include soft-deleted banks"),
):
    """Return a paginated list of question banks with per-bank question counts."""
    # Subquery: count non-deleted questions per bank
    q_count = (
        select(func.count(Question.id))
        .where(
            Question.bank_id == QuestionBank.id,
            Question.is_deleted.is_(False),
        )
        .correlate(QuestionBank)
        .scalar_subquery()
    )

    stmt = select(QuestionBank, q_count.label("question_count"))

    if not include_deleted:
        stmt = stmt.where(QuestionBank.is_deleted.is_(False))

    if search:
        stmt = stmt.where(QuestionBank.title.ilike(f"%{search}%"))

    # Total count
    count_stmt = select(func.count()).select_from(
        select(QuestionBank)
        .where(QuestionBank.is_deleted.is_(False) if not include_deleted else True)
        .subquery()
    )
    total: int = (await db.execute(count_stmt)).scalar() or 0

    offset = (page - 1) * page_size
    rows = (await db.execute(stmt.offset(offset).limit(page_size))).all()

    items = []
    for bank, question_count in rows:
        items.append(
            AdminBankSummary(
                id=bank.id,
                title=bank.title,
                description=bank.description,
                duration_minutes=bank.duration_minutes,
                is_deleted=bank.is_deleted,
                question_count=question_count or 0,
                created_at=bank.created_at,
                updated_at=bank.updated_at,
            )
        )

    return AdminBankListResponse(
        items=items,
        **_paginate(total, page, page_size),
    )


# ─────────────────────────────────────────────────────────────
# GET /admin/question-banks/{bank_id}
# ─────────────────────────────────────────────────────────────

@router.get(
    "/question-banks/{bank_id}",
    response_model=QuestionBankAdminDetail,
    summary="[Admin] Question bank detail with correct answers",
)
async def admin_get_question_bank(
    bank_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Return bank metadata and all questions including ``correct_answer``."""
    stmt = (
        select(QuestionBank)
        .where(QuestionBank.id == bank_id)
        .options(selectinload(QuestionBank.questions))
    )
    bank = (await db.execute(stmt)).scalar_one_or_none()

    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    active_questions = [
        QuestionAdminSchema.model_validate(q)
        for q in bank.questions
        if not q.is_deleted
    ]

    return QuestionBankAdminDetail(
        id=bank.id,
        title=bank.title,
        description=bank.description,
        duration_minutes=bank.duration_minutes,
        created_at=bank.created_at,
        questions=active_questions,
    )


# ─────────────────────────────────────────────────────────────
# POST /admin/question-banks  — Create
# ─────────────────────────────────────────────────────────────

@router.post(
    "/question-banks",
    response_model=QuestionBankResponse,
    status_code=status.HTTP_201_CREATED,
    summary="[Admin] Create question bank",
)
async def admin_create_question_bank(
    payload: QuestionBankCreateRequest,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Create a new question bank.

    - **title**: Required, 1–255 characters.
    - **description**: Optional free-text description.
    - **duration_minutes**: Optional time limit (≥1); omit for no limit.

    Returns the created bank. Redis cache is invalidated automatically.
    """
    bank = await QuestionBankRepository.create_bank(db, payload)

    logger.info("Admin %s created question bank %s.", _admin.id, bank.id)
    await invalidate_question_bank_cache(bank.id)

    return QuestionBankResponse.model_validate(bank)


# ─────────────────────────────────────────────────────────────
# PATCH /admin/question-banks/{bank_id}  — Partial update
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/question-banks/{bank_id}",
    response_model=QuestionBankResponse,
    summary="[Admin] Update question bank",
)
@router.put(
    "/question-banks/{bank_id}",
    response_model=QuestionBankResponse,
    summary="[Admin] Update question bank",
)
async def admin_update_question_bank(
    bank_id: int,
    payload: QuestionBankUpdateRequest,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Partially update an existing question bank (PATCH semantics).

    Only the fields provided in the request body are updated; omitted
    fields are left unchanged.

    - Returns **404** if the bank does not exist or is soft-deleted.

    Redis cache is invalidated after a successful update.
    """
    bank = await QuestionBankRepository.get_bank(db, bank_id)
    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    bank = await QuestionBankRepository.update_bank(db, bank, payload)

    logger.info("Admin %s updated question bank %s.", _admin.id, bank.id)
    await invalidate_question_bank_cache(bank.id)

    return QuestionBankResponse.model_validate(bank)


# ─────────────────────────────────────────────────────────────
# DELETE /admin/question-banks/{bank_id}  — Delete / disable
# ─────────────────────────────────────────────────────────────

@router.delete(
    "/question-banks/{bank_id}",
    response_model=QuestionBankDeleteResponse,
    summary="[Admin] Delete or disable a question bank",
)
async def admin_delete_question_bank(
    bank_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    permanent: bool = Query(
        False,
        description=(
            "If true, permanently removes the row from the database. "
            "Default is soft-delete (sets is_deleted=True)."
        ),
    ),
):
    """
    Soft-delete (disable) or permanently delete a question bank.

    - **permanent=false** (default): Sets ``is_deleted=True``; the bank
      is hidden from all user-facing endpoints but remains in the database.
      The bank can be restored by toggling it back via a PATCH.
    - **permanent=true**: Irreversibly removes the row and all its questions
      via the DB cascade.

    - Returns **404** if the bank does not exist (or is already soft-deleted
      when ``permanent=false``).

    Redis cache is invalidated after a successful deletion.
    """
    bank = await QuestionBankRepository.get_bank(
        db, bank_id, include_deleted=permanent
    )
    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    await QuestionBankRepository.delete_bank(db, bank, permanent=permanent)

    action = "permanently deleted" if permanent else "disabled (soft-deleted)"
    logger.info("Admin %s %s question bank %s.", _admin.id, action, bank_id)
    await invalidate_question_bank_cache(bank_id)

    return QuestionBankDeleteResponse(
        id=bank_id,
        permanent=permanent,
        message=f"Question bank {bank_id} has been {action}.",
    )


# ─────────────────────────────────────────────────────────────
# GET /admin/question-banks/{bank_id}/questions
# ─────────────────────────────────────────────────────────────

@router.get(
    "/question-banks/{bank_id}/questions",
    response_model=AdminQuestionListResponse,
    summary="[Admin] List questions in a bank",
)
async def admin_list_questions(
    bank_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Questions per page (max 100)"),
    include_deleted: bool = Query(False, description="Include soft-deleted questions"),
):
    """Return a paginated list of questions in a question bank."""
    # Verify bank exists (any state)
    bank = await QuestionBankRepository.get_bank(db, bank_id, include_deleted=True)
    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    stmt = select(Question).where(Question.bank_id == bank_id)

    if not include_deleted:
        stmt = stmt.where(Question.is_deleted.is_(False))

    # Total count
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total: int = (await db.execute(count_stmt)).scalar() or 0

    # Paginated rows
    offset = (page - 1) * page_size
    rows = (await db.execute(stmt.offset(offset).limit(page_size))).scalars().all()

    items = [AdminQuestionSummary.model_validate(q) for q in rows]

    return AdminQuestionListResponse(
        items=items,
        **_paginate(total, page, page_size),
    )


# ─────────────────────────────────────────────────────────────
# POST /admin/question-banks/{bank_id}/questions  — Create
# ─────────────────────────────────────────────────────────────

@router.post(
    "/question-banks/{bank_id}/questions",
    response_model=QuestionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="[Admin] Add a question to a bank",
)
async def admin_create_question(
    bank_id: int,
    payload: QuestionCreateRequest,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Add a new question to the specified question bank.

    - **content**: Question text (required).
    - **choices**: Answer choices — typically a list of strings or an object
      mapping option keys to labels (stored as JSONB).
    - **correct_answer**: The value that matches the correct choice.

    - Returns **404** if the bank does not exist or is soft-deleted.

    Redis cache is invalidated after the question is created.
    """
    # Verify bank is active
    bank = await QuestionBankRepository.get_bank(db, bank_id)
    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    question = await QuestionBankRepository.create_question(db, bank_id, payload)

    logger.info(
        "Admin %s added question %s to bank %s.",
        _admin.id,
        question.id,
        bank_id,
    )
    await invalidate_question_bank_cache(bank_id)

    return QuestionResponse.model_validate(question)


# ─────────────────────────────────────────────────────────────
# PATCH /admin/questions/{question_id}  — Partial update
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/questions/{question_id}",
    response_model=QuestionResponse,
    summary="[Admin] Update a question",
)
@router.put(
    "/questions/{question_id}",
    response_model=QuestionResponse,
    summary="[Admin] Update a question",
)
async def admin_update_question(
    question_id: int,
    payload: QuestionUpdateRequest,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Partially update a question (PATCH semantics).

    Only the fields provided in the request body are updated; omitted
    fields are left unchanged.

    - Returns **404** if the question does not exist or is soft-deleted.

    Redis cache for the parent bank is invalidated after a successful update.
    """
    question = await QuestionBankRepository.get_question(db, question_id)
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    question = await QuestionBankRepository.update_question(db, question, payload)

    logger.info(
        "Admin %s updated question %s (bank %s).",
        _admin.id,
        question.id,
        question.bank_id,
    )
    await invalidate_question_bank_cache(question.bank_id)

    return QuestionResponse.model_validate(question)


# ─────────────────────────────────────────────────────────────
# DELETE /admin/questions/{question_id}  — Delete / disable
# ─────────────────────────────────────────────────────────────

@router.delete(
    "/questions/{question_id}",
    response_model=QuestionDeleteResponse,
    summary="[Admin] Delete or disable a question",
)
async def admin_delete_question(
    question_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
    permanent: bool = Query(
        False,
        description=(
            "If true, permanently removes the row from the database. "
            "Default is soft-delete (sets is_deleted=True)."
        ),
    ),
):
    """
    Soft-delete (disable) or permanently delete a question.

    - **permanent=false** (default): Sets ``is_deleted=True``; the question
      is excluded from quizzes but remains in the database.
    - **permanent=true**: Irreversibly removes the row.

    - Returns **404** if the question does not exist (or is already
      soft-deleted when ``permanent=false``).

    Redis cache for the parent bank is invalidated after a successful deletion.
    """
    question = await QuestionBankRepository.get_question(
        db, question_id, include_deleted=permanent
    )
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    bank_id = question.bank_id
    await QuestionBankRepository.delete_question(db, question, permanent=permanent)

    action = "permanently deleted" if permanent else "disabled (soft-deleted)"
    logger.info(
        "Admin %s %s question %s (bank %s).",
        _admin.id,
        action,
        question_id,
        bank_id,
    )
    await invalidate_question_bank_cache(bank_id)

    return QuestionDeleteResponse(
        id=question_id,
        permanent=permanent,
        message=f"Question {question_id} has been {action}.",
    )


# ─────────────────────────────────────────────────────────────
# PATCH /admin/question-banks/{bank_id}/toggle  — Toggle active
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/question-banks/{bank_id}/toggle",
    response_model=QuestionBankResponse,
    summary="[Admin] Toggle question bank active/inactive",
)
async def admin_toggle_question_bank(
    bank_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Toggle a question bank between active (``is_deleted=False``) and
    inactive (``is_deleted=True``).

    This is a convenience endpoint for restoring a soft-deleted bank or
    quickly disabling an active one without permanently removing it.

    - Returns **404** if the bank does not exist in any state.

    Redis cache is invalidated after the toggle.
    """
    bank = await QuestionBankRepository.get_bank(db, bank_id, include_deleted=True)
    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    bank.is_deleted = not bank.is_deleted
    await db.commit()
    await db.refresh(bank)

    action = "deactivated" if bank.is_deleted else "activated"
    logger.info("Admin %s %s question bank %s.", _admin.id, action, bank.id)
    await invalidate_question_bank_cache(bank.id)

    return QuestionBankResponse.model_validate(bank)


# ─────────────────────────────────────────────────────────────
# PATCH /admin/questions/{question_id}/toggle  — Toggle active
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/questions/{question_id}/toggle",
    response_model=QuestionResponse,
    summary="[Admin] Toggle question active/inactive",
)
async def admin_toggle_question(
    question_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Toggle a question between active (``is_deleted=False``) and
    inactive (``is_deleted=True``).

    Useful for restoring a soft-deleted question without creating a new one.

    - Returns **404** if the question does not exist in any state.

    Redis cache for the parent bank is invalidated after the toggle.
    """
    question = await QuestionBankRepository.get_question(
        db, question_id, include_deleted=True
    )
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    question.is_deleted = not question.is_deleted
    await db.commit()
    await db.refresh(question)

    action = "deactivated" if question.is_deleted else "activated"
    logger.info(
        "Admin %s %s question %s (bank %s).",
        _admin.id,
        action,
        question.id,
        question.bank_id,
    )
    await invalidate_question_bank_cache(question.bank_id)

    return QuestionResponse.model_validate(question)
