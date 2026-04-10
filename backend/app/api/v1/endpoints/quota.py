from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.user import User, UserAiQuota
from app.schemas.quota import QuotaCreate, QuotaResponse

from app.core.database import get_db

router = APIRouter()

@router.post("/", response_model=QuotaResponse, status_code=201)
async def create_user_quota(quota_in: QuotaCreate, db: AsyncSession = Depends(get_db)):
    # 1. Kiểm tra xem User có tồn tại không (Để tránh lỗi Khóa ngoại)
    result = await db.execute(select(User).filter(User.id == quota_in.user_id))
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(
            status_code=404, 
            detail="Người dùng không tồn tại. Hãy chắc chắn user_id là chính xác!"
        )

    # 2. Đổ dữ liệu từ Pydantic Schema sang SQLAlchemy Model
    new_quota = UserAiQuota(
        user_id=quota_in.user_id,
        service_type=quota_in.service_type,
        max_requests=quota_in.max_requests,
        requests_used=0, # Mặc định ban đầu là 0
        total_tokens_used=0
    )
    
    # 3. Lưu vào Database
    db.add(new_quota)
    await db.commit()
    await db.refresh(new_quota)
    
    return new_quota