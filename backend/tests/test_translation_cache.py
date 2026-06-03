"""
Test cases for Translation Caching Implementation
Tests the complete cache flow: Redis → API → Database
"""
import pytest
import pytest_asyncio
import asyncio
from unittest.mock import patch
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.redis_client import (
    close_redis,
    get_redis_client,
    get_cached_translation,
    set_cached_translation,
    _generate_cache_key
)
from app.models.base import Base
from app.models.translation import Translation
from app.models.user import User
from app.schemas.translation import TranslationRequest
from app.services.translation_service import TranslationService
from app.repositories.translation_repository import TranslationRepository


@pytest_asyncio.fixture(autouse=True)
async def reset_redis_client():
    """Do not reuse an asyncio Redis client across pytest event loops."""
    await close_redis()
    client = await get_redis_client()
    keys = await client.keys("translation:*")
    if keys:
        await client.delete(*keys)
    yield
    await close_redis()


@pytest_asyncio.fixture
async def db():
    """Create the minimum schema used by translation repository tests."""
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")

    async with engine.begin() as conn:
        await conn.run_sync(
            Base.metadata.create_all,
            tables=[User.__table__, Translation.__table__],
        )

    async_session = sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with async_session() as session:
        session.add(
            User(
                id=1,
                email="translation-cache@example.com",
                password_hash="test-password-hash",
            )
        )
        await session.commit()
        yield session

    await engine.dispose()


class TestCacheKeyGeneration:
    """Test cache key generation and normalization"""
    
    def test_cache_key_format(self):
        """Cache key should have correct format"""
        key = _generate_cache_key("Hello", "en", "vi")
        assert key.startswith("translation:")
        assert "en" in key
        assert "vi" in key
    
    def test_cache_key_normalization(self):
        """Same text with different cases should produce same key"""
        key1 = _generate_cache_key("Hello", "en", "vi")
        key2 = _generate_cache_key("HELLO", "en", "vi")
        key3 = _generate_cache_key("  hello  ", "en", "vi")
        
        # All should be same key after normalization
        assert key1 == key2 == key3
    
    def test_cache_key_different_langs(self):
        """Different language pairs should produce different keys"""
        key1 = _generate_cache_key("Hello", "en", "vi")
        key2 = _generate_cache_key("Hello", "en", "fr")
        
        assert key1 != key2


class TestRedisCache:
    """Test Redis cache operations"""
    
    @pytest.mark.asyncio
    async def test_cache_set_and_get(self):
        """Test setting and retrieving from cache"""
        source_text = "Hello, how are you?"
        translated_text = "Xin chào, bạn khỏe không?"
        
        # Set cache
        success = await set_cached_translation(
            source_text, "en", "vi", translated_text
        )
        assert success is True
        
        # Get from cache
        result = await get_cached_translation(source_text, "en", "vi")
        assert result == translated_text
    
    @pytest.mark.asyncio
    async def test_cache_miss_returns_none(self):
        """Cache miss should return None"""
        result = await get_cached_translation(
            "Non-existent-text-" + str(asyncio.get_event_loop().time()),
            "en", "vi"
        )
        assert result is None
    
    @pytest.mark.asyncio
    async def test_cache_ttl(self):
        """Cache should expire after TTL"""
        source_text = "Test TTL: " + str(asyncio.get_event_loop().time())
        
        # Set cache with 1 second TTL
        await set_cached_translation(
            source_text, "en", "vi", "Kiểm tra TTL",
            ttl_seconds=1
        )
        
        # Should be available immediately
        result1 = await get_cached_translation(source_text, "en", "vi")
        assert result1 is not None
        
        # Wait for expiry
        await asyncio.sleep(1.5)
        
        # Should be expired now
        result2 = await get_cached_translation(source_text, "en", "vi")
        assert result2 is None


class TestTranslationService:
    """Test translation service with caching"""
    
    @pytest.mark.asyncio
    async def test_translate_with_cache_hit(self, db: AsyncSession):
        """Translation should be returned from cache"""
        # Pre-cache a translation
        await set_cached_translation(
            "Test", "en", "vi", "Kiểm tra"
        )
        
        request = TranslationRequest(
            source_text="Test",
            source_language="en",
            target_language="vi"
        )
        
        # Translate - should hit cache
        translated, is_cached, response_time = await TranslationService.translate_with_cache(
            request, db, save_to_db=False
        )
        
        assert translated == "Kiểm tra"
        assert is_cached is True
        assert response_time < 100  # Should be fast (< 100ms)
    
    @pytest.mark.asyncio
    async def test_translate_cache_miss_calls_api(self, db: AsyncSession):
        """Translation should call API on cache miss"""
        request = TranslationRequest(
            source_text="New text to translate",
            source_language="en",
            target_language="vi"
        )
        
        # Mock API call
        with patch.object(
            TranslationService,
            "_call_translation_api",
            return_value={"translated_text": "Văn bản mới để dịch"}
        ):
            translated, is_cached, response_time = await TranslationService.translate_with_cache(
                request, db, save_to_db=False
            )
        
        assert translated == "Văn bản mới để dịch"
        assert is_cached is False
    
    @pytest.mark.asyncio
    async def test_translate_caches_result(self, db: AsyncSession):
        """Translation result should be cached"""
        request = TranslationRequest(
            source_text="Cache this",
            source_language="en",
            target_language="vi"
        )
        
        with patch.object(
            TranslationService,
            "_call_translation_api",
            return_value={"translated_text": "Lưu cái này vào cache"}
        ):
            # First call - cache miss, API called
            translated1, is_cached1, _ = await TranslationService.translate_with_cache(
                request, db, save_to_db=False
            )
            
            # Second call - should hit cache
            translated2, is_cached2, _ = await TranslationService.translate_with_cache(
                request, db, save_to_db=False
            )
        
        assert translated1 == translated2 == "Lưu cái này vào cache"
        assert is_cached1 is False  # First call misses
        assert is_cached2 is True   # Second call hits
    
    @pytest.mark.asyncio
    async def test_translate_saves_to_db(self, db: AsyncSession):
        """Translation should optionally save to database"""
        request = TranslationRequest(
            source_text="Save to database",
            source_language="en",
            target_language="vi"
        )
        
        with patch.object(
            TranslationService,
            "_call_translation_api",
            return_value={"translated_text": "Lưu vào cơ sở dữ liệu"}
        ):
            translated, is_cached, _ = await TranslationService.translate_with_cache(
                request, db, user_id=1, save_to_db=True
            )
        
        # Verify it was saved to DB
        existing = await TranslationRepository.check_existing_translation(
            db, 1, "Save to database", "en", "vi"
        )
        
        assert existing is not None
        assert getattr(existing, "translated_text") == "Lưu vào cơ sở dữ liệu"


    @pytest.mark.asyncio
    async def test_auto_source_language_is_resolved_before_database_save(
        self,
        db: AsyncSession,
    ):
        request = TranslationRequest(
            source_text="Hello",
            source_language="auto",
            target_language="vi",
        )

        with patch.object(
            TranslationService,
            "_call_translation_api",
            return_value={
                "translated_text": "Xin chao",
                "detected_source_language": "en",
            },
        ):
            translated, is_cached, _ = await TranslationService.translate_with_cache(
                request,
                db,
                user_id=1,
                save_to_db=True,
            )

        auto_existing = await TranslationRepository.check_existing_translation(
            db, 1, "Hello", "auto", "vi"
        )
        detected_existing = await TranslationRepository.check_existing_translation(
            db, 1, "Hello", "en", "vi"
        )

        assert translated == "Xin chao"
        assert is_cached is False
        assert request.source_language == "en"
        assert auto_existing is None
        assert detected_existing is not None


class TestTranslationRepository:
    """Test database operations"""
    
    @pytest.mark.asyncio
    async def test_create_translation(self, db: AsyncSession):
        """Create translation in database"""
        from app.schemas.translation import TranslationCreateDB
        
        translation_data = TranslationCreateDB(
            user_id=1,
            source_text="Hello",
            translated_text="Xin chào",
            source_language="en",
            target_language="vi"
        )
        
        translation = await TranslationRepository.create_translation(
            db, translation_data
        )
        
        assert translation.id is not None
        assert getattr(translation, "source_text") == "Hello"
        assert getattr(translation, "translated_text") == "Xin chào"
    
    @pytest.mark.asyncio
    async def test_check_existing_translation(self, db: AsyncSession):
        """Check if translation exists in database"""
        from app.schemas.translation import TranslationCreateDB
        
        # Create one first
        translation_data = TranslationCreateDB(
            user_id=1,
            source_text="Test existing",
            translated_text="Kiểm tra tồn tại",
            source_language="en",
            target_language="vi"
        )
        
        created = await TranslationRepository.create_translation(
            db, translation_data
        )
        
        # Check it exists
        existing = await TranslationRepository.check_existing_translation(
            db, 1, "Test existing", "en", "vi"
        )
        
        assert existing is not None
        assert getattr(existing, "id") == getattr(created, "id")
    
    @pytest.mark.asyncio
    async def test_get_user_translations(self, db: AsyncSession):
        """Get user's translation history"""
        from app.schemas.translation import TranslationCreateDB
        
        # Create multiple translations
        for i in range(3):
            translation_data = TranslationCreateDB(
                user_id=1,
                source_text=f"Text {i}",
                translated_text=f"Văn bản {i}",
                source_language="en",
                target_language="vi"
            )
            await TranslationRepository.create_translation(db, translation_data)
        
        # Get history
        translations, total = await TranslationRepository.get_user_translations(
            db, 1, skip=0, limit=10
        )
        
        assert total >= 3
        assert len(translations) >= 3


class TestCachePerformance:
    """Test cache performance metrics"""
    
    @pytest.mark.asyncio
    async def test_cache_response_time_goal(self):
        """Cache hit should be < 50ms"""
        source_text = "Performance test"
        
        # Pre-cache
        await set_cached_translation(
            source_text, "en", "vi", "Kiểm tra hiệu năng"
        )
        
        # Measure retrieval time
        import time
        start = time.time()
        result = await get_cached_translation(source_text, "en", "vi")
        elapsed_ms = (time.time() - start) * 1000
        
        assert result is not None
        assert elapsed_ms < 50, f"Cache retrieval took {elapsed_ms}ms (target: < 50ms)"


# Integration tests would go here
# These test the entire flow through the API endpoints
