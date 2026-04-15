from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.future import select

from app.core import security
from app.core.config import settings
from app.core.dependencies import DBSession
from app.models.user import User
from app.schemas import user as schemas

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/login", response_model=schemas.Token)
async def login(
    db: DBSession,
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()]
):
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
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    refresh_token_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    access_token = security.create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    refresh_token = security.create_access_token(
        data={"sub": str(user.id), "type": "refresh"}, expires_delta=refresh_token_expires
    )
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

@router.post("/register", response_model=schemas.Token)
async def register(
    db: DBSession,
    user_in: schemas.UserCreate,
):
    # 1. Kiểm tra email trùng lặp
    result = await db.execute(select(User).filter(User.email == user_in.email))
    existing_user = result.scalars().first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
        
    # 2. Tạo user mới (Đã loại bỏ is_verified để khớp với ERD)
    hashed_password = security.hash_password(user_in.password)
    new_user = User(
        email=user_in.email,
        password_hash=hashed_password,
        role="user",
        status="active"
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    # 3. Cấp Token ngay sau khi đăng ký thành công
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    refresh_token_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    access_token = security.create_access_token(
        data={"sub": str(new_user.id)}, expires_delta=access_token_expires
    )
    refresh_token = security.create_access_token(
        data={"sub": str(new_user.id), "type": "refresh"}, expires_delta=refresh_token_expires
    )
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }