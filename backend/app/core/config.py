import os
from functools import lru_cache
from typing import Optional

from pydantic import Field, field_validator # Đổi sang field_validator chuẩn V2
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Pydantic v2 Settings với load từ .env
    Quy tắc: 
    - Không hardcode secret key trong code
    - Env variable case_sensitive=False
    - Tất cả secret phải từ .env
    """
    
    # Application
    PROJECT_NAME: str = "TranslationApp API"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = Field(default="development")  # development, staging, production
    
    # Database (PostgreSQL)
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://postgres:123456@127.0.0.1:5432/translation_app"
    )
    
    # Security - JWT
    SECRET_KEY: str = Field(
        default_factory=lambda: os.getenv("SECRET_KEY", ""),
        min_length=32,
        description="Minimum 32 characters for security"
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Redis (for token blacklisting & session management)
    REDIS_URL: str = Field(default="redis://localhost:6379/0")
    TOKEN_BLACKLIST_EXPIRY_MINUTES: int = 1440  # 24 hours: clear old blacklist entries
    
    # AI Services
    TRANSLATION_SERVICE_TIMEOUT: int = 10  # seconds
    CACHE_ENABLED: bool = True
    CACHE_TTL_SECONDS: int = 3600  # 1 hour
    TRANSLATION_FALLBACK_ENABLED: bool = True

    # Rate limiting / throttling
    GUEST_MAX_REQUESTS_PER_HOUR: int = 10
    GUEST_MAX_CHAR_LENGTH: int = 500
    USER_MAX_REQUESTS_PER_HOUR: int = 100
    USER_MAX_CHAR_LENGTH: int = 5000
    RATE_LIMIT_WINDOW_SECONDS: int = 3600  # 1 hour

    # CORS configuration
    BACKEND_CORS_ORIGINS: list[str] = Field(
        default_factory=lambda: ["*"],
        description="Allowed CORS origins. Use comma-separated values in env."
    )
    BACKEND_CORS_ALLOW_CREDENTIALS: bool = True
    BACKEND_CORS_ALLOW_METHODS: list[str] = Field(default_factory=lambda: ["*"])
    BACKEND_CORS_ALLOW_HEADERS: list[str] = Field(default_factory=lambda: ["*"])

    # External APIs (Optional)
    GOOGLE_CLOUD_API_KEY: Optional[str] = None

    # Pydantic V2 configuration
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",  
    )
    
    # CẬP NHẬT chuẩn Pydantic V2
    @field_validator("SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        """Đảm bảo SECRET_KEY thực sự từ .env, không phải default"""
        if len(v) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters")
        if v == "your-secret-key-here":
            raise ValueError("SECRET_KEY không được là placeholder!")
        return v

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def split_cors_origins(cls, v):
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v
    
    @field_validator("ENVIRONMENT")
    @classmethod
    def validate_environment(cls, v: str) -> str:
        allowed = {"development", "staging", "production"}
        if v not in allowed:
            raise ValueError(f"ENVIRONMENT phải là một trong {allowed}")
        return v
    
    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"


@lru_cache
def get_settings() -> Settings:
    """
    Singleton pattern với caching.
    Load settings một lần duy nhất.
    """
    return Settings()


# Instance toàn cục (dùng trong app)
settings = get_settings()