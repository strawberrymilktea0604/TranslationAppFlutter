from pydantic import BaseModel, ConfigDict, Field
from typing import Optional
from datetime import datetime


class TranslationRequest(BaseModel):
    """Request schema for translating text"""
    source_text: str = Field(
        ..., 
        min_length=1, 
        max_length=5000,
        description="Text to translate (max 5000 chars)"
    )
    source_language: str = Field(
        ..., 
        min_length=2, 
        max_length=5,
        description="Source language code (e.g., 'en', 'vi')"
    )
    target_language: str = Field(
        ..., 
        min_length=2, 
        max_length=5,
        description="Target language code (e.g., 'en', 'vi')"
    )
    translation_type: str = Field(
        default="text",
        description="Type of translation: 'text', 'voice', 'image'"
    )


class TranslationResponse(BaseModel):
    """Response schema for a single translation"""
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    source_text: str
    translated_text: str
    source_language: str
    target_language: str
    translation_type: str
    is_cached: bool = Field(
        default=False,
        description="Whether this result came from cache"
    )
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class TranslationQuickResponse(BaseModel):
    """Simplified response for quick translation (without DB save)"""
    source_text: str
    translated_text: str
    source_language: str
    target_language: str
    is_cached: bool = Field(
        default=False,
        description="Whether this result came from cache (improves response < 500ms)"
    )
    response_time_ms: Optional[float] = Field(
        default=None,
        description="Response time in milliseconds"
    )


class TranslationListResponse(BaseModel):
    """Response schema for list of translations"""
    model_config = ConfigDict(from_attributes=True)
    
    status: str = "success"
    data: list[TranslationResponse]
    total: int = Field(default=0, description="Total translations count")


class TranslationCreateDB(BaseModel):
    """Schema for creating translation record in database"""
    user_id: int
    source_text: str
    translated_text: str
    source_language: str
    target_language: str
    translation_type: str = "text"
