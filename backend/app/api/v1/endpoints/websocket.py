"""
WebSocket Endpoints — /api/v1/ws  (sync notifications)
                    — /api/v1/ws/conversation  (real-time voice translation)

=== /api/v1/ws (unchanged) ===
Provides a persistent WebSocket connection so the server can push real-time
sync notifications to the Flutter client.

Flow:
  1. Flutter opens  ws://<host>/api/v1/ws?token=<access_token>
  2. Server verifies the JWT and registers the connection under user_id.
  3. After a successful vocabulary/history sync, the sync endpoint calls
     ConnectionManager.broadcast_sync_completed(user_id, synced_count).
  4. Flutter receives the JSON event and triggers a local Isar reload so
     both the History and Saved-Vocab tabs update their isSynced badges.

Message format (server → client):
  {
    "event":        "sync_completed",
    "synced_count": <int>,
    "timestamp":    "<ISO-8601 UTC>"
  }

Message format (client → server):
  { "ping": true }   — keepalive; server replies  { "pong": true }

=== /api/v1/ws/conversation ===
Real-time voice translation pipeline over a single persistent WebSocket.

Protocol summary:
  1. Connect with ?token=<access_token>.
  2. Send {"event": "session_start", "source_language": "vi",
           "target_language": "en", "speaker": "SPEAKER_A"}.
  3. Stream raw 16 kHz mono PCM chunks as binary frames.
  4. Send {"event": "end_utterance"} to flush → STT → translate.
  5. Receive {"event": "translation_result", ...}.
  6. Send {"event": "session_end"} to close gracefully.

See app/schemas/websocket.py for full message schemas.
"""

import json
import logging
import time
import wave
from io import BytesIO
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
from app.schemas.realtime_session import AudioFormat, AudioMetadata, SessionStatus
from app.schemas.translation import TranslationRequest
from app.schemas.websocket import (
    KNOWN_EVENTS,
    WsAudioMetadataEvent,
    WsSessionStartEvent,
    WsSpeakerChangedEvent,
)
from app.services.conversation_session_manager import conversation_manager
from app.services.stt_service import STTError, STTService
from app.services.translation_service import TranslationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["websocket"])


# ---------------------------------------------------------------------------
# Connection Manager (sync notifications — unchanged)
# ---------------------------------------------------------------------------


class ConnectionManager:
    """Manages all active WebSocket connections, keyed by user_id."""

    def __init__(self) -> None:
        # user_id → list of open WebSocket objects
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

        # Clean up dead connections
        for ws in dead:
            self.disconnect(ws, user_id)

    def connection_count(self, user_id: int) -> int:
        return len(self._connections.get(user_id, []))


# Global singleton — imported by sync endpoint to call broadcast.
manager = ConnectionManager()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _error_event(code: str, message: str) -> dict:
    """Build a standard error event dict."""
    return {"event": "error", "code": code, "message": message}


_AUDIO_FORMAT_SUFFIXES = {
    AudioFormat.WAV: ".wav",
    AudioFormat.M4A: ".m4a",
    AudioFormat.AAC: ".aac",
    AudioFormat.MP3: ".mp3",
    AudioFormat.OGG: ".ogg",
    AudioFormat.FLAC: ".flac",
}


def _language_for_stt(source_language: str) -> Optional[str]:
    """Return None for auto-detect, otherwise the explicit source language."""
    return None if source_language.lower() == "auto" else source_language


def _wrap_pcm_s16le_as_wav(audio_bytes: bytes, sample_rate: int) -> bytes:
    """Wrap raw mono signed 16-bit little-endian PCM bytes in a WAV container."""
    output = BytesIO()
    with wave.open(output, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_bytes)
    return output.getvalue()


def _prepare_audio_for_stt(
    audio_bytes: bytes,
    metadata: AudioMetadata,
) -> tuple[bytes, str]:
    """Prepare buffered audio bytes and temp-file suffix for faster-whisper."""
    if metadata.audio_format == AudioFormat.PCM_S16LE:
        return _wrap_pcm_s16le_as_wav(audio_bytes, metadata.sample_rate), ".wav"
    return audio_bytes, _AUDIO_FORMAT_SUFFIXES.get(metadata.audio_format, ".tmp")


async def _authenticate_ws(
    websocket: WebSocket, token: str
) -> Optional[User]:
    """
    Decode and validate an access JWT for a WebSocket handshake.

    Returns the User on success, or None after sending a close frame on failure.
    The WebSocket is NOT accepted before this call.

    Checks (in order):
      1. JWT is decodable and not expired.
      2. Token type claim is "access" (not refresh).
      3. JTI is not revoked in Redis.
      4. User exists in DB and is active (not deleted, not locked).
    """
    # 1. Decode JWT
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

    # 2. Must be an access token
    if payload.get("type") != "access":
        logger.warning(
            "WS/conversation auth: token type=%r is not 'access'",
            payload.get("type"),
        )
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    # 3. Validate sub / user_id
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

    # 4. Check token revocation
    jti: Optional[str] = payload.get("jti")
    if jti:
        try:
            revoked = await is_token_revoked(jti)
        except Exception:  # noqa: BLE001
            revoked = False  # fail-open: Redis unavailable is not a security block
        if revoked:
            logger.warning(
                "WS/conversation auth: token revoked jti=%s user_id=%s", jti, user_id
            )
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return None

    # 5. Load user from DB (short-lived session for auth only)
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
    # --- Authenticate before accepting ---
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
            # Keep connection alive; handle client pings.
            data = await websocket.receive_json()
            if data.get("ping"):
                await websocket.send_json({"pong": True})
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
    except Exception as exc:  # noqa: BLE001
        logger.error("WS error for user %s: %s", user_id, exc)
        manager.disconnect(websocket, user_id)


# ---------------------------------------------------------------------------
# New real-time voice-translation WebSocket route
# ---------------------------------------------------------------------------


@router.websocket("/conversation")
async def websocket_conversation(
    websocket: WebSocket,
    token: str = Query(..., description="Bearer access token for auth"),
):
    """
    Real-time voice translation WebSocket.

    Accepts raw 16 kHz mono PCM audio chunks (binary frames) and JSON control
    events (text frames). On end_utterance, flushes the PCM buffer through STT
    and the translation pipeline, then sends a translation_result event.

    Authentication: ?token=<access_token> query parameter (access tokens only).
    """
    # ------------------------------------------------------------------
    # AUTH — before accept()
    # ------------------------------------------------------------------
    user = await _authenticate_ws(websocket, token)
    if user is None:
        return  # close frame already sent by _authenticate_ws

    # Accept the connection only after successful auth
    await websocket.accept()
    logger.info(
        "WS/conversation accepted: user_id=%s email=%s", user.id, user.email
    )

    # Track the active session_id for this connection (set after session_start)
    active_session_id: Optional[str] = None

    try:
        while True:
            # Use raw receive() so we can distinguish text vs bytes vs disconnect
            frame = await websocket.receive()

            # ----------------------------------------------------------
            # Disconnect frame
            # ----------------------------------------------------------
            if frame.get("type") == "websocket.disconnect":
                break

            # ----------------------------------------------------------
            # Binary frame — raw PCM audio chunk
            # ----------------------------------------------------------
            if "bytes" in frame and frame["bytes"] is not None:
                chunk: bytes = frame["bytes"]

                if active_session_id is None:
                    await websocket.send_json(
                        _error_event(
                            "INVALID_SESSION_STATE",
                            "Binary audio received before session_start.",
                        )
                    )
                    continue

                buffer = conversation_manager.get_buffer(active_session_id)
                if buffer is None:
                    await websocket.send_json(
                        _error_event("SESSION_NOT_FOUND", "Session buffer missing.")
                    )
                    continue

                session = conversation_manager.get_session(active_session_id)
                if session is None:
                    await websocket.send_json(
                        _error_event("SESSION_NOT_FOUND", "Session state missing.")
                    )
                    continue

                if session.audio_metadata is None:
                    await websocket.send_json(
                        _error_event(
                            "MISSING_AUDIO_METADATA",
                            "Audio metadata must be sent before binary audio.",
                        )
                    )
                    continue

                session.status = SessionStatus.RECORDING
                session.mark_active()

                try:
                    buffer.append(chunk)
                except BufferOverflowError as exc:
                    logger.warning(
                        "WS/conversation buffer overflow: session_id=%s user_id=%s — %s",
                        active_session_id,
                        user.id,
                        exc,
                    )
                    await websocket.send_json(
                        _error_event(
                            "BUFFER_OVERFLOW",
                            f"PCM buffer exceeded maximum size ({exc.max_size} bytes). "
                            "Send end_utterance before sending more audio.",
                        )
                    )
                    await websocket.close(code=1009)
                    break

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
                await websocket.send_json(
                    _error_event("INVALID_JSON", "Could not parse JSON frame.")
                )
                continue

            event_name: str = data.get("event", "")

            if event_name not in KNOWN_EVENTS:
                await websocket.send_json(
                    _error_event(
                        "UNKNOWN_EVENT",
                        f"Unrecognised event '{event_name}'. "
                        f"Expected one of: {sorted(KNOWN_EVENTS)}",
                    )
                )
                continue

            # ------------------------------------------------------
            # session_start
            # ------------------------------------------------------
            if event_name == "session_start":
                if active_session_id is not None:
                    await websocket.send_json(
                        _error_event(
                            "SESSION_ALREADY_ACTIVE",
                            "A session is already active. "
                            "Send session_end before starting a new one.",
                        )
                    )
                    continue

                try:
                    evt = WsSessionStartEvent(**data)
                except Exception as parse_exc:  # noqa: BLE001
                    await websocket.send_json(
                        _error_event(
                            "INVALID_PAYLOAD",
                            f"session_start validation error: {parse_exc}",
                        )
                    )
                    continue

                session = conversation_manager.create_session(
                    user_id=user.id,
                    source_language=evt.source_language,
                    target_language=evt.target_language,
                    speaker=evt.speaker,
                )
                active_session_id = session.session_id

                await websocket.send_json(
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

            # ------------------------------------------------------
            # audio_metadata
            # ------------------------------------------------------
            elif event_name == "audio_metadata":
                if active_session_id is None:
                    await websocket.send_json(
                        _error_event(
                            "INVALID_SESSION_STATE",
                            "audio_metadata received before session_start.",
                        )
                    )
                    continue

                buffer = conversation_manager.get_buffer(active_session_id)
                if buffer is not None and not buffer.is_empty:
                    await websocket.send_json(
                        _error_event(
                            "METADATA_UPDATE_REJECTED",
                            "Cannot update audio metadata while audio is buffered. "
                            "Send end_utterance before changing metadata.",
                        )
                    )
                    continue

                try:
                    evt = WsAudioMetadataEvent(**data)
                except Exception as parse_exc:  # noqa: BLE001
                    await websocket.send_json(
                        _error_event(
                            "INVALID_AUDIO_METADATA",
                            f"audio_metadata validation error: {parse_exc}",
                        )
                    )
                    continue

                session = conversation_manager.get_session(active_session_id)
                if session is None:
                    await websocket.send_json(
                        _error_event("SESSION_NOT_FOUND", "Session state missing.")
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

                await websocket.send_json(
                    {
                        "event": "audio_metadata_ack",
                        "session_id": active_session_id,
                        "metadata": metadata.model_dump(mode="json"),
                    }
                )

            # ------------------------------------------------------
            # ping
            # ------------------------------------------------------
            elif event_name == "ping":
                await websocket.send_json({"event": "pong"})

            # ------------------------------------------------------
            # speaker_changed
            # ------------------------------------------------------
            elif event_name == "speaker_changed":
                if active_session_id is None:
                    await websocket.send_json(
                        _error_event(
                            "INVALID_SESSION_STATE",
                            "speaker_changed received before session_start.",
                        )
                    )
                    continue

                try:
                    evt = WsSpeakerChangedEvent(**data)
                except Exception as parse_exc:  # noqa: BLE001
                    await websocket.send_json(
                        _error_event(
                            "INVALID_PAYLOAD",
                            f"speaker_changed validation error: {parse_exc}",
                        )
                    )
                    continue

                session = conversation_manager.get_session(active_session_id)
                if session:
                    session.current_speaker = evt.speaker
                    session.mark_active()

            # ------------------------------------------------------
            # end_utterance — flush PCM → STT → translate
            # ------------------------------------------------------
            elif event_name == "end_utterance":
                if active_session_id is None:
                    await websocket.send_json(
                        _error_event(
                            "INVALID_SESSION_STATE",
                            "end_utterance received before session_start.",
                        )
                    )
                    continue

                session = conversation_manager.get_session(active_session_id)
                buffer = conversation_manager.get_buffer(active_session_id)

                if session is None or buffer is None:
                    await websocket.send_json(
                        _error_event("SESSION_NOT_FOUND", "Session state missing.")
                    )
                    continue

                if buffer.is_empty:
                    await websocket.send_json(
                        _error_event(
                            "EMPTY_AUDIO_BUFFER",
                            "No audio received since last flush. "
                            "Send binary PCM data before end_utterance.",
                        )
                    )
                    continue

                if session.audio_metadata is None:
                    await websocket.send_json(
                        _error_event(
                            "MISSING_AUDIO_METADATA",
                            "Audio metadata must be sent before end_utterance.",
                        )
                    )
                    continue

                session.status = SessionStatus.PROCESSING
                session.mark_active()

                # Snapshot and immediately reset buffer so new audio can
                # arrive while STT/translate are running.
                audio_bytes = buffer.get_audio()
                buffer.reset()
                audio_bytes, file_extension = _prepare_audio_for_stt(
                    audio_bytes,
                    session.audio_metadata,
                )

                pipeline_start = time.time()

                # --- STT (short-lived DB session not needed here) ---
                try:
                    stt_result = await STTService.transcribe_audio(
                        audio_bytes,
                        language=_language_for_stt(session.source_language),
                        file_extension=file_extension,
                    )
                except STTError as stt_exc:
                    logger.error(
                        "WS/conversation STT error: session_id=%s — %s",
                        active_session_id,
                        stt_exc,
                    )
                    await websocket.send_json(
                        _error_event("STT_FAILED", f"Speech-to-text failed: {stt_exc}")
                    )
                    session.status = SessionStatus.IDLE
                    continue

                extracted_text: str = stt_result.get("text", "").strip()
                if not extracted_text:
                    await websocket.send_json(
                        _error_event(
                            "STT_NO_TEXT_EXTRACTED",
                            "No speech detected in the audio. "
                            "Check audio quality or try speaking louder.",
                        )
                    )
                    session.status = SessionStatus.IDLE
                    continue

                # --- Translation (short-lived DB session per flush) ---
                try:
                    translation_req = TranslationRequest(
                        source_text=extracted_text,
                        source_language=session.source_language,
                        target_language=session.target_language,
                        translation_type="voice",
                    )
                    async with async_session_maker() as db:
                        translated_text, is_cached, response_time_ms = (
                            await TranslationService.translate_with_cache(
                                request=translation_req,
                                db=db,
                                user_id=user.id,
                                save_to_db=True,
                            )
                        )
                except Exception as trans_exc:  # noqa: BLE001
                    logger.error(
                        "WS/conversation translation error: session_id=%s — %s",
                        active_session_id,
                        trans_exc,
                    )
                    await websocket.send_json(
                        _error_event(
                            "TRANSLATION_FAILED",
                            f"Translation failed: {trans_exc}",
                        )
                    )
                    session.status = SessionStatus.IDLE
                    continue

                total_ms = (time.time() - pipeline_start) * 1000
                session.status = SessionStatus.IDLE
                session.mark_active()

                await websocket.send_json(
                    {
                        "event": "translation_result",
                        "session_id": active_session_id,
                        "source_text": extracted_text,
                        "translated_text": translated_text,
                        "source_language": session.source_language,
                        "target_language": session.target_language,
                        "speaker": session.current_speaker.value
                        if session.current_speaker
                        else None,
                        "is_cached": is_cached,
                        "response_time_ms": round(total_ms, 2),
                    }
                )
                logger.info(
                    "WS/conversation translation_result: session_id=%s "
                    "cached=%s time=%.1fms",
                    active_session_id,
                    is_cached,
                    total_ms,
                )

            # ------------------------------------------------------
            # session_end
            # ------------------------------------------------------
            elif event_name == "session_end":
                if active_session_id is not None:
                    conversation_manager.remove_session(active_session_id)
                    logger.info(
                        "WS/conversation session_end: session_id=%s user_id=%s",
                        active_session_id,
                        user.id,
                    )
                    active_session_id = None

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
        # Always clean up session state on disconnect / error
        if active_session_id is not None:
            conversation_manager.remove_session(active_session_id)
            logger.info(
                "WS/conversation cleanup: session_id=%s user_id=%s",
                active_session_id,
                user.id,
            )
