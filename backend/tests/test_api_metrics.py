"""Tests for best-effort outbound translation provider metrics."""
import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
import pytest

from app.core.config import settings
from app.schemas.translation import TranslationRequest
from app.services.api_metric_service import ApiMetricService
from app.services.google_translate_service import GoogleTranslateError, GoogleTranslateService
from app.services.googletrans_fallback_service import GoogleTransFallbackService
from app.services.translation_service import TranslationService


def _run(coro):
    return asyncio.run(coro)


def _request(translation_type="text"):
    return TranslationRequest(
        source_text="Hello world",
        source_language="en",
        target_language="vi",
        translation_type=translation_type,
    )


class _FakeHttpClient:
    def __init__(self, response=None, error=None):
        self.response = response
        self.error = error

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_args):
        return None

    async def post(self, *_args, **_kwargs):
        if self.error:
            raise self.error
        return self.response


class _FakeTranslator:
    async def translate(self, *_args, **_kwargs):
        return SimpleNamespace(text="Xin chao fallback", src="en")


def test_google_translate_success_records_one_metric(monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLOUD_API_KEY", "test-key")
    response = SimpleNamespace(
        status_code=200,
        json=lambda: {
            "data": {"translations": [{"translatedText": "Xin chao"}]}
        },
    )

    with patch(
        "app.services.google_translate_service.httpx.AsyncClient",
        return_value=_FakeHttpClient(response=response),
    ), patch.object(
        ApiMetricService,
        "record_ai_request",
        new=AsyncMock(),
    ) as record_mock:
        result = _run(
            GoogleTranslateService.translate_text(
                "Hello",
                "vi",
                "en",
                user_id=7,
                translation_type="voice",
            )
        )

    assert result["translated_text"] == "Xin chao"
    record_mock.assert_awaited_once()
    metric = record_mock.await_args.kwargs
    assert metric["endpoint"] == "translation/voice"
    assert metric["ai_model"] == "google-translate-v2"
    assert metric["status_code"] == 200
    assert metric["user_id"] == 7


def test_google_translate_failure_still_records_metric(monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLOUD_API_KEY", "test-key")

    with patch(
        "app.services.google_translate_service.httpx.AsyncClient",
        return_value=_FakeHttpClient(error=httpx.ConnectError("offline")),
    ), patch.object(
        ApiMetricService,
        "record_ai_request",
        new=AsyncMock(),
    ) as record_mock:
        with pytest.raises(GoogleTranslateError):
            _run(GoogleTranslateService.translate_text("Hello", "vi", "en"))

    record_mock.assert_awaited_once()
    assert record_mock.await_args.kwargs["status_code"] == 503


def test_primary_failure_then_fallback_records_two_metrics(monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLOUD_API_KEY", "test-key")
    monkeypatch.setattr(settings, "TRANSLATION_FALLBACK_ENABLED", True)
    response = SimpleNamespace(status_code=429, text="rate limited")

    with patch(
        "app.services.google_translate_service.httpx.AsyncClient",
        return_value=_FakeHttpClient(response=response),
    ), patch.object(
        GoogleTransFallbackService,
        "_check_rate_limit",
        new=AsyncMock(return_value=True),
    ), patch(
        "googletrans.Translator",
        return_value=_FakeTranslator(),
    ), patch.object(
        ApiMetricService,
        "record_ai_request",
        new=AsyncMock(),
    ) as record_mock:
        result = _run(TranslationService._call_translation_api(_request("image"), user_id=8))

    assert result == "Xin chao fallback"
    assert record_mock.await_count == 2
    metrics = [call.kwargs for call in record_mock.await_args_list]
    assert [metric["ai_model"] for metric in metrics] == [
        "google-translate-v2",
        "googletrans-fallback",
    ]
    assert [metric["status_code"] for metric in metrics] == [429, 200]
    assert all(metric["endpoint"] == "translation/image" for metric in metrics)
    assert all(metric["user_id"] == 8 for metric in metrics)


def test_cache_hit_does_not_record_provider_metric():
    with patch(
        "app.services.translation_service.get_cached_translation",
        new=AsyncMock(return_value="Xin chao cached"),
    ), patch.object(
        ApiMetricService,
        "record_ai_request",
        new=AsyncMock(),
    ) as record_mock:
        translated, is_cached, _ = _run(
            TranslationService.translate_with_cache(
                _request(),
                db=SimpleNamespace(),
                save_to_db=False,
            )
        )

    assert translated == "Xin chao cached"
    assert is_cached is True
    record_mock.assert_not_awaited()


def test_metric_persistence_failure_is_best_effort():
    class _BrokenSession:
        async def __aenter__(self):
            raise RuntimeError("database unavailable")

        async def __aexit__(self, *_args):
            return None

    with patch(
        "app.services.api_metric_service.async_session_maker",
        return_value=_BrokenSession(),
    ):
        _run(
            ApiMetricService.record_ai_request(
                endpoint="translation/text",
                ai_model="google-translate-v2",
                response_time_ms=12.4,
                status_code=200,
            )
        )
