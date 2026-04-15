from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.dependencies import get_admin_user
from app.models.user import User, UserAiQuota
from app.schemas.quota import QuotaCreate


router = APIRouter()

@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_user_quota(
    quota_in: QuotaCreate, 
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_admin_user) 
):
    # 1. Kiểm tra User tồn tại
    result = await db.execute(select(User).filter(User.id == quota_in.user_id))
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail={
                "status": "error", 
                "code": "USER_NOT_FOUND", 
                "message": "Người dùng không tồn tại. Hãy kiểm tra lại user_id!"
            }
        )

    # 2. Đổ dữ liệu sang Model
    new_quota = UserAiQuota(
        user_id=quota_in.user_id,
        service_type=quota_in.service_type,
        max_requests=quota_in.max_requests,
        requests_used=0,
        total_tokens_used=0
    )
    
    # 3. Lưu Database
    db.add(new_quota)
    await db.commit()
    await db.refresh(new_quota)
    
    # 4. Trả về đúng Format chuẩn của dự án
    return {
        "status": "success",
        "data": new_quota
    }