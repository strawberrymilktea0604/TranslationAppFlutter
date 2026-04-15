from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core import security
from app.models.user import User

DBSession = Annotated[AsyncSession, Depends(get_db)]

# Đường dẫn chuẩn để Swagger UI gọi nút Authorize
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

async def get_current_user(
    db: DBSession, token: Annotated[str, Depends(oauth2_scheme)]
) -> User:
    try:
        # 1. Giải mã token
        payload = security.verify_token(token)
        user_id_str = payload.get("sub")
        if user_id_str is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token payload invalid",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        # Kiểm tra an toàn phòng trường hợp token bị sai format
        try:
            user_id = int(user_id_str)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, 
                detail="Invalid user ID format in token"
            )
            
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 2. Lấy thông tin User từ Database
    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalars().first()
    
    # 3. Kiểm tra các điều kiện của User
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
        
    if str(user.status) == "locked":
        raise HTTPException(status_code=403, detail="Account locked")
        
    # Trả về TOÀN BỘ object User thay vì chỉ trả về mỗi cái ID
    return user


async def get_admin_user(current_user: Annotated[User, Depends(get_current_user)]) -> User:
    """Dependency dành riêng cho các API yêu cầu quyền Admin"""
    if str(current_user.role) != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Not enough permissions"
        )
    return current_user