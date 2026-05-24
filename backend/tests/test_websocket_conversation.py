"""
Tests for /api/v1/ws/conversation — Real-Time Voice Translation WebSocket

Uses FastAPI's TestClient WebSocket context manager.
All external dependencies (Redis, DB, STT, Translation) are mocked to ensure
tests are fast and deterministic.

Existing /api/v1/ws sync behaviour is verified in the last test class.
"""

from typing import Optional
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from jose import jwt

from app.core.config import settings
from app.main import app
from app.schemas.realtime_session import SessionStatus

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_ALGO = settings.ALGORITHM
_SECRET = settings.SECRET_KEY


def _make_token(user_id: int = 1, token_type: str = "access", jti: str = "test-jti") -> str:
    """Generate a minimal signed JWT for testing."""
    payload = {
        "sub": str(user_id),
        "type": token_type,
        "jti": jti,
    }
    return jwt.encode(payload, _SECRET, algorithm=_ALGO)


def _make_user(
    user_id: int = 1,
    is_deleted: bool = False,
    status: str = "active",
) -> MagicMock:
    """Return a mock User ORM object."""
    user = MagicMock()
    user.id = user_id
    user.email = f"user{user_id}@test.com"
    user.is_deleted = is_deleted
    user.status = status
    return user


# Common mock patches applied by most tests
_PATCH_IS_TOKEN_REVOKED = "app.api.v1.endpoints.websocket.is_token_revoked"
_PATCH_SESSION_MAKER = "app.api.v1.endpoints.websocket.async_session_maker"
_PATCH_STT = "app.api.v1.endpoints.websocket.STTService.transcribe_audio"
_PATCH_TRANSLATE = "app.api.v1.endpoints.websocket.TranslationService.translate_with_cache"


def _make_db_ctx(user: Optional[MagicMock]):
    """
    Return a callable suitable as side_effect for async_session_maker.
    Each call to async_session_maker() returns a fresh async context manager
    that yields a mock DB session returning *user*.
    """
    def _factory(*args, **kwargs):
        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = user

        mock_db = AsyncMock()
        mock_db.execute = AsyncMock(return_value=mock_result)

        ctx = MagicMock()
        ctx.__aenter__ = AsyncMock(return_value=mock_db)
        ctx.__aexit__ = AsyncMock(return_value=False)
        return ctx

    return _factory


# ---------------------------------------------------------------------------
# 1. Authentication rejection tests
# ---------------------------------------------------------------------------


class TestAuthRejection:
    """WebSocket connections with bad tokens must be closed before any data."""

    def test_missing_token_rejected(self):
        """No ?token= param → connection closed (WS 1008 or immediate close)."""
        client = TestClient(app)
        with pytest.raises(Exception):
            # TestClient raises when the server rejects without accepting
            with client.websocket_connect("/api/v1/ws/conversation"):
                pass

    def test_invalid_token_rejected(self):
        """Malformed JWT string → close 1008."""
        client = TestClient(app)
        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)):
            with pytest.raises(Exception):
                with client.websocket_connect(
                    "/api/v1/ws/conversation?token=not-a-jwt"
                ):
                    pass

    def test_refresh_token_rejected(self):
        """Token with type='refresh' must be rejected — only access tokens accepted."""
        token = _make_token(token_type="refresh")
        client = TestClient(app)
        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)):
            with pytest.raises(Exception):
                with client.websocket_connect(
                    f"/api/v1/ws/conversation?token={token}"
                ):
                    pass

    def test_revoked_token_rejected(self):
        """Token whose JTI is in the revocation list must be refused."""
        token = _make_token(jti="revoked-jti")
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=True)):
            with patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(_make_user())):
                with pytest.raises(Exception):
                    with client.websocket_connect(
                        f"/api/v1/ws/conversation?token={token}"
                    ):
                        pass

    def test_deleted_user_rejected(self):
        """User flagged as deleted must be refused even with a valid token."""
        token = _make_token()
        deleted_user = _make_user(is_deleted=True)
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)):
            with patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(deleted_user)):
                with pytest.raises(Exception):
                    with client.websocket_connect(
                        f"/api/v1/ws/conversation?token={token}"
                    ):
                        pass

    def test_locked_user_rejected(self):
        """User with status='locked' must be refused."""
        token = _make_token()
        locked_user = _make_user(status="locked")
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)):
            with patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(locked_user)):
                with pytest.raises(Exception):
                    with client.websocket_connect(
                        f"/api/v1/ws/conversation?token={token}"
                    ):
                        pass

    def test_nonexistent_user_rejected(self):
        """Valid token for a user that no longer exists → close 1008."""
        token = _make_token(user_id=999)
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)):
            with patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(None)):
                with pytest.raises(Exception):
                    with client.websocket_connect(
                        f"/api/v1/ws/conversation?token={token}"
                    ):
                        pass


# ---------------------------------------------------------------------------
# 2. Session lifecycle tests
# ---------------------------------------------------------------------------


class TestSessionLifecycle:
    """Tests for session_start → session_started → session_end flow."""

    def _patches(self, user: MagicMock):
        return [
            patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)),
            patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)),
        ]

    def test_valid_connect_and_session_start(self):
        """Valid token + session_start must return a session_started event."""
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                reply = ws.receive_json()

        assert reply["event"] == "session_started"
        assert "session_id" in reply
        assert reply["status"] == SessionStatus.IDLE.value

    def test_ping_pong(self):
        """ping event → server replies with pong event."""
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({"event": "ping"})
                reply = ws.receive_json()

        assert reply["event"] == "pong"

    def test_session_end_closes_connection(self):
        """session_end must remove the session from the manager and close cleanly."""
        from app.services.conversation_session_manager import conversation_manager

        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        session_id_holder = []

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                reply = ws.receive_json()
                session_id = reply["session_id"]
                session_id_holder.append(session_id)

                # Session should be active now
                assert conversation_manager.has_session(session_id)

                ws.send_json({"event": "session_end"})
                # Connection closes; no further message expected.

        # After close, session must be cleaned up
        assert not conversation_manager.has_session(session_id_holder[0])

    def test_duplicate_session_start_returns_error(self):
        """Sending session_start twice on the same connection must return an error."""
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                ws.receive_json()  # session_started

                # Second session_start on same connection
                ws.send_json({
                    "event": "session_start",
                    "source_language": "en",
                    "target_language": "vi",
                    "speaker": "SPEAKER_B",
                })
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "SESSION_ALREADY_ACTIVE"


# ---------------------------------------------------------------------------
# 3. Binary audio buffer tests
# ---------------------------------------------------------------------------


class TestBinaryAudio:
    """Tests for binary PCM frame handling."""

    def test_binary_before_session_start_returns_error(self):
        """Binary frame before session_start must return INVALID_SESSION_STATE."""
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_bytes(b"\x00" * 1024)
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "INVALID_SESSION_STATE"

    def test_binary_chunks_accumulate_in_buffer(self):
        """
        Multiple binary frames must be concatenated in the PCM buffer.
        We verify this behaviourally: STT is called with the combined bytes
        (not just the last chunk), and end_utterance succeeds (not empty buffer).
        """
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        received_audio = []

        async def _capture_stt(audio_bytes, language):
            received_audio.append(audio_bytes)
            return {"text": "Xin chào", "language": "vi", "language_probability": 0.99}

        translate_mock = AsyncMock(return_value=("Hello", False, 50.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=_capture_stt), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                ws.receive_json()  # session_started

                # Send two PCM chunks then flush
                ws.send_bytes(b"\x00" * 512)
                ws.send_bytes(b"\xff" * 512)
                ws.send_json({"event": "end_utterance"})
                result = ws.receive_json()

        # STT must have been called with both chunks concatenated (1024 bytes)
        assert result["event"] == "translation_result"
        assert len(received_audio) == 1
        assert len(received_audio[0]) == 1024
        # First 512 bytes are 0x00, second 512 are 0xff
        assert received_audio[0][:512] == b"\x00" * 512
        assert received_audio[0][512:] == b"\xff" * 512

    def test_end_utterance_empty_buffer_returns_error(self):
        """end_utterance with no audio → EMPTY_AUDIO_BUFFER error."""
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                ws.receive_json()  # session_started

                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "EMPTY_AUDIO_BUFFER"


# ---------------------------------------------------------------------------
# 4. end_utterance → STT → translation pipeline tests
# ---------------------------------------------------------------------------


class TestEndUtterancePipeline:
    """Full STT + translation pipeline triggered by end_utterance."""

    def test_end_utterance_returns_translation_result(self):
        """
        end_utterance should call mocked STT and mocked translate, then return
        a translation_result event with expected fields.
        """
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "Xin chào thế giới",
            "language": "vi",
            "language_probability": 0.98,
        })
        translate_mock = AsyncMock(return_value=("Hello world", False, 120.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                ws.receive_json()  # session_started

                ws.send_bytes(b"\x00" * 1024)
                ws.send_json({"event": "end_utterance"})

                result = ws.receive_json()

        assert result["event"] == "translation_result"
        assert result["source_text"] == "Xin chào thế giới"
        assert result["translated_text"] == "Hello world"
        assert result["source_language"] == "vi"
        assert result["target_language"] == "en"
        assert result["speaker"] == "SPEAKER_A"
        assert result["is_cached"] is False
        assert "response_time_ms" in result
        assert "session_id" in result

    def test_end_utterance_clears_buffer_after_flush(self):
        """
        After end_utterance succeeds, the buffer must be empty so a second
        end_utterance (with no new audio) returns EMPTY_AUDIO_BUFFER.
        """
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "test speech",
            "language": "vi",
            "language_probability": 0.95,
        })
        translate_mock = AsyncMock(return_value=("test speech translated", True, 30.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                ws.receive_json()  # session_started

                # First utterance — succeeds
                ws.send_bytes(b"\x00" * 2048)
                ws.send_json({"event": "end_utterance"})
                result = ws.receive_json()
                assert result["event"] == "translation_result"

                # Second end_utterance without any new audio must fail
                # because buffer was reset after the first flush.
                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "EMPTY_AUDIO_BUFFER"

    def test_end_utterance_cached_result(self):
        """Translation from cache sets is_cached=True in the result."""
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "cached text",
            "language": "vi",
            "language_probability": 0.90,
        })
        # Simulate cache hit: is_cached=True
        translate_mock = AsyncMock(return_value=("cached translation", True, 10.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                ws.receive_json()

                ws.send_bytes(b"\x00" * 512)
                ws.send_json({"event": "end_utterance"})
                result = ws.receive_json()

        assert result["is_cached"] is True

    def test_end_utterance_stt_failure_returns_error(self):
        """If STT raises STTError, server returns STT_FAILED error (not a crash)."""
        from app.services.stt_service import STTError

        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(side_effect=STTError("engine failed"))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                ws.receive_json()

                ws.send_bytes(b"\x00" * 512)
                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "STT_FAILED"


# ---------------------------------------------------------------------------
# 5. Speaker changed test
# ---------------------------------------------------------------------------


class TestSpeakerChanged:
    def test_speaker_changed_updates_session(self):
        """speaker_changed event must update current_speaker in session state."""
        from app.services.conversation_session_manager import conversation_manager

        token = _make_token()
        user = _make_user()
        client = TestClient(app)
        session_ids = []

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                reply = ws.receive_json()
                session_ids.append(reply["session_id"])

                ws.send_json({"event": "speaker_changed", "speaker": "SPEAKER_B"})
                # No reply expected for speaker_changed
                # Small sleep to let handler process
                import time 
                time.sleep(0.05)

                session = conversation_manager.get_session(session_ids[0])
                assert session is not None
                assert session.current_speaker.value == "SPEAKER_B"


# ---------------------------------------------------------------------------
# 6. Disconnect cleanup test
# ---------------------------------------------------------------------------


class TestDisconnectCleanup:
    def test_disconnect_removes_session(self):
        """When the client disconnects, the session must be removed from manager."""
        from app.services.conversation_session_manager import conversation_manager

        token = _make_token()
        user = _make_user()
        client = TestClient(app)
        session_ids = []

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                reply = ws.receive_json()
                session_ids.append(reply["session_id"])
                # Connection closes here (end of `with` block)

        assert not conversation_manager.has_session(session_ids[0])


# ---------------------------------------------------------------------------
# 7. Backward-compatibility — existing /api/v1/ws sync socket
# ---------------------------------------------------------------------------


class TestExistingSyncSocket:
    """The sync notification socket must still work after adding /conversation."""

    def test_sync_ws_ping_still_works(self):
        """Existing /api/v1/ws ping behaviour unchanged."""
        token = _make_token()
        client = TestClient(app)

        with patch(
            "app.api.v1.endpoints.websocket.verify_token",
            return_value={"sub": "1", "type": "access"},
        ):
            with client.websocket_connect(
                f"/api/v1/ws?token={token}"
            ) as ws:
                ws.send_json({"ping": True})
                reply = ws.receive_json()

        assert reply == {"pong": True}
