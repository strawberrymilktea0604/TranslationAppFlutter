from sqlalchemy import Column, Integer, String, DateTime, text
from app.core.database import Base

class ApiMetric(Base):
    __tablename__ = "api_metrics"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    endpoint = Column(String, nullable=False)
    response_time_ms = Column(Integer)
    status_code = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))