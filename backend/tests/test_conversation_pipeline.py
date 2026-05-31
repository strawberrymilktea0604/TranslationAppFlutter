"""Focused tests for per-session conversation pipeline queue semantics."""

import asyncio
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.conversation_pipeline import ConversationPipeline


def _pipeline() -> tuple[ConversationPipeline, MagicMock, MagicMock]:
    websocket = MagicMock()
    websocket.send_json = AsyncMock()
    session_logger = MagicMock()
    session_logger.bytes_transmitted = 0
    pipeline = ConversationPipeline(
        session_id="session-1",
        session_db_id=101,
        user_id=1,
        source_language="vi",
        target_language="en",
        websocket=websocket,
        send_lock=asyncio.Lock(),
        session_logger=session_logger,
    )
    return pipeline, websocket, session_logger


@pytest.mark.asyncio
async def test_pipeline_processes_utterances_in_fifo_order():
    pipeline, _, _ = _pipeline()
    processed_sequences = []

    async def _capture(item):
        processed_sequences.append(item.sequence_number)

    pipeline._process_utterance = _capture
    pipeline.start()
    await pipeline.enqueue_utterance(
        pcm_bytes=b"\x01\x00",
        trigger="end_utterance",
        speaker="SPEAKER_A",
        audio_duration_ms=1.0,
        audio_size_bytes=2,
    )
    await pipeline.enqueue_utterance(
        pcm_bytes=b"\x02\x00",
        trigger="end_utterance",
        speaker="SPEAKER_B",
        audio_duration_ms=1.0,
        audio_size_bytes=2,
    )

    assert await pipeline.drain(timeout_seconds=1.0) is True
    assert processed_sequences == [1, 2]


@pytest.mark.asyncio
async def test_pipeline_drain_timeout_cancels_worker_and_sends_error():
    pipeline, websocket, session_logger = _pipeline()

    async def _hang(_item):
        await asyncio.Event().wait()

    pipeline._process_utterance = _hang
    pipeline.start()
    await pipeline.enqueue_utterance(
        pcm_bytes=b"\x01\x00",
        trigger="session_end",
        speaker="SPEAKER_A",
        audio_duration_ms=1.0,
        audio_size_bytes=2,
    )

    assert await pipeline.drain(timeout_seconds=0.001) is False
    assert pipeline._task is not None
    assert pipeline._task.done()
    websocket.send_json.assert_awaited_once_with(
        {
            "event": "error",
            "code": "DRAIN_TIMEOUT",
            "message": "Conversation pipeline did not finish within 0.001s.",
        }
    )
    session_logger.log_session_error.assert_called_once_with(
        user_id=1,
        error_msg="Pipeline drain timed out after 0.001s",
        error_code="DRAIN_TIMEOUT",
    )
    await pipeline.stop()


@pytest.mark.asyncio
async def test_send_json_tracks_bytes_only_after_successful_send():
    pipeline, websocket, session_logger = _pipeline()
    payload = {"event": "final_translation", "translated_text": "hello"}

    assert await pipeline._send_json(payload) is True
    websocket.send_json.assert_awaited_once_with(payload)
    assert session_logger.bytes_transmitted > 0


@pytest.mark.asyncio
async def test_send_json_returns_false_when_websocket_send_fails():
    pipeline, websocket, session_logger = _pipeline()
    websocket.send_json.side_effect = RuntimeError("socket closed")

    assert await pipeline._send_json({"event": "final_translation"}) is False
    assert session_logger.bytes_transmitted == 0
