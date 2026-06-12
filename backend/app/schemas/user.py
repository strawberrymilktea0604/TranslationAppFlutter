from datetime import datetime
from urllib.parse import urlparse

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


def normalize_avatar_url(value: str | None) -> str | None:
    if not value:
        return value

    parsed = urlparse(value)
    if parsed.scheme and parsed.netloc:
        return parsed.path if parsed.path.startswith("/api/v1/users/avatar/") else value

    return value


class UserBase(BaseModel):
    email: EmailStr
    first_name: str | None = None
    last_name: str | None = None
    avatar_url: str | None = None

    @field_validator("avatar_url")
    @classmethod
    def normalize_avatar_url_field(cls, v: str | None) -> str | None:
        return normalize_avatar_url(v)


class UserCreate(UserBase):
    first_name: str
    last_name: str
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
    created_at: datetime
    updated_at: datetime


class UserUpdate(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    avatar_url: str | None = None

class UserAvatarResponse(BaseModel):
    avatar_url: str

    @field_validator("avatar_url")
    @classmethod
    def normalize_avatar_url_field(cls, v: str) -> str:
        return normalize_avatar_url(v) or v


class UserPasswordUpdate(BaseModel):
    old_password: str
    new_password: str = Field(min_length=8, max_length=72)


class UserListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    first_name: str | None = None
    last_name: str | None = None
    avatar_url: str | None = None
    role: str
    status: str
    created_at: datetime

    @field_validator("avatar_url")
    @classmethod
    def normalize_avatar_url_field(cls, v: str | None) -> str | None:
        return normalize_avatar_url(v)


class UserListResponse(BaseModel):
    items: list[UserListItem]
    total: int
    page: int
    page_size: int


class UserStatusUpdate(BaseModel):
    status: str = Field(pattern="^(active|locked)$")


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


class EmailCheckRequest(BaseModel):
    email: EmailStr

class EmailCheckResponse(BaseModel):
    is_available: bool


