"""
OCR Service - Extract text from images
Supports dual engines: Tesseract OCR and PaddleOCR
Handles multiple languages and image formats

Engine Selection:
- "tesseract": Classic Tesseract OCR (requires system binary)
- "paddleocr": PaddleOCR by Baidu (pure Python, better for vi/en)
"""
import logging
import io
from typing import Optional, Dict, List, Tuple, Any
from PIL import Image
import pytesseract
import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Valid OCR engine names
VALID_ENGINES = ("tesseract", "paddleocr")
DEFAULT_ENGINE = "paddleocr"


class OCRError(Exception):
    """Custom exception for OCR operations"""
    pass


class OCRService:
    """
    OCR Service for extracting text from images
    
    Supported Engines:
    - Tesseract (pytesseract) — original engine
    - PaddleOCR — recommended for Vietnamese & English
    
    Supported Features:
    - Multiple language support (eng, vie, fra, deu, etc.)
    - Automatic image preprocessing (deskew, denoise)
    - Confidence scoring
    - Language detection
    - Text region extraction with bounding boxes
    """
    
    # Supported languages in Tesseract
    SUPPORTED_LANGUAGES = {
        'en': 'eng',
        'vi': 'vie',
        'fr': 'fra',
        'de': 'deu',
        'es': 'spa',
        'pt': 'por',
        'zh': 'chi_sim',
        'ja': 'jpn',
        'ko': 'kor',
        'ru': 'rus',
        'ar': 'ara',
        'th': 'tha',
    }

    @staticmethod
    async def extract_text(
        image_bytes: bytes,
        language: Optional[str] = None,
        preprocess: bool = True,
        engine: str = DEFAULT_ENGINE,
    ) -> Dict[str, Any]:
        """
        Extract text from image bytes using the selected OCR engine.
        
        Args:
            image_bytes: Image file content (PNG, JPG, etc.)
            language: Language code (en, vi, fr, etc.). Auto-detect if None
            preprocess: Whether to preprocess image for better OCR
            engine: OCR engine to use — "tesseract" or "paddleocr"
        
        Returns:
            Dict containing:
            {
                "raw_text": "Extracted text",
                "confidence": 85.5,
                "language": "eng",
                "text_regions": [...],
                "processing_time_ms": 125.5,
                "image_size": (w, h),
                "ocr_engine": "paddleocr"
            }
        
        Raises:
            OCRError: If image processing or OCR fails
        """
        # Validate engine parameter
        if engine not in VALID_ENGINES:
            raise OCRError(
                f"Invalid OCR engine '{engine}'. "
                f"Valid options: {VALID_ENGINES}"
            )

        # ---- Route to PaddleOCR ----
        if engine == "paddleocr":
            try:
                from app.services.paddle_ocr_service import (
                    PaddleOCRService,
                    PaddleOCRError,
                )

                logger.info("🐉 Using PaddleOCR engine")
                result = await PaddleOCRService.extract_text(
                    image_bytes=image_bytes,
                    language=language,
                    preprocess=preprocess,
                )
                result["ocr_engine"] = "paddleocr"
                return result

            except PaddleOCRError as e:
                raise OCRError(str(e)) from e
            except ImportError:
                logger.warning(
                    "⚠️ PaddleOCR not installed, falling back to Tesseract"
                )
                # Fall through to Tesseract below

        # ---- Tesseract engine (original logic) ----
        import time
        start_time = time.time()

        logger.info("🔤 Using Tesseract OCR engine")
        
        try:
            # Convert bytes to PIL Image
            image = Image.open(io.BytesIO(image_bytes))
            logger.info(f"📸 Image loaded: {image.size} ({image.format})")
            
            # Convert RGBA to RGB if needed
            if image.mode in ('RGBA', 'LA', 'P'):
                image = image.convert('RGB')
            
            # Preprocess if requested
            if preprocess:
                image = OCRService._preprocess_image(image)
                logger.info("✅ Image preprocessing completed")
            
            # Determine language
            lang_code = OCRService.SUPPORTED_LANGUAGES.get(
                language or 'en', 'eng'
            )
            
            # Extract text with confidence
            data = pytesseract.image_to_data(
                image,
                lang=lang_code,
                output_type=pytesseract.Output.DICT
            )
            
            # Process results
            raw_text = pytesseract.image_to_string(image, lang=lang_code)
            
            # Calculate average confidence
            confidences = [
                int(conf) for conf in data['conf']
                if int(conf) > 0
            ]
            avg_confidence = (
                sum(confidences) / len(confidences)
                if confidences else 0
            )
            
            # Extract text regions with bounding boxes
            text_regions = OCRService._extract_regions(data)
            
            processing_time = (time.time() - start_time) * 1000
            
            logger.info(
                f"🎯 Tesseract OCR completed: {len(raw_text)} chars, "
                f"confidence: {avg_confidence:.1f}%, "
                f"time: {processing_time:.1f}ms"
            )
            
            return {
                "raw_text": raw_text.strip(),
                "confidence": round(avg_confidence, 2),
                "language": lang_code,
                "text_regions": text_regions,
                "processing_time_ms": round(processing_time, 2),
                "image_size": image.size,
                "ocr_engine": "tesseract",
            }
            
        except Exception as e:
            error_msg = f"Tesseract OCR processing failed: {str(e)}"
            logger.error(f"❌ {error_msg}")
            raise OCRError(error_msg) from e

    @staticmethod
    def _preprocess_image(image: Image.Image) -> Image.Image:
        """
        Preprocess image for better OCR accuracy.
        
        Techniques:
        - Convert to grayscale
        - Increase contrast
        - Denoise
        - Deskew if needed
        """
        # Convert to numpy array for OpenCV operations
        img_array = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        
        # Convert to grayscale
        gray = cv2.cvtColor(img_array, cv2.COLOR_BGR2GRAY)
        
        # Apply denoising
        denoised = cv2.fastNlMeansDenoising(
            gray,
            h=10,
            templateWindowSize=7,
            searchWindowSize=21
        )
        
        # Increase contrast using CLAHE
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        contrast_enhanced = clahe.apply(denoised)
        
        # Threshold for binary image (helps OCR)
        _, binary = cv2.threshold(
            contrast_enhanced,
            127,
            255,
            cv2.THRESH_BINARY + cv2.THRESH_OTSU
        )
        
        # Deskew (detect and correct rotation)
        deskewed = OCRService._deskew_image(binary)
        
        # Convert back to PIL Image
        return Image.fromarray(deskewed)

    @staticmethod
    def _deskew_image(image: np.ndarray) -> np.ndarray:
        """
        Deskew image by detecting text rotation angle.
        """
        try:
            # Flip (y, x) to (x, y) for cv2.minAreaRect
            coords = np.column_stack(np.where(image > 0)[::-1])
            if len(coords) < 4:
                return image
            
            angle = cv2.minAreaRect(coords)[2]
            
            # Adjust angle to be between -45 and 45 degrees
            if angle < -45:
                angle = 90 + angle
            elif angle > 45:
                angle = angle - 90
            
            # Skip if rotation is minimal
            if abs(angle) < 0.5:
                return image
            
            # Rotate image
            h, w = image.shape[:2]
            center = (float(w // 2), float(h // 2))
            M = cv2.getRotationMatrix2D(center, angle, 1.0).astype(np.float32)
            rotated = cv2.warpAffine(
                image,
                M,
                (w, h),
                flags=cv2.INTER_LINEAR,
                borderMode=cv2.BORDER_CONSTANT,
                borderValue=(255, 255, 255) if len(image.shape) == 3 else (255,),
            )
            return rotated
            
        except Exception as e:
            logger.warning(f"Deskew failed: {e}. Using original image.")
            return image

    @staticmethod
    def _extract_regions(ocr_data: Dict) -> List[Dict]:
        """
        Extract text regions with bounding boxes and confidence.
        """
        regions = []
        for i in range(len(ocr_data['text'])):
            text = ocr_data['text'][i].strip()
            conf = int(ocr_data['conf'][i])
            
            # Skip low confidence or empty text
            if conf < 30 or not text:
                continue
            
            region = {
                "text": text,
                "confidence": conf,
                "bbox": {
                    "x": ocr_data['left'][i],
                    "y": ocr_data['top'][i],
                    "width": ocr_data['width'][i],
                    "height": ocr_data['height'][i],
                }
            }
            regions.append(region)
        
        return regions

    @staticmethod
    async def batch_extract(
        image_list: List[bytes],
        language: Optional[str] = None,
        engine: str = DEFAULT_ENGINE,
    ) -> List[Dict]:
        """
        Extract text from multiple images using the selected engine.
        """
        results = []
        for idx, image_bytes in enumerate(image_list):
            try:
                result = await OCRService.extract_text(
                    image_bytes,
                    language=language,
                    engine=engine,
                )
                results.append(result)
            except OCRError as e:
                logger.error(f"Batch OCR failed for image {idx}: {e}")
                results.append({"error": str(e)})
        
        return results

    @staticmethod
    def validate_image(image_bytes: bytes, max_size_mb: int = 10) -> Tuple[bool, str]:
        """
        Validate image before OCR processing.
        
        Checks:
        - File size
        - Image format
        - Corrupted image
        """
        try:
            # Check file size
            if len(image_bytes) > max_size_mb * 1024 * 1024:
                return False, f"Image size exceeds {max_size_mb}MB limit"
            
            # Try to open image
            image = Image.open(io.BytesIO(image_bytes))
            
            # Check if image is corrupted
            image.verify()
            
            # Check format
            if image.format and image.format.lower() in ['png', 'jpg', 'jpeg', 'bmp', 'tiff', 'gif']:
                return True, "Valid image"
            else:
                return False, f"Unsupported format: {image.format}"
                
        except Exception as e:
            return False, f"Invalid image: {str(e)}"
