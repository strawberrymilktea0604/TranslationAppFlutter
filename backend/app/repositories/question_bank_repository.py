"""
Question Bank Repository — Admin CRUD operations.

All mutations here are intended only for admin-protected endpoints.
Soft-delete (is_deleted=True) is the default strategy for both
QuestionBank and Question; hard (permanent) delete is opt-in.
"""
import logging
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.learning import Question, QuestionBank
from app.schemas.admin import (
    QuestionBankCreateRequest,
    QuestionBankUpdateRequest,
    QuestionCreateRequest,
    QuestionUpdateRequest,
)

logger = logging.getLogger(__name__)


class QuestionBankRepository:
    """Data-access layer for admin Question Bank & Question mutations."""

    # ──────────────────────────────────────────────
    # QuestionBank CRUD
    # ──────────────────────────────────────────────

    @staticmethod
    async def create_bank(
        db: AsyncSession,
        data: QuestionBankCreateRequest,
    ) -> QuestionBank:
        """
        Create a new QuestionBank record.

        Args:
            db: Async database session.
            data: Validated create request.

        Returns:
            The newly created QuestionBank ORM instance (after commit & refresh).
        """
        bank = QuestionBank(
            title=data.title,
            description=data.description,
            duration_minutes=data.duration_minutes,
            is_deleted=False,
        )
        db.add(bank)
        await db.commit()
        await db.refresh(bank)
        logger.info("✅ QuestionBank created (ID: %s, title: %r)", bank.id, bank.title)
        return bank

    @staticmethod
    async def get_bank(
        db: AsyncSession,
        bank_id: int,
        include_deleted: bool = False,
    ) -> Optional[QuestionBank]:
        """
        Fetch a single QuestionBank by primary key.

        Args:
            db: Async database session.
            bank_id: Primary key of the bank.
            include_deleted: If True, soft-deleted banks are also returned.

        Returns:
            QuestionBank instance or None.
        """
        stmt = select(QuestionBank).where(QuestionBank.id == bank_id)
        if not include_deleted:
            stmt = stmt.where(QuestionBank.is_deleted.is_(False))
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    @staticmethod
    async def update_bank(
        db: AsyncSession,
        bank: QuestionBank,
        data: QuestionBankUpdateRequest,
    ) -> QuestionBank:
        """
        Apply a partial update to an existing QuestionBank.

        Only non-None fields in *data* are written; None means "leave unchanged".

        Args:
            db: Async database session.
            bank: ORM instance to mutate (already fetched, not soft-deleted).
            data: Validated partial-update request.

        Returns:
            The updated QuestionBank instance (after commit & refresh).
        """
        if data.title is not None:
            bank.title = data.title
        if data.description is not None:
            bank.description = data.description
        if data.duration_minutes is not None:
            bank.duration_minutes = data.duration_minutes

        await db.commit()
        await db.refresh(bank)
        logger.info("✏️  QuestionBank updated (ID: %s)", bank.id)
        return bank

    @staticmethod
    async def delete_bank(
        db: AsyncSession,
        bank: QuestionBank,
        permanent: bool = False,
    ) -> None:
        """
        Delete or soft-disable a QuestionBank.

        Args:
            db: Async database session.
            bank: ORM instance to delete (already fetched).
            permanent: If True, hard-delete the row; otherwise set is_deleted=True.
        """
        if permanent:
            await db.delete(bank)
            logger.info("🗑️  QuestionBank hard-deleted (ID: %s)", bank.id)
        else:
            bank.is_deleted = True
            logger.info("🚫 QuestionBank soft-deleted (ID: %s)", bank.id)
        await db.commit()

    # ──────────────────────────────────────────────
    # Question CRUD
    # ──────────────────────────────────────────────

    @staticmethod
    async def create_question(
        db: AsyncSession,
        bank_id: int,
        data: QuestionCreateRequest,
    ) -> Question:
        """
        Add a new Question to an existing QuestionBank.

        Args:
            db: Async database session.
            bank_id: FK to the owning QuestionBank (caller must verify it exists).
            data: Validated create request.

        Returns:
            The newly created Question ORM instance (after commit & refresh).
        """
        question = Question(
            bank_id=bank_id,
            content=data.content,
            choices=data.choices,
            correct_answer=data.correct_answer,
            is_deleted=False,
        )
        db.add(question)
        await db.commit()
        await db.refresh(question)
        logger.info(
            "✅ Question created (ID: %s, bank_id: %s)", question.id, bank_id
        )
        return question

    @staticmethod
    async def get_question(
        db: AsyncSession,
        question_id: int,
        include_deleted: bool = False,
    ) -> Optional[Question]:
        """
        Fetch a single Question by primary key.

        Args:
            db: Async database session.
            question_id: Primary key of the question.
            include_deleted: If True, soft-deleted questions are also returned.

        Returns:
            Question instance or None.
        """
        stmt = select(Question).where(Question.id == question_id)
        if not include_deleted:
            stmt = stmt.where(Question.is_deleted.is_(False))
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    @staticmethod
    async def update_question(
        db: AsyncSession,
        question: Question,
        data: QuestionUpdateRequest,
    ) -> Question:
        """
        Apply a partial update to an existing Question.

        Only non-None fields in *data* are written; None means "leave unchanged".

        Args:
            db: Async database session.
            question: ORM instance to mutate (already fetched, not soft-deleted).
            data: Validated partial-update request.

        Returns:
            The updated Question instance (after commit & refresh).
        """
        if data.content is not None:
            question.content = data.content
        if data.choices is not None:
            question.choices = data.choices
        if data.correct_answer is not None:
            question.correct_answer = data.correct_answer

        await db.commit()
        await db.refresh(question)
        logger.info("✏️  Question updated (ID: %s)", question.id)
        return question

    @staticmethod
    async def delete_question(
        db: AsyncSession,
        question: Question,
        permanent: bool = False,
    ) -> None:
        """
        Delete or soft-disable a Question.

        Args:
            db: Async database session.
            question: ORM instance to delete (already fetched).
            permanent: If True, hard-delete the row; otherwise set is_deleted=True.
        """
        if permanent:
            await db.delete(question)
            logger.info("🗑️  Question hard-deleted (ID: %s)", question.id)
        else:
            question.is_deleted = True
            logger.info("🚫 Question soft-deleted (ID: %s)", question.id)
        await db.commit()
