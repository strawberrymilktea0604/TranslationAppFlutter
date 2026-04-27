"""
Token service: handles token lifecycle (creation, refresh, revocation).
Encapsulates business logic for token management separate from HTTP layer.
"""
import logging
from datetime import datetime, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from fastapi import HTTPException, status

from app.models.user import User, UserToken
from app.core import security
from app.core.config import settings
from app.core.redis_client import set_revoked_token, is_token_revoked

logger = logging.getLogger(__name__)


async def create_tokens_for_user(user: User) -> dict:
    """
    Generate access token and refresh token for a user, store refresh token in DB.
    
    Args:
        user: User object
        
    Returns:
        Dict with access_token, refresh_token, expires_in, token_type
    """
    # Generate access token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token, access_jti = security.create_access_token(
        data={"sub": str(user.id)},
        expires_delta=access_token_expires
    )
    
    # Generate refresh token
    refresh_token_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_token, refresh_jti = security.create_refresh_token(
        data={"sub": str(user.id)},
        expires_delta=refresh_token_expires
    )
    
    # Store refresh token in database with JTI
    refresh_token_expires_at = datetime.now(timezone.utc) + refresh_token_expires
    new_token_record = UserToken(
        user_id=user.id,
        jti=refresh_jti,
        refresh_token=refresh_token,
        expires_at=refresh_token_expires_at,
        is_revoked=False
    )
    
    # Return token response (DB save is responsibility of caller)
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # in seconds
        "db_token_record": new_token_record  # For caller to save to DB
    }


async def refresh_access_token(
    refresh_token: str,
    db: AsyncSession
) -> dict:
    """
    Validate refresh token, invalidate it (single-use), issue new tokens.
    
    Args:
        refresh_token: The refresh token string
        db: Database session
        
    Returns:
        Dict with new access_token, refresh_token, expires_in, token_type
        
    Raises:
        HTTPException if token invalid/revoked/expired
    """
    # 1. Decode and validate refresh token
    try:
        payload = security.verify_refresh_token(refresh_token)
    except HTTPException:
        raise  # Re-raise validation errors
    
    user_id_str = payload.get("sub")
    old_refresh_jti = payload.get("jti")
    
    if not user_id_str or not old_refresh_jti:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token payload"
        )
    
    try:
        user_id = int(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID in token"
        )
    
    # 2. Check if token is already revoked (single-use enforcement)
    if await is_token_revoked(old_refresh_jti):
        logger.warning(f"Attempted reuse of revoked refresh token for user {user_id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has already been used"
        )
    
    # 3. Fetch token record from DB to verify it's not marked revoked
    result = await db.execute(
        select(UserToken).where(
            UserToken.jti == old_refresh_jti
        )
    )
    token_record = result.scalars().first()
    
    if not token_record:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token not found in database"
        )
    
    if token_record.is_revoked:
        logger.warning(f"Attempted to use revoked token by user {user_id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has been revoked"
        )
    
    # 4. Check token expiry (JWT signature validates initial expiry but double-check)
    if token_record.expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has expired"
        )
    
    # 5. Fetch user to verify account status
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if str(user.status) == "locked":
        raise HTTPException(status_code=403, detail="Account is locked")
    
    # 6. Invalidate old refresh token (single-use)
    token_record.is_revoked = True
    await db.flush()  # Flush before committing new tokens
    
    # Add to Redis blacklist with TTL matching token expiry
    ttl_seconds = int((token_record.expires_at - datetime.now(timezone.utc)).total_seconds())
    await set_revoked_token(old_refresh_jti, ttl_seconds)
    
    logger.info(f"Invalidated refresh token JTI {old_refresh_jti} for user {user_id}")
    
    # 7. Generate new tokens
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token, access_jti = security.create_access_token(
        data={"sub": str(user.id)},
        expires_delta=access_token_expires
    )
    
    refresh_token_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    new_refresh_token, new_refresh_jti = security.create_refresh_token(
        data={"sub": str(user.id)},
        expires_delta=refresh_token_expires
    )
    
    # 8. Store new refresh token in DB
    new_token_expires_at = datetime.now(timezone.utc) + refresh_token_expires
    new_token_record = UserToken(
        user_id=user.id,
        jti=new_refresh_jti,
        refresh_token=new_refresh_token,
        expires_at=new_token_expires_at,
        is_revoked=False
    )
    db.add(new_token_record)
    await db.commit()
    
    logger.info(f"Issued new tokens for user {user_id} during refresh")
    
    return {
        "access_token": access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    }


async def revoke_token(
    jti: str,
    user_id: int,
    db: AsyncSession,
    ttl_seconds: int = None
) -> bool:
    """
    Revoke a single token by JTI (logout single session).
    
    Args:
        jti: JWT ID to revoke
        user_id: User ID (for validation)
        db: Database session
        ttl_seconds: Time to live for blacklist entry (auto-calculated if None)
        
    Returns:
        True if successfully revoked, False if already revoked or not found
    """
    try:
        # 1. Find token in DB
        result = await db.execute(
            select(UserToken).where(
                UserToken.jti == jti,
                UserToken.user_id == user_id
            )
        )
        token_record = result.scalars().first()
        
        if not token_record:
            logger.warning(f"Token revocation: JTI {jti} not found for user {user_id}")
            return False
        
        if token_record.is_revoked:
            logger.debug(f"Token {jti} already revoked, skipping")
            return True
        
        # 2. Mark as revoked in DB
        token_record.is_revoked = True
        await db.flush()
        
        # 3. Add to Redis blacklist
        if ttl_seconds is None:
            ttl_seconds = int((token_record.expires_at - datetime.now(timezone.utc)).total_seconds())
            ttl_seconds = max(ttl_seconds, 60)  # Minimum 1 minute
        
        await set_revoked_token(jti, ttl_seconds)
        
        logger.info(f"Revoked token {jti} for user {user_id}")
        return True
        
    except Exception as e:
        logger.error(f"Error revoking token {jti}: {e}")
        return False


async def revoke_all_user_tokens(user_id: int, db: AsyncSession) -> int:
    """
    Revoke all tokens for a user (logout all sessions).
    
    Args:
        user_id: User ID
        db: Database session
        
    Returns:
        Number of tokens revoked
    """
    try:
        # 1. Find all non-revoked tokens for user
        result = await db.execute(
            select(UserToken).where(
                UserToken.user_id == user_id,
                UserToken.is_revoked.is_(False)
            )
        )
        tokens_to_revoke = result.scalars().all()
        
        if not tokens_to_revoke:
            logger.info(f"No active tokens found for user {user_id}")
            return 0
        
        # 2. Revoke all tokens
        revoked_count = 0
        for token_record in tokens_to_revoke:
            token_record.is_revoked = True
            
            # Add to Redis blacklist
            ttl_seconds = int((token_record.expires_at - datetime.now(timezone.utc)).total_seconds())
            ttl_seconds = max(ttl_seconds, 60)
            await set_revoked_token(token_record.jti, ttl_seconds)
            revoked_count += 1
        
        await db.commit()
        logger.info(f"Revoked {revoked_count} tokens for user {user_id}")
        return revoked_count
        
    except Exception as e:
        logger.error(f"Error revoking all tokens for user {user_id}: {e}")
        return 0


async def cleanup_expired_tokens(db: AsyncSession) -> int:
    """
    Delete expired refresh token records from DB (for maintenance).
    Called periodically (e.g., nightly via cron/Celery).
    
    Args:
        db: Database session
        
    Returns:
        Number of tokens deleted
    """
    try:
        result = await db.execute(
            select(UserToken).where(
                UserToken.expires_at < datetime.now(timezone.utc)
            )
        )
        expired_tokens = result.scalars().all()
        
        if not expired_tokens:
            return 0
        
        for token in expired_tokens:
            await db.delete(token)
        
        await db.commit()
        logger.info(f"Cleaned up {len(expired_tokens)} expired tokens")
        return len(expired_tokens)
        
    except Exception as e:
        logger.error(f"Error during token cleanup: {e}")
        return 0
