"""
Redis-based Static Content Caching Service
Handles caching of static assets, API responses, and frequently accessed data.
"""
import logging
import json
from typing import Optional, Any, List, Dict
from functools import wraps

from redis.asyncio import Redis

logger = logging.getLogger(__name__)


class StaticContentCacheService:
    """Service for caching static content in Redis"""
    
    # Cache key prefixes for organization
    PREFIX_STATIC = "static:"
    PREFIX_API_RESPONSE = "api_response:"
    PREFIX_CONFIG = "config:"
    PREFIX_VOCABULARY = "vocabulary:"
    PREFIX_LANGUAGE_LIST = "languages:"
    
    # Default TTLs
    DEFAULT_TTL_STATIC = 86400 * 7  # 7 days for static assets
    DEFAULT_TTL_API = 3600  # 1 hour for API responses
    DEFAULT_TTL_CONFIG = 86400  # 1 day for configuration
    
    def __init__(self, redis_client: Redis):
        """
        Initialize cache service.
        
        Args:
            redis_client: Redis async client instance
        """
        self.redis = redis_client
        logger.info("✅ Static Content Cache Service initialized")
    
    async def set_cache(
        self,
        key: str,
        value: Any,
        ttl: Optional[int] = None,
        prefix: str = PREFIX_STATIC,
    ) -> bool:
        """
        Set a value in cache.
        
        Args:
            key: Cache key
            value: Value to cache (will be JSON serialized)
            ttl: Time to live in seconds (None = use default)
            prefix: Key prefix for organization
        
        Returns:
            True if successful, False otherwise
        """
        try:
            full_key = f"{prefix}{key}"
            
            # JSON serialize the value
            if isinstance(value, (dict, list)):
                cached_value = json.dumps(value)
            else:
                cached_value = str(value)
            
            # Set in Redis with TTL
            ttl = ttl or self.DEFAULT_TTL_STATIC
            result = await self.redis.setex(full_key, ttl, cached_value)
            
            if result:
                logger.debug(f"📝 Cached: {full_key} (TTL: {ttl}s)")
                return True
            return False
            
        except Exception as e:
            logger.error(f"❌ Cache set failed for {key}: {e}")
            return False
    
    async def get_cache(
        self,
        key: str,
        prefix: str = PREFIX_STATIC,
        deserialize: bool = True,
    ) -> Optional[Any]:
        """
        Get a value from cache.
        
        Args:
            key: Cache key
            prefix: Key prefix for organization
            deserialize: Whether to JSON deserialize the value
        
        Returns:
            Cached value or None if not found
        """
        try:
            full_key = f"{prefix}{key}"
            value = await self.redis.get(full_key)
            
            if value is None:
                logger.debug(f"❌ Cache miss: {full_key}")
                return None
            
            logger.debug(f"✅ Cache hit: {full_key}")
            
            # Try to deserialize JSON
            if deserialize:
                try:
                    return json.loads(value)
                except json.JSONDecodeError:
                    return value
            
            return value
            
        except Exception as e:
            logger.error(f"❌ Cache get failed for {key}: {e}")
            return None
    
    async def delete_cache(self, key: str, prefix: str = PREFIX_STATIC) -> bool:
        """
        Delete a cache entry.
        
        Args:
            key: Cache key
            prefix: Key prefix for organization
        
        Returns:
            True if deleted, False if not found or error
        """
        try:
            full_key = f"{prefix}{key}"
            result = await self.redis.delete(full_key)
            
            if result > 0:
                logger.info(f"🗑️  Deleted cache: {full_key}")
                return True
            return False
            
        except Exception as e:
            logger.error(f"❌ Cache delete failed for {key}: {e}")
            return False
    
    async def clear_cache_by_pattern(self, pattern: str) -> int:
        """
        Delete all cache entries matching a pattern.
        
        Args:
            pattern: Redis key pattern (e.g., "api_response:*")
        
        Returns:
            Number of keys deleted
        """
        try:
            keys = await self.redis.keys(pattern)
            
            if not keys:
                logger.info(f"No keys found for pattern: {pattern}")
                return 0
            
            deleted = await self.redis.delete(*keys)
            logger.info(f"🗑️  Cleared {deleted} cache entries matching: {pattern}")
            return deleted
            
        except Exception as e:
            logger.error(f"❌ Cache clear pattern failed: {e}")
            return 0
    
    async def cache_language_list(self, languages: List[Dict[str, str]]) -> bool:
        """
        Cache the list of supported languages.
        
        Args:
            languages: List of language dictionaries
        
        Returns:
            True if successful
        """
        return await self.set_cache(
            "supported_languages",
            languages,
            ttl=self.DEFAULT_TTL_STATIC,
            prefix=self.PREFIX_LANGUAGE_LIST,
        )
    
    async def get_cached_language_list(self) -> Optional[List[Dict[str, str]]]:
        """Get cached language list"""
        return await self.get_cache(
            "supported_languages",
            prefix=self.PREFIX_LANGUAGE_LIST,
        )
    
    async def cache_vocabulary(self, vocab_id: str, vocab_data: Dict) -> bool:
        """
        Cache vocabulary data.
        
        Args:
            vocab_id: Vocabulary identifier
            vocab_data: Vocabulary dictionary/data
        
        Returns:
            True if successful
        """
        return await self.set_cache(
            vocab_id,
            vocab_data,
            ttl=self.DEFAULT_TTL_STATIC,
            prefix=self.PREFIX_VOCABULARY,
        )
    
    async def get_cached_vocabulary(self, vocab_id: str) -> Optional[Dict]:
        """Get cached vocabulary data"""
        return await self.get_cache(
            vocab_id,
            prefix=self.PREFIX_VOCABULARY,
        )
    
    async def cache_api_response(
        self,
        endpoint: str,
        response_data: Any,
        params_hash: Optional[str] = None,
        ttl: Optional[int] = None,
    ) -> bool:
        """
        Cache API endpoint response.
        
        Args:
            endpoint: API endpoint path
            response_data: Response data to cache
            params_hash: Hash of request parameters (for parameterized endpoints)
            ttl: Custom TTL for this response
        
        Returns:
            True if successful
        """
        cache_key = f"{endpoint}:{params_hash}" if params_hash else endpoint
        ttl = ttl or self.DEFAULT_TTL_API
        
        return await self.set_cache(
            cache_key,
            response_data,
            ttl=ttl,
            prefix=self.PREFIX_API_RESPONSE,
        )
    
    async def get_cached_api_response(
        self,
        endpoint: str,
        params_hash: Optional[str] = None,
    ) -> Optional[Any]:
        """Get cached API response"""
        cache_key = f"{endpoint}:{params_hash}" if params_hash else endpoint
        
        return await self.get_cache(
            cache_key,
            prefix=self.PREFIX_API_RESPONSE,
        )
    
    async def invalidate_api_cache(self, endpoint: str) -> int:
        """
        Invalidate all cached responses for an endpoint.
        
        Args:
            endpoint: API endpoint path
        
        Returns:
            Number of entries invalidated
        """
        pattern = f"{self.PREFIX_API_RESPONSE}{endpoint}:*"
        return await self.clear_cache_by_pattern(pattern)
    
    async def get_cache_stats(self) -> Dict[str, Any]:
        """
        Get cache statistics.
        
        Returns:
            Dictionary with cache stats
        """
        try:
            info = await self.redis.info("memory")
            dbsize = await self.redis.dbsize()
            
            stats = {
                "db_size_entries": dbsize,
                "memory_used_bytes": info.get("used_memory", 0),
                "memory_used_human": info.get("used_memory_human", "N/A"),
                "memory_peak_bytes": info.get("used_memory_peak", 0),
                "memory_peak_human": info.get("used_memory_peak_human", "N/A"),
                "evicted_keys": info.get("evicted_keys", 0),
            }
            
            return stats
            
        except Exception as e:
            logger.error(f"❌ Failed to get cache stats: {e}")
            return {}
    
    async def prefetch_static_content(
        self,
        content_map: Dict[str, Any],
        prefix: str = PREFIX_STATIC,
        ttl: Optional[int] = None,
    ) -> int:
        """
        Prefetch multiple static content items into cache.
        
        Args:
            content_map: Dictionary of {key: value} to cache
            prefix: Key prefix for organization
            ttl: Time to live for all items
        
        Returns:
            Number of items successfully cached
        """
        successful = 0
        ttl = ttl or self.DEFAULT_TTL_STATIC
        
        for key, value in content_map.items():
            if await self.set_cache(key, value, ttl, prefix):
                successful += 1
        
        logger.info(f"✅ Prefetched {successful}/{len(content_map)} items")
        return successful


def cache_response(
    ttl: Optional[int] = None,
    prefix: str = StaticContentCacheService.PREFIX_API_RESPONSE,
):
    """
    Decorator for caching FastAPI endpoint responses.
    
    Args:
        ttl: Cache time to live in seconds
        prefix: Cache key prefix
    
    Usage:
        @cache_response(ttl=3600)
        async def get_languages(cache_service: StaticContentCacheService):
            ...
    """
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract cache_service from dependencies
            cache_service = kwargs.get("cache_service")
            
            if not cache_service:
                # If no cache service available, just call function
                return await func(*args, **kwargs)
            
            # Generate cache key from function name and significant args
            cache_key = f"{func.__name__}"
            
            # Try to get from cache
            cached_value = await cache_service.get_cache(
                cache_key,
                prefix=prefix,
            )
            
            if cached_value is not None:
                logger.debug(f"✅ Returning cached response for {func.__name__}")
                return cached_value
            
            # Call function
            result = await func(*args, **kwargs)
            
            # Cache the result
            await cache_service.set_cache(
                cache_key,
                result,
                ttl=ttl or StaticContentCacheService.DEFAULT_TTL_API,
                prefix=prefix,
            )
            
            return result
        
        return wrapper
    
    return decorator
