from functools import lru_cache
from typing import Optional

from pydantic import Field, validator
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
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/translation_app"
    )
    
    # Security - JWT
    SECRET_KEY: str = Field(
        ...,  # Bắt buộc phải có trong .env
        min_length=32,
        description="Minimum 32 characters for security"
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # AI Services
    TRANSLATION_SERVICE_TIMEOUT: int = 10  # seconds
    CACHE_ENABLED: bool = True
    CACHE_TTL_SECONDS: int = 3600  # 1 hour
    
    # External APIs (Optional)
    GOOGLE_CLOUD_API_KEY: Optional[str] = None
    
    # Pydantic V2 configuration
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="forbid",  # Không cho unknown fields
    )
    
    @validator("SECRET_KEY")
    def validate_secret_key(cls, v):
        """Đảm bảo SECRET_KEY thực sự từ .env, không phải default"""
        if len(v) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters")
        if v == "your-secret-key-here":
            raise ValueError("SECRET_KEY không được là placeholder!")
        return v
    
    @validator("ENVIRONMENT")
    def validate_environment(cls, v):
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