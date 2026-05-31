"""
Conversation Repository — persistence layer for conversation sessions and
messages.

All database interaction for the ``conversation_sessions`` and
``conversation_messages`` tables is centralised here so the pipeline
service and WebSocket endpoint remain storage-agnostic.
"""

import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conversation import ConversationMessage, ConversationSession

logger = logging.getLogger(__name__)


class ConversationRepository:
    """Static methods mirroring the pattern used by TranslationRepository."""

    # ------------------------------------------------------------------
    # Session lifecycle
    # ------------------------------------------------------------------

    @staticmethod
    async def create_session(
        db: AsyncSession,
        session_uuid: str,
        user_id: int,
        source_language: str,
        target_language: str,
    ) -> ConversationSession:
        """Insert a new conversation session and return the ORM object."""
        session = ConversationSession(
            session_uuid=session_uuid,
            user_id=user_id,
            source_language=source_language,
            target_language=target_language,
            status="active",
        )
        db.add(session)
        await db.flush()  # populate session.id
        await db.commit()
        await db.refresh(session)
        return session

    @staticmethod
    async def update_session_status(
        db: AsyncSession,
        session_uuid: str,
        status: str,
        ended_at: Optional[datetime] = None,
    ) -> None:
        """Update the status (and optionally ended_at) for a session."""
        values: dict = {"status": status}
        if ended_at is not None:
            values["ended_at"] = ended_at
        elif status in ("completed", "disconnected", "drain_timeout"):
            values["ended_at"] = datetime.now(timezone.utc)

        stmt = (
            update(ConversationSession)
            .where(ConversationSession.session_uuid == session_uuid)
            .values(**values)
        )
        await db.execute(stmt)
        await db.commit()

    @staticmethod
    async def update_session_languages(
        db: AsyncSession,
        session_uuid: str,
        source_language: str,
        target_language: str,
    ) -> None:
        """Persist validated language changes from audio metadata."""
        stmt = (
            update(ConversationSession)
            .where(ConversationSession.session_uuid == session_uuid)
            .values(
                source_language=source_language,
                target_language=target_language,
            )
        )
        await db.execute(stmt)
        await db.commit()

    # ------------------------------------------------------------------
    # Message persistence
    # ------------------------------------------------------------------

    @staticmethod
    async def append_message(
        db: AsyncSession,
        *,
        session_db_id: int,
        sequence_number: int,
        speaker: str,
        transcript: str,
        translated_text: str,
        source_language: str,
        target_language: str,
        stt_language: Optional[str] = None,
        stt_confidence: Optional[float] = None,
        finalize_trigger: str = "silence",
        audio_size_bytes: Optional[int] = None,
        audio_duration_ms: Optional[float] = None,
        is_cached: bool = False,
        latency_stt_ms: Optional[float] = None,
        latency_translate_ms: Optional[float] = None,
        latency_persist_ms: Optional[float] = None,
        latency_total_ms: Optional[float] = None,
    ) -> ConversationMessage:
        """Insert a conversation message and return the ORM object."""
        message = ConversationMessage(
            session_id=session_db_id,
            sequence_number=sequence_number,
            speaker=speaker,
            transcript=transcript,
            translated_text=translated_text,
            source_language=source_language,
            target_language=target_language,
            stt_language=stt_language,
            stt_confidence=stt_confidence,
            finalize_trigger=finalize_trigger,
            audio_size_bytes=audio_size_bytes,
            audio_duration_ms=audio_duration_ms,
            is_cached=is_cached,
            latency_stt_ms=latency_stt_ms,
            latency_translate_ms=latency_translate_ms,
            latency_persist_ms=latency_persist_ms,
            latency_total_ms=latency_total_ms,
        )
        db.add(message)
        await db.flush()
        await db.commit()
        await db.refresh(message)
        return message

    @staticmethod
    async def update_message_latencies(
        db: AsyncSession,
        message_id: int,
        *,
        latency_persist_ms: float,
        latency_total_ms: float,
    ) -> None:
        """Store latencies that are only known after the initial insert."""
        stmt = (
            update(ConversationMessage)
            .where(ConversationMessage.id == message_id)
            .values(
                latency_persist_ms=latency_persist_ms,
                latency_total_ms=latency_total_ms,
            )
        )
        await db.execute(stmt)
        await db.commit()
