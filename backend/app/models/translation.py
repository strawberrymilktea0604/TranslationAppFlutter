from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, text
from sqlalchemy.orm import relationship
from app.core.database import Base
from sqlalchemy.dialects.postgresql import UUID

class TranslationHistory(Base):
    __tablename__ = "translation_histories"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    # Giữ UUID này vì nó là định danh từ phía Client Flutter gửi lên để sync
    local_client_id = Column(UUID(as_uuid=True), unique=True, index=True)
    
    # Khóa ngoại trỏ về User (Integer)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    source_lang = Column(String(5), nullable=False)
    target_lang = Column(String(5), nullable=False)
    source_text = Column(Text, nullable=False)
    translated_text = Column(Text, nullable=False)
    input_type = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))

    flashcards = relationship("Flashcard", back_populates="translation", cascade="all, delete-orphan")

class Flashcard(Base):
    __tablename__ = "flashcards"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    # history_id trỏ về id của TranslationHistory (Integer)
    history_id = Column(Integer, ForeignKey("translation_histories.id", ondelete="CASCADE"), nullable=False)
    
    user_notes = Column(Text)
    status = Column(String, nullable=False, default="learning")
    created_at = Column(DateTime(timezone=True), server_default=text('now()'))

    translation = relationship("TranslationHistory", back_populates="flashcards")