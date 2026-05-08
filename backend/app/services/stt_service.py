import logging
import os
import tempfile
import time
from typing import Optional

from faster_whisper import WhisperModel

logger = logging.getLogger(__name__)

class STTError(Exception):
    """Custom exception for STT related errors"""
    pass

class STTService:
    """
    Speech-to-Text service utilizing faster-whisper.
    Handles singleton model initialization to prevent memory leaks and reloading overhead.
    """
    _model: Optional[WhisperModel] = None
    _model_size = "small"
    _device = "cpu"
    _compute_type = "int8"

    @classmethod
    def _get_model(cls) -> WhisperModel:
        """
        Get or initialize the WhisperModel singleton instance.
        """
        if cls._model is None:
            logger.info(f"🎙️ Initializing faster-whisper model ({cls._model_size}) on {cls._device} with {cls._compute_type}...")
            start_time = time.time()
            try:
                cls._model = WhisperModel(
                    model_size_or_path=cls._model_size,
                    device=cls._device,
                    compute_type=cls._compute_type
                )
                logger.info(f"✅ STT Model initialized in {(time.time() - start_time):.2f}s")
            except Exception as e:
                logger.error(f"❌ Failed to initialize STT model: {e}")
                raise STTError(f"Engine initialization failed: {e}")
        return cls._model

    @classmethod
    async def transcribe_audio(cls, audio_bytes: bytes, language: Optional[str] = None) -> dict:
        """
        Transcribe audio bytes to text.
        
        Args:
            audio_bytes: The audio file content as bytes.
            language: Optional language code (e.g. 'vi', 'en'). If not provided, it will be auto-detected.
            
        Returns:
            dict containing:
                - text: Transcribed text
                - language: Detected or provided language
                - language_probability: Confidence of language detection
        """
        if not audio_bytes:
            raise STTError("Empty audio data provided")

        temp_file_path = None
        try:
            # Create a temporary file to save the audio bytes
            # faster-whisper requires a file path or a binary stream, but file path is safer for various formats
            with tempfile.NamedTemporaryFile(delete=False, suffix=".tmp") as temp_file:
                temp_file.write(audio_bytes)
                temp_file_path = temp_file.name

            model = cls._get_model()
            
            logger.info(f"🎙️ Starting transcription (Language: {language or 'auto'})")
            
            # Run transcription
            # We use word_timestamps=False and beam_size=5 for a good balance of speed and accuracy
            segments, info = model.transcribe(
                temp_file_path, 
                beam_size=5, 
                language=language,
                vad_filter=True, # Helps to remove silences and improve accuracy
            )

            # segments is a generator, so we need to iterate to get the result
            text_parts = []
            for segment in segments:
                text_parts.append(segment.text)
                
            full_text = " ".join([t.strip() for t in text_parts if t.strip()])
            
            result = {
                "text": full_text.strip(),
                "language": info.language,
                "language_probability": info.language_probability
            }
            
            logger.info(f"✅ Transcription complete. Detected language: {info.language} ({info.language_probability:.2f})")
            return result

        except Exception as e:
            logger.exception(f"❌ STT processing error: {e}")
            raise STTError(str(e))
            
        finally:
            # Cleanup temporary file
            if temp_file_path and os.path.exists(temp_file_path):
                try:
                    os.remove(temp_file_path)
                except Exception as e:
                    logger.warning(f"⚠️ Failed to delete temporary audio file {temp_file_path}: {e}")
