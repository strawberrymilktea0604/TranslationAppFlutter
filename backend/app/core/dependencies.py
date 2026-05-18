from typing import Annotated, Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core import security
from app.core.redis_client import get_redis_client, is_token_revoked
from app.models.user import User
from app.services.static_cache_service import StaticContentCacheService

DBSession = Annotated[AsyncSession, Depends(get_db)]

# For standard authentication required
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

# For optional authentication (Guest allowed)
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)


async def get_static_cache_service() -> Optional[StaticContentCacheService]:
    """Return the Redis-backed static cache service when Redis is available."""
    try:
        redis_client = await get_redis_client()
    except Exception:
        return None
    return StaticContentCacheService(redis_client)

async def _verify_token_and_get_user(db: AsyncSession, token: str) -> Optional[User]:
    try:
        # 1. Decode token
        payload = security.verify_token(token)
        user_id_str = payload.get("sub")
        jti = payload.get("jti")
        
        if user_id_str is None:
            return None
            
        # 2. Check if token is revoked
        if jti and await is_token_revoked(jti):
            return None
            
        # Ensure user_id format is correct
        try:
            user_id = int(user_id_str)
        except ValueError:
            return None
            
    except Exception:
        return None
    
    # 3. Retrieve user
    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalars().first()
    
    # 4. Check user status
    if user is None or str(user.status) == "locked" or user.is_deleted is True:
        return None
        
    return user


async def get_current_user_optional(
    db: DBSession, token: Annotated[Optional[str], Depends(oauth2_scheme_optional)]
) -> Optional[User]:
    """
    Dependency for endpoints that allow Guest access but can identify Users.
    Guest will receive None. Authenticated users will receive their User object.
    """
    if not token:
        return None
    return await _verify_token_and_get_user(db, token)


async def get_current_user(
    db: DBSession, token: Annotated[str, Depends(oauth2_scheme)]
) -> User:
    """Dependency for endpoints that require at least User role."""
    # Catch token parse exceptions or revoked status through _verify_token_and_get_user
    # but we need to strictly raise HTTP 401/403 for existing clients
    try:
        payload = security.verify_token(token)
        user_id_str = payload.get("sub")
        jti = payload.get("jti")
        
        if user_id_str is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token payload invalid",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        if jti and await is_token_revoked(jti):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has been revoked",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        try:
            user_id = int(user_id_str)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, 
                detail="Invalid user ID format in token"
            )
            
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalars().first()
    
    if user is None or user.is_deleted is True:
        raise HTTPException(status_code=404, detail="User not found")
        
    if str(user.status) == "locked":
        raise HTTPException(status_code=403, detail="Account locked")
        
    return user


async def get_admin_user(current_user: Annotated[User, Depends(get_current_user)]) -> User:
    """Dependency specifically for API endpoints requiring Admin permissions."""
    if str(current_user.role) != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Not enough permissions"
        )
    return current_user
