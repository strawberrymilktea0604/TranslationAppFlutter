"""
googletrans fallback service.

Used when Google Cloud Translation API is unavailable.
"""

import logging
from typing import Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class GoogleTransFallbackError(Exception):
    """Custom exception for googletrans fallback failures."""

    def __init__(self, message: str, error_code: str = "FALLBACK_TRANSLATION_ERROR"):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)


class GoogleTransFallbackService:
    """Fallback translation provider powered by googletrans."""

    @staticmethod
    async def _check_rate_limit() -> bool:
        """Check if fallback rate limit is exceeded to prevent IP ban."""
        try:
            from app.core.redis_client import get_redis_client
            client = await get_redis_client()
            
            rate_key = "rate_limit:googletrans_fallback_global"
            max_requests = settings.FALLBACK_MAX_REQUESTS_PER_MINUTE
            
            current_count = await client.get(rate_key)
            if current_count is None:
                pipe = client.pipeline()
                pipe.incr(rate_key)
                pipe.expire(rate_key, 60) # 1 minute window
                await pipe.execute()
                return True
                
            if int(current_count) >= max_requests:
                return False
                
            await client.incr(rate_key)
            return True
        except Exception as e:
            logger.warning(f"Fallback rate limit check failed: {e}. Allowing request.")
            return True

    @staticmethod
    async def translate_text(
        text: str,
        target_language: str,
        source_language: Optional[str] = None,
    ) -> dict:
        """
        Translate text using googletrans in a worker thread.

        Args:
            text: Source text to translate.
            target_language: Target language code.
            source_language: Source language code or "auto".

        Returns:
            dict with keys:
                - translated_text
                - detected_source_language

        Raises:
            GoogleTransFallbackError: If fallback translation fails.
        """
        # Rate limit check before proceeding
        is_allowed = await GoogleTransFallbackService._check_rate_limit()
        if not is_allowed:
            raise GoogleTransFallbackError(
                message="Googletrans fallback rate limit exceeded to prevent IP ban. Please try again later.",
                error_code="FALLBACK_RATE_LIMIT_EXCEEDED",
            )

        src = source_language if source_language and source_language.lower() != "auto" else "auto"
        timeout = settings.TRANSLATION_SERVICE_TIMEOUT

        try:
            from googletrans import Translator
        except Exception as exc:
            raise GoogleTransFallbackError(
                message="googletrans package is not installed",
                error_code="FALLBACK_DEPENDENCY_MISSING",
            ) from exc

        translator = Translator(timeout=httpx.Timeout(float(timeout)))

        try:
            result = await translator.translate(text, src=src, dest=target_language)
            translated_text = getattr(result, "text", "")
            detected_source = getattr(result, "src", src)

            if not translated_text:
                raise GoogleTransFallbackError(
                    message="googletrans returned empty translation",
                    error_code="FALLBACK_EMPTY_RESPONSE",
                )

            logger.info(
                "googletrans fallback succeeded "
                f"({detected_source} to {target_language})"
            )
            return {
                "translated_text": translated_text,
                "detected_source_language": detected_source,
            }
        except GoogleTransFallbackError:
            raise
        except Exception as exc:
            logger.error(f"Unexpected googletrans fallback error: {exc}", exc_info=True)
            raise GoogleTransFallbackError(
                message=f"Unexpected fallback error: {str(exc)}",
                error_code="FALLBACK_UNEXPECTED_ERROR",
            ) from exc
