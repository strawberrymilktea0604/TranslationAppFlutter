"""
ConversationSessionManager — In-process session registry for real-time
voice translation WebSocket sessions.

Manages paired (TranslationSession, PCMBuffer, ConversationPipeline) objects,
keyed by session_id.  One session per WebSocket connection.

This is an in-process singleton suitable for single-worker deployments.
Replace with a Redis-backed registry for multi-worker / horizontal scaling.
"""

import logging
from typing import Dict, Optional, Tuple

from app.core.config import settings
from app.core.pcm_buffer import PCMBuffer
from app.schemas.realtime_session import SessionStatus, Speaker, TranslationSession
from app.services.conversation_pipeline import ConversationPipeline

logger = logging.getLogger(__name__)

# Maximum buffer size is configured through CONVERSATION_MAX_AUDIO_SIZE.
class ConversationSessionManager:
    """
    In-process registry that maps session_id → (TranslationSession, PCMBuffer).

    Thread / asyncio safety: all mutations happen in the event loop, so no
    explicit locking is needed for a single-worker deployment.
    """

    def __init__(self) -> None:
        # session_id → (TranslationSession, PCMBuffer)
        self._sessions: Dict[str, Tuple[TranslationSession, PCMBuffer]] = {}
        # session_id → ConversationPipeline (optional, set after pipeline created)
        self._pipelines: Dict[str, ConversationPipeline] = {}

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
        buffer = PCMBuffer(
            max_size_bytes=settings.CONVERSATION_MAX_AUDIO_SIZE * 1024 * 1024,
            sample_rate=settings.CONVERSATION_PCM_SAMPLE_RATE,
            silence_threshold=settings.CONVERSATION_SILENCE_RMS_THRESHOLD,
            silence_duration_ms=settings.CONVERSATION_SILENCE_DURATION_MS,
            silence_window_ms=settings.CONVERSATION_SILENCE_WINDOW_MS,
        )
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

    def set_pipeline(
        self, session_id: str, pipeline: ConversationPipeline
    ) -> None:
        """Associate a pipeline with a session."""
        self._pipelines[session_id] = pipeline

    def get_pipeline(
        self, session_id: str
    ) -> Optional[ConversationPipeline]:
        """Return the ConversationPipeline for *session_id*, or None."""
        return self._pipelines.get(session_id)

    def remove_session(self, session_id: str) -> None:
        """
        Remove a session and its buffer from the registry.

        Marks the session as ENDED and clears the PCM buffer before discarding,
        to free memory promptly rather than waiting for GC.
        """
        pair = self._sessions.pop(session_id, None)
        self._pipelines.pop(session_id, None)
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
