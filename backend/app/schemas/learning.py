from pydantic import BaseModel, ConfigDict, Field
from typing import List, Optional, Any
from datetime import datetime


# ─────────────────────────────────────────────
# Question / Question Bank schemas
# ─────────────────────────────────────────────

class QuestionSchema(BaseModel):
    id: int
    bank_id: int
    content: str
    choices: Any
    correct_answer: str
    is_deleted: bool = False

    model_config = ConfigDict(from_attributes=True)


class QuestionBankBase(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    duration_minutes: Optional[int] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class QuestionBankDetail(QuestionBankBase):
    questions: List[QuestionSchema] = []


# ─────────────────────────────────────────────
# Quiz Submit schemas
# ─────────────────────────────────────────────

class UserAnswerItem(BaseModel):
    """A single answer supplied by the user."""
    question_id: int = Field(..., description="ID of the question being answered")
    selected_answer: str = Field(..., description="The answer option chosen by the user")


class QuizSubmitRequest(BaseModel):
    """Request body for submitting a completed quiz."""
    answers: List[UserAnswerItem] = Field(..., description="List of user answers")
    completion_time_seconds: int = Field(
        ..., ge=0, description="Total time spent answering questions in seconds"
    )


class QuizAnswerResult(BaseModel):
    """Per-question grading result returned to the client."""
    question_id: int
    selected_answer: str
    correct_answer: str
    is_correct: bool


class QuizSubmitResponse(BaseModel):
    """Response returned after a quiz is submitted and graded."""
    quiz_id: int = Field(..., description="ID of the saved UserQuiz record")
    bank_id: int
    score: float = Field(..., description="Percentage score (0–100)")
    total_questions: int
    correct_count: int
    completion_time_seconds: int
    status: str = Field(..., description="'completed' or 'timeout'")
    created_at: datetime
    results: List[QuizAnswerResult] = Field(
        ..., description="Per-question grading breakdown"
    )

    model_config = ConfigDict(from_attributes=True)


# ─────────────────────────────────────────────
# Quiz History schemas
# ─────────────────────────────────────────────

class UserQuizHistoryItem(BaseModel):
    """One entry in a user's quiz history list."""
    quiz_id: int
    bank_id: int
    bank_title: str
    score: Optional[float]
    completion_time_seconds: Optional[int]
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserQuizHistoryResponse(BaseModel):
    """Paginated quiz history for the current user."""
    items: List[UserQuizHistoryItem]
    total: int
    page: int
    page_size: int
    total_pages: int
    has_next: bool
    has_prev: bool
