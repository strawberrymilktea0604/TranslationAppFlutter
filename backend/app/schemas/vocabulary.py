"""
Vocabulary Schema - Pydantic models for Vocabulary CRUD operations
"""
from pydantic import BaseModel, ConfigDict, Field
from typing import Optional
from datetime import datetime


class VocabularyCreate(BaseModel):
    """Request schema for creating a vocabulary entry"""
    translation_id: int = Field(
        ...,
        description="ID of the translation to add to vocabulary"
    )


class VocabularyCreateMultiple(BaseModel):
    """Request schema for creating multiple vocabulary entries at once"""
    translation_ids: list[int] = Field(
        ...,
        min_items=1,
        max_items=50,
        description="List of translation IDs to add to vocabulary (max 50 at once)"
    )


class VocabularyUpdate(BaseModel):
    """Request schema for updating vocabulary entries (future use for tags, notes, etc.)"""
    # Placeholder for future fields like tags, learning_level, last_reviewed_at, etc.
    pass


class VocabularyResponse(BaseModel):
    """Response schema for a single vocabulary entry with full details"""
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    user_id: int
    translation_id: int
    is_deleted: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class VocabularyDetailResponse(BaseModel):
    """Response schema for vocabulary entry with translation details"""
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    user_id: int
    translation_id: int
    is_deleted: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    # Translation details embedded
    source_language: str = Field(..., description="Source language code")
    target_language: str = Field(..., description="Target language code")
    source_text: str = Field(..., description="Original text in source language")
    translated_text: str = Field(..., description="Translated text in target language")
    translation_type: Optional[str] = Field(None, description="Type: 'text', 'voice', or 'image'")
    translation_created_at: Optional[datetime] = Field(None, description="When translation was created")


class VocabularyListResponse(BaseModel):
    """Response schema for list of vocabulary entries with pagination"""
    items: list[VocabularyDetailResponse]
    total: int = Field(..., description="Total number of vocabulary entries")
    page: int = Field(..., description="Current page number (1-indexed)")
    page_size: int = Field(..., description="Number of items per page")
    total_pages: int = Field(..., description="Total number of pages")
    has_next: bool = Field(..., description="Whether there are more pages")
    has_prev: bool = Field(..., description="Whether there are previous pages")
