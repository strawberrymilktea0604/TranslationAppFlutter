"""
PaddleOCR Service - Extract text from images using PaddleOCR
Runs alongside Tesseract OCR as an alternative engine
Optimized for Vietnamese and English text recognition
"""
import logging
import io
import time
import threading
from typing import Optional, Dict, List, Tuple, Any

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)


class PaddleOCRError(Exception):
    """Custom exception for PaddleOCR operations"""
    pass


class PaddleOCRService:
    """
    PaddleOCR Service for extracting text from images.

    Key Advantages over Tesseract:
    - Superior accuracy for Vietnamese & CJK languages
    - Built-in text detection (no need for pre-deskewing)
    - Automatic angle classification & correction
    - Pure Python install (no system binary required)

    Uses singleton pattern to avoid reloading models per request.
    Each language loads its own PaddleOCR instance (~150MB RAM).
    """

    # Thread lock for safe lazy initialization
    _lock = threading.Lock()

    # Cached PaddleOCR instances keyed by language code
    _ocr_instances: Dict[str, Any] = {}

    # ==================== LANGUAGE MAPPING ====================
    # Map app language codes → PaddleOCR lang parameter
    # Priority: Vietnamese (vi) and English (en)
    SUPPORTED_LANGUAGES: Dict[str, str] = {
        'vi': 'vi',           # Vietnamese  ★ Priority
        'en': 'en',           # English     ★ Priority
        'zh': 'ch',           # Chinese Simplified
        'ja': 'japan',        # Japanese
        'ko': 'korean',       # Korean
        'fr': 'fr',           # French
        'de': 'german',       # German
        'es': 'es',           # Spanish
        'pt': 'pt',           # Portuguese
        'ru': 'ru',           # Russian
        'ar': 'ar',           # Arabic
        'th': 'th',           # Thai
    }

    # ==================== ENGINE INITIALIZATION ====================

    @classmethod
    def _get_ocr_engine(cls, lang: str) -> Any:
        """
        Get or create a PaddleOCR instance for the given language.

        Uses double-checked locking for thread safety.
        Model is downloaded on first use and cached in memory.

        Args:
            lang: PaddleOCR language code (e.g. 'vi', 'en', 'ch')

        Returns:
            PaddleOCR instance ready for inference
        """
        if lang in cls._ocr_instances:
            return cls._ocr_instances[lang]

        with cls._lock:
            # Double-check after acquiring lock
            if lang in cls._ocr_instances:
                return cls._ocr_instances[lang]

            try:
                from paddleocr import PaddleOCR

                logger.info(f"🔄 Initializing PaddleOCR engine for lang='{lang}' ...")

                ocr = PaddleOCR(
                    use_angle_cls=True,   # Auto-detect text rotation
                    lang=lang,            # Language model
                    show_log=False,       # Suppress PaddlePaddle logs
                    use_gpu=False,        # CPU mode
                )

                cls._ocr_instances[lang] = ocr
                logger.info(f"✅ PaddleOCR engine ready for lang='{lang}'")
                return ocr

            except ImportError:
                raise PaddleOCRError(
                    "PaddleOCR is not installed. "
                    "Run: pip install paddlepaddle paddleocr"
                )
            except Exception as e:
                raise PaddleOCRError(
                    f"Failed to initialize PaddleOCR for lang='{lang}': {e}"
                ) from e

    # ==================== MAIN EXTRACTION ====================

    @staticmethod
    async def extract_text(
        image_bytes: bytes,
        language: Optional[str] = None,
        preprocess: bool = True,
    ) -> Dict[str, Any]:
        """
        Extract text from image bytes using PaddleOCR.

        Interface is compatible with OCRService.extract_text() so the
        image translation endpoint can switch engines transparently.

        Args:
            image_bytes: Image file content (PNG, JPG, etc.)
            language: App language code (en, vi, fr, etc.). Defaults to 'en'.
            preprocess: Whether to apply preprocessing (PaddleOCR already
                        handles detection/deskew internally, so this only
                        applies extra denoise/contrast if True).

        Returns:
            Dict matching OCRService format:
            {
                "raw_text": "Extracted text",
                "confidence": 92.5,
                "language": "vi",
                "text_regions": [
                    {"text": "...", "confidence": 95, "bbox": {...}}
                ],
                "processing_time_ms": 350.2,
                "image_size": (width, height),
            }

        Raises:
            PaddleOCRError: If OCR processing fails
        """
        start_time = time.time()

        try:
            # ---- Resolve language ----
            safe_lang = str(language) if language else 'en'
            paddle_lang = str(PaddleOCRService.SUPPORTED_LANGUAGES.get(safe_lang, 'en'))
            logger.info(
                f"📸 PaddleOCR: lang={language} → paddle_lang={paddle_lang}"
            )

            # ---- Decode image into numpy array ----
            nparr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if img is None:
                raise PaddleOCRError("Failed to decode image bytes")

            image_height, image_width = img.shape[:2]
            logger.info(
                f"📸 Image decoded: {image_width}x{image_height}"
            )

            # ---- Optional lightweight preprocessing ----
            if preprocess:
                img = PaddleOCRService._light_preprocess(img)

            # ---- Run PaddleOCR ----
            ocr_engine = PaddleOCRService._get_ocr_engine(paddle_lang)
            result = getattr(ocr_engine, 'ocr')(img, cls=True)

            # ---- Parse results ----
            raw_lines: List[str] = []
            confidences: List[float] = []
            text_regions: List[Dict] = []

            # PaddleOCR returns: list[list[  [box, (text, conf)]  ]]
            # result[0] is the page results (single image → index 0)
            page_results = result[0] if result and result[0] else []

            for item in page_results:
                box = item[0]       # [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]
                text = item[1][0]   # recognized text
                conf = item[1][1]   # confidence 0.0-1.0

                if not text or not text.strip():
                    continue

                raw_lines.append(text.strip())
                confidences.append(conf * 100)  # convert to percentage

                # Convert 4-point polygon to bounding rect
                xs = [pt[0] for pt in box]
                ys = [pt[1] for pt in box]
                x_min, x_max = int(min(xs)), int(max(xs))
                y_min, y_max = int(min(ys)), int(max(ys))

                text_regions.append({
                    "text": text.strip(),
                    "confidence": int(conf * 100),
                    "bbox": {
                        "x": x_min,
                        "y": y_min,
                        "width": x_max - x_min,
                        "height": y_max - y_min,
                    },
                })

            # ---- Aggregate ----
            raw_text = "\n".join(raw_lines)
            avg_confidence = (
                sum(confidences) / len(confidences) if confidences else 0.0
            )

            processing_time = (time.time() - start_time) * 1000

            logger.info(
                f"🎯 PaddleOCR completed: {len(raw_text)} chars, "
                f"{len(text_regions)} regions, "
                f"confidence: {avg_confidence:.1f}%, "
                f"time: {processing_time:.1f}ms"
            )

            return {
                "raw_text": raw_text.strip(),
                "confidence": round(avg_confidence, 2),
                "language": paddle_lang,
                "text_regions": text_regions,
                "processing_time_ms": round(processing_time, 2),
                "image_size": (image_width, image_height),
            }

        except PaddleOCRError:
            raise
        except Exception as e:
            error_msg = f"PaddleOCR processing failed: {str(e)}"
            logger.error(f"❌ {error_msg}")
            raise PaddleOCRError(error_msg) from e

    # ==================== PREPROCESSING ====================

    @staticmethod
    def _light_preprocess(img: np.ndarray) -> np.ndarray:
        """
        Lightweight preprocessing before PaddleOCR.

        PaddleOCR already handles text detection, angle classification,
        and deskewing internally. We only apply:
        - Mild denoising (reduces noise without blurring text)
        - Contrast enhancement via CLAHE

        This keeps the image in color (BGR) because PaddleOCR's
        detection model works best with color input.
        """
        try:
            # Convert to LAB color space for CLAHE on luminance only
            lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
            l_channel, a_channel, b_channel = cv2.split(lab)

            # CLAHE on luminance
            clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
            enhanced_l = clahe.apply(l_channel)

            # Merge back
            enhanced_lab = cv2.merge([enhanced_l, a_channel, b_channel])
            enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)

            # Mild denoising (keep details)
            denoised = cv2.fastNlMeansDenoisingColored(
                enhanced_bgr, h=6.0, hColor=6.0, templateWindowSize=7, searchWindowSize=21
            )

            return denoised

        except Exception as e:
            logger.warning(
                f"PaddleOCR preprocessing failed: {e}. Using original image."
            )
            return img

    # ==================== BATCH EXTRACTION ====================

    @staticmethod
    async def batch_extract(
        image_list: List[bytes],
        language: Optional[str] = None,
    ) -> List[Dict]:
        """
        Extract text from multiple images.
        Compatible with OCRService.batch_extract() interface.
        """
        results = []
        for idx, image_bytes in enumerate(image_list):
            try:
                result = await PaddleOCRService.extract_text(
                    image_bytes, language=language
                )
                results.append(result)
            except PaddleOCRError as e:
                logger.error(f"Batch PaddleOCR failed for image {idx}: {e}")
                results.append({"error": str(e)})
        return results

    # ==================== VALIDATION ====================

    @staticmethod
    def validate_image(
        image_bytes: bytes, max_size_mb: int = 10
    ) -> Tuple[bool, str]:
        """
        Validate image before OCR processing.
        Same interface as OCRService.validate_image().
        """
        try:
            if len(image_bytes) > max_size_mb * 1024 * 1024:
                return False, f"Image size exceeds {max_size_mb}MB limit"

            image = Image.open(io.BytesIO(image_bytes))
            image.verify()

            if image.format and image.format.lower() in [
                'png', 'jpg', 'jpeg', 'bmp', 'tiff', 'gif'
            ]:
                return True, "Valid image"
            else:
                return False, f"Unsupported format: {image.format}"

        except Exception as e:
            return False, f"Invalid image: {str(e)}"

    # ==================== HEALTH CHECK ====================

    @classmethod
    def is_available(cls) -> bool:
        """Check if PaddleOCR dependencies are installed."""
        try:
            from paddleocr import PaddleOCR  # noqa: F401
            return True
        except ImportError:
            return False

    @classmethod
    def get_loaded_languages(cls) -> List[str]:
        """Return list of currently loaded language engines."""
        return list(cls._ocr_instances.keys())
