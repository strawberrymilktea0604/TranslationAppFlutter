"""
Translation Service - Business logic with Redis caching
Implements: Check Redis cache → Call API → Store in Redis + DB
"""
import logging
import time
from typing import Optional, Tuple, cast
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis_client import (
    get_cached_translation,
    set_cached_translation
)
from app.repositories.translation_repository import TranslationRepository
from app.schemas.translation import TranslationRequest, TranslationCreateDB
from app.models.translation import Translation
from app.services.google_translate_service import GoogleTranslateError, GoogleTranslateService
from app.services.googletrans_fallback_service import (
    GoogleTransFallbackError,
    GoogleTransFallbackService,
)

logger = logging.getLogger(__name__)


class TranslationService:
    """
    Translation service with Redis caching strategy:
    1. Check Redis cache first (< 50ms typically)
    2. If miss: Call external translation API
    3. Cache result in Redis with TTL
    4. Optionally save to database
    """
    
    @staticmethod
    async def translate_with_cache(
        request: TranslationRequest,
        db: AsyncSession,
        user_id: Optional[int] = None,
        save_to_db: bool = True
    ) -> Tuple[str, bool, float]:
        """
        Translate text with caching strategy.
        
        Process:
        1. Check Redis cache first (FAST - < 500ms total including DB save)
        2. If cache hit: return immediately
        3. If cache miss: call translation API
        4. Save to Redis cache + optional DB save
        
        Args:
            request: TranslationRequest with source_text, languages
            db: Database session for saving translations
            user_id: User ID (optional, for tracking translation history)
            save_to_db: Whether to save translation to database (default: True)
        
        Returns:
            Tuple of (translated_text, is_cached, response_time_ms)
        
        Raises:
            ValueError: If languages are not supported
            Exception: If translation API fails
        """
        start_time = time.time()
        is_cached = False
        translated_text = ""
        
        # ==================== STEP 1: Check Redis Cache ====================
        try:
            cached_result = await get_cached_translation(
                request.source_text,
                request.source_language,
                request.target_language
            )
            
            if cached_result:
                is_cached = True
                translated_text = cached_result
                response_time_ms = (time.time() - start_time) * 1000
                logger.info(
                    f"🚀 CACHE HIT returned in {response_time_ms:.2f}ms "
                    f"({request.source_language}→{request.target_language})"
                )
                return translated_text, is_cached, response_time_ms
                
        except Exception as e:
            logger.warning(f"Redis lookup failed: {e}. Continuing with API call.")
        
        # ==================== STEP 2: Check Database (Local Cache) ====================
        if not is_cached and user_id:
            try:
                existing = await TranslationRepository.check_existing_translation(
                    db,
                    user_id,
                    request.source_text,
                    request.source_language,
                    request.target_language
                )
                if existing:
                    translated_text = cast(str, existing.translated_text)
                    is_cached = True
                    response_time_ms = (time.time() - start_time) * 1000
                    
                    # Also cache in Redis for next time
                    await set_cached_translation(
                        request.source_text,
                        request.source_language,
                        request.target_language,
                        translated_text
                    )
                    
                    logger.info(
                        f"📚 DB Cache HIT returned in {response_time_ms:.2f}ms"
                    )
                    return translated_text, is_cached, response_time_ms
                    
            except Exception as e:
                logger.warning(f"Database lookup failed: {e}. Continuing with API call.")
        
        # ==================== STEP 3: Call Translation API ====================
        logger.info(
            f"🔄 Cache MISS - Calling Translation API "
            f"({request.source_language}→{request.target_language})"
        )
        
        try:
            translated_text = await TranslationService._call_translation_api(
                request,
                user_id=user_id,
            )
            
            # ==================== STEP 4: Cache the Result ====================
            
            # 4a. Save to Redis (fast, expires in 1 hour by default)
            await set_cached_translation(
                request.source_text,
                request.source_language,
                request.target_language,
                translated_text
            )
            logger.info("💾 Result cached in Redis")
            
            # 4b. Optionally save to database (for history & analytics)
            if save_to_db and user_id:
                translation_db = TranslationCreateDB(
                    user_id=user_id,
                    source_text=request.source_text,
                    translated_text=translated_text,
                    source_language=request.source_language,
                    target_language=request.target_language,
                    translation_type=request.translation_type
                )
                
                try:
                    await TranslationRepository.create_translation(db, translation_db)
                    logger.info("💾 Result saved to database")
                except Exception as e:
                    logger.warning(f"Failed to save to database: {e}")
            
            response_time_ms = (time.time() - start_time) * 1000
            logger.info(
                f"✅ Translation completed in {response_time_ms:.2f}ms "
                f"(cached: {is_cached})"
            )
            
            return translated_text, is_cached, response_time_ms
            
        except Exception as e:
            response_time_ms = (time.time() - start_time) * 1000
            logger.error(
                f"❌ Translation failed after {response_time_ms:.2f}ms: {e}"
            )
            raise
    
    @staticmethod
    async def _call_translation_api(
        request: TranslationRequest,
        user_id: Optional[int] = None,
    ) -> str:
        """
        Call Google Cloud Translation API v2.
        
        Uses GoogleTranslateService to make real API calls.
        API Key is managed via GOOGLE_CLOUD_API_KEY environment variable.
        
        Args:
            request: TranslationRequest with source_text, source_language, target_language
        
        Returns:
            Translated text string
        
        Raises:
            GoogleTranslateError: If API call fails
            ValueError: If API key is not configured
        """
        try:
            result = await GoogleTranslateService.translate_text(
                text=request.source_text,
                target_language=request.target_language,
                source_language=request.source_language,
                user_id=user_id,
                translation_type=request.translation_type,
            )
            return result["translated_text"]
            
        except GoogleTranslateError as primary_error:
            logger.error(
                f"Google Translate API error: {primary_error.message} "
                f"(code={primary_error.error_code}, status={primary_error.status_code})"
            )

            if (
                settings.TRANSLATION_FALLBACK_ENABLED
                and TranslationService._is_google_service_unavailable(primary_error)
            ):
                logger.warning(
                    "⚠️ Google Cloud Translation unavailable. Falling back to googletrans."
                )
                return await TranslationService._call_googletrans_fallback(
                    request,
                    primary_error,
                    user_id=user_id,
                )

            raise
        except Exception as e:
            logger.error(f"Unexpected error in translation API call: {e}", exc_info=True)

            if settings.TRANSLATION_FALLBACK_ENABLED:
                synthetic_primary_error = GoogleTranslateError(
                    message=f"Unexpected primary translation error: {str(e)}",
                    status_code=503,
                    error_code="UNEXPECTED_ERROR",
                )
                return await TranslationService._call_googletrans_fallback(
                    request,
                    synthetic_primary_error,
                    user_id=user_id,
                )

            raise

    @staticmethod
    def _is_google_service_unavailable(error: GoogleTranslateError) -> bool:
        """Return True if the error indicates Google Cloud API is unavailable."""
        unavailable_error_codes = {
            "API_KEY_NOT_CONFIGURED",
            "API_KEY_INVALID",
            "RATE_LIMIT_EXCEEDED",
            "API_ERROR",
            "TIMEOUT",
            "CONNECTION_ERROR",
            "UNEXPECTED_ERROR",
        }
        return error.error_code in unavailable_error_codes

    @staticmethod
    async def _call_googletrans_fallback(
        request: TranslationRequest,
        primary_error: GoogleTranslateError,
        user_id: Optional[int] = None,
    ) -> str:
        """Call googletrans as fallback provider and map failures consistently."""
        try:
            fallback_result = await GoogleTransFallbackService.translate_text(
                text=request.source_text,
                target_language=request.target_language,
                source_language=request.source_language,
                user_id=user_id,
                translation_type=request.translation_type,
            )
            return fallback_result["translated_text"]
        except GoogleTransFallbackError as fallback_error:
            logger.error(
                "Fallback translation failed after Google Cloud failure: "
                f"primary={primary_error.error_code}, fallback={fallback_error.error_code}"
            )
            raise GoogleTranslateError(
                message=(
                    "Google Cloud Translation and fallback provider are unavailable. "
                    f"Primary: {primary_error.message}. "
                    f"Fallback: {fallback_error.message}."
                ),
                status_code=503,
                error_code="TRANSLATION_SERVICES_UNAVAILABLE",
            ) from fallback_error
    
    @staticmethod
    async def get_user_translations(
        db: AsyncSession,
        user_id: int,
        skip: int = 0,
        limit: int = 50
    ) -> Tuple[list[Translation], int]:
        """
        Get user's translation history.
        
        Args:
            db: Database session
            user_id: User ID
            skip: Pagination offset
            limit: Pagination limit
        
        Returns:
            Tuple of (translations, total_count)
        """
        return await TranslationRepository.get_user_translations(
            db, user_id, skip, limit
        )
    
    @staticmethod
    async def delete_translation(
        db: AsyncSession,
        translation_id: int,
        user_id: int
    ) -> bool:
        """
        Delete a user's translation.
        
        Args:
            db: Database session
            translation_id: Translation ID to delete
            user_id: User ID (for authorization)
        
        Returns:
            True if deleted successfully
        """
        return await TranslationRepository.delete_translation(
            db, translation_id, user_id
        )
    
    @staticmethod
    async def clear_cache() -> bool:
        """
        Clear all translation cache (admin function).
        
        Returns:
            True if successful
        """
        try:
            from app.core.redis_client import invalidate_user_translation_cache
            await invalidate_user_translation_cache(0)  # 0 = all users
            logger.info("✅ All translation cache cleared")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to clear cache: {e}")
            return False
    
    @staticmethod
    async def get_cache_stats() -> dict:
        """
        Get cache performance statistics.
        
        Returns:
            Dictionary with cache stats
        """
        try:
            from app.core.redis_client import get_cache_stats
            stats = await get_cache_stats()
            return stats
        except Exception as e:
            logger.error(f"Failed to get cache stats: {e}")
            return {}
    
    @staticmethod
    async def search_translations(
        db: AsyncSession,
        user_id: int,
        search_text: str,
        skip: int = 0,
        limit: int = 50
    ) -> Tuple[list[Translation], int]:
        """
        Search user's translation history.
        
        Args:
            db: Database session
            user_id: User ID
            search_text: Search query
            skip: Pagination offset
            limit: Pagination limit
        
        Returns:
            Tuple of (matching translations, total_count)
        """
        return await TranslationRepository.search_translations(
            db, user_id, search_text, skip, limit
        )
    
    @staticmethod
    async def filter_translations(
        db: AsyncSession,
        user_id: int,
        source_language: str = None,
        target_language: str = None,
        translation_type: str = None,
        skip: int = 0,
        limit: int = 50
    ) -> Tuple[list[Translation], int]:
        """
        Filter user translations by language or type.
        
        Args:
            db: Database session
            user_id: User ID
            source_language: Optional source language
            target_language: Optional target language
            translation_type: Optional translation type (text/voice/image)
            skip: Pagination offset
            limit: Pagination limit
        
        Returns:
            Tuple of (filtered translations, total_count)
        """
        return await TranslationRepository.filter_by_language(
            db, user_id, source_language, target_language, 
            translation_type, skip, limit
        )
    
    @staticmethod
    async def delete_multiple_translations(
        db: AsyncSession,
        user_id: int,
        translation_ids: list[int]
    ) -> int:
        """
        Delete multiple translations.
        
        Args:
            db: Database session
            user_id: User ID (for authorization)
            translation_ids: List of translation IDs to delete
        
        Returns:
            Number of translations deleted
        """
        return await TranslationRepository.delete_multiple_translations(
            db, user_id, translation_ids
        )
