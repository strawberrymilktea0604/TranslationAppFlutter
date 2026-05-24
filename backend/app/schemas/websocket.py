"""
WebSocket Message Schemas — /api/v1/ws/conversation

Pydantic models for validating inbound client messages on the
real-time voice translation WebSocket endpoint.

Outbound server messages are plain dicts for minimal overhead in
the hot receive loop.
"""

from typing import Literal

from pydantic import (
    AliasChoices,
    BaseModel,
    ConfigDict,
    Field,
    StrictInt,
    field_validator,
)

from app.schemas.realtime_session import AudioFormat, Speaker


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


class WsAudioMetadataEvent(BaseModel):
    """
    Sent by the client after session_start and before binary audio.

    Example::
        {
            "event": "audio_metadata",
            "sample_rate": 44100,
            "audio_format": "pcm_s16le",
            "speaker": "SPEAKER_A",
            "source_language": "vi",
            "target_language": "en"
        }

    Flutter camelCase aliases are accepted for the metadata field names.
    """

    model_config = ConfigDict(populate_by_name=True)

    event: Literal["audio_metadata"]
    sample_rate: StrictInt = Field(
        ...,
        validation_alias=AliasChoices("sample_rate", "sampleRate"),
        description="Input audio sample rate in Hz.",
    )
    audio_format: AudioFormat = Field(
        ...,
        validation_alias=AliasChoices("audio_format", "audioFormat"),
        description="Input audio encoding/container.",
    )
    speaker: Speaker = Field(..., description="Current active speaker.")
    source_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        validation_alias=AliasChoices("source_language", "sourceLanguage"),
        description="ISO 639-1 source language code or 'auto'.",
    )
    target_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        validation_alias=AliasChoices("target_language", "targetLanguage"),
        description="ISO 639-1 target language code.",
    )

    @field_validator("sample_rate")
    @classmethod
    def validate_sample_rate(cls, value: int) -> int:
        allowed = {8000, 16000, 22050, 24000, 32000, 44100, 48000}
        if value not in allowed:
            raise ValueError(
                "sample_rate must be one of: "
                "8000, 16000, 22050, 24000, 32000, 44100, 48000"
            )
        return value

    @field_validator("audio_format", mode="before")
    @classmethod
    def normalize_audio_format(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip().lower()
        return value

    @field_validator("source_language", "target_language", mode="before")
    @classmethod
    def normalize_language(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip().lower()
        return value


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
        "audio_metadata",
        "ping",
        "speaker_changed",
        "end_utterance",
        "session_end",
    }
)
