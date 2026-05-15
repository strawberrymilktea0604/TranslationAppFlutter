from pydantic import BaseModel, ConfigDict
from typing import List, Optional, Any
from datetime import datetime

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
