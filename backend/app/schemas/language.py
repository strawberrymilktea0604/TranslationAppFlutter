from pydantic import BaseModel, Field


class Language(BaseModel):
    """Schema for a single language"""
    code: str = Field(..., description="Language code (e.g., 'en', 'vi')")
    name: str = Field(..., description="Language name in English (e.g., 'English')")
    nativeName: str = Field(..., description="Language name in its native language (e.g., 'Tiếng Việt')")


class LanguageListResponse(BaseModel):
    """Response containing list of supported languages"""
    status: str = Field(default="success", description="Response status")
    data: list[Language] = Field(..., description="List of supported languages")
