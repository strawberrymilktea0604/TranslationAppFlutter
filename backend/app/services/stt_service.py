import asyncio
import logging
import os
import tempfile
import time
from typing import Optional

from faster_whisper import WhisperModel

from app.core.config import settings

logger = logging.getLogger(__name__)


class STTError(Exception):
    """Custom exception for STT related errors."""


class STTService:
    """
    Speech-to-Text service utilizing faster-whisper.

    Handles singleton model initialization to prevent memory leaks and repeated
    model loads. Startup preload remains authoritative: if the model cannot be
    loaded, the backend should not report itself as ready.
    """

    _model: Optional[WhisperModel] = None
    _model_size = settings.STT_MODEL_SIZE
    _device = settings.STT_DEVICE
    _compute_type = settings.STT_COMPUTE_TYPE

    @classmethod
    def preload_model(cls) -> None:
        """Preload the model into memory during app startup."""
        cls._get_model()

    @classmethod
    def _get_model(cls) -> WhisperModel:
        """Get or initialize the WhisperModel singleton instance."""
        if cls._model is None:
            download_root = settings.STT_DOWNLOAD_ROOT or None
            logger.info(
                "Initializing faster-whisper model (%s) on %s with %s "
                "(download_root=%s, local_files_only=%s)",
                cls._model_size,
                cls._device,
                cls._compute_type,
                download_root,
                settings.STT_LOCAL_FILES_ONLY,
            )
            start_time = time.time()
            try:
                cls._model = WhisperModel(
                    model_size_or_path=cls._model_size,
                    device=cls._device,
                    compute_type=cls._compute_type,
                    download_root=download_root,
                    local_files_only=settings.STT_LOCAL_FILES_ONLY,
                )
                logger.info(
                    "STT model initialized in %.2fs",
                    time.time() - start_time,
                )
            except Exception as e:
                logger.error("Failed to initialize STT model: %s", e)
                raise STTError(f"Engine initialization failed: {e}") from e
        return cls._model

    @classmethod
    def _run_transcription(
        cls,
        temp_file_path: str,
        language: Optional[str] = None,
    ) -> dict:
        """Run transcription synchronously; callers execute this in a thread."""
        model = cls._get_model()

        logger.info("Starting transcription (language=%s)", language or "auto")

        segments, info = model.transcribe(
            temp_file_path,
            beam_size=5,
            language=language,
            vad_filter=True,
        )

        text_parts = [segment.text for segment in segments]
        full_text = " ".join(t.strip() for t in text_parts if t.strip())

        return {
            "text": full_text.strip(),
            "language": info.language,
            "language_probability": info.language_probability,
        }

    @classmethod
    async def transcribe_audio(
        cls,
        audio_bytes: bytes,
        language: Optional[str] = None,
        file_extension: str = ".tmp",
    ) -> dict:
        """
        Transcribe audio bytes to text.

        Returns a dict containing text, detected language, and confidence.
        """
        if not audio_bytes:
            raise STTError("Empty audio data provided")

        temp_file_path = None
        try:
            suffix = file_extension if file_extension.startswith(".") else f".{file_extension}"
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
                temp_file.write(audio_bytes)
                temp_file_path = temp_file.name

            result = await asyncio.to_thread(
                cls._run_transcription,
                temp_file_path,
                language,
            )

            logger.info(
                "Transcription complete. Detected language: %s (%.2f)",
                result["language"],
                result["language_probability"],
            )
            return result

        except Exception as e:
            logger.exception("STT processing error: %s", e)
            raise STTError(str(e)) from e

        finally:
            if temp_file_path and os.path.exists(temp_file_path):
                try:
                    os.remove(temp_file_path)
                except Exception as e:
                    logger.warning(
                        "Failed to delete temporary audio file %s: %s",
                        temp_file_path,
                        e,
                    )
