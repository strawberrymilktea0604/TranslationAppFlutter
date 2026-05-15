"""
Quiz Repository - Data access layer for UserQuiz operations.
"""
import logging
from typing import List, Tuple

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
        completion_time_seconds: int,
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
            completion_time_seconds: Elapsed time in seconds.

        Returns:
            Tuple of (UserQuiz ORM instance, list of QuizAnswerResult).

        Raises:
            ValueError: If the question bank is not found or has no questions.
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
            raise ValueError(f"Question bank {bank_id} not found")

        active_questions: List[Question] = [
            q for q in bank.questions if not q.is_deleted
        ]

        if not active_questions:
            raise ValueError(f"Question bank {bank_id} contains no active questions")

        # 2. Build a lookup map {question_id -> correct_answer}
        correct_map = {q.id: q.correct_answer for q in active_questions}

        # 3. Grade each submitted answer
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

        # 4. Calculate percentage score
        total_questions = len(active_questions)
        score = round((correct_count / total_questions) * 100, 2) if total_questions else 0.0

        # 5. Determine status
        status = "completed"

        # 6. Persist to user_quizzes
        quiz = UserQuiz(
            user_id=user_id,
            bank_id=bank_id,
            score=score,
            completion_time_seconds=completion_time_seconds,
            status=status,
        )
        db.add(quiz)
        await db.commit()
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
                status=quiz.status,
                created_at=quiz.created_at,
            )
            for quiz, bank_title in rows
        ]

        return items, total
