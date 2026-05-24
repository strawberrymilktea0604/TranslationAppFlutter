"""
WebSocket Message Schemas — /api/v1/ws/conversation

Pydantic models for validating inbound client messages on the
real-time voice translation WebSocket endpoint.

Outbound server messages are plain dicts for minimal overhead in
the hot receive loop.
"""

from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.realtime_session import Speaker


# ==============================================================================
# INBOUND CLIENT EVENT MODELS
# ==============================================================================


class WsSessionStartEvent(BaseModel):
    """
    First message the client must send after connecting.

    Example::
        {
            "event": "session_start",
            "source_language": "vi",
            "target_language": "en",
            "speaker": "SPEAKER_A"
        }
    """

    event: Literal["session_start"]
    source_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        description="ISO 639-1 source language code (e.g. 'vi', 'en').",
    )
    target_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        description="ISO 639-1 target language code (e.g. 'en', 'ja').",
    )
    speaker: Speaker = Field(
        default=Speaker.SPEAKER_A,
        description="Active speaker at session start.",
    )


class WsSpeakerChangedEvent(BaseModel):
    """
    Sent by the client to update the active speaker mid-session.

    Example::
        {"event": "speaker_changed", "speaker": "SPEAKER_B"}
    """

    event: Literal["speaker_changed"]
    speaker: Speaker = Field(..., description="New active speaker.")


class WsPingEvent(BaseModel):
    """
    Keepalive ping. Server replies with a pong event.

    Example::
        {"event": "ping"}
    """

    event: Literal["ping"]


class WsEndUtteranceEvent(BaseModel):
    """
    Signals that the client has finished speaking.
    Server flushes the PCM buffer, runs STT, translates, and returns a
    translation_result event.

    Example::
        {"event": "end_utterance"}
    """

    event: Literal["end_utterance"]


class WsSessionEndEvent(BaseModel):
    """
    Graceful session termination from the client.
    Server clears session state and closes the connection with code 1000.

    Example::
        {"event": "session_end"}
    """

    event: Literal["session_end"]


# ==============================================================================
# KNOWN EVENT TYPES (for dispatch)
# ==============================================================================

#: All recognised event names for quick validation before model parsing.
KNOWN_EVENTS = frozenset(
    {
        "session_start",
        "ping",
        "speaker_changed",
        "end_utterance",
        "session_end",
    }
)
