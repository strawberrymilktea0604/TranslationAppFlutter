"""
PCMBuffer: A high-performance, bounded buffer for accumulating raw PCM audio
chunks received over WebSocket before dispatch to the Speech-to-Text service.

Designed for single-session use — one PCMBuffer instance per active WebSocket
connection. The WebSocket Manager is responsible for lifecycle management
(instantiation, reset, and disposal).
"""

import time
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

    def __init__(self, max_size_bytes: int = _DEFAULT_MAX_SIZE_BYTES) -> None:
        self._buffer: bytearray = bytearray()
        self._max_size_bytes: int = max_size_bytes
        self.start_time: Optional[float] = None
        self.last_chunk_time: Optional[float] = None

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
    # VAD / Silence-detection helpers
    # --------------------------------------------------------------------------

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
            f"has_audio={not self.is_empty}"
            f")"
        )
