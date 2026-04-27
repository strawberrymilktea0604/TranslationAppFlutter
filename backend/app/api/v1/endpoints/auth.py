from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.future import select

from app.core import security
from app.core.dependencies import DBSession, get_current_user
from app.models.user import User
from app.schemas import user as schemas
from app.services import token_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=schemas.Token)
async def login(
    db: DBSession,
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()]
):
    """
    User login endpoint.
    
    Returns access token and refresh token.
    Refresh token is stored in database for tracking and revocation.
    """
    # 1. Tìm user theo email
    result = await db.execute(select(User).filter(User.email == form_data.username))
    user = result.scalars().first()
    
    # 2. Kiểm tra tài khoản và mật khẩu
    if not user or not security.verify_password(form_data.password, str(user.password_hash)):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    # 3. Kiểm tra trạng thái khóa
    if str(user.status) == "locked":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account locked")

    # 4. Tạo JWT Token
    token_response = await token_service.create_tokens_for_user(user)
    
    # 5. Store refresh token in database
    new_token_record = token_response.pop("db_token_record")
    db.add(new_token_record)
    await db.commit()
    
    return token_response


@router.post("/check-email", response_model=schemas.EmailCheckResponse)
async def check_email(
    db: DBSession,
    request: schemas.EmailCheckRequest,
):
    """
    Check if an email is already registered.
    Returns is_available = True if email is NOT registered.
    """
    result = await db.execute(select(User).filter(User.email == request.email))
    existing_user = result.scalars().first()
    
    return {"is_available": existing_user is None}


@router.post("/register", response_model=schemas.Token)
async def register(
    db: DBSession,
    user_in: schemas.UserCreate,
):
    """
    User registration endpoint.
    
    Creates new user and returns access token and refresh token.
    """
    # 1. Kiểm tra email trùng lặp
    result = await db.execute(select(User).filter(User.email == user_in.email))
    existing_user = result.scalars().first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
        
    # 2. Tạo user mới
    hashed_password = security.hash_password(user_in.password)
    new_user = User(
        email=user_in.email,
        first_name=user_in.first_name,
        last_name=user_in.last_name,
        password_hash=hashed_password,
        role="user",
        status="active"
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    # 3. Cấp Token ngay sau khi đăng ký thành công
    token_response = await token_service.create_tokens_for_user(new_user)
    
    # 4. Store refresh token in database
    new_token_record = token_response.pop("db_token_record")
    db.add(new_token_record)
    await db.commit()
    
    return token_response


@router.post("/refresh", response_model=schemas.Token)
async def refresh(
    db: DBSession,
    request: schemas.RefreshTokenRequest,
):
    """
    Refresh access token using refresh token.
    
    - Validates refresh token
    - Invalidates old refresh token (single-use enforcement)
    - Issues new access token and refresh token
    
    This implements the single-use refresh token pattern:
    - Old refresh token is marked as revoked in both Redis and DB
    - New refresh token must be used for next refresh
    - Prevents token replay attacks
    """
    return await token_service.refresh_access_token(
        refresh_token=request.refresh_token,
        db=db
    )


@router.post("/logout", response_model=schemas.LogoutResponse)
async def logout(
    db: DBSession,
    request: schemas.LogoutRequest,
    current_user: Annotated[User, Depends(get_current_user)] = None,
):
    """
    User logout endpoint.
    
    Revokes both access token and refresh token by:
    1. Adding tokens to Redis blacklist (for fast O(1) checks)
    2. Marking refresh token as revoked in database (for persistence)
    
    - Only revokes current session (not all sessions)
    - User must provide access token to authenticate the logout
    - Both tokens are immediately blacklisted
    """
    try:
        # Decode both tokens to extract JTIs
        access_payload = security.verify_token(request.access_token)
        refresh_payload = security.verify_refresh_token(request.refresh_token)
        
        access_jti = access_payload.get("jti")
        refresh_jti = refresh_payload.get("jti")
        user_id = int(access_payload.get("sub"))
        
        # Verify that tokens belong to the authenticated user
        if user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tokens do not belong to current user"
            )
        
        # Revoke both tokens
        if refresh_jti:
            await token_service.revoke_token(
                jti=refresh_jti,
                user_id=user_id,
                db=db
            )
        
        if access_jti:
            # Access token may not be in DB (only refresh tokens are stored)
            # But add to Redis blacklist for immediate rejection
            from app.core.redis_client import set_revoked_token
            access_expiry = access_payload.get("exp")
            import time
            ttl_seconds = max(int(access_expiry - time.time()), 60)
            await set_revoked_token(access_jti, ttl_seconds)
        
        return {"detail": "Successfully logged out"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Logout failed: {str(e)}"
        )


@router.post("/logout-all")
async def logout_all(
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
):
    """
    Logout all sessions for current user (revoke all refresh tokens).
    
    Use this if user suspects account compromise.
    All active refresh tokens will be invalidated.
    User must login again from all devices.
    """
    revoked_count = await token_service.revoke_all_user_tokens(
        user_id=current_user.id,
        db=db
    )
    
    return {
        "detail": "All sessions logged out",
        "revoked_tokens_count": revoked_count
    }
