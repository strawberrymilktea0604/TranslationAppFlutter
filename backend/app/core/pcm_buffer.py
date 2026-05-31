"""
PCMBuffer: A high-performance, bounded buffer for accumulating raw PCM audio
chunks received over WebSocket before dispatch to the Speech-to-Text service.

Designed for single-session use — one PCMBuffer instance per active WebSocket
connection. The WebSocket Manager is responsible for lifecycle management
(instantiation, reset, and disposal).

Extended with RMS-based Voice Activity Detection (VAD):
- Scans each incoming chunk in fixed-size windows (default 100 ms at 16 kHz).
- Tracks speech onset and trailing silence duration.
- Reports when trailing silence exceeds a configurable threshold, signalling
  end-of-utterance so the pipeline can snapshot and dispatch the audio.
- Strips leading silence and trims trailing silence at snapshot boundaries.
"""

import math
import struct
import time
from dataclasses import dataclass
from typing import Optional


# ==============================================================================
# CUSTOM EXCEPTIONS
# ==============================================================================


class BufferOverflowError(Exception):
    """
    Raised when appending a chunk causes the buffer to exceed its maximum
    allowed size. The WebSocket Manager should catch this to either force an
    immediate STT flush or terminate the connection to prevent RAM exhaustion.
    """

    def __init__(self, current_size: int, max_size: int) -> None:
        self.current_size = current_size
        self.max_size = max_size
        super().__init__(
            f"PCMBuffer overflow: size {current_size} bytes exceeds "
            f"max allowed {max_size} bytes. Flush or disconnect immediately."
        )


# ==============================================================================
# VAD RESULT DATACLASS
# ==============================================================================


@dataclass(frozen=True, slots=True)
class SilenceCheckResult:
    """Result of appending a chunk with silence detection enabled."""

    should_finalize: bool
    """True if trailing silence >= configured threshold after speech."""

    has_speech: bool
    """True if any non-silent audio has been detected in this recording turn."""


# ==============================================================================
# PCM BUFFER
# ==============================================================================


class PCMBuffer:
    """
    A bounded, mutable buffer for accumulating raw PCM audio chunks.

    Uses ``bytearray`` as the underlying storage to enable O(1) in-place
    appends with minimal heap allocations, avoiding the per-chunk object
    overhead of ``List[bytes]``.

    Args:
        max_size_bytes: Maximum allowed buffer capacity in bytes.
                        Defaults to 5 MB (5 * 1024 * 1024).
        sample_rate: Sample rate in Hz (default 16000).
        silence_threshold: Normalised RMS threshold (0..1).  Values below
                           this are considered silence.  Default 0.008.
        silence_duration_ms: Milliseconds of trailing silence required to
                             trigger finalization.  Default 1500.
        silence_window_ms: Size of the RMS scanning window in milliseconds.
                           Default 100.

    Raises:
        BufferOverflowError: If appending a chunk causes the buffer to exceed
                             ``max_size_bytes``.

    Example::

        buffer = PCMBuffer(max_size_bytes=5 * 1024 * 1024)

        # In WebSocket receive loop:
        buffer.append(chunk)

        # When silence is detected (VAD) or buffer is ready:
        audio_data = buffer.get_audio()
        buffer.reset()
    """

    _DEFAULT_MAX_SIZE_BYTES: int = 5 * 1024 * 1024  # 5 MB

    def __init__(
        self,
        max_size_bytes: int = _DEFAULT_MAX_SIZE_BYTES,
        sample_rate: int = 16000,
        silence_threshold: float = 0.008,
        silence_duration_ms: int = 1500,
        silence_window_ms: int = 100,
    ) -> None:
        self._buffer: bytearray = bytearray()
        self._max_size_bytes: int = max_size_bytes
        self.start_time: Optional[float] = None
        self.last_chunk_time: Optional[float] = None

        # VAD parameters
        self._sample_rate: int = sample_rate
        self._silence_threshold: float = silence_threshold
        self._silence_duration_ms: int = silence_duration_ms
        self._silence_window_ms: int = silence_window_ms

        # Derived constants (samples per window, bytes per window)
        # PCM s16le: 2 bytes per sample, mono
        if sample_rate <= 0 or silence_window_ms <= 0:
            raise ValueError("sample_rate and silence_window_ms must be positive")
        if silence_duration_ms <= 0:
            raise ValueError("silence_duration_ms must be positive")

        self._samples_per_window: int = int(sample_rate * silence_window_ms / 1000)
        self._bytes_per_window: int = self._samples_per_window * 2

        # Silence required in number of windows
        self._silence_windows_needed: int = max(
            1, (silence_duration_ms + silence_window_ms - 1) // silence_window_ms
        )

        # VAD state
        self._has_speech: bool = False
        self._speech_start_offset: int = 0  # byte offset of first speech
        self._trailing_silence_windows: int = 0
        self._scan_offset: int = 0
        self._finalize_offset: Optional[int] = None
        self._speech_end_offset: Optional[int] = None

    # --------------------------------------------------------------------------
    # Public API
    # --------------------------------------------------------------------------

    def append(self, chunk: bytes) -> None:
        """
        Appends a raw PCM chunk to the buffer.

        Sets ``start_time`` on the first chunk received in a recording turn.
        Always updates ``last_chunk_time`` to the current wall-clock time.

        Args:
            chunk: Raw PCM audio bytes from the WebSocket frame.

        Raises:
            BufferOverflowError: If the buffer size after appending exceeds
                                 ``max_size_bytes``.
        """
        now: float = time.monotonic()

        # Record the start of this recording turn on the first chunk.
        if self.start_time is None:
            self.start_time = now

        self._buffer.extend(chunk)
        self.last_chunk_time = now

        # Safety guard: fail-fast before the buffer grows unboundedly.
        if len(self._buffer) > self._max_size_bytes:
            raise BufferOverflowError(
                current_size=len(self._buffer),
                max_size=self._max_size_bytes,
            )

    def append_with_vad(self, chunk: bytes) -> SilenceCheckResult:
        """
        Appends a raw PCM chunk and performs RMS-based silence analysis.

        Scans each ``silence_window_ms`` window of the *newly appended* data.
        Updates speech/silence tracking state and returns whether the caller
        should finalize (snapshot the buffer for STT processing).

        Returns:
            SilenceCheckResult indicating whether to finalize and whether
            speech has been detected.
        """
        self.append(chunk)

        # Keep a persistent cursor so small or uneven chunks are combined into
        # complete windows instead of being skipped.
        pos = self._scan_offset
        while pos + self._bytes_per_window <= len(self._buffer):
            window_bytes = self._buffer[pos : pos + self._bytes_per_window]
            rms = _compute_rms_s16le(window_bytes)

            if rms >= self._silence_threshold:
                # Speech detected
                if not self._has_speech:
                    self._has_speech = True
                    self._speech_start_offset = pos
                self._trailing_silence_windows = 0
            else:
                # Silence window
                if self._has_speech:
                    self._trailing_silence_windows += 1
                    if (
                        self._trailing_silence_windows
                        >= self._silence_windows_needed
                    ):
                        self._finalize_offset = pos + self._bytes_per_window
                        self._speech_end_offset = (
                            self._finalize_offset
                            - self._silence_windows_needed * self._bytes_per_window
                        )
                        pos += self._bytes_per_window
                        break

            pos += self._bytes_per_window

        self._scan_offset = pos

        # Discard processed leading silence so a continuously open microphone
        # does not grow the buffer forever before anyone speaks.
        if not self._has_speech and self._scan_offset:
            del self._buffer[: self._scan_offset]
            self._scan_offset = 0
            if not self._buffer:
                self.start_time = None

        should_finalize = self._finalize_offset is not None

        return SilenceCheckResult(
            should_finalize=should_finalize,
            has_speech=self._has_speech,
        )

    def snapshot_speech(self) -> tuple[bytes, bytes]:
        """
        Snapshot the speech portion and return (speech_bytes, leftover_bytes).

        - Strips leading silence (everything before first speech window).
        - Trims trailing silence at the finalization boundary.
        - Returns leftover bytes (anything after trailing silence) which may
          contain the start of a new utterance.

        Call this when ``SilenceCheckResult.should_finalize`` is True.
        After calling, the buffer is reset and leftover is NOT automatically
        re-appended — the caller must handle it.
        """
        if not self._has_speech:
            return b"", bytes(self._buffer)

        speech_start = max(0, self._speech_start_offset)
        speech_end = self._speech_end_offset
        if speech_end is None:
            speech_end = len(self._buffer)
        speech_end = max(speech_start, speech_end)

        speech_bytes = bytes(self._buffer[speech_start:speech_end])

        # Drop the silence windows that closed the utterance, but retain any
        # data after that boundary. It may contain the next utterance.
        leftover_start = self._finalize_offset or len(self._buffer)
        leftover = bytes(self._buffer[leftover_start:])

        return speech_bytes, leftover

    def reset(self) -> None:
        """
        Clears all buffered audio data and resets timing state.

        Uses in-place deletion (``del self._buffer[:]``) to reuse the
        underlying ``bytearray`` allocation, avoiding a new heap allocation
        and reducing GC pressure between recording turns.
        """
        del self._buffer[:]
        self.start_time = None
        self.last_chunk_time = None
        self._has_speech = False
        self._speech_start_offset = 0
        self._trailing_silence_windows = 0
        self._scan_offset = 0
        self._finalize_offset = None
        self._speech_end_offset = None

    def get_audio(self) -> bytes:
        """
        Returns a snapshot of the current buffer as an immutable ``bytes`` object.

        The returned value is safe to pass across thread or async boundaries
        (e.g., to an STT coroutine) without risk of mutation by the WebSocket
        receive loop.

        Returns:
            Immutable copy of all accumulated PCM data.
        """
        return bytes(self._buffer)

    # --------------------------------------------------------------------------
    # Duration / max utterance helpers
    # --------------------------------------------------------------------------

    def duration_seconds(self) -> float:
        """
        Return the current buffer duration in seconds based on sample rate.

        Assumes mono 16-bit PCM (2 bytes per sample).
        """
        if self._sample_rate <= 0:
            return 0.0
        num_samples = len(self._buffer) // 2
        return num_samples / self._sample_rate

    def is_over_max_duration(self, max_seconds: float) -> bool:
        """True if the buffer contains more audio than *max_seconds*."""
        return self.duration_seconds() > max_seconds

    # --------------------------------------------------------------------------
    # VAD / Silence-detection helpers
    # --------------------------------------------------------------------------

    @property
    def has_speech(self) -> bool:
        """True if speech has been detected in the current recording turn."""
        return self._has_speech

    @property
    def has_finalized_speech(self) -> bool:
        """True if the current buffer contains an utterance boundary."""
        return self._finalize_offset is not None

    def duration_since_last_chunk(self) -> float:
        """
        Calculates elapsed seconds since the most recently received chunk.

        Intended as the primary signal for Voice Activity Detection (VAD):
        if this value exceeds a threshold (e.g., 1.5 s), the session manager
        should treat the gap as end-of-utterance and trigger an STT flush.

        Returns:
            Elapsed time in seconds since ``last_chunk_time``, or ``0.0`` if
            no chunk has been received yet.
        """
        if self.last_chunk_time is None:
            return 0.0
        return time.monotonic() - self.last_chunk_time

    # --------------------------------------------------------------------------
    # Diagnostics / repr
    # --------------------------------------------------------------------------

    @property
    def size(self) -> int:
        """Current buffer size in bytes."""
        return len(self._buffer)

    @property
    def is_empty(self) -> bool:
        """Returns True if the buffer contains no audio data."""
        return len(self._buffer) == 0

    def __repr__(self) -> str:
        return (
            f"PCMBuffer("
            f"size={self.size} B, "
            f"max={self._max_size_bytes} B, "
            f"has_audio={not self.is_empty}, "
            f"has_speech={self._has_speech}"
            f")"
        )


# ==============================================================================
# MODULE-LEVEL HELPERS
# ==============================================================================


def _compute_rms_s16le(data: bytes) -> float:
    """
    Compute normalised RMS of signed 16-bit little-endian PCM samples.

    Returns a value in [0.0, 1.0] where 1.0 corresponds to full scale.
    """
    num_samples = len(data) // 2
    if num_samples == 0:
        return 0.0

    # Unpack all samples at once for speed.
    try:
        samples = struct.unpack(f"<{num_samples}h", data[: num_samples * 2])
    except struct.error:
        return 0.0

    sum_sq = sum(s * s for s in samples)
    rms_raw = math.sqrt(sum_sq / num_samples)

    # Normalise to [0, 1]
    return rms_raw / 32768.0
