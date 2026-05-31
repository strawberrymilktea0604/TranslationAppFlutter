"""
Quiz Repository - Data access layer for UserQuiz operations.
"""
import logging
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, desc
from sqlalchemy.orm import selectinload

from app.models.learning import Question, QuestionBank, UserQuiz
from app.schemas.learning import (
    UserAnswerItem,
    QuizAnswerResult,
    UserQuizHistoryItem,
)

logger = logging.getLogger(__name__)


class QuizRepository:
    """Repository for quiz submission and history operations."""

    # ------------------------------------------------------------------
    # Submit / Grade
    # ------------------------------------------------------------------

    @staticmethod
    async def grade_and_save(
        db: AsyncSession,
        user_id: int,
        bank_id: int,
        answers: List[UserAnswerItem],
        completion_time_seconds: Optional[int] = None,
        time_spent_seconds: Optional[int] = None,
        sync_client_id: Optional[str] = None,
        commit: bool = True,
    ) -> Tuple[UserQuiz, List[QuizAnswerResult]]:
        """
        Grade user answers against the correct answers stored in the DB,
        persist the result to ``user_quizzes``, and return the saved record
        together with a per-question breakdown.

        Args:
            db: Async database session.
            user_id: Authenticated user ID.
            bank_id: ID of the QuestionBank being submitted.
            answers: List of UserAnswerItem (question_id + selected_answer).
            completion_time_seconds: Legacy elapsed time field.
            time_spent_seconds: Canonical elapsed time field (preferred).
            sync_client_id: Stable client ID used by offline sync retries.
            commit: Commit immediately for normal submissions; flush only when
                    an outer batch transaction owns the commit.

        Returns:
            Tuple of (UserQuiz ORM instance, list of QuizAnswerResult).

        Raises:
            ValueError: Prefixed with "not_found:" or "bad_request:" so the
                        endpoint can map to the correct HTTP status.
        """
        # 1. Load the bank with its active questions
        bank_result = await db.execute(
            select(QuestionBank)
            .where(
                QuestionBank.id == bank_id,
                QuestionBank.is_deleted.is_(False),
            )
            .options(selectinload(QuestionBank.questions))
        )
        bank = bank_result.scalar_one_or_none()

        if bank is None:
            raise ValueError(f"not_found:Question bank {bank_id} not found")

        active_questions: List[Question] = [
            q for q in bank.questions if not q.is_deleted
        ]

        if not active_questions:
            raise ValueError(
                f"not_found:Question bank {bank_id} contains no active questions"
            )

        # 1b. Enforce time limit — reject submissions that exceed the bank's duration.
        #     Only applies when duration_minutes is configured on the bank.
        resolved_time = time_spent_seconds if time_spent_seconds is not None else completion_time_seconds
        if bank.duration_minutes is not None and resolved_time is not None:
            time_limit_seconds = bank.duration_minutes * 60
            if resolved_time > time_limit_seconds:
                raise ValueError(
                    f"bad_request:Quiz time limit exceeded "
                    f"({resolved_time}s submitted, limit is {time_limit_seconds}s)"
                )

        # 2. Validate the submitted answer set
        active_ids = {q.id for q in active_questions}
        submitted_ids = [a.question_id for a in answers]

        # a) Duplicate question IDs
        seen: set = set()
        duplicates = {qid for qid in submitted_ids if qid in seen or seen.add(qid)}  # type: ignore[func-returns-value]
        if duplicates:
            raise ValueError(
                f"bad_request:Duplicate answers for question IDs: {sorted(duplicates)}"
            )

        submitted_id_set = set(submitted_ids)

        # b) Unknown question IDs
        unknown = submitted_id_set - active_ids
        if unknown:
            raise ValueError(
                f"bad_request:Unknown question IDs for this bank: {sorted(unknown)}"
            )

        # c) Missing answers for active questions
        missing = active_ids - submitted_id_set
        if missing:
            raise ValueError(
                f"bad_request:Missing answers for question IDs: {sorted(missing)}"
            )

        # 3. Build a lookup map {question_id -> correct_answer}
        correct_map = {q.id: q.correct_answer for q in active_questions}

        # 4. Grade each submitted answer
        results: List[QuizAnswerResult] = []
        correct_count = 0

        for answer in answers:
            correct_answer = correct_map.get(answer.question_id, "")
            is_correct = (
                answer.selected_answer.strip() == correct_answer.strip()
            )
            if is_correct:
                correct_count += 1

            results.append(
                QuizAnswerResult(
                    question_id=answer.question_id,
                    selected_answer=answer.selected_answer,
                    correct_answer=correct_answer,
                    is_correct=is_correct,
                )
            )

        # 5. Calculate percentage score
        total_questions = len(active_questions)
        score = round((correct_count / total_questions) * 100, 2) if total_questions else 0.0

        # 6. resolved_time was already computed above (for timeout enforcement).

        # 7. Status is always 'completed' here — timed-out submissions are
        #    rejected with 400 before they reach this point (step 1b).
        quiz_status = "completed"

        # 8. Persist to user_quizzes
        now_utc = datetime.now(timezone.utc)
        quiz = UserQuiz(
            user_id=user_id,
            sync_client_id=sync_client_id,
            bank_id=bank_id,
            score=score,
            # Legacy field kept populated for backward compat
            completion_time_seconds=(
                completion_time_seconds if completion_time_seconds is not None else resolved_time
            ),
            # New canonical fields
            time_spent_seconds=resolved_time,
            total_questions=total_questions,
            correct_answers=correct_count,
            submitted_at=now_utc,
            status=quiz_status,
        )
        db.add(quiz)
        if commit:
            await db.commit()
        else:
            await db.flush()
        await db.refresh(quiz)

        logger.info(
            "✅ Quiz saved (ID: %s, User: %s, Bank: %s, Score: %.2f%%)",
            quiz.id,
            user_id,
            bank_id,
            score,
        )
        return quiz, results

    # ------------------------------------------------------------------
    # History
    # ------------------------------------------------------------------

    @staticmethod
    async def get_user_history(
        db: AsyncSession,
        user_id: int,
        page: int = 1,
        page_size: int = 20,
    ) -> Tuple[List[UserQuizHistoryItem], int]:
        """
        Retrieve a paginated list of the user's past quiz attempts,
        including the bank title for display purposes.

        Args:
            db: Async database session.
            user_id: Authenticated user ID.
            page: 1-indexed page number.
            page_size: Number of records per page (max 100).

        Returns:
            Tuple of (list of UserQuizHistoryItem, total count).
        """
        page_size = min(max(page_size, 1), 100)
        skip = (max(page, 1) - 1) * page_size

        # Total count
        count_result = await db.execute(
            select(func.count(UserQuiz.id)).where(UserQuiz.user_id == user_id)
        )
        total: int = count_result.scalar() or 0

        # Fetch page — join QuestionBank for its title
        rows_result = await db.execute(
            select(UserQuiz, QuestionBank.title.label("bank_title"))
            .join(QuestionBank, UserQuiz.bank_id == QuestionBank.id)
            .where(UserQuiz.user_id == user_id)
            .order_by(desc(UserQuiz.created_at))
            .offset(skip)
            .limit(page_size)
        )
        rows = rows_result.all()

        items: List[UserQuizHistoryItem] = [
            UserQuizHistoryItem(
                quiz_id=quiz.id,
                bank_id=quiz.bank_id,
                bank_title=bank_title,
                score=quiz.score,
                completion_time_seconds=quiz.completion_time_seconds,
                time_spent_seconds=quiz.time_spent_seconds,
                total_questions=quiz.total_questions,
                correct_answers=quiz.correct_answers,
                status=quiz.status,
                created_at=quiz.created_at,
            )
            for quiz, bank_title in rows
        ]

        return items, total
