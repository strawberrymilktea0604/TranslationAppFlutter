import os
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile
from fastapi.responses import FileResponse

from app.core import security
from app.core.dependencies import DBSession, get_current_user
from app.models.user import User
from app.schemas import user as schemas
from app.services.image_service import ImageService
from sqlalchemy import select, func, or_

router = APIRouter(prefix="/users", tags=["users"])

UPLOAD_DIR = "app/static/avatars"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.get("/me", response_model=schemas.UserRead)
async def get_profile(
    current_user: Annotated[User, Depends(get_current_user)]
):
    """
    Get current user profile.
    """
    return current_user


@router.patch("/me", response_model=schemas.UserRead)
async def update_profile(
    db: DBSession,
    user_in: schemas.UserUpdate,
    current_user: Annotated[User, Depends(get_current_user)]
):
    """
    Update current user profile.
    """
    if user_in.first_name is not None:
        current_user.first_name = user_in.first_name
    if user_in.last_name is not None:
        current_user.last_name = user_in.last_name
        
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    return current_user


@router.patch("/me/password", response_model=schemas.UserRead)
async def update_password(
    db: DBSession,
    password_in: schemas.UserPasswordUpdate,
    current_user: Annotated[User, Depends(get_current_user)]
):
    """
    Update current user password.
    """
    if not security.verify_password(password_in.old_password, str(current_user.password_hash)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mật khẩu cũ không chính xác"
        )
        
    current_user.password_hash = security.hash_password(password_in.new_password)
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    return current_user


@router.post("/me/avatar", response_model=schemas.UserAvatarResponse)
async def upload_avatar(
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
    file: UploadFile = File(...)
):
    """
    Upload and update user avatar.
    """
    image_bytes = await file.read()
    
    is_valid, msg = ImageService.validate_image_bytes(image_bytes)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid image: {msg}"
        )
        
    # Optimize image (resize to a reasonable size like 256x256)
    optimized_bytes = await ImageService.optimize_image(
        image_bytes, 
        max_width=256, 
        max_height=256, 
        quality=85
    )
    
    filename = f"{current_user.id}_{uuid.uuid4().hex[:8]}.jpg"
    file_path = os.path.join(UPLOAD_DIR, filename)
    
    with open(file_path, "wb") as f:
        f.write(optimized_bytes)
        
    avatar_url = f"/api/v1/users/avatar/{filename}"
    
    current_user.avatar_url = avatar_url
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    return {"avatar_url": avatar_url}


@router.get("/avatar/{filename}", response_class=FileResponse)
async def get_avatar(filename: str):
    """
    Get user avatar image.
    """
    file_path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Avatar not found")
    return FileResponse(file_path)


# ==================== ADMIN ENDPOINTS ====================

async def get_admin_user(current_user: Annotated[User, Depends(get_current_user)]):
    """
    Dependency to ensure current user is an admin.
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return current_user


@router.get("/admin/users", response_model=schemas.UserListResponse)
async def list_users(
    db: DBSession,
    admin_user: Annotated[User, Depends(get_admin_user)],
    page: int = 1,
    page_size: int = 20,
    search: str | None = None,
):
    """
    List all users with pagination and search.
    Only accessible to admin users.
    """
    if page < 1:
        page = 1
    if page_size < 1 or page_size > 100:
        page_size = 20

    query = select(User).where(User.is_deleted.is_(False))
    
    # Apply search filter
    if search and search.strip():
        search_term = f"%{search.strip()}%"
        query = query.where(
            or_(
                User.email.ilike(search_term),
                User.first_name.ilike(search_term),
                User.last_name.ilike(search_term)
            )
        )
    
    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()
    
    # Apply pagination
    skip = (page - 1) * page_size
    users_result = await db.execute(query.offset(skip).limit(page_size))
    users = users_result.scalars().all()
    
    return schemas.UserListResponse(
        items=[schemas.UserListItem.model_validate(u) for u in users],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.patch("/admin/users/{user_id}/ban", response_model=schemas.UserRead)
async def ban_user(
    user_id: int,
    db: DBSession,
    admin_user: Annotated[User, Depends(get_admin_user)],
):
    """
    Ban a user (lock their account).
    Only accessible to admin users.
    """
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    if user.id == admin_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot ban yourself"
        )
    
    user.status = "locked"
    db.add(user)
    await db.commit()
    await db.refresh(user)
    
    return user


@router.patch("/admin/users/{user_id}/unban", response_model=schemas.UserRead)
async def unban_user(
    user_id: int,
    db: DBSession,
    admin_user: Annotated[User, Depends(get_admin_user)],
):
    """
    Unban a user (unlock their account).
    Only accessible to admin users.
    """
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    user.status = "active"
    db.add(user)
    await db.commit()
    await db.refresh(user)
    
    return user
