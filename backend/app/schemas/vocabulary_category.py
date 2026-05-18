from pydantic import BaseModel, ConfigDict, Field
from typing import Optional
from datetime import datetime

class VocabularyCategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)

class VocabularyCategoryUpdate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)

class VocabularyCategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    name: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
