"""Focused tests for PCM buffering, server-side VAD, and WAV wrapping."""

import io
import struct
import wave

import pytest

from app.core.pcm_buffer import BufferOverflowError, PCMBuffer
from app.services.conversation_pipeline import _wrap_pcm_as_wav


_SAMPLE_RATE = 16000
_WINDOW_SAMPLES = 1600


def _window(sample: int) -> bytes:
    return struct.pack(f"<{_WINDOW_SAMPLES}h", *([sample] * _WINDOW_SAMPLES))


def test_vad_combines_small_chunks_before_scanning():
    buffer = PCMBuffer(
        sample_rate=_SAMPLE_RATE,
        silence_duration_ms=200,
        silence_window_ms=100,
    )
    speech = _window(1000)
    silence = _window(0)

    first = buffer.append_with_vad(speech[:1000])
    second = buffer.append_with_vad(speech[1000:])
    buffer.append_with_vad(silence[:1000])
    buffer.append_with_vad(silence[1000:])
    final = buffer.append_with_vad(silence)

    assert first.has_speech is False
    assert second.has_speech is True
    assert final.should_finalize is True


def test_snapshot_strips_leading_and_trailing_silence_and_preserves_remainder():
    buffer = PCMBuffer(
        sample_rate=_SAMPLE_RATE,
        silence_duration_ms=200,
        silence_window_ms=100,
    )
    speech = _window(1000)
    silence = _window(0)
    next_speech = _window(1200)

    buffer.append_with_vad(silence)
    result = buffer.append_with_vad(speech + silence + silence + next_speech)

    assert result.should_finalize is True
    utterance, remainder = buffer.snapshot_speech()
    assert utterance == speech
    assert remainder == next_speech

    buffer.reset()
    next_result = buffer.append_with_vad(remainder)
    assert next_result.has_speech is True


def test_leading_silence_does_not_accumulate():
    buffer = PCMBuffer(sample_rate=_SAMPLE_RATE, silence_window_ms=100)

    for _ in range(10):
        buffer.append_with_vad(_window(0))

    assert buffer.is_empty
    assert buffer.has_speech is False


def test_buffer_overflow_raises():
    buffer = PCMBuffer(max_size_bytes=4)

    with pytest.raises(BufferOverflowError):
        buffer.append(b"\x00" * 6)


def test_duration_limit_uses_pcm_sample_count():
    buffer = PCMBuffer(sample_rate=_SAMPLE_RATE)
    buffer.append(_window(1000))

    assert buffer.duration_seconds() == pytest.approx(0.1)
    assert buffer.is_over_max_duration(0.05) is True


def test_wrap_pcm_as_wav_builds_valid_mono_s16le_file():
    pcm = _window(1000)
    wav_bytes = _wrap_pcm_as_wav(pcm, _SAMPLE_RATE)

    with wave.open(io.BytesIO(wav_bytes), "rb") as wav_file:
        assert wav_file.getframerate() == _SAMPLE_RATE
        assert wav_file.getnchannels() == 1
        assert wav_file.getsampwidth() == 2
        assert wav_file.readframes(wav_file.getnframes()) == pcm
