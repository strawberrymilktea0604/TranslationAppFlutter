"""
Conversation persistence models — session and message tracking for
real-time voice translation WebSocket sessions.

These tables are the authoritative record for conversation data.
The existing ``translations`` table continues to serve as the general
translation history. These tables add the session-level conversation record.
"""

from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.models.base import Base


class ConversationSession(Base):
    """Tracks the lifecycle of a single real-time conversation session."""

    __tablename__ = "conversation_sessions"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    session_uuid = Column(
        String(36), unique=True, nullable=False, index=True
    )
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source_language = Column(String(10), nullable=False)
    target_language = Column(String(10), nullable=False)
    status = Column(
        String(20), nullable=False, default="active"
    )  # active | completed | disconnected | drain_timeout
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    ended_at = Column(DateTime(timezone=True), nullable=True)

    messages = relationship(
        "ConversationMessage",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="ConversationMessage.sequence_number",
    )
    user = relationship("User", back_populates="conversation_sessions")


class ConversationMessage(Base):
    """A single STT + translation result within a conversation session."""

    __tablename__ = "conversation_messages"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    session_id = Column(
        BigInteger,
        ForeignKey("conversation_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    sequence_number = Column(Integer, nullable=False)

    # Content
    speaker = Column(String(20), nullable=False)  # SPEAKER_A | SPEAKER_B
    transcript = Column(Text, nullable=False)
    translated_text = Column(Text, nullable=False)
    source_language = Column(String(10), nullable=False)
    target_language = Column(String(10), nullable=False)

    # STT metadata
    stt_language = Column(String(10), nullable=True)
    stt_confidence = Column(Float, nullable=True)

    # Finalization context
    finalize_trigger = Column(
        String(20), nullable=False
    )  # silence | end_utterance | session_end

    # Audio metrics
    audio_size_bytes = Column(Integer, nullable=True)
    audio_duration_ms = Column(Float, nullable=True)

    # Cache / performance
    is_cached = Column(Boolean, default=False)
    latency_stt_ms = Column(Float, nullable=True)
    latency_translate_ms = Column(Float, nullable=True)
    latency_persist_ms = Column(Float, nullable=True)
    latency_total_ms = Column(Float, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint(
            "session_id",
            "sequence_number",
            name="uq_session_sequence",
        ),
    )

    session = relationship("ConversationSession", back_populates="messages")
