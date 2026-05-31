from sqlalchemy import func, Column, BigInteger, Integer, String, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.orm import relationship
from app.models.base import Base

class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    first_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=True)
    avatar_url = Column(String(255), nullable=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(50), default="user") # 'user' hoặc 'admin'
    status = Column(String(50), default="active") # 'active' hoặc 'locked'
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Mối quan hệ liên kết
    tokens = relationship("UserToken", back_populates="user", cascade="all, delete-orphan")
    quotas = relationship("UserAiQuota", back_populates="user", cascade="all, delete-orphan")
    translations = relationship("Translation", back_populates="user", cascade="all, delete-orphan")
    vocabularies = relationship("Vocabulary", back_populates="user", cascade="all, delete-orphan")
    user_quizzes = relationship("UserQuiz", back_populates="user", cascade="all, delete-orphan")
    conversation_sessions = relationship("ConversationSession", back_populates="user", cascade="all, delete-orphan")

class UserToken(Base):
    __tablename__ = "user_tokens"
    __table_args__ = (
        Index('ix_user_tokens_user_id_is_revoked', 'user_id', 'is_revoked'),
        Index('ix_user_tokens_jti', 'jti'),
    )
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    jti = Column(String(255), unique=True, nullable=False)  # JWT ID for tracking & revocation
    refresh_token = Column(String, nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_revoked = Column(Boolean, default=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

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
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="quotas")
