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
    category_id: Optional[int] = Field(None, description="Category ID for flashcard grouping")


class VocabularyCreateMultiple(BaseModel):
    """Request schema for creating multiple vocabulary entries at once"""
    translation_ids: list[int] = Field(
        ...,
        min_items=1,
        max_items=50,
        description="List of translation IDs to add to vocabulary (max 50 at once)"
    )


class VocabularyProgressUpdate(BaseModel):
    """Request schema for updating vocabulary learning progress via PATCH."""
    mastery_level: Optional[int] = Field(None, ge=0, le=5, description="Mastery level 0–5")
    last_tested_at: Optional[datetime] = Field(None, description="When the flashcard was last tested")


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
    category_id: Optional[int] = Field(None, description="Category ID")
    category: str = Field("Chưa phân loại", description="Category name")
    mastery_level: int = Field(0, description="Learning mastery level 0–5")
    last_tested_at: Optional[datetime] = Field(None, description="When this card was last tested")
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    # Translation details embedded (via join in service layer)
    source_language: str = Field(..., description="Source language code")
    target_language: str = Field(..., description="Target language code")
    source_text: str = Field(..., description="Original text in source language")
    translated_text: str = Field(..., description="Translated text in target language")
    translation_type: Optional[str] = Field(None, description="Type: 'text', 'voice', or 'image'")
    translation_created_at: Optional[datetime] = Field(None, description="When translation was created")

    # Convenience aliases matching the vocabularies table columns.
    # Flutter VocabularyModel.fromJson reads these directly.
    @property
    def word(self) -> str:
        return self.source_text

    @property
    def definition(self) -> str:
        return self.translated_text


class VocabularyListResponse(BaseModel):
    """Response schema for list of vocabulary entries with pagination"""
    items: list[VocabularyDetailResponse]
    total: int = Field(..., description="Total number of vocabulary entries")
    page: int = Field(..., description="Current page number (1-indexed)")
    page_size: int = Field(..., description="Number of items per page")
    total_pages: int = Field(..., description="Total number of pages")
    has_next: bool = Field(..., description="Whether there are more pages")
    has_prev: bool = Field(..., description="Whether there are previous pages")
