"""
Tests for /api/v1/ws/conversation — Real-Time Voice Translation WebSocket

Uses FastAPI's TestClient WebSocket context manager.
All external dependencies (Redis, DB, STT, Translation) are mocked to ensure
tests are fast and deterministic.

Existing /api/v1/ws sync behaviour is verified in the last test class.
"""

import io
import struct
import wave
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


def _send_session_start(
    ws,
    source_language: str = "vi",
    target_language: str = "en",
    speaker: str = "SPEAKER_A",
) -> dict:
    ws.send_json({
        "event": "session_start",
        "source_language": source_language,
        "target_language": target_language,
        "speaker": speaker,
    })
    return ws.receive_json()


def _send_audio_metadata(
    ws,
    sample_rate: int = 16000,
    audio_format: str = "pcm_s16le",
    speaker: str = "SPEAKER_A",
    source_language: str = "vi",
    target_language: str = "en",
) -> dict:
    ws.send_json({
        "event": "audio_metadata",
        "sample_rate": sample_rate,
        "audio_format": audio_format,
        "speaker": speaker,
        "source_language": source_language,
        "target_language": target_language,
    })
    return ws.receive_json()


def _pcm_window(sample: int, duration_ms: int = 100) -> bytes:
    """Build one mono PCM s16le window for server-side VAD tests."""
    sample_count = settings.CONVERSATION_PCM_SAMPLE_RATE * duration_ms // 1000
    return struct.pack(f"<{sample_count}h", *([sample] * sample_count))


# Common mock patches applied by most tests
_PATCH_IS_TOKEN_REVOKED = "app.api.v1.endpoints.websocket.is_token_revoked"
_PATCH_SESSION_MAKER = "app.api.v1.endpoints.websocket.async_session_maker"
_PATCH_STT = "app.services.conversation_pipeline.STTService.transcribe_audio"
_PATCH_TRANSLATE = (
    "app.services.conversation_pipeline.TranslationService.translate_with_cache"
)
_PATCH_CREATE_CONVERSATION_SESSION = (
    "app.api.v1.endpoints.websocket.ConversationRepository.create_session"
)
_PATCH_UPDATE_CONVERSATION_SESSION = (
    "app.api.v1.endpoints.websocket.ConversationRepository.update_session_status"
)
_PATCH_UPDATE_CONVERSATION_LANGUAGES = (
    "app.api.v1.endpoints.websocket.ConversationRepository.update_session_languages"
)
_PATCH_APPEND_CONVERSATION_MESSAGE = (
    "app.services.conversation_pipeline.ConversationRepository.append_message"
)
_PATCH_UPDATE_CONVERSATION_MESSAGE = (
    "app.services.conversation_pipeline.ConversationRepository.update_message_latencies"
)


@pytest.fixture(autouse=True)
def _mock_conversation_persistence():
    """Keep WebSocket tests isolated from the conversation persistence tables."""
    with patch(
        _PATCH_CREATE_CONVERSATION_SESSION,
        new=AsyncMock(return_value=MagicMock(id=101)),
    ), patch(
        _PATCH_UPDATE_CONVERSATION_SESSION,
        new=AsyncMock(return_value=None),
    ), patch(
        _PATCH_UPDATE_CONVERSATION_LANGUAGES,
        new=AsyncMock(return_value=None),
    ), patch(
        _PATCH_APPEND_CONVERSATION_MESSAGE,
        new=AsyncMock(return_value=MagicMock(id=201)),
    ), patch(
        _PATCH_UPDATE_CONVERSATION_MESSAGE,
        new=AsyncMock(return_value=None),
    ):
        yield


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
                _send_session_start(ws)
                _send_audio_metadata(ws)

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

    def test_session_start_persist_failure_returns_error(self):
        from app.services.conversation_session_manager import conversation_manager

        token = _make_token()
        user = _make_user()
        client = TestClient(app)
        baseline_count = conversation_manager.active_session_count()

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(
                 _PATCH_CREATE_CONVERSATION_SESSION,
                 new=AsyncMock(side_effect=RuntimeError("db unavailable")),
             ):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                ws.send_json({
                    "event": "session_start",
                    "source_language": "vi",
                    "target_language": "en",
                    "speaker": "SPEAKER_A",
                })
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "SESSION_PERSIST_FAILED"
        assert conversation_manager.active_session_count() == baseline_count


# ---------------------------------------------------------------------------
# 3. Audio metadata tests
# ---------------------------------------------------------------------------


class TestAudioMetadata:
    """Tests for audio_metadata validation and session state updates."""

    def test_audio_metadata_updates_session_state(self):
        from app.services.conversation_session_manager import conversation_manager

        token = _make_token()
        user = _make_user()
        client = TestClient(app)
        session_id = None
        language_update_mock = AsyncMock(return_value=None)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_UPDATE_CONVERSATION_LANGUAGES, new=language_update_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                start = _send_session_start(ws)
                session_id = start["session_id"]

                ack = _send_audio_metadata(
                    ws,
                    sample_rate=16000,
                    audio_format="PCM_S16LE",
                    speaker="SPEAKER_B",
                    source_language="en",
                    target_language="vi",
                )

                session = conversation_manager.get_session(session_id)
                assert session is not None
                assert session.audio_metadata is not None
                assert session.audio_metadata.sample_rate == 16000
                assert session.audio_metadata.audio_format.value == "pcm_s16le"
                assert session.current_speaker.value == "SPEAKER_B"
                assert session.source_language == "en"
                assert session.target_language == "vi"

        language_update_mock.assert_awaited_once()
        assert language_update_mock.await_args.args[1:] == (
            session_id,
            "en",
            "vi",
        )
        assert ack["event"] == "audio_metadata_ack"
        assert ack["metadata"] == {
            "sample_rate": 16000,
            "audio_format": "pcm_s16le",
            "speaker": "SPEAKER_B",
            "source_language": "en",
            "target_language": "vi",
        }

    def test_audio_metadata_accepts_flutter_camel_case(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)

                ws.send_json({
                    "event": "audio_metadata",
                    "sampleRate": 16000,
                    "audioFormat": "pcm_s16le",
                    "speaker": "SPEAKER_A",
                    "sourceLanguage": "vi",
                    "targetLanguage": "en",
                })
                ack = ws.receive_json()

        assert ack["event"] == "audio_metadata_ack"
        assert ack["metadata"]["sample_rate"] == 16000
        assert ack["metadata"]["audio_format"] == "pcm_s16le"

    def test_audio_metadata_persist_failure_returns_error(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(
                 _PATCH_UPDATE_CONVERSATION_LANGUAGES,
                 new=AsyncMock(side_effect=RuntimeError("db unavailable")),
             ):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                error = _send_audio_metadata(ws)

        assert error["event"] == "error"
        assert error["code"] == "SESSION_PERSIST_FAILED"

    @pytest.mark.parametrize(
        "payload",
        [
            {
                "event": "audio_metadata",
                "audio_format": "pcm_s16le",
                "speaker": "SPEAKER_A",
                "source_language": "vi",
                "target_language": "en",
            },
            {
                "event": "audio_metadata",
                "sample_rate": 12345,
                "audio_format": "pcm_s16le",
                "speaker": "SPEAKER_A",
                "source_language": "vi",
                "target_language": "en",
            },
            {
                "event": "audio_metadata",
                "sample_rate": 44100,
                "audio_format": "pcm_s16le",
                "speaker": "SPEAKER_A",
                "source_language": "vi",
                "target_language": "en",
            },
            {
                "event": "audio_metadata",
                "sample_rate": 16000,
                "audio_format": "m4a",
                "speaker": "SPEAKER_A",
                "source_language": "vi",
                "target_language": "en",
            },
            {
                "event": "audio_metadata",
                "sample_rate": 44100,
                "audio_format": "webm",
                "speaker": "SPEAKER_A",
                "source_language": "vi",
                "target_language": "en",
            },
            {
                "event": "audio_metadata",
                "sample_rate": "44100",
                "audio_format": "pcm_s16le",
                "speaker": "SPEAKER_A",
                "source_language": "vi",
                "target_language": "en",
            },
            {
                "event": "audio_metadata",
                "sample_rate": 44100,
                "audio_format": "pcm_s16le",
                "speaker": "SPEAKER_C",
                "source_language": "vi",
                "target_language": "en",
            },
        ],
    )
    def test_invalid_audio_metadata_returns_error(self, payload):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                ws.send_json(payload)
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "INVALID_AUDIO_METADATA"

    def test_audio_metadata_update_rejected_when_buffer_has_audio(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(b"\x00" * 512)

                error = _send_audio_metadata(
                    ws,
                    sample_rate=16000,
                    speaker="SPEAKER_B",
                    source_language="en",
                    target_language="vi",
                )

        assert error["event"] == "error"
        assert error["code"] == "METADATA_UPDATE_REJECTED"


# ---------------------------------------------------------------------------
# 4. Binary audio buffer tests
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

        async def _capture_stt(audio_bytes, language, file_extension=".tmp"):
            received_audio.append(audio_bytes)
            assert language == "vi"
            assert file_extension == ".wav"
            return {"text": "Xin chào", "language": "vi", "language_probability": 0.99}

        translate_mock = AsyncMock(return_value=("Hello", False, 50.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=_capture_stt), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)

                # Send two PCM chunks then flush
                ws.send_bytes(b"\x00" * 512)
                ws.send_bytes(b"\xff" * 512)
                ws.send_json({"event": "end_utterance"})
                result = ws.receive_json()

        # STT must have been called with both chunks concatenated (1024 bytes)
        assert result["event"] == "final_translation"
        assert len(received_audio) == 1
        with wave.open(io.BytesIO(received_audio[0]), "rb") as wav_file:
            assert wav_file.getframerate() == 16000
            assert wav_file.getnchannels() == 1
            assert wav_file.getsampwidth() == 2
            pcm_frames = wav_file.readframes(wav_file.getnframes())

        assert len(pcm_frames) == 1024
        # First 512 bytes are 0x00, second 512 are 0xff
        assert pcm_frames[:512] == b"\x00" * 512
        assert pcm_frames[512:] == b"\xff" * 512

    def test_binary_after_session_start_before_metadata_returns_error(self):
        """Binary frame before audio_metadata must return MISSING_AUDIO_METADATA."""
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                ws.send_bytes(b"\x00" * 1024)
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "MISSING_AUDIO_METADATA"

    def test_empty_binary_chunk_returns_error(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(b"")
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "EMPTY_AUDIO_CHUNK"

    def test_odd_sized_pcm_chunk_returns_error(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(b"\x00")
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "INVALID_AUDIO_CHUNK"

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
                _send_session_start(ws)
                _send_audio_metadata(ws)

                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "EMPTY_AUDIO_BUFFER"


# ---------------------------------------------------------------------------
# 4. end_utterance → STT → translation pipeline tests
# ---------------------------------------------------------------------------


class TestEndUtterancePipeline:
    """Full STT + translation pipeline triggered by end_utterance."""

    def test_end_utterance_returns_final_translation(self):
        """
        end_utterance should call mocked STT and mocked translate, then return
        a final_translation event with expected fields.
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
                _send_session_start(ws)
                _send_audio_metadata(ws)

                ws.send_bytes(b"\x00" * 1024)
                ws.send_json({"event": "end_utterance"})

                result = ws.receive_json()

        assert result["event"] == "final_translation"
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
                _send_session_start(ws)
                _send_audio_metadata(ws)

                # First utterance — succeeds
                ws.send_bytes(b"\x00" * 2048)
                ws.send_json({"event": "end_utterance"})
                result = ws.receive_json()
                assert result["event"] == "final_translation"

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
                _send_session_start(ws)
                _send_audio_metadata(ws)

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
                _send_session_start(ws)
                _send_audio_metadata(ws)

                ws.send_bytes(b"\x00" * 512)
                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "STT_FAILED"

    def test_end_utterance_empty_stt_result_returns_error(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": " ",
            "language": "vi",
            "language_probability": 0.99,
        })

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "STT_NO_TEXT_EXTRACTED"

    def test_end_utterance_translation_failure_returns_error(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "xin chao",
            "language": "vi",
            "language_probability": 0.99,
        })
        translate_mock = AsyncMock(side_effect=RuntimeError("translator unavailable"))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "TRANSLATION_FAILED"

    def test_trailing_silence_auto_finalizes_without_end_utterance(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "xin chao",
            "language": "vi",
            "language_probability": 0.99,
        })
        translate_mock = AsyncMock(return_value=("hello", False, 25.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                ws.send_bytes(_pcm_window(0, duration_ms=1500))
                result = ws.receive_json()

        assert result["event"] == "final_translation"
        assert result["source_text"] == "xin chao"
        assert result["translated_text"] == "hello"
        assert result["sequence_number"] == 1

    def test_empty_fallback_after_silence_auto_finalize_is_ignored_once(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "xin chao",
            "language": "vi",
            "language_probability": 0.99,
        })
        translate_mock = AsyncMock(return_value=("hello", False, 25.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                ws.send_bytes(_pcm_window(0, duration_ms=1500))
                result = ws.receive_json()

                ws.send_json({"event": "end_utterance"})
                ws.send_json({"event": "ping"})
                pong = ws.receive_json()

                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert result["event"] == "final_translation"
        assert pong["event"] == "pong"
        assert error["event"] == "error"
        assert error["code"] == "EMPTY_AUDIO_BUFFER"

    def test_message_persist_failure_returns_error_instead_of_final_translation(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "xin chao",
            "language": "vi",
            "language_probability": 0.99,
        })
        translate_mock = AsyncMock(return_value=("hello", False, 25.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock), \
             patch(
                 _PATCH_APPEND_CONVERSATION_MESSAGE,
                 new=AsyncMock(side_effect=RuntimeError("db unavailable")),
             ):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                ws.send_json({"event": "end_utterance"})
                error = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "MESSAGE_PERSIST_FAILED"

    def test_final_translation_is_persisted_before_send(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "xin chao",
            "language": "vi",
            "language_probability": 0.99,
        })
        translate_mock = AsyncMock(return_value=("hello", False, 25.0))
        append_mock = AsyncMock(return_value=MagicMock(id=987))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock), \
             patch(_PATCH_APPEND_CONVERSATION_MESSAGE, new=append_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                ws.send_json({"event": "end_utterance"})
                result = ws.receive_json()

        append_mock.assert_awaited_once()
        persisted = append_mock.await_args.kwargs
        assert persisted["session_db_id"] == 101
        assert persisted["sequence_number"] == 1
        assert persisted["speaker"] == "SPEAKER_A"
        assert persisted["transcript"] == "xin chao"
        assert persisted["translated_text"] == "hello"
        assert persisted["finalize_trigger"] == "end_utterance"
        assert result["event"] == "final_translation"
        assert result["message_id"] == 987

    def test_session_end_flushes_short_audio_before_closing(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        stt_mock = AsyncMock(return_value={
            "text": "short speech",
            "language": "en",
            "language_probability": 0.99,
        })
        translate_mock = AsyncMock(return_value=("loi noi ngan", False, 25.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(b"\x01\x00" * 100)
                ws.send_json({"event": "session_end"})
                result = ws.receive_json()

        assert result["event"] == "final_translation"
        assert result["source_text"] == "short speech"
        assert result["translated_text"] == "loi noi ngan"


class TestPipelineLimitsAndObservability:
    def test_audio_too_long_resets_only_current_turn(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch.object(settings, "CONVERSATION_MAX_UTTERANCE_SECONDS", 0.05):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                error = ws.receive_json()
                ws.send_json({"event": "ping"})
                pong = ws.receive_json()

        assert error["event"] == "error"
        assert error["code"] == "AUDIO_TOO_LONG"
        assert pong["event"] == "pong"

    def test_pipeline_logs_latency_for_each_processing_stage(self):
        from app.services.realtime_session_logger import (
            RealtimeSessionLogger,
            SessionEventType,
        )

        token = _make_token()
        user = _make_user()
        client = TestClient(app)
        stt_mock = AsyncMock(return_value={
            "text": "xin chao",
            "language": "vi",
            "language_probability": 0.99,
        })
        translate_mock = AsyncMock(return_value=("hello", False, 25.0))

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock), \
             patch.object(RealtimeSessionLogger, "log_event") as log_event_mock:
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as ws:
                _send_session_start(ws)
                _send_audio_metadata(ws)
                ws.send_bytes(_pcm_window(1000))
                ws.send_json({"event": "end_utterance"})
                result = ws.receive_json()

        assert result["event"] == "final_translation"
        calls_by_type = {
            invocation.kwargs["event_type"]: invocation.kwargs
            for invocation in log_event_mock.call_args_list
        }
        latency_events = {
            SessionEventType.AUDIO_CHUNK_RECEIVED,
            SessionEventType.WAV_CONVERSION_COMPLETED,
            SessionEventType.STT_COMPLETED,
            SessionEventType.TRANSLATION_COMPLETED,
            SessionEventType.MESSAGE_PERSISTED,
            SessionEventType.FINAL_TRANSLATION_SENT,
        }
        assert latency_events <= calls_by_type.keys()
        for event_type in latency_events:
            assert calls_by_type[event_type]["latency_ms"] >= 0


class TestSessionIsolation:
    def test_final_translation_returns_to_originating_websocket(self):
        token = _make_token()
        user = _make_user()
        client = TestClient(app)
        stt_mock = AsyncMock(side_effect=[
            {
                "text": "first utterance",
                "language": "en",
                "language_probability": 0.99,
            },
            {
                "text": "second utterance",
                "language": "en",
                "language_probability": 0.99,
            },
        ])
        translate_mock = AsyncMock(side_effect=[
            ("first translation", False, 10.0),
            ("second translation", False, 10.0),
        ])

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_STT, new=stt_mock), \
             patch(_PATCH_TRANSLATE, new=translate_mock):
            with client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as first_ws, client.websocket_connect(
                f"/api/v1/ws/conversation?token={token}"
            ) as second_ws:
                first_start = _send_session_start(first_ws)
                second_start = _send_session_start(second_ws)
                _send_audio_metadata(first_ws)
                _send_audio_metadata(second_ws)

                first_ws.send_bytes(_pcm_window(1000))
                first_ws.send_json({"event": "end_utterance"})
                first_result = first_ws.receive_json()

                second_ws.send_bytes(_pcm_window(1000))
                second_ws.send_json({"event": "end_utterance"})
                second_result = second_ws.receive_json()

        assert first_result["session_id"] == first_start["session_id"]
        assert first_result["translated_text"] == "first translation"
        assert second_result["session_id"] == second_start["session_id"]
        assert second_result["translated_text"] == "second translation"


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
        """Disconnect removes in-memory state and persists the terminal status."""
        from app.services.conversation_session_manager import conversation_manager

        token = _make_token()
        user = _make_user()
        client = TestClient(app)
        session_ids = []
        update_mock = AsyncMock(return_value=None)

        with patch(_PATCH_IS_TOKEN_REVOKED, new=AsyncMock(return_value=False)), \
             patch(_PATCH_SESSION_MAKER, side_effect=_make_db_ctx(user)), \
             patch(_PATCH_UPDATE_CONVERSATION_SESSION, new=update_mock):
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
        update_mock.assert_awaited_once()
        assert update_mock.await_args.args[1:] == (session_ids[0], "disconnected")


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
