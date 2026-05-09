"""
Audio Preprocessing Service
Handles audio file validation and conversion to standard format (WAV 16kHz mono)
Supports: MP3, M4A, AAC, FLAC, OGG, WAV
"""
import logging
import os
import tempfile
from typing import Tuple, Optional
import io

import librosa
import soundfile as sf

logger = logging.getLogger(__name__)

# Supported audio formats
SUPPORTED_AUDIO_FORMATS = {
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/mp4": ".m4a",
    "audio/x-m4a": ".m4a",
    "audio/aac": ".aac",
    "audio/x-aac": ".aac",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/flac": ".flac",
    "audio/x-flac": ".flac",
    "audio/ogg": ".ogg",
    "audio/x-ogg": ".ogg",
    "audio/vorbis": ".ogg",
    # File extensions (fallback)
}

# Target audio specifications
TARGET_SAMPLE_RATE = 16000  # 16 kHz
TARGET_CHANNELS = 1  # Mono
TARGET_FORMAT = "WAV"
MAX_AUDIO_SIZE_MB = 25  # 25 MB max file size
MAX_AUDIO_DURATION_MINUTES = 30  # 30 minutes max


class AudioPreprocessingError(Exception):
    """Custom exception for audio preprocessing errors"""
    pass


class AudioPreprocessingService:
    """Service for audio file validation and preprocessing"""

    @staticmethod
    def _get_file_extension(content_type: Optional[str], filename: Optional[str] = None) -> str:
        """
        Get file extension from content type or filename
        
        Args:
            content_type: MIME type (e.g., 'audio/mp3')
            filename: Original filename
            
        Returns:
            File extension (e.g., '.mp3')
        """
        if content_type and content_type in SUPPORTED_AUDIO_FORMATS:
            return SUPPORTED_AUDIO_FORMATS[content_type]
        
        if filename:
            _, ext = os.path.splitext(filename.lower())
            if ext in [".mp3", ".m4a", ".aac", ".wav", ".flac", ".ogg"]:
                return ext
        
        # Default to WAV if unable to determine
        return ".wav"

    @staticmethod
    def validate_audio_file(
        audio_bytes: bytes,
        content_type: Optional[str] = None,
        filename: Optional[str] = None,
    ) -> dict:
        """
        Validate audio file and get metadata
        
        Args:
            audio_bytes: Raw audio file bytes
            content_type: MIME type
            filename: Original filename
            
        Returns:
            dict with validation status and metadata
            
        Raises:
            AudioPreprocessingError: If file is invalid
        """
        # Check file size
        file_size_mb = len(audio_bytes) / (1024 * 1024)
        if file_size_mb > MAX_AUDIO_SIZE_MB:
            raise AudioPreprocessingError(
                f"Audio file too large ({file_size_mb:.1f}MB > {MAX_AUDIO_SIZE_MB}MB). "
                f"Maximum allowed size is {MAX_AUDIO_SIZE_MB}MB"
            )

        if file_size_mb == 0:
            raise AudioPreprocessingError("Empty audio file")

        # Try to load the audio and get metadata
        temp_file = None
        try:
            # Create temporary file with appropriate extension
            file_ext = AudioPreprocessingService._get_file_extension(content_type, filename)
            
            with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as tmp:
                tmp.write(audio_bytes)
                temp_file = tmp.name

            # Load audio to validate and get metadata
            audio_data, sr = librosa.load(temp_file, sr=None, mono=False)

            # Get duration
            if len(audio_data.shape) == 1:
                # Mono audio
                duration_seconds = len(audio_data) / sr
                channels = 1
            else:
                # Multi-channel audio
                duration_seconds = audio_data.shape[1] / sr
                channels = audio_data.shape[0]

            duration_minutes = duration_seconds / 60

            # Check duration
            if duration_minutes > MAX_AUDIO_DURATION_MINUTES:
                raise AudioPreprocessingError(
                    f"Audio duration too long ({duration_minutes:.1f}min > {MAX_AUDIO_DURATION_MINUTES}min). "
                    f"Maximum allowed duration is {MAX_AUDIO_DURATION_MINUTES} minutes"
                )

            if duration_seconds == 0:
                raise AudioPreprocessingError("Audio file has zero duration")

            return {
                "valid": True,
                "original_sample_rate": sr,
                "channels": channels,
                "duration_seconds": duration_seconds,
                "file_size_mb": file_size_mb,
                "estimated_format": file_ext.lstrip(".").upper(),
            }

        except AudioPreprocessingError:
            raise
        except Exception as e:
            logger.warning(f"⚠️ Audio validation error: {e}")
            raise AudioPreprocessingError(f"Failed to validate audio file: {str(e)}")
        finally:
            # Cleanup temporary file
            if temp_file and os.path.exists(temp_file):
                try:
                    os.remove(temp_file)
                except Exception as e:
                    logger.warning(f"Failed to delete temp file {temp_file}: {e}")

    @staticmethod
    async def preprocess_audio(
        audio_bytes: bytes,
        content_type: Optional[str] = None,
        filename: Optional[str] = None,
    ) -> Tuple[bytes, dict]:
        """
        Preprocess audio file to standard format (WAV 16kHz mono)
        
        Args:
            audio_bytes: Raw audio file bytes
            content_type: MIME type
            filename: Original filename
            
        Returns:
            Tuple of (preprocessed_audio_bytes, metadata_dict)
            
        Raises:
            AudioPreprocessingError: If preprocessing fails
        """
        logger.info(
            f"🎵 Starting audio preprocessing - "
            f"Size: {len(audio_bytes)/1024:.1f}KB, "
            f"Format: {content_type or 'unknown'}"
        )

        temp_file = None
        try:
            # Validate audio first
            validation_result = AudioPreprocessingService.validate_audio_file(
                audio_bytes, content_type, filename
            )
            logger.info(f"✅ Audio validation passed: {validation_result}")

            # Create temporary file with appropriate extension
            file_ext = AudioPreprocessingService._get_file_extension(content_type, filename)
            
            with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as tmp:
                tmp.write(audio_bytes)
                temp_file = tmp.name

            # Load audio
            logger.info(f"📂 Loading audio from {file_ext} format...")
            audio_data, sr = librosa.load(temp_file, sr=None, mono=False)
            logger.info(f"✅ Audio loaded: SR={sr}Hz, Shape={audio_data.shape}")

            # Handle multi-channel audio - convert to mono by averaging
            if len(audio_data.shape) > 1 and audio_data.shape[0] > 1:
                logger.info(f"🔊 Converting {audio_data.shape[0]} channels to mono...")
                audio_data = librosa.to_mono(audio_data)
            elif len(audio_data.shape) > 1:
                audio_data = audio_data[0]

            # Resample to target sample rate if necessary
            if sr != TARGET_SAMPLE_RATE:
                logger.info(f"⏱️ Resampling from {sr}Hz to {TARGET_SAMPLE_RATE}Hz...")
                audio_data = librosa.resample(audio_data, orig_sr=sr, target_sr=TARGET_SAMPLE_RATE)
            
            # Normalize audio to prevent clipping (limit to [-1, 1])
            if audio_data.max() > 1.0 or audio_data.min() < -1.0:
                logger.info("📊 Normalizing audio level...")
                max_val = max(abs(audio_data.max()), abs(audio_data.min()))
                audio_data = audio_data / max_val

            # Save as WAV format
            output_buffer = io.BytesIO()
            sf.write(output_buffer, audio_data, TARGET_SAMPLE_RATE, format='WAV')
            preprocessed_bytes = output_buffer.getvalue()

            metadata = {
                **validation_result,
                "preprocessed": True,
                "target_sample_rate": TARGET_SAMPLE_RATE,
                "target_channels": TARGET_CHANNELS,
                "target_format": TARGET_FORMAT,
                "preprocessed_size_mb": len(preprocessed_bytes) / (1024 * 1024),
                "compression_ratio": len(audio_bytes) / len(preprocessed_bytes),
            }

            logger.info(
                f"✅ Audio preprocessing complete - "
                f"Original: {len(audio_bytes)/1024:.1f}KB → "
                f"Processed: {len(preprocessed_bytes)/1024:.1f}KB "
                f"({metadata['compression_ratio']:.2f}x compression)"
            )

            return preprocessed_bytes, metadata

        except AudioPreprocessingError:
            raise
        except Exception as e:
            logger.exception(f"❌ Audio preprocessing error: {e}")
            raise AudioPreprocessingError(f"Audio preprocessing failed: {str(e)}")
        finally:
            # Cleanup temporary file
            if temp_file and os.path.exists(temp_file):
                try:
                    os.remove(temp_file)
                except Exception as e:
                    logger.warning(f"Failed to delete temp file {temp_file}: {e}")

    @staticmethod
    def get_supported_formats() -> list:
        """Get list of supported audio formats"""
        formats = set()
        for content_type, ext in SUPPORTED_AUDIO_FORMATS.items():
            if "+" not in content_type:  # Skip complex types
                formats.add(ext.lstrip(".").upper())
        return sorted(list(formats))

    @staticmethod
    def get_audio_specs() -> dict:
        """Get target audio specifications"""
        return {
            "sample_rate": TARGET_SAMPLE_RATE,
            "channels": TARGET_CHANNELS,
            "format": TARGET_FORMAT,
            "max_size_mb": MAX_AUDIO_SIZE_MB,
            "max_duration_minutes": MAX_AUDIO_DURATION_MINUTES,
        }
