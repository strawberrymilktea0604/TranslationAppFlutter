"""Tests for Google Cloud to googletrans fallback behavior."""

import asyncio
from unittest.mock import AsyncMock, patch

import pytest

from app.core.config import settings
from app.schemas.translation import TranslationRequest
from app.services.google_translate_service import GoogleTranslateError, GoogleTranslateService
from app.services.googletrans_fallback_service import (
    GoogleTransFallbackError,
    GoogleTransFallbackService,
)
from app.services.translation_service import TranslationService


def _build_request() -> TranslationRequest:
    return TranslationRequest(
        source_text="Hello world",
        source_language="en",
        target_language="vi",
        translation_type="text",
    )


def _run(coro):
    """Run async coroutine in sync pytest tests without pytest-asyncio."""
    return asyncio.run(coro)


def test_translation_uses_google_cloud_when_available(monkeypatch):
    """Should use primary provider and skip fallback on success."""
    monkeypatch.setattr(settings, "TRANSLATION_FALLBACK_ENABLED", True, raising=False)

    with patch.object(
        GoogleTranslateService,
        "translate_text",
        new=AsyncMock(return_value={"translated_text": "Xin chao"}),
    ) as primary_mock, patch.object(
        GoogleTransFallbackService,
        "translate_text",
        new=AsyncMock(),
    ) as fallback_mock:
        result = _run(TranslationService._call_translation_api(_build_request()))

    assert result == "Xin chao"
    primary_mock.assert_awaited_once()
    fallback_mock.assert_not_awaited()


def test_translation_falls_back_when_google_cloud_unavailable(monkeypatch):
    """Should use googletrans when Google Cloud is unavailable."""
    monkeypatch.setattr(settings, "TRANSLATION_FALLBACK_ENABLED", True, raising=False)

    with patch.object(
        GoogleTranslateService,
        "translate_text",
        new=AsyncMock(
            side_effect=GoogleTranslateError(
                message="Quota exceeded",
                status_code=429,
                error_code="RATE_LIMIT_EXCEEDED",
            )
        ),
    ) as primary_mock, patch.object(
        GoogleTransFallbackService,
        "translate_text",
        new=AsyncMock(return_value={"translated_text": "Xin chao fallback"}),
    ) as fallback_mock:
        result = _run(TranslationService._call_translation_api(_build_request()))

    assert result == "Xin chao fallback"
    primary_mock.assert_awaited_once()
    fallback_mock.assert_awaited_once()


def test_translation_falls_back_when_google_api_key_missing(monkeypatch):
    """Missing Google Cloud key should still use fallback provider."""
    monkeypatch.setattr(settings, "TRANSLATION_FALLBACK_ENABLED", False, raising=False)

    with patch.object(
        GoogleTranslateService,
        "translate_text",
        new=AsyncMock(
            side_effect=GoogleTranslateError(
                message="GOOGLE_CLOUD_API_KEY is not configured",
                status_code=503,
                error_code="API_KEY_NOT_CONFIGURED",
            )
        ),
    ) as primary_mock, patch.object(
        GoogleTransFallbackService,
        "translate_text",
        new=AsyncMock(return_value={"translated_text": "Xin chao fallback"}),
    ) as fallback_mock:
        result = _run(TranslationService._call_translation_api(_build_request()))

    assert result == "Xin chao fallback"
    primary_mock.assert_awaited_once()
    fallback_mock.assert_awaited_once()


def test_translation_does_not_fallback_for_invalid_request(monkeypatch):
    """Should preserve client-side errors without fallback attempts."""
    monkeypatch.setattr(settings, "TRANSLATION_FALLBACK_ENABLED", True, raising=False)

    with patch.object(
        GoogleTranslateService,
        "translate_text",
        new=AsyncMock(
            side_effect=GoogleTranslateError(
                message="Invalid target language",
                status_code=400,
                error_code="INVALID_REQUEST",
            )
        ),
    ) as primary_mock, patch.object(
        GoogleTransFallbackService,
        "translate_text",
        new=AsyncMock(),
    ) as fallback_mock:
        with pytest.raises(GoogleTranslateError) as exc_info:
            _run(TranslationService._call_translation_api(_build_request()))

    assert exc_info.value.error_code == "INVALID_REQUEST"
    primary_mock.assert_awaited_once()
    fallback_mock.assert_not_awaited()


def test_translation_raises_when_primary_and_fallback_fail(monkeypatch):
    """Should return a unified service unavailable error if both providers fail."""
    monkeypatch.setattr(settings, "TRANSLATION_FALLBACK_ENABLED", True, raising=False)

    with patch.object(
        GoogleTranslateService,
        "translate_text",
        new=AsyncMock(
            side_effect=GoogleTranslateError(
                message="Primary provider down",
                status_code=503,
                error_code="CONNECTION_ERROR",
            )
        ),
    ) as primary_mock, patch.object(
        GoogleTransFallbackService,
        "translate_text",
        new=AsyncMock(
            side_effect=GoogleTransFallbackError(
                message="Fallback provider down",
                error_code="FALLBACK_TRANSLATION_ERROR",
            )
        ),
    ) as fallback_mock:
        with pytest.raises(GoogleTranslateError) as exc_info:
            _run(TranslationService._call_translation_api(_build_request()))

    assert exc_info.value.error_code == "TRANSLATION_SERVICES_UNAVAILABLE"
    assert exc_info.value.status_code == 503
    primary_mock.assert_awaited_once()
    fallback_mock.assert_awaited_once()
