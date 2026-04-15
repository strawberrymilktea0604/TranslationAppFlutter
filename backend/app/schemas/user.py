import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class UserBase(BaseModel):
    email: EmailStr


class UserCreate(UserBase):
    password: str = Field(min_length=8, max_length=72)

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isalpha() for char in v):
            raise ValueError('Password must contain at least one letter')
        return v


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    role: str
    status: str
    is_verified: bool
    created_at: datetime
    updated_at: datetime


class Token(BaseModel):
    """Token response schema (login, register, refresh)"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Access token expiration time in seconds")


class TokenPayload(BaseModel):
    """JWT payload after decoding"""
    sub: str | None = None
    exp: int | None = None
    jti: str | None = None
    iat: int | None = None
    type: str | None = None


class RefreshTokenRequest(BaseModel):
    """Request body for refresh token endpoint"""
    refresh_token: str = Field(description="Refresh token from login response")


class LogoutRequest(BaseModel):
    """Request body for logout endpoint"""
    access_token: str = Field(description="Access token to validate logout request")
    refresh_token: str = Field(description="Refresh token to revoke")


class LogoutResponse(BaseModel):
    """Response from logout endpoint"""
    detail: str = "Successfully logged out"

