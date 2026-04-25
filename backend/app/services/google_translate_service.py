"""
Google Cloud Translation API v2 Service
Handles direct HTTP calls to Google Translation API using REST endpoint.
API Key is managed securely via environment variables.
"""
import logging
from typing import Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

# Google Translation API v2 endpoint
GOOGLE_TRANSLATE_URL = "https://translation.googleapis.com/language/translate/v2"
GOOGLE_DETECT_URL = "https://translation.googleapis.com/language/translate/v2/detect"
GOOGLE_LANGUAGES_URL = "https://translation.googleapis.com/language/translate/v2/languages"


class GoogleTranslateError(Exception):
    """Custom exception for Google Translate API errors."""

    def __init__(self, message: str, status_code: int = 500, error_code: str = "TRANSLATION_ERROR"):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        super().__init__(self.message)


class GoogleTranslateService:
    """
    Service wrapper for Google Cloud Translation API v2.
    
    Uses REST API with API Key authentication (NOT client library).
    This keeps dependencies minimal and avoids heavy google-cloud-translate SDK.
    
    API Docs: https://cloud.google.com/translate/docs/reference/rest/v2/translations/translate
    """

    @staticmethod
    def _get_api_key() -> str:
        """
        Retrieve Google Cloud API Key from environment.
        
        Raises:
            GoogleTranslateError: If API key is not configured
        """
        api_key = settings.GOOGLE_CLOUD_API_KEY
        if not api_key or api_key in ("optional-api-key", "your-api-key-here", ""):
            raise GoogleTranslateError(
                message="GOOGLE_CLOUD_API_KEY is not configured. Set it in .env file.",
                status_code=503,
                error_code="API_KEY_NOT_CONFIGURED"
            )
        return api_key

    @staticmethod
    async def translate_text(
        text: str,
        target_language: str,
        source_language: Optional[str] = None,
    ) -> dict:
        """
        Translate text using Google Translation API v2.
        
        Args:
            text: The text to translate (max 5000 chars per request)
            target_language: Target language code (ISO 639-1, e.g., 'vi', 'en', 'ja')
            source_language: Source language code. If None, Google will auto-detect.
        
        Returns:
            dict with keys:
                - translated_text: The translated string
                - detected_source_language: Detected source language (if auto-detect used)
        
        Raises:
            GoogleTranslateError: On API failure or configuration issue
        """
        api_key = GoogleTranslateService._get_api_key()
        timeout = settings.TRANSLATION_SERVICE_TIMEOUT

        # Build request payload
        params = {
            "key": api_key,
        }

        payload = {
            "q": text,
            "target": target_language,
            "format": "text",  # "text" or "html"
        }

        if source_language and source_language.lower() != "auto":
            payload["source"] = source_language

        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    GOOGLE_TRANSLATE_URL,
                    params=params,
                    json=payload,
                )

                if response.status_code == 200:
                    data = response.json()
                    translations = data.get("data", {}).get("translations", [])

                    if not translations:
                        raise GoogleTranslateError(
                            message="Google API returned empty translations",
                            status_code=500,
                            error_code="EMPTY_RESPONSE"
                        )

                    result = translations[0]
                    translated_text = result.get("translatedText", "")
                    detected_source = result.get("detectedSourceLanguage", source_language)

                    logger.info(
                        f"✅ Google Translate: '{text[:50]}...' "
                        f"({detected_source}→{target_language}) OK"
                    )

                    return {
                        "translated_text": translated_text,
                        "detected_source_language": detected_source,
                    }

                elif response.status_code == 400:
                    error_detail = response.json().get("error", {}).get("message", "Bad Request")
                    raise GoogleTranslateError(
                        message=f"Invalid request: {error_detail}",
                        status_code=400,
                        error_code="INVALID_REQUEST"
                    )

                elif response.status_code == 403:
                    raise GoogleTranslateError(
                        message="Google API Key is invalid or quota exceeded",
                        status_code=403,
                        error_code="API_KEY_INVALID"
                    )

                elif response.status_code == 429:
                    raise GoogleTranslateError(
                        message="Google Translation API rate limit exceeded. Try again later.",
                        status_code=429,
                        error_code="RATE_LIMIT_EXCEEDED"
                    )

                else:
                    error_body = response.text[:200]
                    raise GoogleTranslateError(
                        message=f"Google API error (HTTP {response.status_code}): {error_body}",
                        status_code=response.status_code,
                        error_code="API_ERROR"
                    )

        except httpx.TimeoutException:
            logger.error(f"Google Translate API timeout after {timeout}s")
            raise GoogleTranslateError(
                message=f"Translation request timed out after {timeout} seconds",
                status_code=504,
                error_code="TIMEOUT"
            )

        except httpx.ConnectError:
            logger.error("Cannot connect to Google Translate API")
            raise GoogleTranslateError(
                message="Cannot connect to Google Translation service. Check network.",
                status_code=503,
                error_code="CONNECTION_ERROR"
            )

        except GoogleTranslateError:
            raise

        except Exception as e:
            logger.error(f"Unexpected error calling Google Translate: {e}", exc_info=True)
            raise GoogleTranslateError(
                message=f"Unexpected translation error: {str(e)}",
                status_code=500,
                error_code="UNEXPECTED_ERROR"
            )

    @staticmethod
    async def detect_language(text: str) -> dict:
        """
        Detect the language of the given text.
        
        Args:
            text: Text to detect language for
        
        Returns:
            dict with keys:
                - language: Detected language code (ISO 639-1)
                - confidence: Detection confidence (0.0 to 1.0)
        """
        api_key = GoogleTranslateService._get_api_key()
        timeout = settings.TRANSLATION_SERVICE_TIMEOUT

        params = {"key": api_key}
        payload = {"q": text}

        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    GOOGLE_DETECT_URL,
                    params=params,
                    json=payload,
                )

                if response.status_code == 200:
                    data = response.json()
                    detections = data.get("data", {}).get("detections", [[]])

                    if detections and detections[0]:
                        detection = detections[0][0]
                        return {
                            "language": detection.get("language", "unknown"),
                            "confidence": detection.get("confidence", 0.0),
                        }

                    return {"language": "unknown", "confidence": 0.0}

                else:
                    error_body = response.text[:200]
                    raise GoogleTranslateError(
                        message=f"Language detection failed (HTTP {response.status_code}): {error_body}",
                        status_code=response.status_code,
                        error_code="DETECT_FAILED"
                    )

        except GoogleTranslateError:
            raise
        except Exception as e:
            logger.error(f"Language detection error: {e}")
            raise GoogleTranslateError(
                message=f"Language detection failed: {str(e)}",
                status_code=500,
                error_code="DETECT_ERROR"
            )

    @staticmethod
    async def get_supported_languages(target_language: str = "en") -> list[dict]:
        """
        Get list of languages supported by Google Translate.
        
        Args:
            target_language: Language code for language names in response
        
        Returns:
            List of dicts with 'language' code and 'name'
        """
        api_key = GoogleTranslateService._get_api_key()
        timeout = settings.TRANSLATION_SERVICE_TIMEOUT

        params = {
            "key": api_key,
            "target": target_language,
        }

        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.get(
                    GOOGLE_LANGUAGES_URL,
                    params=params,
                )

                if response.status_code == 200:
                    data = response.json()
                    languages = data.get("data", {}).get("languages", [])
                    return languages

                else:
                    raise GoogleTranslateError(
                        message=f"Failed to fetch supported languages",
                        status_code=response.status_code,
                        error_code="LANGUAGES_FAILED"
                    )

        except GoogleTranslateError:
            raise
        except Exception as e:
            logger.error(f"Get supported languages error: {e}")
            raise GoogleTranslateError(
                message=f"Failed to fetch supported languages: {str(e)}",
                status_code=500,
                error_code="LANGUAGES_ERROR"
            )
