"""
PaddleOCR service for extracting text from images.

The service keeps one PaddleOCR engine per language in memory. When the app
passes a concrete source language, that exact OCR model is used. When the app
passes auto/None, the service tries the app's supported OCR language choices
and selects the best result using OCR confidence plus script-aware heuristics.
"""

import io
import logging
import threading
import time
import unicodedata
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)


class PaddleOCRError(Exception):
    """Custom exception for PaddleOCR operations."""


class PaddleOCRService:
    """PaddleOCR wrapper with language-aware auto detection."""

    _lock = threading.Lock()
    _ocr_instances: Dict[str, Any] = {}

    SUPPORTED_LANGUAGES: Dict[str, str] = {
        "vi": "vi",
        "en": "en",
        "zh": "ch",
        "ja": "japan",
        "ko": "korean",
        "fr": "fr",
        "de": "german",
        "es": "es",
        "pt": "pt",
        "ru": "ru",
        "ar": "ar",
        "th": "th",
    }

    PADDLE_TO_APP_LANGUAGE: Dict[str, str] = {
        paddle_lang: app_lang
        for app_lang, paddle_lang in SUPPORTED_LANGUAGES.items()
    }

    AUTO_CANDIDATE_LANGUAGES: List[str] = [
        "vi",
        "en",
        "zh",
        "ja",
        "ko",
        "fr",
        "de",
        "es",
    ]

    @classmethod
    def _get_ocr_engine(cls, lang: str) -> Any:
        """Get or create a PaddleOCR instance for a PaddleOCR language code."""
        if lang in cls._ocr_instances:
            return cls._ocr_instances[lang]

        with cls._lock:
            if lang in cls._ocr_instances:
                return cls._ocr_instances[lang]

            try:
                import os

                os.environ["KMP_DUPLICATE_LIB_OK"] = "True"
                from paddleocr import PaddleOCR

                logger.info("Initializing PaddleOCR engine for lang=%s", lang)
                ocr = PaddleOCR(
                    use_angle_cls=True,
                    lang=lang,
                    show_log=False,
                    use_gpu=False,
                    enable_mkldnn=False,
                )

                cls._ocr_instances[lang] = ocr
                logger.info("PaddleOCR engine ready for lang=%s", lang)
                return ocr

            except ImportError as exc:
                raise PaddleOCRError(
                    "PaddleOCR is not installed. Run: pip install "
                    "paddlepaddle paddleocr"
                ) from exc
            except Exception as exc:
                raise PaddleOCRError(
                    f"Failed to initialize PaddleOCR for lang='{lang}': {exc}"
                ) from exc

    @staticmethod
    async def extract_text(
        image_bytes: bytes,
        language: Optional[str] = None,
        preprocess: bool = True,
    ) -> Dict[str, Any]:
        """Extract text from image bytes using PaddleOCR."""
        start_time = time.time()

        try:
            nparr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if img is None:
                raise PaddleOCRError("Failed to decode image bytes")

            image_height, image_width = img.shape[:2]
            logger.info(
                "Image decoded for PaddleOCR: %sx%s",
                image_width,
                image_height,
            )

            if preprocess:
                img = PaddleOCRService._light_preprocess(img)

            app_lang = PaddleOCRService._normalize_app_language(language)
            if app_lang is None:
                return PaddleOCRService._extract_text_auto(
                    img=img,
                    image_size=(image_width, image_height),
                    start_time=start_time,
                )

            paddle_lang = PaddleOCRService.SUPPORTED_LANGUAGES.get(app_lang, "en")
            logger.info(
                "PaddleOCR language resolved: requested=%s app=%s paddle=%s",
                language,
                app_lang,
                paddle_lang,
            )

            result = PaddleOCRService._run_ocr(
                img=img,
                app_lang=app_lang,
                paddle_lang=paddle_lang,
                image_size=(image_width, image_height),
                start_time=start_time,
            )
            logger.info(
                "PaddleOCR completed: chars=%d regions=%d confidence=%.1f "
                "time=%.1fms",
                len(result["raw_text"]),
                len(result["text_regions"]),
                result["confidence"],
                result["processing_time_ms"],
            )
            return result

        except PaddleOCRError:
            raise
        except Exception as exc:
            error_msg = f"PaddleOCR processing failed: {exc}"
            logger.error(error_msg)
            raise PaddleOCRError(error_msg) from exc

    @staticmethod
    def _normalize_app_language(language: Optional[str]) -> Optional[str]:
        safe_lang = str(language or "auto").strip().lower()
        if safe_lang in {"", "auto", "detect", "none"}:
            return None
        return (
            safe_lang
            if safe_lang in PaddleOCRService.SUPPORTED_LANGUAGES
            else "en"
        )

    @staticmethod
    def _run_ocr(
        img: np.ndarray,
        app_lang: str,
        paddle_lang: str,
        image_size: Tuple[int, int],
        start_time: float,
    ) -> Dict[str, Any]:
        ocr_engine = PaddleOCRService._get_ocr_engine(paddle_lang)
        result = getattr(ocr_engine, "ocr")(img, cls=True)

        raw_lines: List[str] = []
        confidences: List[float] = []
        text_regions: List[Dict] = []

        page_results = result[0] if result and result[0] else []

        for item in page_results:
            box = item[0]
            text = item[1][0]
            conf = item[1][1]

            if not text or not text.strip():
                continue

            raw_lines.append(text.strip())
            confidences.append(conf * 100)

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

        raw_text = "\n".join(raw_lines).strip()
        avg_confidence = (
            sum(confidences) / len(confidences) if confidences else 0.0
        )
        processing_time = (time.time() - start_time) * 1000

        return {
            "raw_text": raw_text,
            "confidence": round(avg_confidence, 2),
            "language": paddle_lang,
            "source_language": app_lang,
            "detected_source_language": app_lang,
            "text_regions": text_regions,
            "processing_time_ms": round(processing_time, 2),
            "image_size": image_size,
        }

    @staticmethod
    def _extract_text_auto(
        img: np.ndarray,
        image_size: Tuple[int, int],
        start_time: float,
    ) -> Dict[str, Any]:
        candidates: List[Dict[str, Any]] = []

        for app_lang in PaddleOCRService.AUTO_CANDIDATE_LANGUAGES:
            paddle_lang = PaddleOCRService.SUPPORTED_LANGUAGES[app_lang]
            try:
                result = PaddleOCRService._run_ocr(
                    img=img,
                    app_lang=app_lang,
                    paddle_lang=paddle_lang,
                    image_size=image_size,
                    start_time=start_time,
                )
            except PaddleOCRError:
                raise
            except Exception as exc:
                logger.warning(
                    "PaddleOCR auto candidate failed: lang=%s error=%s",
                    app_lang,
                    exc,
                )
                continue

            result["auto_score"] = PaddleOCRService._score_auto_result(
                result["raw_text"],
                result["confidence"],
                app_lang,
            )
            candidates.append(result)

        if not candidates:
            raise PaddleOCRError("PaddleOCR auto detection produced no candidates.")

        best = max(candidates, key=lambda item: item["auto_score"])
        logger.info(
            "PaddleOCR auto selected: source=%s paddle_lang=%s score=%.2f",
            best["source_language"],
            best["language"],
            best["auto_score"],
        )
        return best

    @staticmethod
    def _score_auto_result(text: str, confidence: float, app_lang: str) -> float:
        stripped = text.strip()
        if not stripped:
            return -1000.0

        score = float(confidence)
        score += min(len(stripped) / 8.0, 12.0)
        score += min(len(stripped.split()) * 0.8, 8.0)

        if app_lang == "vi":
            if PaddleOCRService._has_vietnamese_diacritic(stripped):
                score += 18.0
            score -= PaddleOCRService._western_umlaut_count(stripped) * 8.0
        elif app_lang == "en":
            score -= PaddleOCRService._western_umlaut_count(stripped) * 6.0
            if PaddleOCRService._has_vietnamese_diacritic(stripped):
                score -= 10.0
        elif app_lang == "zh":
            score += PaddleOCRService._count_cjk(stripped) * 3.0
        elif app_lang == "ja":
            score += PaddleOCRService._count_kana(stripped) * 4.0
            score += PaddleOCRService._count_cjk(stripped) * 1.0
        elif app_lang == "ko":
            score += PaddleOCRService._count_hangul(stripped) * 4.0

        return score

    @staticmethod
    def _has_vietnamese_diacritic(text: str) -> bool:
        for char in text:
            if char in {"\u0110", "\u0111"}:
                return True
            name = unicodedata.name(char, "")
            if (
                "HOOK ABOVE" in name
                or "DOT BELOW" in name
                or "HORN" in name
                or "BREVE" in name
            ):
                return True
        return False

    @staticmethod
    def _western_umlaut_count(text: str) -> int:
        return sum(1 for char in text if char in "ÄÖÜËÏäöüëï")

    @staticmethod
    def _count_cjk(text: str) -> int:
        return sum(1 for char in text if "\u4e00" <= char <= "\u9fff")

    @staticmethod
    def _count_kana(text: str) -> int:
        return sum(1 for char in text if "\u3040" <= char <= "\u30ff")

    @staticmethod
    def _count_hangul(text: str) -> int:
        return sum(1 for char in text if "\uac00" <= char <= "\ud7af")

    @staticmethod
    def _light_preprocess(img: np.ndarray) -> np.ndarray:
        """Apply lightweight denoising and contrast enhancement."""
        try:
            lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
            l_channel, a_channel, b_channel = cv2.split(lab)

            clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
            enhanced_l = clahe.apply(l_channel)

            enhanced_lab = cv2.merge([enhanced_l, a_channel, b_channel])
            enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)

            return cv2.fastNlMeansDenoisingColored(
                enhanced_bgr,
                h=6.0,
                hColor=6.0,
                templateWindowSize=7,
                searchWindowSize=21,
            )

        except Exception as exc:
            logger.warning(
                "PaddleOCR preprocessing failed: %s. Using original image.",
                exc,
            )
            return img

    @staticmethod
    async def batch_extract(
        image_list: List[bytes],
        language: Optional[str] = None,
    ) -> List[Dict]:
        """Extract text from multiple images."""
        results = []
        for idx, image_bytes in enumerate(image_list):
            try:
                result = await PaddleOCRService.extract_text(
                    image_bytes,
                    language=language,
                )
                results.append(result)
            except PaddleOCRError as exc:
                logger.error("Batch PaddleOCR failed for image %s: %s", idx, exc)
                results.append({"error": str(exc)})
        return results

    @staticmethod
    def validate_image(
        image_bytes: bytes,
        max_size_mb: int = 10,
    ) -> Tuple[bool, str]:
        """Validate image before OCR processing."""
        try:
            if len(image_bytes) > max_size_mb * 1024 * 1024:
                return False, f"Image size exceeds {max_size_mb}MB limit"

            image = Image.open(io.BytesIO(image_bytes))
            image.verify()

            if image.format and image.format.lower() in [
                "png",
                "jpg",
                "jpeg",
                "bmp",
                "tiff",
                "gif",
            ]:
                return True, "Valid image"
            return False, f"Unsupported format: {image.format}"

        except Exception as exc:
            return False, f"Invalid image: {exc}"

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
        """Return loaded PaddleOCR language engines."""
        return list(cls._ocr_instances.keys())
