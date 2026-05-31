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
from app.core.redis_client import set_revoked_token
from app.models.learning import Question, QuestionBank, UserQuiz
from app.models.system import ApiMetric
from app.models.user import User, UserToken
from app.schemas.admin import (
    AdminAnalyticsSummaryResponse,
    AdminBankListResponse,
    AdminBankSummary,
    AdminUserListResponse,
    AdminUserRead,
    BanUserResponse,
    QuestionBankCreate,
    QuestionBankUpdate,
    QuestionBankToggleResponse,
    QuestionCreate,
    QuestionUpdate,
    AdminQuestionSummary,
    AdminQuestionListResponse,
    QuestionToggleResponse,
)
from app.schemas.learning import QuestionAdminSchema, QuestionBankAdminDetail

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get(
    "/analytics/summary",
    response_model=AdminAnalyticsSummaryResponse,
    summary="[Admin] Get all-time analytics summary",
)
async def admin_get_analytics_summary(
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Return the initial all-time metrics for the admin dashboard."""
    total_users = (
        await db.execute(
            select(func.count(User.id)).where(User.is_deleted.is_(False))
        )
    ).scalar() or 0
    total_quiz_attempts = (
        await db.execute(select(func.count(UserQuiz.id)))
    ).scalar() or 0
    total_ai_requests = (
        await db.execute(
            select(func.count(ApiMetric.id)).where(ApiMetric.is_ai_request.is_(True))
        )
    ).scalar() or 0
    average_quiz_score = (
        await db.execute(
            select(func.avg(UserQuiz.score)).where(UserQuiz.score.is_not(None))
        )
    ).scalar()

    return AdminAnalyticsSummaryResponse(
        total_users=total_users,
        total_quiz_attempts=total_quiz_attempts,
        total_ai_requests=total_ai_requests,
        average_quiz_score=round(float(average_quiz_score or 0.0), 2),
    )


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
# GET /admin/users
# ─────────────────────────────────────────────────────────────

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
    response_model=AdminBankSummary,
    status_code=201,
    summary="[Admin] Create question bank",
)
async def admin_create_question_bank(
    payload: QuestionBankCreate,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Create a new question bank."""
    bank = QuestionBank(
        title=payload.title,
        description=payload.description,
        duration_minutes=payload.duration_minutes,
    )
    db.add(bank)
    await db.commit()
    await db.refresh(bank)

    logger.info("Admin %s created question bank %s.", _admin.id, bank.id)

    return AdminBankSummary(
        id=bank.id,
        title=bank.title,
        description=bank.description,
        duration_minutes=bank.duration_minutes,
        is_deleted=bank.is_deleted,
        question_count=0,
        created_at=bank.created_at,
        updated_at=bank.updated_at,
    )


# ─────────────────────────────────────────────────────────────
# PUT /admin/question-banks/{bank_id}  — Update
# ─────────────────────────────────────────────────────────────

@router.put(
    "/question-banks/{bank_id}",
    response_model=AdminBankSummary,
    summary="[Admin] Update question bank",
)
async def admin_update_question_bank(
    bank_id: int,
    payload: QuestionBankUpdate,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Update an existing question bank's metadata."""
    result = await db.execute(
        select(QuestionBank).where(QuestionBank.id == bank_id)
    )
    bank = result.scalar_one_or_none()

    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    if payload.title is not None:
        bank.title = payload.title
    if payload.description is not None:
        bank.description = payload.description
    if payload.duration_minutes is not None:
        bank.duration_minutes = payload.duration_minutes

    await db.commit()
    await db.refresh(bank)

    # Re-compute question count
    q_count_result = await db.execute(
        select(func.count(Question.id)).where(
            Question.bank_id == bank_id,
            Question.is_deleted.is_(False),
        )
    )
    question_count: int = q_count_result.scalar() or 0

    logger.info("Admin %s updated question bank %s.", _admin.id, bank.id)

    return AdminBankSummary(
        id=bank.id,
        title=bank.title,
        description=bank.description,
        duration_minutes=bank.duration_minutes,
        is_deleted=bank.is_deleted,
        question_count=question_count,
        created_at=bank.created_at,
        updated_at=bank.updated_at,
    )


# ─────────────────────────────────────────────────────────────
# PATCH /admin/question-banks/{bank_id}/toggle  — Toggle active
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/question-banks/{bank_id}/toggle",
    response_model=QuestionBankToggleResponse,
    summary="[Admin] Toggle question bank active/inactive",
)
async def admin_toggle_question_bank(
    bank_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Toggle a question bank between active (is_deleted=False) and inactive (is_deleted=True)."""
    result = await db.execute(
        select(QuestionBank).where(QuestionBank.id == bank_id)
    )
    bank = result.scalar_one_or_none()

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

    return QuestionBankToggleResponse(
        id=bank.id,
        title=bank.title,
        is_deleted=bank.is_deleted,
        message=f"Question bank '{bank.title}' has been {action}.",
    )


# ─────────────────────────────────────────────────────────────
# DELETE /admin/question-banks/{bank_id}  — Soft delete
# ─────────────────────────────────────────────────────────────

@router.delete(
    "/question-banks/{bank_id}",
    status_code=204,
    summary="[Admin] Soft-delete question bank",
)
async def admin_delete_question_bank(
    bank_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Permanently soft-delete a question bank (sets is_deleted=True, cannot be reversed via API)."""
    result = await db.execute(
        select(QuestionBank).where(QuestionBank.id == bank_id)
    )
    bank = result.scalar_one_or_none()

    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    bank.is_deleted = True
    await db.commit()

    logger.info("Admin %s deleted question bank %s.", _admin.id, bank_id)


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
    # Verify bank exists
    result = await db.execute(
        select(QuestionBank).where(QuestionBank.id == bank_id)
    )
    bank = result.scalar_one_or_none()
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
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total else 0,
        has_next=page < math.ceil(total / page_size) if total else False,
        has_prev=page > 1,
    )


# ─────────────────────────────────────────────────────────────
# POST /admin/question-banks/{bank_id}/questions  — Create
# ─────────────────────────────────────────────────────────────

@router.post(
    "/question-banks/{bank_id}/questions",
    response_model=AdminQuestionSummary,
    status_code=201,
    summary="[Admin] Create question in a bank",
)
async def admin_create_question(
    bank_id: int,
    payload: QuestionCreate,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Create a new question in the specified question bank."""
    # Verify bank exists
    result = await db.execute(
        select(QuestionBank).where(QuestionBank.id == bank_id)
    )
    bank = result.scalar_one_or_none()
    if bank is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found.",
        )

    question = Question(
        bank_id=bank_id,
        content=payload.content,
        choices=payload.choices,
        correct_answer=payload.correct_answer,
    )
    db.add(question)
    await db.commit()
    await db.refresh(question)

    logger.info(
        "Admin %s created question %s in bank %s.",
        _admin.id,
        question.id,
        bank_id,
    )

    return AdminQuestionSummary.model_validate(question)


# ─────────────────────────────────────────────────────────────
# PUT /admin/questions/{question_id}  — Update
# ─────────────────────────────────────────────────────────────

@router.put(
    "/questions/{question_id}",
    response_model=AdminQuestionSummary,
    summary="[Admin] Update question",
)
async def admin_update_question(
    question_id: int,
    payload: QuestionUpdate,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Update an existing question's content, choices, or correct answer."""
    result = await db.execute(
        select(Question).where(Question.id == question_id)
    )
    question = result.scalar_one_or_none()

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    if payload.content is not None:
        question.content = payload.content
    if payload.choices is not None:
        question.choices = payload.choices
    if payload.correct_answer is not None:
        question.correct_answer = payload.correct_answer

    await db.commit()
    await db.refresh(question)

    logger.info(
        "Admin %s updated question %s in bank %s.",
        _admin.id,
        question.id,
        question.bank_id,
    )

    return AdminQuestionSummary.model_validate(question)


# ─────────────────────────────────────────────────────────────
# PATCH /admin/questions/{question_id}/toggle  — Toggle active
# ─────────────────────────────────────────────────────────────

@router.patch(
    "/questions/{question_id}/toggle",
    response_model=QuestionToggleResponse,
    summary="[Admin] Toggle question active/inactive",
)
async def admin_toggle_question(
    question_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Toggle a question between active (is_deleted=False) and inactive (is_deleted=True)."""
    result = await db.execute(
        select(Question).where(Question.id == question_id)
    )
    question = result.scalar_one_or_none()

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
        "Admin %s %s question %s in bank %s.",
        _admin.id,
        action,
        question.id,
        question.bank_id,
    )

    return QuestionToggleResponse(
        id=question.id,
        bank_id=question.bank_id,
        is_deleted=question.is_deleted,
        message=f"Question has been {action}.",
    )


# ─────────────────────────────────────────────────────────────
# DELETE /admin/questions/{question_id}  — Soft delete
# ─────────────────────────────────────────────────────────────

@router.delete(
    "/questions/{question_id}",
    status_code=204,
    summary="[Admin] Soft-delete question",
)
async def admin_delete_question(
    question_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """Permanently soft-delete a question (sets is_deleted=True, cannot be reversed via API)."""
    result = await db.execute(
        select(Question).where(Question.id == question_id)
    )
    question = result.scalar_one_or_none()

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    question.is_deleted = True
    await db.commit()

    logger.info(
        "Admin %s deleted question %s in bank %s.",
        _admin.id,
        question_id,
        question.bank_id,
    )
