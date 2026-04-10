from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
from typing import Optional

# 1. Base Schema: Chứa các trường chung nhất
class QuotaBase(BaseModel):
    service_type: str = Field(..., description="Loại dịch vụ, VD: 'text_translation', 'voice_stt'")
    max_requests: int = Field(default=100, ge=0, description="Hạn mức tối đa, không được âm")

# 2. Schema Create: Dùng để hứng dữ liệu từ API POST khi cấp Quota mới
class QuotaCreate(QuotaBase):
    user_id: int = Field(..., description="ID của người dùng được cấp hạn mức")

# 3. Schema Update: Dùng khi người dùng xài API và ta cần trừ Quota
class QuotaUpdate(BaseModel):
    requests_used: Optional[int] = Field(None, ge=0)
    total_tokens_used: Optional[int] = Field(None, ge=0)
    max_requests: Optional[int] = Field(None, ge=0)
    reset_at: Optional[datetime] = None

# 4. Schema Response: Dùng để trả dữ liệu (JSON) về cho App Flutter
class QuotaResponse(QuotaBase):
    id: int
    user_id: int
    requests_used: int
    total_tokens_used: int
    reset_at: Optional[datetime]
    updated_at: datetime

    # Giúp Pydantic tự động đọc dữ liệu từ Object của SQLAlchemy
    model_config = ConfigDict(from_attributes=True)