"""
In-memory session state definition for real-time translation.
Used by WebSocket Manager to track and manage active session lifecycles.
"""

import time
import uuid
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, StrictInt


# ==============================================================================
# ENUMS
# ==============================================================================

class Speaker(str, Enum):
    """Speaker roles in a two-way conversation."""
    SPEAKER_A = "SPEAKER_A"
    SPEAKER_B = "SPEAKER_B"


class AudioFormat(str, Enum):
    """Audio formats accepted from the real-time WebSocket client."""
    PCM_S16LE = "pcm_s16le"
    WAV = "wav"
    M4A = "m4a"
    AAC = "aac"
    MP3 = "mp3"
    OGG = "ogg"
    FLAC = "flac"


class SessionStatus(str, Enum):
    """Lifecycle states of a real-time translation session."""
    IDLE = "IDLE"
    RECORDING = "RECORDING"
    PROCESSING = "PROCESSING"
    ENDED = "ENDED"


# ==============================================================================
# SESSION STATE MODEL
# ==============================================================================

class AudioMetadata(BaseModel):
    """Client-provided audio and translation context for a session."""

    sample_rate: StrictInt = Field(..., description="Input audio sample rate in Hz.")
    audio_format: AudioFormat = Field(..., description="Input audio encoding/container.")
    speaker: Speaker = Field(..., description="Current active speaker.")
    source_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        description="ISO 639-1 source language code or 'auto'.",
    )
    target_language: str = Field(
        ...,
        min_length=2,
        max_length=5,
        description="ISO 639-1 target language code.",
    )


class TranslationSession(BaseModel):
    """Represents the complete state of an active real-time translation session."""

    # --------------------------------------------------------------------------
    # Identifiers & Metadata
    # --------------------------------------------------------------------------
    session_id: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="Unique UUID identifying the session.",
    )
    user_id: int = Field(
        ...,
        description="Primary key (BigInteger) from the users table. Ensures type-safety.",
    )

    # --------------------------------------------------------------------------
    # Language Configuration
    # --------------------------------------------------------------------------
    source_language: str = Field(
        ...,
        description="ISO 639-1 source language code (e.g., 'vi', 'en').",
    )
    target_language: str = Field(
        ...,
        description="ISO 639-1 target language code (e.g., 'en', 'ja').",
    )

    # --------------------------------------------------------------------------
    # Dynamic Session State
    # --------------------------------------------------------------------------
    current_speaker: Optional[Speaker] = Field(
        default=None,
        description="Current active speaker. None if undefined.",
    )
    audio_metadata: Optional[AudioMetadata] = Field(
        default=None,
        description="Most recent validated audio metadata from the client.",
    )
    status: SessionStatus = Field(
        default=SessionStatus.IDLE,
        description="Current session lifecycle status.",
    )

    # --------------------------------------------------------------------------
    # Audio Buffer (Optimized via bytearray)
    # --------------------------------------------------------------------------
    # Contiguous mutable buffer minimizes heap allocations and memory fragmentation
    # compared to List[bytes], optimizing continuous chunks from WebSockets.
    audio_buffer: bytearray = Field(
        default_factory=bytearray,
        description="Raw binary audio stream buffer. Cleared in-place after STT processing.",
    )

    # --------------------------------------------------------------------------
    # Timestamps
    # --------------------------------------------------------------------------
    created_at: float = Field(
        default_factory=time.time,
        description="Unix timestamp when the session was initialized.",
    )
    last_active: float = Field(
        default_factory=time.time,
        description="Unix timestamp of the most recent activity. Used for timeout cleanup.",
    )

    # --------------------------------------------------------------------------
    # Pydantic Configuration
    # --------------------------------------------------------------------------
    model_config = {
        "arbitrary_types_allowed": True,
    }

    # ==========================================================================
    # METHODS
    # ==========================================================================

    def mark_active(self) -> None:
        """Updates the last active timestamp to the current time."""
        self.last_active = time.time()

    def clear_buffer(self) -> None:
        """
        Clears the audio buffer contents in-place to avoid new object allocation
        and reduce garbage collection overhead.
        """
        del self.audio_buffer[:]

    def is_idle_timeout(self, timeout_seconds: float = 300.0) -> bool:
        """
        Checks if the session has exceeded the maximum allowed inactivity period.
        
        Args:
            timeout_seconds: Maximum allowed idle duration in seconds. Defaults to 300.0 (5m).
        """
        return (time.time() - self.last_active) > timeout_seconds
