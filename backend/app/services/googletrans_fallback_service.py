"""
googletrans fallback service.

Used when Google Cloud Translation API is unavailable.
"""

import asyncio
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
        src = source_language if source_language and source_language.lower() != "auto" else "auto"
        timeout = settings.TRANSLATION_SERVICE_TIMEOUT

        def _translate_sync() -> dict:
            try:
                from googletrans import Translator
            except Exception as exc:
                raise GoogleTransFallbackError(
                    message="googletrans package is not installed",
                    error_code="FALLBACK_DEPENDENCY_MISSING",
                ) from exc

            translator = Translator(timeout=httpx.Timeout(float(timeout)))

            try:
                result = translator.translate(text, src=src, dest=target_language)
                translated_text = getattr(result, "text", "")
                detected_source = getattr(result, "src", src)

                if not translated_text:
                    raise GoogleTransFallbackError(
                        message="googletrans returned empty translation",
                        error_code="FALLBACK_EMPTY_RESPONSE",
                    )

                return {
                    "translated_text": translated_text,
                    "detected_source_language": detected_source,
                }
            except GoogleTransFallbackError:
                raise
            except Exception as exc:
                raise GoogleTransFallbackError(
                    message=f"googletrans translation failed: {str(exc)}",
                    error_code="FALLBACK_TRANSLATION_ERROR",
                ) from exc

        try:
            result = await asyncio.to_thread(_translate_sync)
            logger.info(
                "googletrans fallback succeeded "
                f"({result.get('detected_source_language')} to {target_language})"
            )
            return result
        except GoogleTransFallbackError:
            raise
        except Exception as exc:
            logger.error(f"Unexpected googletrans fallback error: {exc}", exc_info=True)
            raise GoogleTransFallbackError(
                message=f"Unexpected fallback error: {str(exc)}",
                error_code="FALLBACK_UNEXPECTED_ERROR",
            ) from exc
