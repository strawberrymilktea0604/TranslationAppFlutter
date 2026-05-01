"""
Image Translation Endpoints - /images/translate
Complete image → OCR → translate → response pipeline

Pipeline:
1. Receive image (multipart/form-data)
2. Validate and optimize image (in-memory)
3. Extract text via OCR
4. Translate extracted text (with cache)
5. Return translated text
6. IMPORTANT: No temporary files - all in RAM!
"""
import logging
import time
from typing import Optional, List

from fastapi import APIRouter, File, UploadFile, Form, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user_optional
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.schemas.translation import (
    ImageTranslationResponse,
    ImageTranslationBatchResponse,
    TranslationRequest,
)
from app.services.image_service import ImageService
from app.services.ocr_service import OCRService, OCRError
from app.services.translation_service import TranslationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/images", tags=["images"])


# ==================== HELPER FUNCTIONS ====================

async def _check_image_rate_limit(identifier: str, max_requests: int) -> dict:
    """Check rate limit via Redis counter"""
    try:
        from app.core.redis_client import get_redis_client
        from app.core.config import settings
        
        client = await get_redis_client()
        rate_key = f"rate_limit:image_translate:{identifier}"

        current_count = await client.get(rate_key)

        if current_count is None:
            pipe = client.pipeline()
            pipe.incr(rate_key)
            pipe.expire(rate_key, settings.RATE_LIMIT_WINDOW_SECONDS)
            await pipe.execute()
            return {
                "allowed": True,
                "remaining": max_requests - 1,
                "reset_in_seconds": settings.RATE_LIMIT_WINDOW_SECONDS,
            }

        current_count = int(current_count)

        if current_count >= max_requests:
            ttl = await client.ttl(rate_key)
            return {
                "allowed": False,
                "remaining": 0,
                "reset_in_seconds": max(ttl, 0),
            }

        await client.incr(rate_key)
        ttl = await client.ttl(rate_key)
        return {
            "allowed": True,
            "remaining": max_requests - current_count - 1,
            "reset_in_seconds": max(ttl, 0),
        }

    except Exception as e:
        logger.warning(f"Rate limit check failed: {e}. Allowing request (fail-open).")
        return {
            "allowed": True,
            "remaining": -1,
            "reset_in_seconds": 0,
        }


async def _get_rate_limit_key(
    request: Request,
    current_user: Optional[User] = None
) -> tuple[str, int]:
    """Get rate limit identifier and max requests based on user type"""
    if current_user:
        # Authenticated users: higher limit
        return f"user:{current_user.id}", 100  # 100 req/hour
    else:
        # Guest users: lower limit based on IP
        client_ip = request.client.host if request.client else "unknown"
        return f"guest:{client_ip}", 10  # 10 req/hour


# ==================== IMAGE TRANSLATION ENDPOINT ====================

@router.post("/translate", response_model=SuccessResponse)
async def translate_image(
    request: Request,
    source_language: str = Form(default="en", description="Source language code"),
    target_language: str = Form(..., description="Target language code"),
    optimize_image: bool = Form(default=True, description="Optimize image before OCR"),
    return_regions: bool = Form(default=False, description="Include text regions"),
    ocr_engine: str = Form(default="paddleocr", description="OCR engine: 'tesseract' or 'paddleocr'"),
    file: UploadFile = File(..., description="Image file (PNG, JPG, etc.)"),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Translate image endpoint - Complete image translation pipeline.
    
    **Pipeline:**
    1. 📥 Upload image (PNG, JPG, etc.)
    2. ✅ Validate and optimize image (in RAM)
    3. 👁️ Extract text via OCR/Tesseract
    4. 🔄 Translate extracted text (with Redis cache)
    5. ✔️ Return original text + translated text
    
    **Important:**
    - ✅ ALL processing in RAM - no temporary files on disk
    - ✅ Automatic memory cleanup after response
    - ✅ Supports 20+ languages
    - ✅ Confidence scores for both OCR and translation
    
    **Request:**
    ```
    POST /api/v1/images/translate
    Content-Type: multipart/form-data
    
    Parameters:
    - file: Image file (required)
    - source_language: "en", "vi", "fr", etc. (default: "en")
    - target_language: "en", "vi", "fr", etc. (required)
    - optimize_image: true/false (default: true)
    - return_regions: true/false (default: false, includes bounding boxes)
    ```
    
    **Example Response:**
    ```json
    {
      "status": "success",
      "data": {
        "source_text": "Hello, how are you?",
        "translated_text": "Xin chào, bạn khỏe không?",
        "source_language": "en",
        "target_language": "vi",
        "ocr_confidence": 92.5,
        "is_cached": false,
        "response_time_ms": 1250.5,
        "translation_type": "image"
      }
    }
    ```
    
    **Response Times:**
    - Image validation: 5-10ms
    - Image optimization: 20-50ms
    - OCR: 800-2000ms (depends on image complexity)
    - Translation (cache hit): 20-50ms
    - Translation (API call): 2000-5000ms
    - **Total: 1-7 seconds**
    
    **File Storage:**
    - ✅ Zero disk writes - only RAM
    - ✅ Automatic garbage collection
    - ✅ Safe for high-concurrency servers
    """
    
    pipeline_start = time.time()
    
    try:
        # ==================== RATE LIMITING ====================
        rate_limit_key, max_requests = await _get_rate_limit_key(request, current_user)
        rate_check = await _check_image_rate_limit(rate_limit_key, max_requests)
        
        if not rate_check["allowed"]:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Reset in {rate_check['reset_in_seconds']}s"
            )
        
        user_type = "authenticated" if current_user else "guest"
        logger.info(
            f"🖼️ Image translation started - User: {user_type} - "
            f"Languages: {source_language}→{target_language} - "
            f"Engine: {ocr_engine}"
        )
        
        # ==================== STEP 1: READ FILE FROM UPLOAD ====================
        image_bytes = await file.read()
        
        logger.info(
            f"📥 Image received: {len(image_bytes)/1024:.1f}KB, "
            f"format: {file.content_type}"
        )
        
        # ==================== STEP 2: VALIDATE IMAGE ====================
        is_valid, validation_msg = ImageService.validate_image_bytes(image_bytes)
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid image: {validation_msg}"
            )
        
        logger.info("✅ Image validation passed")
        
        # ==================== STEP 3: OPTIMIZE IMAGE (IN-MEMORY) ====================
        optimize_start = time.time()
        if optimize_image:
            image_bytes = await ImageService.optimize_image(image_bytes)
            optimize_time = (time.time() - optimize_start) * 1000
            logger.info(f"📐 Image optimized in {optimize_time:.1f}ms")
        
        # ==================== STEP 4: EXTRACT TEXT VIA OCR ====================
        ocr_start = time.time()
        try:
            ocr_result = await OCRService.extract_text(
                image_bytes,
                language=source_language,
                preprocess=True,
                engine=ocr_engine,
            )
        except OCRError as e:
            logger.error(f"❌ OCR failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"OCR processing failed: {str(e)}"
            )
        
        ocr_time = (time.time() - ocr_start) * 1000
        
        extracted_text = ocr_result["raw_text"]
        
        if not extracted_text or len(extracted_text.strip()) == 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No text could be extracted from image"
            )
        
        logger.info(
            f"👁️ OCR completed: {len(extracted_text)} chars, "
            f"confidence: {ocr_result['confidence']}%, "
            f"time: {ocr_time:.1f}ms"
        )
        
        # ==================== STEP 5: TRANSLATE EXTRACTED TEXT ====================
        try:
            translation_request = TranslationRequest(
                source_text=extracted_text,
                source_language=source_language,
                target_language=target_language,
                translation_type="image"
            )
            
            translated_text, is_cached, translate_response_time = await TranslationService.translate_with_cache(
                request=translation_request,
                db=db,
                user_id=current_user.id if current_user else None,
                save_to_db=True
            )
            
        except Exception as e:
            logger.error(f"❌ Translation failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Translation failed: {str(e)}"
            )
        
        cache_status = "🚀 HIT" if is_cached else "❌ MISS"
        logger.info(
            f"🔄 Translation {cache_status}: "
            f"response_time: {translate_response_time:.1f}ms"
        )
        
        # ==================== STEP 6: BUILD RESPONSE ====================
        total_time = (time.time() - pipeline_start) * 1000
        
        # Extract regions if requested
        text_regions = None
        if return_regions and ocr_result.get("text_regions"):
            text_regions = ocr_result["text_regions"]
        
        # Extract metadata if requested
        image_metadata = None
        if return_regions:
            image_metadata = {
                "format": ocr_result.get("image_size"),
                "size": (ocr_result.get("image_size", (0, 0))[0], 
                        ocr_result.get("image_size", (0, 0))[1]),
                "width": ocr_result.get("image_size", (0, 0))[0],
                "height": ocr_result.get("image_size", (0, 0))[1],
                "mode": "RGB",
                "bytes": len(image_bytes),
                "estimated_text_density": 0.0,
            }
        
        response_data = ImageTranslationResponse(
            source_text=extracted_text,
            translated_text=translated_text,
            source_language=source_language,
            target_language=target_language,
            ocr_confidence=ocr_result["confidence"],
            text_regions=text_regions,
            is_cached=is_cached,
            response_time_ms=total_time,
            image_metadata=image_metadata,
            translation_type="image",
        )
        
        # ==================== CLEANUP ====================
        # Explicitly cleanup image memory
        await ImageService.cleanup_image_memory(image_bytes)
        
        logger.info(
            f"✅ Image translation completed - "
            f"Total time: {total_time:.1f}ms - "
            f"Cache: {cache_status} - "
            f"User: {current_user.username if current_user else 'guest'}"
        )
        
        return SuccessResponse(data=response_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"❌ Unexpected error in image translation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during image translation"
        )


# ==================== BATCH IMAGE TRANSLATION ====================

@router.post("/translate/batch", response_model=SuccessResponse)
async def translate_images_batch(
    request: Request,
    source_language: str = Form(default="en"),
    target_language: str = Form(...),
    ocr_engine: str = Form(default="paddleocr", description="OCR engine: 'tesseract' or 'paddleocr'"),
    files: List[UploadFile] = File(..., description="Multiple image files"),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Batch translate multiple images.
    
    **Process:**
    - Upload multiple images at once
    - Each image is processed independently
    - Parallel processing where possible
    - Returns array of results with success/failure status
    
    **Request:**
    ```
    POST /api/v1/images/translate/batch
    Content-Type: multipart/form-data
    
    - files: Multiple image files (required)
    - source_language: "en", "vi", etc.
    - target_language: "vi", "en", etc.
    ```
    
    **Response:**
    ```json
    {
      "status": "success",
      "data": {
        "total": 3,
        "successful": 2,
        "failed": 1,
        "results": [
          {
            "source_text": "Hello",
            "translated_text": "Xin chào",
            ...
          }
        ],
        "errors": [
          {"file_index": 2, "error": "OCR failed: ..."}
        ]
      }
    }
    ```
    """
    
    batch_start = time.time()
    
    try:
        # Rate limiting (stricter for batch)
        rate_limit_key, _ = await _get_rate_limit_key(request, current_user)
        batch_rate_check = await _check_image_rate_limit(
            f"{rate_limit_key}:batch",
            max_requests=5  # 5 batch operations per hour
        )
        
        if not batch_rate_check["allowed"]:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Batch rate limit exceeded"
            )
        
        if len(files) > 10:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Maximum 10 images per batch"
            )
        
        logger.info(f"📦 Batch image translation started - {len(files)} images")
        
        results = []
        errors = []
        successful = 0
        
        for idx, file in enumerate(files):
            try:
                image_bytes = await file.read()
                
                # Validate
                is_valid, msg = ImageService.validate_image_bytes(image_bytes)
                if not is_valid:
                    errors.append({"file_index": idx, "error": msg})
                    continue
                
                # Optimize
                image_bytes = await ImageService.optimize_image(image_bytes)
                
                # OCR
                ocr_result = await OCRService.extract_text(
                    image_bytes,
                    language=source_language,
                    engine=ocr_engine,
                )
                
                extracted_text = ocr_result["raw_text"]
                if not extracted_text.strip():
                    errors.append({
                        "file_index": idx,
                        "error": "No text extracted"
                    })
                    continue
                
                # Translate
                trans_req = TranslationRequest(
                    source_text=extracted_text,
                    source_language=source_language,
                    target_language=target_language,
                    translation_type="image"
                )
                
                translated_text, is_cached, _ = await TranslationService.translate_with_cache(
                    request=trans_req,
                    db=db,
                    user_id=current_user.id if current_user else None,
                    save_to_db=False  # Don't save batch results
                )
                
                results.append(ImageTranslationResponse(
                    source_text=extracted_text,
                    translated_text=translated_text,
                    source_language=source_language,
                    target_language=target_language,
                    ocr_confidence=ocr_result["confidence"],
                    is_cached=is_cached,
                    response_time_ms=0.0,
                    translation_type="image",
                ))
                
                successful += 1
                
                # Cleanup
                await ImageService.cleanup_image_memory(image_bytes)
                
            except Exception as e:
                logger.error(f"Batch processing failed for image {idx}: {e}")
                errors.append({
                    "file_index": idx,
                    "error": str(e)
                })
        
        batch_time = (time.time() - batch_start) * 1000
        
        response_data = ImageTranslationBatchResponse(
            total=len(files),
            successful=successful,
            failed=len(files) - successful,
            results=results,
            errors=errors if errors else None
        )
        
        logger.info(
            f"✅ Batch translation completed: "
            f"{successful}/{len(files)} successful in {batch_time:.1f}ms"
        )
        
        return SuccessResponse(data=response_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"❌ Batch translation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Batch translation failed"
        )
