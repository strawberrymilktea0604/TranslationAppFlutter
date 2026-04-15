"""
Redis client for token revocation (blacklist), session management
"""
import logging
from typing import Optional
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
