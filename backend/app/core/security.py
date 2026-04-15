from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import uuid4
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status
from app.core.config import settings

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    """Hash mật khẩu bằng bcrypt"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed: str) -> bool:
    """Kiểm tra mật khẩu"""
    return pwd_context.verify(plain_password, hashed)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> tuple[str, str]:
    """
    Tạo JWT access token với JTI (JWT ID) cho tracking & revocation.
    
    Args:
        data: Claims to include (typically {"sub": user_id})
        expires_delta: Token expiration delta
    
    Returns:
        Tuple of (encoded_jwt, jti) where jti is the unique token ID
    """
    to_encode = data.copy()
    jti = str(uuid4())  # Unique JWT ID for revocation tracking
    
    expire = datetime.now(timezone.utc) + (
        expires_delta 
        or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.now(timezone.utc),  # Issued at
        "jti": jti,  # JWT ID for revocation
        "type": "access"  # Token type claim
    })
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    return encoded_jwt, jti

def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> tuple[str, str]:
    """
    Tạo JWT refresh token.
    
    Args:
        data: Claims to include (typically {"sub": user_id})
        expires_delta: Token expiration delta
    
    Returns:
        Tuple of (encoded_jwt, jti) where jti is the unique token ID
    """
    to_encode = data.copy()
    jti = str(uuid4())  # Unique JWT ID for tracking
    
    expire = datetime.now(timezone.utc) + (
        expires_delta 
        or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    )
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "jti": jti,
        "type": "refresh"  # Mark as refresh token
    })
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    return encoded_jwt, jti

def verify_token(token: str) -> dict:
    """Xác thực JWT token (access hoặc refresh)"""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

def verify_refresh_token(token: str) -> dict:
    """
    Xác thực JWT refresh token (kiểm tra 'type' = 'refresh').
    
    Args:
        token: JWT token string
    
    Returns:
        Decoded payload if valid refresh token
    
    Raises:
        HTTPException if token is invalid or not a refresh token
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        
        # Verify this is actually a refresh token
        token_type = payload.get("type")
        if token_type != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not a refresh token"
            )
        
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
