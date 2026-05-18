"""
Learning endpoints — Question Banks, Quiz submission, and Quiz history.
"""
import math
from typing import List, Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.dependencies import DBSession, get_current_user
from app.models.learning import QuestionBank
from app.models.user import User
from app.repositories.quiz_repository import QuizRepository
from app.schemas.learning import (
    QuestionBankBase,
    QuestionBankDetail,
    QuizSubmitRequest,
    QuizSubmitResponse,
    UserQuizHistoryResponse,
)

router = APIRouter(prefix="/learning", tags=["learning"])


# ──────────────────────────────────────────────────────────
# Question Banks
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


@router.get("/banks/{bank_id}", response_model=QuestionBankDetail)
async def get_question_bank_detail(
    bank_id: int,
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Return details of a specific question bank, including its active questions."""
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

    # Build the response model and filter out deleted questions
    response_data = QuestionBankDetail.model_validate(bank)
    response_data.questions = [q for q in response_data.questions if not q.is_deleted]
    return response_data


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
    - Returns score, per-question breakdown, and the saved record metadata.
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
