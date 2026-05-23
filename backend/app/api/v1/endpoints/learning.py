"""
Learning endpoints — Question Banks, Quiz submission, and Quiz history.

Security note
-------------
``correct_answer`` is intentionally omitted from all user-facing endpoints.
It is only exposed:
  - In ``GET /admin/banks/{bank_id}`` (admin-protected).
  - In ``POST /banks/{bank_id}/submit`` *response* after grading (per-question breakdown).
"""
import math
from typing import List, Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.core.dependencies import DBSession, get_admin_user, get_current_user
from app.models.learning import Question, QuestionBank
from app.models.user import User
from app.repositories.quiz_repository import QuizRepository
from app.schemas.learning import (
    QuestionBankAdminDetail,
    QuestionBankBase,
    QuestionBankDetail,
    QuestionBankStartResponse,
    QuestionListResponse,
    QuestionPublicSchema,
    QuestionAdminSchema,
    QuizSubmitRequest,
    QuizSubmitResponse,
    UserQuizHistoryResponse,
)

router = APIRouter(prefix="/learning", tags=["learning"])


# ──────────────────────────────────────────────────────────
# Question Banks — list
# ──────────────────────────────────────────────────────────

@router.get("/banks", response_model=List[QuestionBankBase])
async def get_question_banks(
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
    skip: int = 0,
    limit: int = 100,
):
    """Return a paginated list of active question banks."""
    stmt = (
        select(QuestionBank)
        .where(QuestionBank.is_deleted.is_(False))
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    banks = result.scalars().all()
    return banks


# ──────────────────────────────────────────────────────────
# Question Banks — detail (mobile-safe: no correct_answer)
# ──────────────────────────────────────────────────────────

@router.get("/banks/{bank_id}", response_model=QuestionBankDetail)
async def get_question_bank_detail(
    bank_id: int,
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
):
    """
    Return details of a specific question bank with its active questions.
    ``correct_answer`` is omitted — use the admin endpoint if you need it.
    """
    stmt = (
        select(QuestionBank)
        .where(
            QuestionBank.id == bank_id,
            QuestionBank.is_deleted.is_(False),
        )
        .options(selectinload(QuestionBank.questions))
    )
    result = await db.execute(stmt)
    bank = result.scalar_one_or_none()

    if not bank:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found",
        )

    active_questions = [
        QuestionPublicSchema.model_validate(q)
        for q in bank.questions
        if not q.is_deleted
    ]

    return QuestionBankDetail(
        id=bank.id,
        title=bank.title,
        description=bank.description,
        duration_minutes=bank.duration_minutes,
        created_at=bank.created_at,
        questions=active_questions,
    )


# ──────────────────────────────────────────────────────────
# Questions list (paginated, mobile-safe)
# ──────────────────────────────────────────────────────────

@router.get("/banks/{bank_id}/questions", response_model=QuestionListResponse)
async def get_bank_questions(
    bank_id: int,
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Questions per page"),
):
    """
    Return a paginated list of active questions for a bank.
    ``correct_answer`` is intentionally omitted for quiz integrity.
    """
    # Verify bank exists
    bank_result = await db.execute(
        select(QuestionBank).where(
            QuestionBank.id == bank_id,
            QuestionBank.is_deleted.is_(False),
        )
    )
    bank = bank_result.scalar_one_or_none()
    if not bank:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found",
        )

    skip = (page - 1) * page_size

    # Total active questions for this bank
    count_result = await db.execute(
        select(func.count(Question.id)).where(
            Question.bank_id == bank_id,
            Question.is_deleted.is_(False),
        )
    )
    total: int = count_result.scalar() or 0
    total_pages = math.ceil(total / page_size) if total else 0

    # Fetch page
    rows_result = await db.execute(
        select(Question)
        .where(
            Question.bank_id == bank_id,
            Question.is_deleted.is_(False),
        )
        .offset(skip)
        .limit(page_size)
    )
    questions = rows_result.scalars().all()

    return QuestionListResponse(
        bank_id=bank_id,
        items=[QuestionPublicSchema.model_validate(q) for q in questions],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_prev=page > 1,
    )


# ──────────────────────────────────────────────────────────
# Quiz start (mobile-safe)
# ──────────────────────────────────────────────────────────

@router.get("/banks/{bank_id}/start", response_model=QuestionBankStartResponse)
async def start_quiz(
    bank_id: int,
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
):
    """
    Official mobile quiz-start endpoint.
    Returns bank metadata and all active questions without ``correct_answer``.
    """
    stmt = (
        select(QuestionBank)
        .where(
            QuestionBank.id == bank_id,
            QuestionBank.is_deleted.is_(False),
        )
        .options(selectinload(QuestionBank.questions))
    )
    result = await db.execute(stmt)
    bank = result.scalar_one_or_none()

    if not bank:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found",
        )

    active_questions = [
        QuestionPublicSchema.model_validate(q)
        for q in bank.questions
        if not q.is_deleted
    ]

    return QuestionBankStartResponse(
        id=bank.id,
        title=bank.title,
        description=bank.description,
        duration_minutes=bank.duration_minutes,
        total_questions=len(active_questions),
        questions=active_questions,
    )


# ──────────────────────────────────────────────────────────
# Quiz Submit
# ──────────────────────────────────────────────────────────

@router.post(
    "/banks/{bank_id}/submit",
    response_model=QuizSubmitResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit quiz answers",
    description=(
        "Grade the user's answers against the correct answers stored in the DB, "
        "persist the result to UserQuizzes, and return a full breakdown."
    ),
)
async def submit_quiz(
    bank_id: int,
    payload: QuizSubmitRequest,
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
):
    """
    Submit quiz answers for a question bank.

    - Validates that the bank exists.
    - Grades each answer against the stored ``correct_answer``.
    - Saves the result in ``user_quizzes``.
    - Returns score, per-question breakdown (correct_answer revealed here), and saved record metadata.
    """
    try:
        quiz, results = await QuizRepository.grade_and_save(
            db=db,
            user_id=current_user.id,
            bank_id=bank_id,
            answers=payload.answers,
            completion_time_seconds=payload.completion_time_seconds,
            time_spent_seconds=payload.time_spent_seconds,
        )
    except ValueError as exc:
        msg = str(exc)
        if msg.startswith("bad_request:"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=msg[len("bad_request:"):].strip(),
            )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=msg[len("not_found:"):].strip() if msg.startswith("not_found:") else msg,
        )

    correct_count = sum(1 for r in results if r.is_correct)

    return QuizSubmitResponse(
        quiz_id=quiz.id,
        bank_id=quiz.bank_id,
        score=quiz.score,
        total_questions=len(results),
        correct_count=correct_count,
        correct_answers=correct_count,
        completion_time_seconds=quiz.completion_time_seconds,
        time_spent_seconds=quiz.time_spent_seconds,
        submitted_at=quiz.submitted_at,
        status=quiz.status,
        created_at=quiz.created_at,
        results=results,
    )


# ──────────────────────────────────────────────────────────
# Quiz History
# ──────────────────────────────────────────────────────────

@router.get(
    "/history",
    response_model=UserQuizHistoryResponse,
    summary="Get user quiz history",
    description="Return a paginated list of all past quiz attempts for the authenticated user.",
)
async def get_quiz_history(
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Records per page"),
):
    """Retrieve the authenticated user's quiz history with pagination."""
    items, total = await QuizRepository.get_user_history(
        db=db,
        user_id=current_user.id,
        page=page,
        page_size=page_size,
    )

    total_pages = math.ceil(total / page_size) if total else 0

    return UserQuizHistoryResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_prev=page > 1,
    )


# ──────────────────────────────────────────────────────────
# Admin — bank detail (includes correct_answer)
# ──────────────────────────────────────────────────────────

@router.get(
    "/admin/banks/{bank_id}",
    response_model=QuestionBankAdminDetail,
    summary="[Admin] Bank detail with correct answers",
    description=(
        "Returns bank metadata and questions including ``correct_answer``. "
        "This endpoint is for internal/admin use only. "
        "Do NOT expose to regular mobile clients."
    ),
    tags=["learning-admin"],
)
async def admin_get_question_bank_detail(
    bank_id: int,
    db: DBSession,
    _admin: Annotated[User, Depends(get_admin_user)],
):
    """
    Admin endpoint: return all question details including correct_answer.

    Protected by ``get_admin_user``: unauthenticated → 401, non-admin → 403.
    """
    stmt = (
        select(QuestionBank)
        .where(
            QuestionBank.id == bank_id,
            QuestionBank.is_deleted.is_(False),
        )
        .options(selectinload(QuestionBank.questions))
    )
    result = await db.execute(stmt)
    bank = result.scalar_one_or_none()

    if not bank:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found",
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
