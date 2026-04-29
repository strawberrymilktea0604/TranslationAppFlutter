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


# ==================== IMAGE TRANSLATION SCHEMAS ====================

class TextRegion(BaseModel):
    """Text region detected in image with bounding box"""
    text: str
    confidence: int = Field(..., ge=0, le=100, description="Confidence percentage")
    bbox: dict = Field(
        ...,
        description="Bounding box: {x, y, width, height}"
    )


class OCRResult(BaseModel):
    """OCR extraction result from image"""
    raw_text: str = Field(..., description="Extracted text from image")
    confidence: float = Field(
        ..., ge=0, le=100,
        description="Average OCR confidence"
    )
    language: str = Field(..., description="Detected language code")
    text_regions: list[TextRegion] = Field(
        default_factory=list,
        description="Individual text regions with bounding boxes"
    )
    processing_time_ms: float = Field(
        ..., description="OCR processing time in milliseconds"
    )
    image_size: tuple[int, int] = Field(..., description="(width, height)")


class ImageMetadata(BaseModel):
    """Image metadata"""
    format: str
    size: tuple[int, int]
    width: int
    height: int
    mode: str
    bytes: int
    estimated_text_density: float = Field(
        ..., ge=0, le=100,
        description="Estimated percentage of image containing text"
    )


class ImageTranslationRequest(BaseModel):
    """Request schema for translating image"""
    # Note: File uploaded via multipart/form-data, not JSON
    source_language: str = Field(
        default="en",
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
    optimize_image: bool = Field(
        default=True,
        description="Optimize image before OCR"
    )
    return_regions: bool = Field(
        default=False,
        description="Include text regions with bounding boxes"
    )


class ImageTranslationResponse(BaseModel):
    """Response schema for image translation"""
    model_config = ConfigDict(from_attributes=True)
    
    # Original content
    source_text: str = Field(
        ..., description="Text extracted from image"
    )
    translated_text: str = Field(
        ..., description="Translated text"
    )
    source_language: str
    target_language: str
    
    # OCR details
    ocr_confidence: float = Field(
        ..., description="OCR extraction confidence"
    )
    text_regions: Optional[list[TextRegion]] = Field(
        default=None,
        description="Text regions if requested"
    )
    
    # Cache and performance
    is_cached: bool = Field(
        default=False,
        description="Whether translation came from cache"
    )
    response_time_ms: float = Field(
        ..., description="Total processing time"
    )
    
    # Image info
    image_metadata: Optional[ImageMetadata] = Field(
        default=None,
        description="Image metadata if requested"
    )
    
    translation_type: str = Field(
        default="image",
        description="Always 'image' for this endpoint"
    )
    
    created_at: Optional[datetime] = None


class ImageTranslationBatchRequest(BaseModel):
    """Request for batch image translation"""
    source_language: str = Field(default="en")
    target_language: str
    return_regions: bool = Field(default=False)
    # Images uploaded via multipart/form-data


class ImageTranslationBatchResponse(BaseModel):
    """Response for batch image translation"""
    model_config = ConfigDict(from_attributes=True)
    
    status: str = "success"
    total: int
    successful: int
    failed: int
    results: list[ImageTranslationResponse]
    errors: Optional[list[dict]] = None
