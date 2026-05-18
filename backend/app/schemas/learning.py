from pydantic import BaseModel, ConfigDict, Field, model_validator
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
    # ``options`` is the primary public name for the multiple-choice list;
    # it mirrors ``choices`` exactly so both old and new clients work.
    options: Any = None
    correct_answer: str
    is_deleted: bool = False

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="after")
    def _sync_options(self) -> "QuestionSchema":
        """Ensure options always mirrors choices for forward-compat clients."""
        if self.options is None:
            self.options = self.choices
        return self


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
    # Primary new field; completion_time_seconds retained for backward compat.
    time_spent_seconds: Optional[int] = Field(
        None, ge=0, description="Time spent answering (seconds) — preferred field"
    )
    completion_time_seconds: Optional[int] = Field(
        None, ge=0, description="Alias for time_spent_seconds (legacy field)"
    )

    @model_validator(mode="after")
    def _resolve_timing(self) -> "QuizSubmitRequest":
        """Require at least one timing field; normalise both to the same value."""
        if self.time_spent_seconds is None and self.completion_time_seconds is None:
            raise ValueError(
                "Either time_spent_seconds or completion_time_seconds must be provided"
            )
        # Back-fill whichever is missing so downstream code can read either.
        if self.time_spent_seconds is None:
            self.time_spent_seconds = self.completion_time_seconds
        if self.completion_time_seconds is None:
            self.completion_time_seconds = self.time_spent_seconds
        return self


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
    correct_count: int  # kept for compat
    correct_answers: int = Field(..., description="Number of correct answers")
    # Both timing fields are returned so old and new clients work.
    completion_time_seconds: Optional[int] = None
    time_spent_seconds: Optional[int] = None
    submitted_at: Optional[datetime] = None
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
    completion_time_seconds: Optional[int]  # legacy — kept for compat
    time_spent_seconds: Optional[int] = None
    total_questions: Optional[int] = None
    correct_answers: Optional[int] = None
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
