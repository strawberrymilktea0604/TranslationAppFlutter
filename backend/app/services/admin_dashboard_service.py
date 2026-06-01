from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.translation import Translation
from app.models.user import User
from app.repositories.admin_dashboard_repository import AdminDashboardRepository
from app.repositories.user_repository import UserRepository
from app.schemas.admin import AdminUserCreateRequest


class AdminDashboardService:
    """Business logic for admin dashboard, service management, and analytics."""

    @staticmethod
    def _bounds(days: int) -> tuple[datetime, datetime, datetime]:
        end_at = AdminDashboardRepository.utcnow()
        start_at = end_at - timedelta(days=days)
        previous_start_at = start_at - timedelta(days=days)
        return previous_start_at, start_at, end_at

    @staticmethod
    def _percentage_items(rows: list[tuple[str, int]]) -> list[dict]:
        total = sum(count for _, count in rows)
        return [
            {
                "type": label,
                "count": count,
                "percentage": round((count / total) * 100, 2) if total else 0.0,
            }
            for label, count in rows
        ]

    @staticmethod
    def _language_items(rows: list[tuple[str, int]]) -> list[dict]:
        total = sum(count for _, count in rows)
        return [
            {
                "language": label,
                "count": count,
                "percentage": round((count / total) * 100, 2) if total else 0.0,
            }
            for label, count in rows
        ]

    @staticmethod
    def _change_percent(current: float, previous: float) -> float:
        if previous == 0:
            return 100.0 if current > 0 else 0.0
        return round(((current - previous) / previous) * 100, 2)

    @staticmethod
    def _metric_card(current: float, previous: float) -> dict:
        return {
            "value": round(float(current), 2),
            "previous_value": round(float(previous), 2),
            "change_percent": AdminDashboardService._change_percent(current, previous),
        }

    @staticmethod
    def _display_name(first_name: Optional[str], last_name: Optional[str]) -> Optional[str]:
        name = " ".join(part for part in [first_name, last_name] if part)
        return name or None

    @staticmethod
    async def create_user(db: AsyncSession, payload: AdminUserCreateRequest) -> User:
        email = payload.email.strip().lower()
        existing = await UserRepository(db).get_by_email(email)
        if existing is not None:
            raise ValueError("Email already exists.")

        user = User(
            email=email,
            first_name=payload.first_name,
            last_name=payload.last_name,
            password_hash=hash_password(payload.password),
            role=payload.role,
            status=payload.status,
            is_deleted=False,
        )
        return await UserRepository(db).create(user)

    @staticmethod
    async def service_summary(db: AsyncSession) -> dict:
        now = AdminDashboardRepository.utcnow()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        week_start = now - timedelta(days=7)
        month_start = now - timedelta(days=30)

        total = await AdminDashboardRepository.count_translations(db)
        today = await AdminDashboardRepository.count_translations(db, start_at=today_start)
        week = await AdminDashboardRepository.count_translations(db, start_at=week_start)
        month = await AdminDashboardRepository.count_translations(db, start_at=month_start)
        by_type_rows = await AdminDashboardRepository.translation_type_counts(db)

        return {
            "total_translations": total,
            "today_translations": today,
            "week_translations": week,
            "month_translations": month,
            "by_type": AdminDashboardService._percentage_items(by_type_rows),
        }

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
    ) -> tuple[list[dict], int]:
        rows, total = await AdminDashboardRepository.list_translations(
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

        items = []
        for translation, email, first_name, last_name in rows:
            items.append(
                {
                    "id": translation.id,
                    "user_id": translation.user_id,
                    "user_email": email,
                    "user_name": AdminDashboardService._display_name(first_name, last_name),
                    "source_language": translation.source_language,
                    "target_language": translation.target_language,
                    "source_text": translation.source_text,
                    "translated_text": translation.translated_text,
                    "translation_type": translation.translation_type,
                    "is_deleted": translation.is_deleted,
                    "created_at": translation.created_at,
                    "updated_at": translation.updated_at,
                }
            )
        return items, total

    @staticmethod
    async def analytics_overview(db: AsyncSession, *, days: int) -> dict:
        previous_start_at, start_at, end_at = AdminDashboardService._bounds(days)

        current_translations = await AdminDashboardRepository.count_translations(
            db, start_at=start_at, end_at=end_at
        )
        previous_translations = await AdminDashboardRepository.count_translations(
            db, start_at=previous_start_at, end_at=start_at
        )
        current_active_users = await AdminDashboardRepository.count_active_translation_users(
            db, start_at=start_at, end_at=end_at
        )
        previous_active_users = await AdminDashboardRepository.count_active_translation_users(
            db, start_at=previous_start_at, end_at=start_at
        )
        current_response_time = await AdminDashboardRepository.average_response_time_ms(
            db, start_at=start_at, end_at=end_at
        )
        previous_response_time = await AdminDashboardRepository.average_response_time_ms(
            db, start_at=previous_start_at, end_at=start_at
        )
        current_success_rate = await AdminDashboardRepository.successful_request_percent(
            db, start_at=start_at, end_at=end_at
        )
        previous_success_rate = await AdminDashboardRepository.successful_request_percent(
            db, start_at=previous_start_at, end_at=start_at
        )

        return {
            "days": days,
            "average_translations_per_day": AdminDashboardService._metric_card(
                current_translations / days,
                previous_translations / days,
            ),
            "active_users": AdminDashboardService._metric_card(
                current_active_users,
                previous_active_users,
            ),
            "average_response_time_ms": AdminDashboardService._metric_card(
                current_response_time,
                previous_response_time,
            ),
            "translation_accuracy_percent": AdminDashboardService._metric_card(
                current_success_rate,
                previous_success_rate,
            ),
        }

    @staticmethod
    async def translation_type_breakdown(db: AsyncSession, *, days: int) -> dict:
        _, start_at, end_at = AdminDashboardService._bounds(days)
        rows = await AdminDashboardRepository.translation_type_counts(
            db, start_at=start_at, end_at=end_at
        )
        return {"days": days, "items": AdminDashboardService._percentage_items(rows)}

    @staticmethod
    async def language_usage(db: AsyncSession, *, days: int) -> dict:
        _, start_at, end_at = AdminDashboardService._bounds(days)
        source_rows = await AdminDashboardRepository.language_counts(
            db,
            column=Translation.source_language,
            start_at=start_at,
            end_at=end_at,
        )
        target_rows = await AdminDashboardRepository.language_counts(
            db,
            column=Translation.target_language,
            start_at=start_at,
            end_at=end_at,
        )
        return {
            "days": days,
            "source_languages": AdminDashboardService._language_items(source_rows),
            "target_languages": AdminDashboardService._language_items(target_rows),
        }

    @staticmethod
    async def service_metrics(db: AsyncSession, *, days: int) -> dict:
        _, start_at, end_at = AdminDashboardService._bounds(days)
        rows = await AdminDashboardRepository.service_metrics(
            db, start_at=start_at, end_at=end_at
        )
        return {
            "days": days,
            "items": [
                {
                    "endpoint": endpoint,
                    "ai_model": ai_model,
                    "total_requests": int(total or 0),
                    "successful_requests": int(successful or 0),
                    "failed_requests": int(failed or 0),
                    "average_response_time_ms": round(float(avg_time or 0.0), 2),
                    "total_tokens_used": int(tokens or 0),
                }
                for endpoint, ai_model, total, successful, failed, avg_time, tokens in rows
            ],
        }

    @staticmethod
    async def recent_activities(db: AsyncSession, *, limit: int) -> dict:
        translations = await AdminDashboardRepository.recent_translations(db, limit=limit)
        users = await AdminDashboardRepository.recent_users(db, limit=limit)
        quizzes = await AdminDashboardRepository.recent_quizzes(db, limit=limit)

        activities: list[dict] = []
        for translation, email in translations:
            activities.append(
                {
                    "type": "translation",
                    "title": "Translation created",
                    "description": translation.source_text[:120],
                    "actor_id": translation.user_id,
                    "actor_email": email,
                    "created_at": translation.created_at,
                    "metadata": {
                        "translation_id": translation.id,
                        "translation_type": translation.translation_type,
                        "source_language": translation.source_language,
                        "target_language": translation.target_language,
                    },
                }
            )

        for user in users:
            activities.append(
                {
                    "type": "user_created",
                    "title": "User created",
                    "description": user.email,
                    "actor_id": user.id,
                    "actor_email": user.email,
                    "created_at": user.created_at,
                    "metadata": {"role": user.role, "status": user.status},
                }
            )

        for quiz, email, bank_title, activity_time in quizzes:
            activities.append(
                {
                    "type": "quiz_submitted",
                    "title": "Quiz submitted",
                    "description": bank_title,
                    "actor_id": quiz.user_id,
                    "actor_email": email,
                    "created_at": activity_time,
                    "metadata": {
                        "quiz_id": quiz.id,
                        "bank_id": quiz.bank_id,
                        "score": quiz.score,
                        "status": quiz.status,
                    },
                }
            )

        fallback = datetime.min.replace(tzinfo=timezone.utc)
        activities.sort(key=lambda item: item["created_at"] or fallback, reverse=True)
        return {"items": activities[:limit]}
