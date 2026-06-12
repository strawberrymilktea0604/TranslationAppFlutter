"""
WebSocket Endpoints — /api/v1/ws  (sync notifications)
                   — /api/v1/ws/conversation  (real-time voice translation)

=== /api/v1/ws (unchanged) ===
Provides a persistent WebSocket connection so the server can push real-time
sync notifications to the Flutter client.

=== /api/v1/ws/conversation ===
Real-time voice translation pipeline over a single persistent WebSocket.

Protocol summary:
  1. Connect with ?token=<access_token>.
  2. Send {"event": "session_start", "source_language": "vi",
           "target_language": "en", "speaker": "SPEAKER_A"}.
  3. Send {"event": "audio_metadata", ...} with pcm_s16le / 16000 Hz.
  4. Stream raw 16 kHz mono PCM chunks as binary frames.
  5. Server auto-finalizes on 1500 ms trailing silence (primary).
     Client may also send {"event": "end_utterance"} as fallback.
  6. Receive {"event": "final_translation", ...}.
  7. Send {"event": "session_end"} to close gracefully.

See app/schemas/websocket.py for full message schemas.
"""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from jose import JWTError, jwt
from sqlalchemy.future import select

from app.core.config import settings
from app.core.database import async_session_maker
from app.core.pcm_buffer import BufferOverflowError
from app.core.redis_client import is_token_revoked
from app.core.security import verify_token
from app.models.user import User
from app.repositories.conversation_repository import ConversationRepository
from app.schemas.realtime_session import AudioFormat, AudioMetadata, SessionStatus
from app.schemas.websocket import (
    KNOWN_EVENTS,
    WsAudioMetadataEvent,
    WsSessionStartEvent,
    WsSpeakerChangedEvent,
)
from app.services.conversation_pipeline import ConversationPipeline
from app.services.conversation_session_manager import conversation_manager
from app.services.realtime_session_logger import (
    RealtimeSessionLogger,
    SessionEventType,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["websocket"])


# ---------------------------------------------------------------------------
# Connection Manager (sync notifications — unchanged)
# ---------------------------------------------------------------------------


class ConnectionManager:
    """Manages all active WebSocket connections, keyed by user_id."""

    def __init__(self) -> None:
        self._connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int) -> None:
        await websocket.accept()
        self._connections.setdefault(user_id, []).append(websocket)
        logger.info(
            "WS connected: user_id=%s (total=%d)",
            user_id,
            len(self._connections[user_id]),
        )

    def disconnect(self, websocket: WebSocket, user_id: int) -> None:
        conns = self._connections.get(user_id, [])
        if websocket in conns:
            conns.remove(websocket)
        if not conns:
            self._connections.pop(user_id, None)
        logger.info("WS disconnected: user_id=%s", user_id)

    async def broadcast_sync_completed(
        self, user_id: int, synced_count: int
    ) -> None:
        """Push a sync_completed event to all connections for this user."""
        conns = self._connections.get(user_id, [])
        if not conns:
            return

        payload = {
            "event": "sync_completed",
            "synced_count": synced_count,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        dead: List[WebSocket] = []
        for ws in list(conns):
            try:
                await ws.send_json(payload)
            except Exception as exc:  # noqa: BLE001
                logger.warning("WS send failed for user %s: %s", user_id, exc)
                dead.append(ws)

        for ws in dead:
            self.disconnect(ws, user_id)

    def connection_count(self, user_id: int) -> int:
        return len(self._connections.get(user_id, []))


manager = ConnectionManager()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _error_event(code: str, message: str) -> dict:
    """Build a standard error event dict."""
    return {"event": "error", "code": code, "message": message}


async def _authenticate_ws(
    websocket: WebSocket, token: str
) -> Optional[User]:
    """
    Decode and validate an access JWT for a WebSocket handshake.

    Returns the User on success, or None after sending a close frame on failure.
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
    except JWTError as exc:
        logger.warning("WS/conversation auth: JWT decode failed — %s", exc)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    if payload.get("type") != "access":
        logger.warning(
            "WS/conversation auth: token type=%r is not 'access'",
            payload.get("type"),
        )
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    user_id_str: Optional[str] = payload.get("sub")
    if not user_id_str:
        logger.warning("WS/conversation auth: missing 'sub' claim")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    try:
        user_id = int(user_id_str)
    except (ValueError, TypeError):
        logger.warning("WS/conversation auth: invalid 'sub' value=%r", user_id_str)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    jti: Optional[str] = payload.get("jti")
    if jti:
        try:
            revoked = await is_token_revoked(jti)
        except Exception:  # noqa: BLE001
            revoked = False
        if revoked:
            logger.warning(
                "WS/conversation auth: token revoked jti=%s user_id=%s", jti, user_id
            )
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return None

    async with async_session_maker() as db:
        result = await db.execute(select(User).filter(User.id == user_id))
        user: Optional[User] = result.scalars().first()

    if user is None:
        logger.warning("WS/conversation auth: user_id=%s not found", user_id)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    if user.is_deleted is True:
        logger.warning("WS/conversation auth: user_id=%s is deleted", user_id)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    if str(user.status) == "locked":
        logger.warning("WS/conversation auth: user_id=%s is locked", user_id)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    return user


# ---------------------------------------------------------------------------
# Existing sync-notification WebSocket route (UNCHANGED)
# ---------------------------------------------------------------------------


@router.websocket("")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(..., description="Bearer access token for auth"),
):
    """
    WebSocket endpoint — authenticated via ?token=<access_token>.

    Protocol: RFC 6455 (WebSocket protocol version 13).
    """
    try:
        payload = verify_token(token)
        user_id: int = int(payload.get("sub"))
    except (JWTError, ValueError, TypeError, Exception) as exc:
        logger.warning("WS auth failed: %s", exc)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket, user_id)

    try:
        while True:
            data = await websocket.receive_json()
            if data.get("ping"):
                await websocket.send_json({"pong": True})
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
    except Exception as exc:  # noqa: BLE001
        logger.error("WS error for user %s: %s", user_id, exc)
        manager.disconnect(websocket, user_id)


# ---------------------------------------------------------------------------
# Real-time voice-translation WebSocket route
# ---------------------------------------------------------------------------


async def _enqueue_from_buffer(
    buffer,
    pipeline: ConversationPipeline,
    session,
    trigger: str,
) -> bool:
    """Snapshot and enqueue buffered audio, preserving data after a VAD boundary."""
    if buffer.is_empty:
        return False
    if trigger == "silence" and not buffer.has_speech:
        buffer.reset()
        return False

    if trigger == "silence":
        enqueued = False
        while buffer.has_finalized_speech:
            speech_bytes, leftover = buffer.snapshot_speech()
            buffer.reset()
            if speech_bytes:
                await _enqueue_pcm_bytes(
                    pipeline, session, speech_bytes, trigger
                )
                enqueued = True
            if not leftover:
                break
            buffer.append_with_vad(leftover)
        return enqueued
    else:
        speech_bytes = buffer.get_audio()
        buffer.reset()

    if not speech_bytes:
        return False

    await _enqueue_pcm_bytes(pipeline, session, speech_bytes, trigger)
    return True


async def _enqueue_pcm_bytes(
    pipeline: ConversationPipeline,
    session,
    speech_bytes: bytes,
    trigger: str,
) -> None:
    """Enqueue one immutable PCM utterance snapshot."""
    sample_rate = settings.CONVERSATION_PCM_SAMPLE_RATE
    num_samples = len(speech_bytes) // 2
    duration_ms = (num_samples / sample_rate) * 1000 if sample_rate > 0 else 0

    speaker = (
        session.current_speaker.value if session.current_speaker else "SPEAKER_A"
    )
    await pipeline.enqueue_utterance(
        pcm_bytes=speech_bytes,
        trigger=trigger,
        speaker=speaker,
        audio_duration_ms=round(duration_ms, 2),
        audio_size_bytes=len(speech_bytes),
    )


@router.websocket("/conversation")
async def websocket_conversation(
    websocket: WebSocket,
    token: str = Query(..., description="Bearer access token for auth"),
):
    """
    Real-time voice translation WebSocket.

    Accepts raw 16 kHz mono PCM audio chunks (binary frames) and JSON control
    events (text frames). Auto-finalizes on 1500 ms trailing silence; also
    accepts end_utterance as fallback. Sends final_translation events.

    Authentication: ?token=<access_token> query parameter (access tokens only).
    """
    user = await _authenticate_ws(websocket, token)
    if user is None:
        return

    await websocket.accept()
    logger.info(
        "WS/conversation accepted: user_id=%s email=%s", user.id, user.email
    )

    active_session_id: Optional[str] = None
    pipeline: Optional[ConversationPipeline] = None
    send_lock = asyncio.Lock()
    session_logger: Optional[RealtimeSessionLogger] = None
    ignore_next_empty_end_utterance = False

    async def _send_json_locked(data: dict) -> None:
        """Send JSON through the send lock."""
        async with send_lock:
            await websocket.send_json(data)

    async def _send_error_locked(code: str, message: str) -> None:
        await _send_json_locked(_error_event(code, message))

    try:
        while True:
            frame = await websocket.receive()

            if frame.get("type") == "websocket.disconnect":
                break

            # ----------------------------------------------------------
            # Binary frame — raw PCM audio chunk
            # ----------------------------------------------------------
            if "bytes" in frame and frame["bytes"] is not None:
                chunk: bytes = frame["bytes"]

                if active_session_id is None:
                    await _send_error_locked(
                        "INVALID_SESSION_STATE",
                        "Binary audio received before session_start.",
                    )
                    continue

                buffer = conversation_manager.get_buffer(active_session_id)
                if buffer is None:
                    await _send_error_locked("SESSION_NOT_FOUND", "Session buffer missing.")
                    continue

                session = conversation_manager.get_session(active_session_id)
                if session is None:
                    await _send_error_locked("SESSION_NOT_FOUND", "Session state missing.")
                    continue

                if session.audio_metadata is None:
                    await _send_error_locked(
                        "MISSING_AUDIO_METADATA",
                        "Audio metadata must be sent before binary audio.",
                    )
                    continue

                # Empty chunk guard
                if len(chunk) == 0:
                    await _send_error_locked(
                        "EMPTY_AUDIO_CHUNK",
                        "Received empty audio chunk.",
                    )
                    continue
                if len(chunk) % 2 != 0:
                    await _send_error_locked(
                        "INVALID_AUDIO_CHUNK",
                        "PCM s16le audio chunks must contain an even number of bytes.",
                    )
                    continue

                session.status = SessionStatus.RECORDING
                session.mark_active()
                receive_started = asyncio.get_running_loop().time()

                try:
                    vad_result = buffer.append_with_vad(chunk)
                except BufferOverflowError as exc:
                    logger.warning(
                        "WS/conversation buffer overflow: session_id=%s user_id=%s — %s",
                        active_session_id,
                        user.id,
                        exc,
                    )
                    await _send_error_locked(
                        "BUFFER_OVERFLOW",
                        f"PCM buffer exceeded maximum size ({exc.max_size} bytes). "
                        "Send end_utterance before sending more audio.",
                    )
                    await websocket.close(code=1009)
                    break

                if session_logger is not None:
                    session_logger.log_audio_chunk(
                        user_id=user.id,
                        chunk_size=len(chunk),
                        sample_rate=session.audio_metadata.sample_rate,
                        channel=1,
                        latency_ms=(
                            asyncio.get_running_loop().time() - receive_started
                        )
                        * 1000,
                    )

                # Max utterance duration check
                max_secs = settings.CONVERSATION_MAX_UTTERANCE_SECONDS
                if buffer.is_over_max_duration(max_secs):
                    await _send_error_locked(
                        "AUDIO_TOO_LONG",
                        f"Utterance exceeded {max_secs}s limit. "
                        "Current turn reset; session remains open.",
                    )
                    buffer.reset()
                    continue

                # Silence-based auto-finalize
                if vad_result.should_finalize and pipeline is not None:
                    ignore_next_empty_end_utterance = await _enqueue_from_buffer(
                        buffer, pipeline, session, "silence"
                    )
                    session.status = SessionStatus.IDLE

                continue

            # ----------------------------------------------------------
            # Text frame — JSON control / metadata event
            # ----------------------------------------------------------
            raw_text: Optional[str] = frame.get("text")
            if raw_text is None:
                continue

            try:
                data = json.loads(raw_text)
            except json.JSONDecodeError:
                await _send_error_locked("INVALID_JSON", "Could not parse JSON frame.")
                continue

            event_name: str = data.get("event", "")

            if event_name not in KNOWN_EVENTS:
                await _send_error_locked(
                    "UNKNOWN_EVENT",
                    f"Unrecognised event '{event_name}'. "
                    f"Expected one of: {sorted(KNOWN_EVENTS)}",
                )
                continue

            # --- session_start ---
            if event_name == "session_start":
                if active_session_id is not None:
                    await _send_error_locked(
                        "SESSION_ALREADY_ACTIVE",
                        "A session is already active. Send session_end before "
                        "starting a new one.",
                    )
                    continue

                try:
                    evt = WsSessionStartEvent(**data)
                except Exception as parse_exc:  # noqa: BLE001
                    await _send_error_locked(
                        "INVALID_PAYLOAD",
                        f"session_start validation error: {parse_exc}",
                    )
                    continue

                session = conversation_manager.create_session(
                    user_id=user.id,
                    source_language=evt.source_language,
                    target_language=evt.target_language,
                    speaker=evt.speaker,
                )
                active_session_id = session.session_id
                session_logger = RealtimeSessionLogger(
                    session_id=session.session_id
                )

                # Persist session to DB
                try:
                    async with async_session_maker() as db:
                        db_session = await ConversationRepository.create_session(
                            db,
                            session_uuid=session.session_id,
                            user_id=user.id,
                            source_language=evt.source_language,
                            target_language=evt.target_language,
                        )
                        session_db_id = db_session.id
                        if session_db_id is None:
                            raise RuntimeError(
                                "Conversation session insert returned no id"
                            )
                except Exception as db_exc:  # noqa: BLE001
                    logger.error(
                        "WS/conversation DB create_session error: %s", db_exc
                    )
                    session_logger.log_session_error(
                        user_id=user.id,
                        error_msg=str(db_exc),
                        error_code="SESSION_PERSIST_FAILED",
                    )
                    conversation_manager.remove_session(session.session_id)
                    active_session_id = None
                    session_logger = None
                    await _send_error_locked(
                        "SESSION_PERSIST_FAILED",
                        "Could not create a persisted conversation session.",
                    )
                    continue

                pipeline = ConversationPipeline(
                    session_id=session.session_id,
                    session_db_id=session_db_id,
                    user_id=user.id,
                    source_language=evt.source_language,
                    target_language=evt.target_language,
                    websocket=websocket,
                    send_lock=send_lock,
                    session_logger=session_logger,
                )
                conversation_manager.set_pipeline(
                    session.session_id, pipeline
                )

                session_logger.log_event(
                    event_type=SessionEventType.SESSION_START,
                    user_id=user.id,
                    details={
                        "session_id": session.session_id,
                        "source_language": evt.source_language,
                        "target_language": evt.target_language,
                    },
                )

                await _send_json_locked(
                    {
                        "event": "session_started",
                        "session_id": session.session_id,
                        "status": session.status.value,
                    }
                )
                logger.info(
                    "WS/conversation session_started: session_id=%s user_id=%s",
                    session.session_id,
                    user.id,
                )

            # --- audio_metadata ---
            elif event_name == "audio_metadata":
                if active_session_id is None:
                    await _send_error_locked(
                        "INVALID_SESSION_STATE",
                        "audio_metadata received before session_start.",
                    )
                    continue

                buffer = conversation_manager.get_buffer(active_session_id)
                if buffer is not None and not buffer.is_empty:
                    await _send_error_locked(
                        "METADATA_UPDATE_REJECTED",
                        "Cannot update audio metadata while audio is buffered. "
                        "Send end_utterance before changing metadata.",
                    )
                    continue

                try:
                    sample_rate_value = data.get("sample_rate", data.get("sampleRate"))
                    if type(sample_rate_value) is not int:
                        await _send_error_locked(
                            "INVALID_AUDIO_METADATA",
                            "audio_metadata validation error: sample_rate must be an integer.",
                        )
                        continue

                    evt = WsAudioMetadataEvent(**data)
                except Exception as parse_exc:  # noqa: BLE001
                    await _send_error_locked(
                        "INVALID_AUDIO_METADATA",
                        f"audio_metadata validation error: {parse_exc}",
                    )
                    continue

                # Conversation endpoint: enforce pcm_s16le + 16000 Hz
                if evt.audio_format != AudioFormat.PCM_S16LE:
                    await _send_error_locked(
                        "INVALID_AUDIO_METADATA",
                        "Conversation endpoint requires audio_format='pcm_s16le'.",
                    )
                    continue

                if evt.sample_rate != settings.CONVERSATION_PCM_SAMPLE_RATE:
                    await _send_error_locked(
                        "INVALID_AUDIO_METADATA",
                        f"Conversation endpoint requires sample_rate="
                        f"{settings.CONVERSATION_PCM_SAMPLE_RATE}.",
                    )
                    continue

                session = conversation_manager.get_session(active_session_id)
                if session is None:
                    await _send_error_locked("SESSION_NOT_FOUND", "Session state missing.")
                    continue

                try:
                    async with async_session_maker() as db:
                        await ConversationRepository.update_session_languages(
                            db,
                            active_session_id,
                            evt.source_language,
                            evt.target_language,
                        )
                except Exception as db_exc:  # noqa: BLE001
                    logger.error(
                        "WS/conversation DB update languages error: %s",
                        db_exc,
                    )
                    await _send_error_locked(
                        "SESSION_PERSIST_FAILED",
                        "Could not save conversation language metadata.",
                    )
                    continue

                metadata = AudioMetadata(
                    sample_rate=evt.sample_rate,
                    audio_format=evt.audio_format,
                    speaker=evt.speaker,
                    source_language=evt.source_language,
                    target_language=evt.target_language,
                )
                session.audio_metadata = metadata
                session.source_language = metadata.source_language
                session.target_language = metadata.target_language
                session.current_speaker = metadata.speaker
                session.mark_active()
                if pipeline is not None:
                    pipeline.update_languages(
                        metadata.source_language,
                        metadata.target_language,
                    )

                await _send_json_locked(
                    {
                        "event": "audio_metadata_ack",
                        "session_id": active_session_id,
                        "metadata": metadata.model_dump(mode="json"),
                    }
                )

            # --- ping ---
            elif event_name == "ping":
                await _send_json_locked({"event": "pong"})

            # --- speaker_changed ---
            elif event_name == "speaker_changed":
                if active_session_id is None:
                    await _send_error_locked(
                        "INVALID_SESSION_STATE",
                        "speaker_changed received before session_start.",
                    )
                    continue

                try:
                    evt = WsSpeakerChangedEvent(**data)
                except Exception as parse_exc:  # noqa: BLE001
                    await _send_error_locked(
                        "INVALID_PAYLOAD",
                        f"speaker_changed validation error: {parse_exc}",
                    )
                    continue

                session = conversation_manager.get_session(active_session_id)
                if session:
                    previous_speaker = session.current_speaker
                    session.current_speaker = evt.speaker
                    session.mark_active()
                    if session_logger is not None:
                        session_logger.log_speaker_changed(
                            user_id=user.id,
                            new_speaker=evt.speaker.value,
                            previous_speaker=(
                                previous_speaker.value
                                if previous_speaker is not None
                                else None
                            ),
                        )

            # --- end_utterance (fallback) ---
            elif event_name == "end_utterance":
                if active_session_id is None:
                    await _send_error_locked(
                        "INVALID_SESSION_STATE",
                        "end_utterance received before session_start.",
                    )
                    continue

                session = conversation_manager.get_session(active_session_id)
                buffer = conversation_manager.get_buffer(active_session_id)

                if session is None or buffer is None:
                    await _send_error_locked("SESSION_NOT_FOUND", "Session state missing.")
                    continue

                if buffer.is_empty:
                    if ignore_next_empty_end_utterance:
                        # Flutter may send its fallback immediately after the
                        # last audio chunk already triggered server-side VAD.
                        ignore_next_empty_end_utterance = False
                        continue
                    await _send_error_locked(
                        "EMPTY_AUDIO_BUFFER",
                        "No audio received since last flush. "
                        "Send binary PCM data before end_utterance.",
                    )
                    continue

                if session.audio_metadata is None:
                    await _send_error_locked(
                        "MISSING_AUDIO_METADATA",
                        "Audio metadata must be sent before end_utterance.",
                    )
                    continue

                if pipeline is None:
                    await _send_error_locked(
                        "PIPELINE_NOT_AVAILABLE",
                        "Conversation pipeline is not available.",
                    )
                    continue

                await _enqueue_from_buffer(
                    buffer, pipeline, session, "end_utterance"
                )
                ignore_next_empty_end_utterance = False
                session.status = SessionStatus.IDLE
                session.mark_active()

            # --- session_end ---
            elif event_name == "session_end":
                if active_session_id is not None:
                    # Flush remaining buffer
                    buffer = conversation_manager.get_buffer(active_session_id)
                    session = conversation_manager.get_session(active_session_id)
                    if (
                        buffer is not None
                        and not buffer.is_empty
                        and session is not None
                        and pipeline is not None
                    ):
                        await _enqueue_from_buffer(
                            buffer, pipeline, session, "session_end"
                        )

                    # Drain pipeline
                    if pipeline is not None:
                        drained = await pipeline.drain()
                    else:
                        drained = True

                    # Update DB status
                    try:
                        async with async_session_maker() as db:
                            await ConversationRepository.update_session_status(
                                db,
                                active_session_id,
                                "completed" if drained else "drain_timeout",
                            )
                    except Exception as db_exc:  # noqa: BLE001
                        logger.error(
                            "WS/conversation DB update_session error: %s",
                            db_exc,
                        )

                    if session_logger is not None:
                        session_logger.log_session_end(
                            user_id=user.id,
                            status="completed" if drained else "drain_timeout",
                        )
                    conversation_manager.remove_session(active_session_id)
                    logger.info(
                        "WS/conversation session_end: session_id=%s user_id=%s",
                        active_session_id,
                        user.id,
                    )
                    active_session_id = None
                    pipeline = None

                await websocket.close(code=1000)
                break

    except WebSocketDisconnect as exc:
        logger.info(
            "WS/conversation disconnected: user_id=%s session_id=%s code=%s",
            user.id,
            active_session_id,
            getattr(exc, "code", "unknown"),
        )
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "WS/conversation unexpected error: user_id=%s session_id=%s — %s",
            user.id,
            active_session_id,
            exc,
            exc_info=True,
        )
    finally:
        if active_session_id is not None:
            # Stop pipeline
            if pipeline is not None:
                await pipeline.stop()

            # Update DB status to disconnected
            try:
                async with async_session_maker() as db:
                    await ConversationRepository.update_session_status(
                        db, active_session_id, "disconnected"
                    )
            except Exception:  # noqa: BLE001
                pass

            if session_logger is not None:
                session_logger.log_session_end(
                    user_id=user.id, status="disconnected"
                )
            conversation_manager.remove_session(active_session_id)
            logger.info(
                "WS/conversation cleanup: session_id=%s user_id=%s",
                active_session_id,
                user.id,
            )
