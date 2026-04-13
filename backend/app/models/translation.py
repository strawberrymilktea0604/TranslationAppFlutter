from sqlalchemy import Column, BigInteger, String, Text, DateTime, ForeignKey, Boolean, text
from sqlalchemy.orm import relationship
from app.models.base import Base

class Translation(Base):
    __tablename__ = "translations"
    
    # TẮT tự động tăng vì dùng Snowflake ID tạo từ Client/App
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=False)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    source_language = Column(String(50), nullable=False)
    target_language = Column(String(50), nullable=False)
    source_text = Column(Text, nullable=False)
    translated_text = Column(Text, nullable=False)
    translation_type = Column(String(50)) # 'text', 'voice', 'image'
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))
    updated_at = Column(DateTime(timezone=True), server_default=text('now()'), onupdate=text('now()'))

    user = relationship("User", back_populates="translations")
    vocabularies = relationship("Vocabulary", back_populates="translation", cascade="all, delete-orphan")

class Vocabulary(Base):
    __tablename__ = "vocabularies"
    
    # TẮT tự động tăng vì dùng Snowflake ID
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=False)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    translation_id = Column(BigInteger, ForeignKey("translations.id", ondelete="CASCADE"), nullable=False)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))
    updated_at = Column(DateTime(timezone=True), server_default=text('now()'), onupdate=text('now()'))

    user = relationship("User", back_populates="vocabularies")
    translation = relationship("Translation", back_populates="vocabularies")