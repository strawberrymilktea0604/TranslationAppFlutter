"""
AI API Rate Limiting Service and Middleware

Provides comprehensive rate limiting for AI API endpoints (translation, audio, etc.)
with support for different user types and configurable limits per endpoint.

Usage:
    from app.services.rate_limiter import AIRateLimiter
    
    limiter = AIRateLimiter()
    
    # In endpoint
    await limiter.check_limit(
        identifier="user:123",
        endpoint="translate",
        request_type="text"  # or "audio", "image"
    )
"""

import logging
from datetime import datetime, timezone
from typing import Optional, Dict
from enum import Enum

from app.core.redis_client import get_redis_client
from app.core.config import settings

logger = logging.getLogger(__name__)


class RequestType(str, Enum):
    """Types of requests that need rate limiting"""
    TEXT_TRANSLATION = "text"
    AUDIO_TRANSLATION = "audio"
    IMAGE_TRANSLATION = "image"
    CONVERSATION = "conversation"
    VOCABULARY = "vocabulary"


class UserType(str, Enum):
    """User types for determining rate limits"""
    GUEST = "guest"
    USER = "user"
    ADMIN = "admin"
    PREMIUM = "premium"


class AIRateLimitConfig:
    """
    Rate limiting configuration for different request types and user types.
    All settings are in requests per hour.
    
    Configurable via environment variables:
    - GUEST_MAX_REQUESTS_PER_HOUR: Default 10
    - USER_MAX_REQUESTS_PER_HOUR: Default 100
    - ADMIN_MAX_REQUESTS_PER_HOUR: Default 1000
    - PREMIUM_MAX_REQUESTS_PER_HOUR: Default 500
    """
    
    def __init__(self):
        self.guest_limit = getattr(settings, 'GUEST_MAX_REQUESTS_PER_HOUR', 10)
        self.user_limit = getattr(settings, 'USER_MAX_REQUESTS_PER_HOUR', 100)
        self.admin_limit = getattr(settings, 'ADMIN_MAX_REQUESTS_PER_HOUR', 1000)
        self.premium_limit = getattr(settings, 'PREMIUM_MAX_REQUESTS_PER_HOUR', 500)
        
        # Per-endpoint overrides (in requests per hour)
        self.endpoint_limits = {
            RequestType.TEXT_TRANSLATION: {
                UserType.GUEST: self.guest_limit,
                UserType.USER: self.user_limit,
                UserType.ADMIN: self.admin_limit,
                UserType.PREMIUM: self.premium_limit,
            },
            RequestType.AUDIO_TRANSLATION: {
                UserType.GUEST: max(1, self.guest_limit // 2),  # Audio is more expensive
                UserType.USER: max(20, self.user_limit // 3),
                UserType.ADMIN: self.admin_limit,
                UserType.PREMIUM: self.premium_limit,
            },
            RequestType.IMAGE_TRANSLATION: {
                UserType.GUEST: max(1, self.guest_limit // 3),  # Image is most expensive
                UserType.USER: max(10, self.user_limit // 4),
                UserType.ADMIN: self.admin_limit,
                UserType.PREMIUM: self.premium_limit,
            },
            RequestType.CONVERSATION: {
                UserType.GUEST: 0,  # Not allowed for guests
                UserType.USER: self.user_limit,
                UserType.ADMIN: self.admin_limit,
                UserType.PREMIUM: self.premium_limit,
            },
            RequestType.VOCABULARY: {
                UserType.GUEST: max(5, self.guest_limit),
                UserType.USER: self.user_limit,
                UserType.ADMIN: self.admin_limit,
                UserType.PREMIUM: self.premium_limit,
            },
        }
    
    def get_limit(
        self, 
        request_type: RequestType, 
        user_type: UserType
    ) -> int:
        """Get rate limit for given request type and user type"""
        try:
            return self.endpoint_limits.get(request_type, {}).get(
                user_type, 
                self.guest_limit
            )
        except (KeyError, AttributeError):
            return self.guest_limit


class AIRateLimiter:
    """
    Centralized rate limiter for AI API endpoints.
    
    Features:
    - Redis-based distributed rate limiting
    - Automatic fallback to fail-open if Redis unavailable
    - Per-endpoint and per-user-type configuration
    - Real-time rate limit status tracking
    - Detailed logging for monitoring
    """
    
    def __init__(self):
        self.config = AIRateLimitConfig()
        self.window_seconds = settings.RATE_LIMIT_WINDOW_SECONDS
        self.metrics = {}  # For local monitoring
    
    async def check_limit(
        self,
        identifier: str,  # "guest:IP" or "user:ID" or "admin:ID"
        request_type: RequestType,
        user_type: Optional[UserType] = None,
        cost: int = 1,  # Quota cost (some requests cost more)
    ) -> Dict:
        """
        Check if request is allowed under rate limit.
        
        Args:
            identifier: Unique identifier for rate limiting (IP for guest, user_id for user)
            request_type: Type of request (text/audio/image/etc)
            user_type: Type of user (guest/user/admin/premium) - inferred from identifier if None
            cost: Cost of the request (1 = 1 request, some may cost more)
        
        Returns:
            {
                "allowed": bool,
                "requests_used": int,
                "requests_remaining": int,
                "requests_limit": int,
                "reset_at": ISO-8601 timestamp,
                "reset_in_seconds": int,
                "error": Optional[str]
            }
        """
        try:
            # Determine user type from identifier if not provided
            if user_type is None:
                user_type = self._parse_user_type(identifier)
            
            # Get rate limit for this request type and user type
            max_requests = self.config.get_limit(request_type, user_type)
            
            # If limit is 0, reject immediately (e.g., guests can't use conversation)
            if max_requests == 0:
                logger.warning(
                    f"Rate limit: {user_type.value} not allowed for {request_type.value}"
                )
                return {
                    "allowed": False,
                    "requests_used": max_requests,
                    "requests_remaining": 0,
                    "requests_limit": max_requests,
                    "reset_at": None,
                    "reset_in_seconds": 0,
                    "error": f"Feature not available for {user_type.value} users"
                }
            
            # Check Redis
            redis_client = await get_redis_client()
            rate_key = f"rate_limit:ai:{request_type.value}:{identifier}"
            
            # Get current count
            current_count = await redis_client.get(rate_key)
            current_count = int(current_count or 0)
            
            # Get TTL for reset time
            ttl = await redis_client.ttl(rate_key)
            if ttl == -1:  # Key exists but no TTL
                ttl = self.window_seconds
            elif ttl == -2:  # Key doesn't exist
                ttl = self.window_seconds
            
            # Calculate reset timestamp
            reset_at = datetime.now(timezone.utc).timestamp() + max(ttl, 0)
            
            # Check if limit exceeded
            if current_count + cost > max_requests:
                logger.warning(
                    f"Rate limit exceeded: {identifier} ({request_type.value}) - "
                    f"Used: {current_count}, Limit: {max_requests}, Cost: {cost}"
                )
                return {
                    "allowed": False,
                    "requests_used": current_count,
                    "requests_remaining": max(0, max_requests - current_count),
                    "requests_limit": max_requests,
                    "reset_at": datetime.fromtimestamp(reset_at, tz=timezone.utc).isoformat(),
                    "reset_in_seconds": max(ttl, 0),
                    "error": f"Rate limit exceeded. Retry in {max(ttl, 0)}s"
                }
            
            # Increment counter
            pipe = redis_client.pipeline()
            pipe.incrby(rate_key, cost)
            pipe.expire(rate_key, self.window_seconds)
            await pipe.execute()
            
            # Calculate remaining
            requests_remaining = max_requests - (current_count + cost)
            
            logger.info(
                f"Rate limit: {identifier} ({request_type.value}) - "
                f"Used: {current_count + cost}/{max_requests}, "
                f"Remaining: {requests_remaining}"
            )
            
            return {
                "allowed": True,
                "requests_used": current_count + cost,
                "requests_remaining": requests_remaining,
                "requests_limit": max_requests,
                "reset_at": datetime.fromtimestamp(reset_at, tz=timezone.utc).isoformat(),
                "reset_in_seconds": self.window_seconds,
                "error": None
            }
        
        except Exception as e:
            logger.error(f"Rate limiter check failed: {e}. Allowing request (fail-open).")
            # Fail-open: allow request if Redis is unavailable
            return {
                "allowed": True,
                "requests_used": -1,
                "requests_remaining": -1,
                "requests_limit": -1,
                "reset_at": None,
                "reset_in_seconds": 0,
                "error": "Rate limiter unavailable (Redis down)"
            }
    
    async def reset_user_limit(self, identifier: str, request_type: Optional[RequestType] = None):
        """
        Reset rate limit for a user (useful for testing or admin override).
        
        Args:
            identifier: User identifier (e.g., "user:123")
            request_type: Specific request type to reset, or None to reset all
        """
        try:
            redis_client = await get_redis_client()
            
            if request_type:
                # Reset specific type
                rate_key = f"rate_limit:ai:{request_type.value}:{identifier}"
                await redis_client.delete(rate_key)
                logger.info(f"Reset rate limit: {identifier} ({request_type.value})")
            else:
                # Reset all types for this identifier
                pattern = f"rate_limit:ai:*:{identifier}"
                keys = await redis_client.keys(pattern)
                if keys:
                    await redis_client.delete(*keys)
                    logger.info(f"Reset all rate limits: {identifier}")
        
        except Exception as e:
            logger.error(f"Failed to reset rate limit: {e}")
    
    async def get_status(self, identifier: str) -> Dict:
        """
        Get current rate limit status for a user across all request types.
        
        Returns:
            {
                "identifier": str,
                "user_type": str,
                "status_by_type": {
                    "text": {...},
                    "audio": {...},
                    ...
                }
            }
        """
        try:
            user_type = self._parse_user_type(identifier)
            status = {
                "identifier": identifier,
                "user_type": user_type.value,
                "status_by_type": {}
            }
            
            for req_type in RequestType:
                # Check current usage without incrementing
                status["status_by_type"][req_type.value] = await self.check_limit(
                    identifier=identifier,
                    request_type=req_type,
                    user_type=user_type,
                    cost=0  # Don't increment for status check
                )
            
            return status
        
        except Exception as e:
            logger.error(f"Failed to get rate limit status: {e}")
            return {"error": str(e)}
    
    @staticmethod
    def _parse_user_type(identifier: str) -> UserType:
        """Parse user type from identifier string"""
        if identifier.startswith("guest:"):
            return UserType.GUEST
        elif identifier.startswith("admin:"):
            return UserType.ADMIN
        elif identifier.startswith("premium:"):
            return UserType.PREMIUM
        else:  # "user:" prefix
            return UserType.USER


# Singleton instance
_rate_limiter = None


async def get_rate_limiter() -> AIRateLimiter:
    """Get or create singleton rate limiter instance"""
    global _rate_limiter
    if _rate_limiter is None:
        _rate_limiter = AIRateLimiter()
    return _rate_limiter
