from sqlalchemy import func, Column, BigInteger, String, Text, DateTime, ForeignKey, Boolean, Integer
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
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="translations")
    vocabularies = relationship("Vocabulary", back_populates="translation", cascade="all, delete-orphan")

class VocabularyCategory(Base):
    __tablename__ = "vocabulary_categories"
    
    # ID sử dụng Snowflake
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=False)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User")
    vocabularies = relationship("Vocabulary", back_populates="category_rel")

class Vocabulary(Base):
    __tablename__ = "vocabularies"
    
    # TẮT tự động tăng vì dùng Snowflake ID
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=False)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    translation_id = Column(BigInteger, ForeignKey("translations.id", ondelete="CASCADE"), nullable=False)
    category_id = Column(BigInteger, ForeignKey("vocabulary_categories.id", ondelete="RESTRICT"), nullable=True)

    # Denormalized content columns — copied from translations at save time
    # so vocabulary can be queried without a JOIN.
    word = Column(Text, nullable=True)             # = translations.source_text
    definition = Column(Text, nullable=True)       # = translations.translated_text
    source_language = Column(String(50), nullable=True)
    target_language = Column(String(50), nullable=True)

    is_deleted = Column(Boolean, default=False)
    mastery_level = Column(Integer, default=0)
    last_tested_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="vocabularies")
    translation = relationship("Translation", back_populates="vocabularies")
    category_rel = relationship("VocabularyCategory", back_populates="vocabularies")