"""
ConversationSessionManager — In-process session registry for real-time
voice translation WebSocket sessions.

Manages paired (TranslationSession, PCMBuffer) objects, keyed by session_id.
One session per WebSocket connection.

This is an in-process singleton suitable for single-worker deployments.
Replace with a Redis-backed registry for multi-worker / horizontal scaling.
"""

import logging
from typing import Dict, Optional, Tuple

from app.core.pcm_buffer import PCMBuffer
from app.schemas.realtime_session import SessionStatus, Speaker, TranslationSession

logger = logging.getLogger(__name__)

# Maximum PCM buffer size per session: 10 MB
# At 16kHz mono 16-bit PCM → ~2.5 minutes of audio.
_MAX_BUFFER_BYTES: int = 10 * 1024 * 1024


class ConversationSessionManager:
    """
    In-process registry that maps session_id → (TranslationSession, PCMBuffer).

    Thread / asyncio safety: all mutations happen in the event loop, so no
    explicit locking is needed for a single-worker deployment.
    """

    def __init__(self) -> None:
        # session_id → (TranslationSession, PCMBuffer)
        self._sessions: Dict[str, Tuple[TranslationSession, PCMBuffer]] = {}

    # --------------------------------------------------------------------------
    # Session lifecycle
    # --------------------------------------------------------------------------

    def create_session(
        self,
        user_id: int,
        source_language: str,
        target_language: str,
        speaker: Speaker = Speaker.SPEAKER_A,
    ) -> TranslationSession:
        """
        Create and register a new translation session.

        Returns:
            The newly created TranslationSession (with generated session_id).
        """
        session = TranslationSession(
            user_id=user_id,
            source_language=source_language,
            target_language=target_language,
            current_speaker=speaker,
            status=SessionStatus.IDLE,
        )
        buffer = PCMBuffer(max_size_bytes=_MAX_BUFFER_BYTES)
        self._sessions[session.session_id] = (session, buffer)
        logger.info(
            "Conversation session created: session_id=%s user_id=%s %s→%s",
            session.session_id,
            user_id,
            source_language,
            target_language,
        )
        return session

    def get_session(self, session_id: str) -> Optional[TranslationSession]:
        """Return the TranslationSession for *session_id*, or None."""
        pair = self._sessions.get(session_id)
        return pair[0] if pair else None

    def get_buffer(self, session_id: str) -> Optional[PCMBuffer]:
        """Return the PCMBuffer for *session_id*, or None."""
        pair = self._sessions.get(session_id)
        return pair[1] if pair else None

    def remove_session(self, session_id: str) -> None:
        """
        Remove a session and its buffer from the registry.

        Marks the session as ENDED and clears the PCM buffer before discarding,
        to free memory promptly rather than waiting for GC.
        """
        pair = self._sessions.pop(session_id, None)
        if pair is None:
            return
        session, buffer = pair
        session.status = SessionStatus.ENDED
        buffer.reset()
        logger.info(
            "Conversation session removed: session_id=%s user_id=%s",
            session_id,
            session.user_id,
        )

    # --------------------------------------------------------------------------
    # Diagnostics
    # --------------------------------------------------------------------------

    def active_session_count(self) -> int:
        """Number of currently tracked sessions."""
        return len(self._sessions)

    def has_session(self, session_id: str) -> bool:
        """True if *session_id* is currently registered."""
        return session_id in self._sessions


# Global singleton — imported by the WebSocket conversation endpoint.
conversation_manager = ConversationSessionManager()
