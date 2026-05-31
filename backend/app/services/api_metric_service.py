"""Best-effort persistence for API usage metrics."""
import logging
from typing import Optional

from app.core.database import async_session_maker
from app.models.system import ApiMetric

logger = logging.getLogger(__name__)


class ApiMetricService:
    """Persist analytics without affecting the caller's business transaction."""

    @staticmethod
    async def record_ai_request(
        *,
        endpoint: str,
        ai_model: str,
        response_time_ms: float,
        status_code: int,
        user_id: Optional[int] = None,
    ) -> None:
        try:
            async with async_session_maker() as db:
                db.add(
                    ApiMetric(
                        user_id=user_id,
                        endpoint=endpoint,
                        response_time_ms=max(0, round(response_time_ms)),
                        status_code=status_code,
                        is_ai_request=True,
                        ai_model=ai_model,
                        ai_tokens_used=0,
                    )
                )
                await db.commit()
        except Exception:
            logger.warning(
                "Failed to persist API metric for %s (%s).",
                endpoint,
                ai_model,
                exc_info=True,
            )
