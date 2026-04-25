"""
Translation Service - Business logic with Redis caching
Implements: Check Redis cache → Call API → Store in Redis + DB
"""
import logging
import time
from typing import Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis_client import (
    get_cached_translation,
    set_cached_translation,
    get_redis_client
)
from app.repositories.translation_repository import TranslationRepository
from app.schemas.translation import TranslationRequest, TranslationResponse, TranslationCreateDB
from app.models.translation import Translation

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
                    translated_text = existing.translated_text
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
            # TODO: Replace with actual translation API call
            # This is a placeholder - integrate with Google Translate, DeepL, or your API
            translated_text = await TranslationService._call_translation_api(request)
            
            # ==================== STEP 4: Cache the Result ====================
            
            # 4a. Save to Redis (fast, expires in 1 hour by default)
            await set_cached_translation(
                request.source_text,
                request.source_language,
                request.target_language,
                translated_text
            )
            logger.info(f"💾 Result cached in Redis")
            
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
                    logger.info(f"💾 Result saved to database")
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
    async def _call_translation_api(request: TranslationRequest) -> str:
        """
        Call external translation API.
        
        TODO: Implement with your actual translation service
        (Google Cloud Translation, Azure Translator, DeepL, etc.)
        
        Args:
            request: TranslationRequest
        
        Returns:
            Translated text
        
        Raises:
            Exception: If API call fails
        """
        # Placeholder implementation
        # Replace this with actual API call to your translation engine
        
        # Example: Using Google Cloud Translation
        # from google.cloud import translate_v2
        # client = translate_v2.Client()
        # result = client.translate_text(
        #     request.source_text,
        #     source_language_code=request.source_language,
        #     target_language_code=request.target_language
        # )
        # return result['translatedText']
        
        # For now, return a mock response
        logger.warning("Using mock translation (implement real API)")
        return f"[{request.source_language}→{request.target_language}] {request.source_text}"
    
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
