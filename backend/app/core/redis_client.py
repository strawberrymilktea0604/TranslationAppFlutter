"""
Redis client for token revocation (blacklist), session management
"""
import logging
import hashlib
from typing import Optional, Dict, Any
from redis.asyncio import Redis, from_url
from app.core.config import settings

logger = logging.getLogger(__name__)

# Global Redis connection
_redis_client: Optional[Redis] = None


async def get_redis_client() -> Redis:
    """
    Get or create Redis client singleton.
    Used for token blacklisting and session management.
    """
    global _redis_client
    
    if _redis_client is None:
        try:
            redis_url = settings.REDIS_URL
            
            _redis_client = await from_url(
                redis_url,
                encoding="utf8",
                decode_responses=True,
                socket_connect_timeout=5,
                socket_keepalive=True,
            )
            # Test connection
            await _redis_client.ping()
            logger.info("✅ Redis connection established")
        except Exception as e:
            logger.error(f"❌ Failed to connect to Redis: {e}")
            # If Redis fails, system still works but without blacklist caching
            # (will fall back to DB checks in dependencies.py)
            _redis_client = None
            raise
    
    return _redis_client


async def close_redis():
    """Close Redis connection"""
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
        logger.info("Redis connection closed")


async def set_revoked_token(jti: str, ttl_seconds: int) -> bool:
    """
    Blacklist a token by its JTI (JWT ID).
    
    Args:
        jti: Unique JWT ID to revoke
        ttl_seconds: Time to live in seconds (should match token expiry)
    
    Returns:
        True if successful, False if Redis unavailable
    """
    try:
        client = await get_redis_client()
        key = f"revoked_token:{jti}"
        # Set with expiry; value is just timestamp for audit
        await client.setex(key, ttl_seconds, "revoked")
        logger.debug(f"Token {jti} added to blacklist (TTL: {ttl_seconds}s)")
        return True
    except Exception as e:
        logger.warning(f"Redis blacklist failed for {jti}: {e}. Will check DB.")
        return False


async def is_token_revoked(jti: str) -> bool:
    """
    Check if a token JTI is blacklisted in Redis.
    
    Args:
        jti: JWT ID to check
    
    Returns:
        True if token is revoked, False if not or Redis unavailable
    """
    try:
        client = await get_redis_client()
        key = f"revoked_token:{jti}"
        result = await client.get(key)
        return result is not None
    except Exception as e:
        logger.warning(f"Redis check failed for {jti}: {e}. Will check DB.")
        return False


async def clear_all_user_tokens(user_id: int) -> bool:
    """
    Revoke all tokens for a specific user (logout all sessions).
    
    Args:
        user_id: User ID whose all sessions should be revoked
    
    Returns:
        True if successful, False if Redis unavailable
    """
    try:
        client = await get_redis_client()
        pattern = f"user_tokens:{user_id}:*"
        # Find all token JTIs for this user
        keys = await client.keys(pattern)
        if keys:
            await client.delete(*keys)
            logger.info(f"Cleared {len(keys)} tokens for user {user_id}")
        return True
    except Exception as e:
        logger.warning(f"Redis batch clear failed for user {user_id}: {e}")
        return False


async def health_check() -> bool:
    """Check if Redis is available"""
    try:
        client = await get_redis_client()
        await client.ping()
        return True
    except Exception:
        return False


# ==================== TRANSLATION CACHING ====================

def _generate_cache_key(source_text: str, source_lang: str, target_lang: str) -> str:
    """
    Generate cache key for translation cache lookup.
    
    Format: translation:{hash}:{source_lang}:{target_lang}
    Uses SHA256 hash of source_text to handle long texts efficiently.
    
    Args:
        source_text: Original text to translate
        source_lang: Source language code (e.g., 'en')
        target_lang: Target language code (e.g., 'vi')
    
    Returns:
        Cache key string
    """
    # Normalize text: strip whitespace, lowercase for consistency
    normalized_text = source_text.strip().lower()
    text_hash = hashlib.sha256(normalized_text.encode('utf-8')).hexdigest()[:16]
    return f"translation:{text_hash}:{source_lang}:{target_lang}"


async def get_cached_translation(
    source_text: str, 
    source_lang: str, 
    target_lang: str
) -> Optional[str]:
    """
    Retrieve cached translation from Redis.
    
    Args:
        source_text: Original text
        source_lang: Source language code
        target_lang: Target language code
    
    Returns:
        Cached translation if found, None otherwise
    """
    if not settings.CACHE_ENABLED:
        return None
    
    try:
        client = await get_redis_client()
        cache_key = _generate_cache_key(source_text, source_lang, target_lang)
        cached_result = await client.get(cache_key)
        
        if cached_result:
            logger.info(f"✅ Cache HIT: {cache_key}")
            return cached_result
        else:
            logger.debug(f"❌ Cache MISS: {cache_key}")
            return None
            
    except Exception as e:
        logger.warning(f"Redis cache retrieval failed: {e}. Proceeding without cache.")
        return None


async def set_cached_translation(
    source_text: str,
    source_lang: str,
    target_lang: str,
    translated_text: str,
    ttl_seconds: Optional[int] = None
) -> bool:
    """
    Store translation result in Redis cache.
    
    Args:
        source_text: Original text
        source_lang: Source language code
        target_lang: Target language code
        translated_text: Translated text result
        ttl_seconds: Time to live (default: from settings.CACHE_TTL_SECONDS)
    
    Returns:
        True if successful, False if cache fails (system continues without cache)
    """
    if not settings.CACHE_ENABLED:
        return False
    
    try:
        client = await get_redis_client()
        cache_key = _generate_cache_key(source_text, source_lang, target_lang)
        ttl = ttl_seconds or settings.CACHE_TTL_SECONDS
        
        # Store with expiry
        await client.setex(cache_key, ttl, translated_text)
        logger.info(f"💾 Cached translation: {cache_key} (TTL: {ttl}s)")
        return True
        
    except Exception as e:
        logger.warning(f"Redis cache storage failed: {e}. Proceeding without cache.")
        return False


async def invalidate_user_translation_cache(user_id: int) -> bool:
    """
    Clear all translation cache entries for a specific user.
    This is useful when user settings change (language preferences, etc).
    
    Args:
        user_id: User ID whose cache should be cleared
    
    Returns:
        True if successful, False if operation fails
    """
    try:
        client = await get_redis_client()
        pattern = "translation:*"
        # Note: This clears ALL translation cache, not user-specific
        # If you need user-specific caching, modify _generate_cache_key to include user_id
        keys = await client.keys(pattern)
        if keys:
            await client.delete(*keys)
            logger.info(f"Cleared {len(keys)} translation cache entries")
        return True
    except Exception as e:
        logger.warning(f"Redis cache invalidation failed: {e}")
        return False


async def get_cache_stats() -> Dict[str, Any]:
    """
    Get translation cache statistics.
    
    Returns:
        Dictionary with cache info (hit rate, count, etc.)
    """
    try:
        client = await get_redis_client()
        pattern = "translation:*"
        keys = await client.keys(pattern)
        
        # Get info from Redis
        info = await client.info("keyspace")
        
        return {
            "translation_cache_count": len(keys),
            "redis_info": info
        }
    except Exception as e:
        logger.warning(f"Failed to get cache stats: {e}")
        return {}
