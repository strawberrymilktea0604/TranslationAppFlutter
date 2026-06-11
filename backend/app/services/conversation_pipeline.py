"""
ConversationPipeline — Per-session FIFO queue processor for real-time
voice translation.

Lifecycle:
  1. Created when ``session_start`` is received.
  2. Utterances are enqueued as ``_UtteranceItem`` named-tuples.
  3. A background ``asyncio.Task`` consumes the queue sequentially:
     PCM → WAV → STT → Translate → DB persist → WS send.
  4. Stopped on ``session_end`` (drain) or disconnect (cancel).

Design constraints:
  - All WebSocket writes go through a shared ``asyncio.Lock`` to prevent
    interleaved frames (pong / error / final_translation).
  - The receive loop continues accepting binary frames while the pipeline
    runs in the background, so audio capture is never blocked by STT.
  - Queue is in-process ``asyncio.Queue``, suitable for single-worker deploy.
"""

import asyncio
import json
import logging
import time
import wave
from dataclasses import dataclass, field
from datetime import datetime, timezone
from io import BytesIO
from typing import Optional

from fastapi import WebSocket

from app.core.config import settings
from app.core.database import async_session_maker
from app.repositories.conversation_repository import ConversationRepository
from app.schemas.translation import TranslationRequest
from app.services.realtime_session_logger import (
    RealtimeSessionLogger,
    SessionEventType,
    SessionLogLevel,
)
from app.services.stt_service import STTError, STTService
from app.services.translation_service import TranslationService

logger = logging.getLogger(__name__)

_TRANSCRIPT_LOG_MAX = 80  # max chars of transcript logged


# ==============================================================================
# Queue item
# ==============================================================================


@dataclass(slots=True)
class _UtteranceItem:
    """Immutable work unit placed on the pipeline queue."""

    pcm_bytes: bytes
    trigger: str  # "silence" | "end_utterance" | "session_end"
    speaker: str  # "SPEAKER_A" | "SPEAKER_B"
    sequence_number: int
    audio_duration_ms: float
    audio_size_bytes: int
    source_language: str
    target_language: str
    enqueued_at: float = field(default_factory=time.time)


# ==============================================================================
# Sentinel
# ==============================================================================

_STOP = object()


# ==============================================================================
# Pipeline
# ==============================================================================


class ConversationPipeline:
    """Per-session FIFO pipeline: PCM → WAV → STT → Translate → Persist → WS."""

    def __init__(
        self,
        *,
        session_id: str,
        session_db_id: int,
        user_id: int,
        source_language: str,
        target_language: str,
        websocket: WebSocket,
        send_lock: asyncio.Lock,
        session_logger: RealtimeSessionLogger,
    ) -> None:
        self._session_id = session_id
        self._session_db_id = session_db_id
        self._user_id = user_id
        self._source_language = source_language
        self._target_language = target_language
        self._ws = websocket
        self._send_lock = send_lock
        self._session_logger = session_logger

        self._queue: asyncio.Queue = asyncio.Queue()
        self._task: Optional[asyncio.Task] = None
        self._seq_counter: int = 0

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def next_sequence_number(self) -> int:
        """Return and increment the per-session sequence counter."""
        self._seq_counter += 1
        return self._seq_counter

    def update_languages(self, source_language: str, target_language: str) -> None:
        """Apply validated metadata language changes to future utterances."""
        self._source_language = source_language
        self._target_language = target_language

    async def enqueue_utterance(
        self,
        pcm_bytes: bytes,
        trigger: str,
        speaker: str,
        audio_duration_ms: float,
        audio_size_bytes: int,
    ) -> int:
        """
        Enqueue an utterance for background processing.

        Returns the assigned sequence number.
        """
        self.start()
        seq = self.next_sequence_number()
        item = _UtteranceItem(
            pcm_bytes=pcm_bytes,
            trigger=trigger,
            speaker=speaker,
            sequence_number=seq,
            audio_duration_ms=audio_duration_ms,
            audio_size_bytes=audio_size_bytes,
            source_language=self._source_language,
            target_language=self._target_language,
        )
        await self._queue.put(item)
        self._session_logger.log_utterance_end(
            user_id=self._user_id,
            duration_seconds=audio_duration_ms / 1000,
            audio_bytes=audio_size_bytes,
            speaker=speaker,
            trigger=trigger,
            sequence_number=seq,
        )
        logger.debug(
            "Pipeline enqueued: session=%s seq=%d trigger=%s size=%d",
            self._session_id,
            seq,
            trigger,
            audio_size_bytes,
        )
        return seq

    def start(self) -> None:
        """Launch the background consumer task."""
        if self._task is None or self._task.done():
            self._task = asyncio.create_task(
                self._process_loop(),
                name=f"pipeline-{self._session_id[:8]}",
            )

    async def drain(self, timeout_seconds: float | None = None) -> bool:
        """
        Wait for the queue to drain.

        Sends a stop sentinel, then waits up to *timeout_seconds* for the
        consumer task to finish.  On timeout, cancels the task.
        """
        timeout = timeout_seconds or settings.CONVERSATION_DRAIN_TIMEOUT_SECONDS
        await self._queue.put(_STOP)

        if self._task is not None:
            try:
                await asyncio.wait_for(
                    asyncio.shield(self._task), timeout=timeout
                )
            except asyncio.TimeoutError:
                logger.warning(
                    "Pipeline drain timeout (%ss): session=%s",
                    timeout,
                    self._session_id,
                )
                self._session_logger.log_session_error(
                    user_id=self._user_id,
                    error_msg=f"Pipeline drain timed out after {timeout}s",
                    error_code="DRAIN_TIMEOUT",
                )
                self._task.cancel()
                try:
                    await self._task
                except asyncio.CancelledError:
                    pass
                await self._send_error(
                    "DRAIN_TIMEOUT",
                    f"Conversation pipeline did not finish within {timeout}s.",
                )
                return False
        return True

    async def stop(self) -> None:
        """Cancel the pipeline immediately (e.g. on disconnect)."""
        if self._task is not None and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        # Drain the queue so items don't leak
        while not self._queue.empty():
            try:
                self._queue.get_nowait()
            except asyncio.QueueEmpty:
                break

    # ------------------------------------------------------------------
    # Consumer loop
    # ------------------------------------------------------------------

    async def _process_loop(self) -> None:
        """Continuously consume utterances from the queue."""
        try:
            while True:
                item = await self._queue.get()
                if item is _STOP:
                    self._queue.task_done()
                    break
                try:
                    await self._process_utterance(item)
                except asyncio.CancelledError:
                    raise
                except Exception as exc:  # noqa: BLE001
                    logger.error(
                        "Pipeline error: session=%s seq=%d — %s",
                        self._session_id,
                        item.sequence_number,
                        exc,
                        exc_info=True,
                    )
                    self._session_logger.log_session_error(
                        user_id=self._user_id,
                        error_msg=str(exc),
                        error_code="PIPELINE_PROCESSING_FAILED",
                    )
                    await self._send_error(
                        "PIPELINE_PROCESSING_FAILED",
                        "Conversation utterance processing failed.",
                    )
                finally:
                    self._queue.task_done()
        except asyncio.CancelledError:
            logger.info(
                "Pipeline cancelled: session=%s", self._session_id
            )

    # ------------------------------------------------------------------
    # Single utterance processing
    # ------------------------------------------------------------------

    async def _process_utterance(self, item: _UtteranceItem) -> None:
        """PCM → WAV → STT → Translate → Persist → WS send."""
        pipeline_start = time.time()

        # 1. WAV conversion
        wav_start = time.time()
        wav_bytes = _wrap_pcm_as_wav(
            item.pcm_bytes, settings.CONVERSATION_PCM_SAMPLE_RATE
        )
        wav_ms = (time.time() - wav_start) * 1000
        self._session_logger.log_event(
            event_type=SessionEventType.WAV_CONVERSION_COMPLETED,
            user_id=self._user_id,
            latency_ms=wav_ms,
            details={
                "sequence_number": item.sequence_number,
                "pcm_bytes": item.audio_size_bytes,
                "wav_bytes": len(wav_bytes),
            },
        )

        # 2. STT
        stt_start = time.time()
        stt_language = _language_for_stt(item.source_language)
        try:
            stt_result = await STTService.transcribe_audio(
                wav_bytes,
                language=stt_language,
                file_extension=".wav",
            )
        except STTError as stt_exc:
            stt_ms = (time.time() - stt_start) * 1000
            logger.error(
                "Pipeline STT error: session=%s seq=%d — %s",
                self._session_id,
                item.sequence_number,
                stt_exc,
            )
            self._session_logger.log_stt_error(
                user_id=self._user_id,
                error_msg=str(stt_exc),
                latency_ms=stt_ms,
            )
            await self._send_error("STT_FAILED", f"Speech-to-text failed: {stt_exc}")
            return

        stt_ms = (time.time() - stt_start) * 1000
        extracted_text: str = stt_result.get("text", "").strip()
        detected_lang: str = stt_result.get("language", "")
        stt_confidence: float = stt_result.get("language_probability", 0.0)

        if not extracted_text:
            self._session_logger.log_event(
                event_type=SessionEventType.STT_COMPLETED,
                level=SessionLogLevel.WARNING,
                user_id=self._user_id,
                details={"trigger": item.trigger, "empty": True},
                latency_ms=stt_ms,
            )
            await self._send_error(
                "STT_NO_TEXT_EXTRACTED",
                "No speech detected in the audio. "
                "Check audio quality or try speaking louder.",
            )
            return

        self._session_logger.log_stt_completed(
            user_id=self._user_id,
            text=extracted_text[:_TRANSCRIPT_LOG_MAX],
            language=detected_lang,
            confidence=stt_confidence,
            latency_ms=stt_ms,
            speaker=item.speaker,
        )

        # 3. Translation
        translate_start = time.time()
        actual_source_language = (
            detected_lang
            if item.source_language.lower() == "auto"
            else item.source_language
        )
        try:
            translation_req = TranslationRequest(
                source_text=extracted_text,
                source_language=actual_source_language,
                target_language=item.target_language,
                translation_type="voice",
            )
            async with async_session_maker() as db:
                translated_text, is_cached, _translation_service_ms = (
                    await TranslationService.translate_with_cache(
                        request=translation_req,
                        db=db,
                        user_id=self._user_id,
                        save_to_db=True,
                    )
                )
        except Exception as trans_exc:  # noqa: BLE001
            translate_ms = (time.time() - translate_start) * 1000
            logger.error(
                "Pipeline translation error: session=%s seq=%d — %s",
                self._session_id,
                item.sequence_number,
                trans_exc,
            )
            self._session_logger.log_translation_error(
                user_id=self._user_id,
                error_msg=str(trans_exc),
                source_language=actual_source_language,
                target_language=item.target_language,
                latency_ms=translate_ms,
            )
            await self._send_error(
                "TRANSLATION_FAILED", f"Translation failed: {trans_exc}"
            )
            return

        translate_ms = (time.time() - translate_start) * 1000

        self._session_logger.log_translation_completed(
            user_id=self._user_id,
            source_text=extracted_text[:_TRANSCRIPT_LOG_MAX],
            translated_text=translated_text[:_TRANSCRIPT_LOG_MAX],
            source_language=actual_source_language,
            target_language=item.target_language,
            latency_ms=translate_ms,
            is_cached=is_cached,
        )

        # 4. Persist to DB
        persist_start = time.time()
        message_db_id: Optional[int] = None
        try:
            async with async_session_maker() as db:
                msg = await ConversationRepository.append_message(
                    db,
                    session_db_id=self._session_db_id,
                    sequence_number=item.sequence_number,
                    speaker=item.speaker,
                    transcript=extracted_text,
                    translated_text=translated_text,
                    source_language=actual_source_language,
                    target_language=item.target_language,
                    stt_language=detected_lang,
                    stt_confidence=stt_confidence,
                    finalize_trigger=item.trigger,
                    audio_size_bytes=item.audio_size_bytes,
                    audio_duration_ms=item.audio_duration_ms,
                    is_cached=is_cached,
                    latency_stt_ms=round(stt_ms, 2),
                    latency_translate_ms=round(translate_ms, 2),
                    latency_persist_ms=None,  # will be set below
                    latency_total_ms=None,
                )
                message_db_id = msg.id
        except Exception as db_exc:  # noqa: BLE001
            logger.error(
                "Pipeline persist error: session=%s seq=%d — %s",
                self._session_id,
                item.sequence_number,
                db_exc,
            )
            self._session_logger.log_session_error(
                user_id=self._user_id,
                error_msg=str(db_exc),
                error_code="MESSAGE_PERSIST_FAILED",
            )
            await self._send_error(
                "MESSAGE_PERSIST_FAILED",
                "Could not save the final conversation message.",
            )
            return

        persist_ms = (time.time() - persist_start) * 1000
        total_ms = (time.time() - pipeline_start) * 1000

        self._session_logger.log_event(
            event_type=SessionEventType.MESSAGE_PERSISTED,
            level=(
                SessionLogLevel.INFO
                if message_db_id is not None
                else SessionLogLevel.ERROR
            ),
            user_id=self._user_id,
            latency_ms=persist_ms,
            details={
                "sequence_number": item.sequence_number,
                "message_id": message_db_id,
            },
        )

        # Update persist and total latency if we have a DB id
        if message_db_id is not None:
            try:
                async with async_session_maker() as db:
                    await ConversationRepository.update_message_latencies(
                        db,
                        message_db_id,
                        latency_persist_ms=round(persist_ms, 2),
                        latency_total_ms=round(total_ms, 2),
                    )
            except Exception:  # noqa: BLE001
                pass  # non-critical update

        # 5. Send final_translation
        payload = {
            "event": "final_translation",
            "message_id": message_db_id,
            "session_id": self._session_id,
            "sequence_number": item.sequence_number,
            "speaker": item.speaker,
            "source_text": extracted_text,
            "translated_text": translated_text,
            "source_language": actual_source_language,
            "target_language": item.target_language,
            "is_cached": is_cached,
            "response_time_ms": round(total_ms, 2),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        send_start = time.time()
        sent = await self._send_json(payload)
        send_ms = (time.time() - send_start) * 1000
        if sent:
            self._session_logger.log_event(
                event_type=SessionEventType.FINAL_TRANSLATION_SENT,
                user_id=self._user_id,
                latency_ms=send_ms,
                details={
                    "sequence_number": item.sequence_number,
                    "message_id": message_db_id,
                    "total_latency_ms": round(total_ms, 2),
                },
            )
        else:
            self._session_logger.log_session_error(
                user_id=self._user_id,
                error_msg="Could not send final_translation to WebSocket.",
                error_code="FINAL_TRANSLATION_SEND_FAILED",
                latency_ms=send_ms,
            )

        logger.info(
            "Pipeline complete: session=%s seq=%d trigger=%s "
            "cached=%s wav=%.0fms stt=%.0fms trans=%.0fms "
            "persist=%.0fms send=%.0fms total=%.0fms",
            self._session_id,
            item.sequence_number,
            item.trigger,
            is_cached,
            wav_ms,
            stt_ms,
            translate_ms,
            persist_ms,
            send_ms,
            total_ms,
        )

    # ------------------------------------------------------------------
    # WebSocket helpers (all go through send_lock)
    # ------------------------------------------------------------------

    async def _send_json(self, data: dict) -> bool:
        """Send a JSON payload through the send lock."""
        try:
            async with self._send_lock:
                await self._ws.send_json(data)
            self._session_logger.bytes_transmitted += len(
                json.dumps(data, ensure_ascii=False).encode("utf-8")
            )
            return True
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Pipeline WS send failed: session=%s — %s",
                self._session_id,
                exc,
            )
            return False

    async def _send_error(self, code: str, message: str) -> None:
        """Send an error event through the send lock."""
        await self._send_json(
            {"event": "error", "code": code, "message": message}
        )


# ==============================================================================
# Module-level helpers
# ==============================================================================


def _wrap_pcm_as_wav(pcm_bytes: bytes, sample_rate: int) -> bytes:
    """Wrap raw mono signed 16-bit little-endian PCM bytes in a WAV container."""
    output = BytesIO()
    with wave.open(output, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm_bytes)
    return output.getvalue()


def _language_for_stt(source_language: str) -> Optional[str]:
    """Return None for auto-detect, otherwise the explicit source language."""
    return None if source_language.lower() == "auto" else source_language
