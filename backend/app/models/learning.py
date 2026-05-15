from sqlalchemy import func, Column, BigInteger, String, Text, DateTime, ForeignKey, Boolean, Integer, Float
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from app.models.base import Base

class QuestionBank(Base):
    __tablename__ = "question_banks"
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    duration_minutes = Column(Integer, nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    questions = relationship("Question", back_populates="bank", cascade="all, delete-orphan")
    user_quizzes = relationship("UserQuiz", back_populates="bank", cascade="all, delete-orphan")

class Question(Base):
    __tablename__ = "questions"
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    bank_id = Column(BigInteger, ForeignKey("question_banks.id", ondelete="CASCADE"), nullable=False)
    content = Column(Text, nullable=False)
    choices = Column(JSONB, nullable=False)
    correct_answer = Column(String(255), nullable=False)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    bank = relationship("QuestionBank", back_populates="questions")

class UserQuiz(Base):
    __tablename__ = "user_quizzes"
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    bank_id = Column(BigInteger, ForeignKey("question_banks.id", ondelete="CASCADE"), nullable=False)
    score = Column(Float, nullable=True)
    completion_time_seconds = Column(Integer, nullable=True)
    status = Column(String(50), nullable=False) # 'completed', 'timeout'
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="user_quizzes")
    bank = relationship("QuestionBank", back_populates="user_quizzes")
