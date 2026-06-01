from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import case, desc, distinct, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.learning import QuestionBank, UserQuiz
from app.models.system import ApiMetric
from app.models.translation import Translation
from app.models.user import User


class AdminDashboardRepository:
    """Read-optimized queries for admin dashboard and analytics screens."""

    @staticmethod
    def utcnow() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    async def count_translations(
        db: AsyncSession,
        *,
        start_at: Optional[datetime] = None,
        end_at: Optional[datetime] = None,
    ) -> int:
        stmt = select(func.count(Translation.id)).where(Translation.is_deleted.is_(False))
        if start_at is not None:
            stmt = stmt.where(Translation.created_at >= start_at)
        if end_at is not None:
            stmt = stmt.where(Translation.created_at < end_at)
        return (await db.execute(stmt)).scalar() or 0

    @staticmethod
    async def count_active_translation_users(
        db: AsyncSession,
        *,
        start_at: datetime,
        end_at: datetime,
    ) -> int:
        stmt = select(func.count(distinct(Translation.user_id))).where(
            Translation.is_deleted.is_(False),
            Translation.created_at >= start_at,
            Translation.created_at < end_at,
        )
        return (await db.execute(stmt)).scalar() or 0

    @staticmethod
    async def average_response_time_ms(
        db: AsyncSession,
        *,
        start_at: datetime,
        end_at: datetime,
    ) -> float:
        stmt = select(func.avg(ApiMetric.response_time_ms)).where(
            ApiMetric.created_at >= start_at,
            ApiMetric.created_at < end_at,
        )
        value = (await db.execute(stmt)).scalar() or 0.0
        return float(value)

    @staticmethod
    async def successful_request_percent(
        db: AsyncSession,
        *,
        start_at: datetime,
        end_at: datetime,
    ) -> float:
        total_stmt = select(func.count(ApiMetric.id)).where(
            ApiMetric.is_ai_request.is_(True),
            ApiMetric.created_at >= start_at,
            ApiMetric.created_at < end_at,
        )
        success_stmt = select(func.count(ApiMetric.id)).where(
            ApiMetric.is_ai_request.is_(True),
            ApiMetric.status_code >= 200,
            ApiMetric.status_code < 400,
            ApiMetric.created_at >= start_at,
            ApiMetric.created_at < end_at,
        )
        total = (await db.execute(total_stmt)).scalar() or 0
        if total == 0:
            return 0.0
        success = (await db.execute(success_stmt)).scalar() or 0
        return (success / total) * 100

    @staticmethod
    async def translation_type_counts(
        db: AsyncSession,
        *,
        start_at: Optional[datetime] = None,
        end_at: Optional[datetime] = None,
    ) -> list[tuple[str, int]]:
        service_type = func.coalesce(Translation.translation_type, "unknown")
        stmt = (
            select(service_type.label("type"), func.count(Translation.id))
            .where(Translation.is_deleted.is_(False))
            .group_by(service_type)
            .order_by(desc(func.count(Translation.id)))
        )
        if start_at is not None:
            stmt = stmt.where(Translation.created_at >= start_at)
        if end_at is not None:
            stmt = stmt.where(Translation.created_at < end_at)
        return [(str(row[0]), int(row[1] or 0)) for row in (await db.execute(stmt)).all()]

    @staticmethod
    async def language_counts(
        db: AsyncSession,
        *,
        column,
        start_at: datetime,
        end_at: datetime,
    ) -> list[tuple[str, int]]:
        language = func.coalesce(column, "unknown")
        stmt = (
            select(language.label("language"), func.count(Translation.id))
            .where(
                Translation.is_deleted.is_(False),
                Translation.created_at >= start_at,
                Translation.created_at < end_at,
            )
            .group_by(language)
            .order_by(desc(func.count(Translation.id)))
        )
        return [(str(row[0]), int(row[1] or 0)) for row in (await db.execute(stmt)).all()]

    @staticmethod
    async def list_translations(
        db: AsyncSession,
        *,
        page: int,
        page_size: int,
        search: Optional[str] = None,
        translation_type: Optional[str] = None,
        source_language: Optional[str] = None,
        target_language: Optional[str] = None,
        user_id: Optional[int] = None,
        include_deleted: bool = False,
    ) -> tuple[list, int]:
        stmt = select(
            Translation,
            User.email,
            User.first_name,
            User.last_name,
        ).outerjoin(User, Translation.user_id == User.id)

        if not include_deleted:
            stmt = stmt.where(Translation.is_deleted.is_(False))
        if translation_type:
            stmt = stmt.where(Translation.translation_type == translation_type)
        if source_language:
            stmt = stmt.where(Translation.source_language == source_language)
        if target_language:
            stmt = stmt.where(Translation.target_language == target_language)
        if user_id:
            stmt = stmt.where(Translation.user_id == user_id)
        if search:
            pattern = f"%{search}%"
            stmt = stmt.where(
                or_(
                    Translation.source_text.ilike(pattern),
                    Translation.translated_text.ilike(pattern),
                    User.email.ilike(pattern),
                    User.first_name.ilike(pattern),
                    User.last_name.ilike(pattern),
                )
            )

        total_stmt = select(func.count()).select_from(stmt.order_by(None).subquery())
        total = (await db.execute(total_stmt)).scalar() or 0

        offset = (page - 1) * page_size
        rows = (
            await db.execute(
                stmt.order_by(desc(Translation.created_at)).offset(offset).limit(page_size)
            )
        ).all()
        return rows, total

    @staticmethod
    async def service_metrics(
        db: AsyncSession,
        *,
        start_at: datetime,
        end_at: datetime,
    ) -> list:
        success_count = func.sum(
            case((ApiMetric.status_code.between(200, 399), 1), else_=0)
        )
        failed_count = func.sum(
            case((ApiMetric.status_code.between(200, 399), 0), else_=1)
        )
        stmt = (
            select(
                ApiMetric.endpoint,
                ApiMetric.ai_model,
                func.count(ApiMetric.id),
                success_count,
                failed_count,
                func.avg(ApiMetric.response_time_ms),
                func.sum(ApiMetric.ai_tokens_used),
            )
            .where(
                ApiMetric.created_at >= start_at,
                ApiMetric.created_at < end_at,
            )
            .group_by(ApiMetric.endpoint, ApiMetric.ai_model)
            .order_by(desc(func.count(ApiMetric.id)))
        )
        return (await db.execute(stmt)).all()

    @staticmethod
    async def recent_translations(db: AsyncSession, *, limit: int) -> list:
        stmt = (
            select(Translation, User.email)
            .outerjoin(User, Translation.user_id == User.id)
            .where(Translation.is_deleted.is_(False))
            .order_by(desc(Translation.created_at))
            .limit(limit)
        )
        return (await db.execute(stmt)).all()

    @staticmethod
    async def recent_users(db: AsyncSession, *, limit: int) -> list[User]:
        stmt = (
            select(User)
            .where(User.is_deleted.is_(False))
            .order_by(desc(User.created_at))
            .limit(limit)
        )
        return (await db.execute(stmt)).scalars().all()

    @staticmethod
    async def recent_quizzes(db: AsyncSession, *, limit: int) -> list:
        activity_time = func.coalesce(UserQuiz.submitted_at, UserQuiz.created_at)
        stmt = (
            select(UserQuiz, User.email, QuestionBank.title, activity_time.label("activity_time"))
            .join(User, UserQuiz.user_id == User.id)
            .join(QuestionBank, UserQuiz.bank_id == QuestionBank.id)
            .order_by(desc(activity_time))
            .limit(limit)
        )
        return (await db.execute(stmt)).all()
