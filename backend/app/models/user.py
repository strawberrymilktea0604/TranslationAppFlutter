from sqlalchemy import Column, BigInteger, Integer, String, Boolean, DateTime, ForeignKey, text
from sqlalchemy.orm import relationship
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(50), default="user") # 'user' hoặc 'admin'
    status = Column(String(50), default="active") # 'active' hoặc 'locked'
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))
    updated_at = Column(DateTime(timezone=True), server_default=text('now()'), onupdate=text('now()'))

    # Mối quan hệ liên kết
    tokens = relationship("UserToken", back_populates="user", cascade="all, delete-orphan")
    quotas = relationship("UserAiQuota", back_populates="user", cascade="all, delete-orphan")
    translations = relationship("Translation", back_populates="user", cascade="all, delete-orphan")
    vocabularies = relationship("Vocabulary", back_populates="user", cascade="all, delete-orphan")

class UserToken(Base):
    __tablename__ = "user_tokens"
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    refresh_token = Column(String, nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_revoked = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))

    user = relationship("User", back_populates="tokens")

class UserAiQuota(Base):
    __tablename__ = "user_ai_quotas"
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    service_type = Column(String(100), nullable=False) # VD: 'text_translation', 'voice_stt'
    requests_used = Column(Integer, default=0)
    max_requests = Column(Integer, default=100)
    total_tokens_used = Column(Integer, default=0)
    reset_at = Column(DateTime(timezone=True))
    updated_at = Column(DateTime(timezone=True), server_default=text('now()'), onupdate=text('now()'))

    user = relationship("User", back_populates="quotas")