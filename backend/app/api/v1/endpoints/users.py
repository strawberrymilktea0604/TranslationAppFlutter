import os
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Request
from fastapi.responses import FileResponse

from app.core import security
from app.core.dependencies import DBSession, get_current_user
from app.models.user import User
from app.schemas import user as schemas
from app.services.image_service import ImageService

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
    request: Request,
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
        
    # Build URL using request
    base_url = str(request.base_url).rstrip("/")
    avatar_url = f"{base_url}{str(request.scope.get('root_path', ''))}/api/v1/users/avatar/{filename}"
    
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
