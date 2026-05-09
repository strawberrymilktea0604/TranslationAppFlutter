"""
Test file for Audio Preprocessing and Voice Translation API
"""
import pytest
import asyncio
from io import BytesIO
import os
import sys
from pathlib import Path

# Add backend to path
backend_path = Path(__file__).parent.parent
sys.path.insert(0, str(backend_path))

from app.services.audio_preprocessing_service import (
    AudioPreprocessingService,
    AudioPreprocessingError,
)

# Try importing optional dependencies
try:
    import librosa
    import numpy as np
    import soundfile as sf
    AUDIO_DEPS_AVAILABLE = True
except ImportError:
    AUDIO_DEPS_AVAILABLE = False
    print("⚠️ Audio dependencies not installed. Install with: pip install librosa soundfile scipy")


class TestAudioPreprocessing:
    """Test suite for audio preprocessing service"""

    @classmethod
    def setup_class(cls):
        """Setup test fixtures"""
        if not AUDIO_DEPS_AVAILABLE:
            pytest.skip("Audio dependencies not available")

    @staticmethod
    def _create_test_audio_wav(duration: float = 1.0, sr: int = 48000) -> bytes:
        """
        Create a test WAV audio file (sine wave)
        
        Args:
            duration: Duration in seconds
            sr: Sample rate
            
        Returns:
            WAV file as bytes
        """
        if not AUDIO_DEPS_AVAILABLE:
            raise RuntimeError("Audio dependencies required")
            
        # Create a 440Hz sine wave (musical note A)
        t = np.linspace(0, duration, int(sr * duration))
        signal = 0.3 * np.sin(2 * np.pi * 440 * t)
        
        # Save to bytes buffer
        buffer = BytesIO()
        sf.write(buffer, signal, sr, format='WAV')
        return buffer.getvalue()

    @staticmethod
    def _create_test_audio_mp3(duration: float = 1.0) -> bytes:
        """
        Create a simple MP3-like audio for testing
        In practice, this would need pydub or similar
        """
        # For testing, we'll use WAV as MP3 - librosa will auto-detect
        return TestAudioPreprocessing._create_test_audio_wav(duration)

    def test_audio_validation_valid_file(self):
        """Test validation of a valid audio file"""
        if not AUDIO_DEPS_AVAILABLE:
            pytest.skip("Audio dependencies not available")
            
        audio_bytes = self._create_test_audio_wav(duration=2.0, sr=44100)
        
        validation = AudioPreprocessingService.validate_audio_file(
            audio_bytes=audio_bytes,
            content_type="audio/wav",
            filename="test.wav"
        )
        
        assert validation["valid"] is True
        assert validation["original_sample_rate"] == 44100
        assert validation["channels"] == 1
        assert abs(validation["duration_seconds"] - 2.0) < 0.1  # Allow small tolerance
        assert validation["file_size_mb"] > 0

    def test_audio_validation_empty_file(self):
        """Test validation of empty audio file"""
        if not AUDIO_DEPS_AVAILABLE:
            pytest.skip("Audio dependencies not available")
            
        with pytest.raises(AudioPreprocessingError, match="Empty audio file"):
            AudioPreprocessingService.validate_audio_file(
                audio_bytes=b"",
                content_type="audio/wav"
            )

    def test_audio_validation_file_too_large(self):
        """Test validation of file exceeding size limit"""
        if not AUDIO_DEPS_AVAILABLE:
            pytest.skip("Audio dependencies not available")
            
        # Create a file larger than max size (this is a fake test)
        oversized_bytes = b"x" * (26 * 1024 * 1024)  # 26MB
        
        with pytest.raises(AudioPreprocessingError, match="too large"):
            AudioPreprocessingService.validate_audio_file(
                audio_bytes=oversized_bytes,
                content_type="audio/wav"
            )

    @pytest.mark.asyncio
    async def test_audio_preprocessing_wav_to_wav(self):
        """Test preprocessing of WAV to standard format"""
        if not AUDIO_DEPS_AVAILABLE:
            pytest.skip("Audio dependencies not available")
            
        audio_bytes = self._create_test_audio_wav(duration=1.0, sr=48000)
        
        preprocessed_bytes, metadata = await AudioPreprocessingService.preprocess_audio(
            audio_bytes=audio_bytes,
            content_type="audio/wav",
            filename="test.wav"
        )
        
        assert metadata["preprocessed"] is True
        assert metadata["target_sample_rate"] == 16000
        assert metadata["target_channels"] == 1
        assert metadata["target_format"] == "WAV"
        assert len(preprocessed_bytes) > 0
        assert metadata["compression_ratio"] > 0

    @pytest.mark.asyncio
    async def test_audio_preprocessing_resample(self):
        """Test resampling from 48kHz to 16kHz"""
        if not AUDIO_DEPS_AVAILABLE:
            pytest.skip("Audio dependencies not available")
            
        # Create audio at 48kHz
        audio_bytes = self._create_test_audio_wav(duration=1.0, sr=48000)
        
        preprocessed_bytes, metadata = await AudioPreprocessingService.preprocess_audio(
            audio_bytes=audio_bytes,
            content_type="audio/wav"
        )
        
        # Check that resampling occurred
        assert metadata["original_sample_rate"] == 48000
        assert metadata["target_sample_rate"] == 16000
        
        # Verify preprocessed audio is valid WAV
        import soundfile as sf
        preprocessed_data, sr = sf.read(BytesIO(preprocessed_bytes))
        assert sr == 16000

    def test_supported_formats(self):
        """Test getting supported audio formats"""
        formats = AudioPreprocessingService.get_supported_formats()
        
        expected_formats = {"MP3", "M4A", "AAC", "WAV", "FLAC", "OGG"}
        assert set(formats).issuperset(expected_formats)

    def test_audio_specs(self):
        """Test getting audio specifications"""
        specs = AudioPreprocessingService.get_audio_specs()
        
        assert specs["sample_rate"] == 16000
        assert specs["channels"] == 1
        assert specs["format"] == "WAV"
        assert specs["max_size_mb"] == 25
        assert specs["max_duration_minutes"] == 30

    def test_file_extension_detection(self):
        """Test file extension detection from content type"""
        # MP3
        ext = AudioPreprocessingService._get_file_extension("audio/mpeg")
        assert ext == ".mp3"
        
        # M4A
        ext = AudioPreprocessingService._get_file_extension("audio/mp4")
        assert ext == ".m4a"
        
        # WAV
        ext = AudioPreprocessingService._get_file_extension("audio/wav")
        assert ext == ".wav"

    def test_file_extension_from_filename(self):
        """Test file extension detection from filename"""
        ext = AudioPreprocessingService._get_file_extension(None, "music.mp3")
        assert ext == ".mp3"
        
        ext = AudioPreprocessingService._get_file_extension(None, "voice.m4a")
        assert ext == ".m4a"

    @pytest.mark.asyncio
    async def test_audio_preprocessing_multichannel_to_mono(self):
        """Test converting stereo to mono"""
        if not AUDIO_DEPS_AVAILABLE:
            pytest.skip("Audio dependencies not available")
            
        # Create stereo audio
        sr = 44100
        duration = 1.0
        t = np.linspace(0, duration, int(sr * duration))
        
        # Left channel: 440Hz sine
        left = 0.3 * np.sin(2 * np.pi * 440 * t)
        # Right channel: 880Hz sine
        right = 0.3 * np.sin(2 * np.pi * 880 * t)
        
        stereo_signal = np.stack([left, right])
        
        # Save to bytes
        buffer = BytesIO()
        sf.write(buffer, stereo_signal.T, sr, format='WAV')
        audio_bytes = buffer.getvalue()
        
        preprocessed_bytes, metadata = await AudioPreprocessingService.preprocess_audio(
            audio_bytes=audio_bytes,
            content_type="audio/wav"
        )
        
        # Verify it's now mono
        assert metadata["original_sample_rate"] == 44100
        assert metadata["channels"] == 2
        assert metadata["target_channels"] == 1
        
        # Load and verify
        preprocessed_data, sr = sf.read(BytesIO(preprocessed_bytes))
        assert len(preprocessed_data.shape) == 1  # Should be 1D (mono)


class TestAudioEndpointIntegration:
    """Integration tests for the audio endpoint"""

    @pytest.mark.asyncio
    async def test_voice_translation_endpoint_request_structure(self):
        """Test the structure of a voice translation endpoint request"""
        # This would test the actual endpoint in integration tests
        # Example structure:
        endpoint = "/api/v1/audio/translate/voice"
        
        # Expected form data:
        form_data = {
            "source_language": "vi",  # Optional
            "target_language": "en",  # Required
            "file": "audio_file.mp3",  # Required
        }
        
        assert "source_language" in form_data
        assert "target_language" in form_data
        assert "file" in form_data


def run_quick_test():
    """Quick test to verify audio preprocessing works"""
    if not AUDIO_DEPS_AVAILABLE:
        print("⚠️ Audio dependencies not available. Installing...")
        os.system("pip install librosa soundfile scipy")
        return

    print("🎵 Running quick audio preprocessing test...")
    
    # Create test audio
    test_audio = TestAudioPreprocessing._create_test_audio_wav(duration=1.0, sr=48000)
    print(f"✅ Created test audio: {len(test_audio)} bytes at 48kHz")
    
    # Validate
    validation = AudioPreprocessingService.validate_audio_file(test_audio, "audio/wav", "test.wav")
    print(f"✅ Validation passed: {validation}")
    
    # Preprocess
    async def preprocess():
        preprocessed, metadata = await AudioPreprocessingService.preprocess_audio(
            test_audio, "audio/wav", "test.wav"
        )
        print(f"✅ Preprocessing complete:")
        print(f"   Original: {metadata['original_sample_rate']}Hz, {metadata['channels']} channels")
        print(f"   Target: {metadata['target_sample_rate']}Hz, {metadata['target_channels']} channels")
        print(f"   Size: {len(test_audio)} bytes → {len(preprocessed)} bytes ({metadata['compression_ratio']:.2f}x)")
    
    asyncio.run(preprocess())


if __name__ == "__main__":
    # Run quick test
    run_quick_test()
