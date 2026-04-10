from sqlalchemy import Column, BigInteger, Integer, String, DateTime, Boolean, ForeignKey, text
from app.core.database import Base

class ApiMetric(Base):
    __tablename__ = "api_metrics"
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    # Khóa ngoại này có thể Null (Khách chưa đăng nhập cũng có thể dùng thử)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    endpoint = Column(String(255), nullable=False)
    response_time_ms = Column(Integer, nullable=False)
    status_code = Column(Integer, nullable=False)
    is_ai_request = Column(Boolean, default=False)
    ai_model = Column(String(100), nullable=True) # VD: 'gemini-1.5'
    ai_tokens_used = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))