import json
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
    
    # Default Admin Account
    DEFAULT_ADMIN_EMAIL: str = "admin@example.com"
    DEFAULT_ADMIN_PASSWORD: str = "admin123"
    
    # Redis (for token blacklisting & session management)
    REDIS_URL: str = Field(default="redis://localhost:6379/0")
    TOKEN_BLACKLIST_EXPIRY_MINUTES: int = 1440  # 24 hours: clear old blacklist entries
    
    # AI Services
    TRANSLATION_SERVICE_TIMEOUT: int = 10  # seconds
    CACHE_ENABLED: bool = True
    CACHE_TTL_SECONDS: int = 3600  # 1 hour
    TRANSLATION_FALLBACK_ENABLED: bool = True
    STT_PRELOAD_ENABLED: bool = True
    STT_MODEL_SIZE: str = "small"
    STT_DEVICE: str = "cpu"
    STT_COMPUTE_TYPE: str = "int8"
    STT_DOWNLOAD_ROOT: Optional[str] = "/models/faster-whisper"
    STT_LOCAL_FILES_ONLY: bool = False
    STT_PRELOAD_TIMEOUT_SECONDS: int = 900

    # Rate limiting / throttling
    GUEST_MAX_REQUESTS_PER_HOUR: int = 10
    GUEST_MAX_CHAR_LENGTH: int = 500
    USER_MAX_REQUESTS_PER_HOUR: int = 100
    USER_MAX_CHAR_LENGTH: int = 5000
    ADMIN_MAX_REQUESTS_PER_HOUR: int = 1000
    ADMIN_MAX_CHAR_LENGTH: int = 50000
    PREMIUM_MAX_REQUESTS_PER_HOUR: int = 500
    RATE_LIMIT_WINDOW_SECONDS: int = 3600  # 1 hour
    FALLBACK_MAX_REQUESTS_PER_MINUTE: int = 20  # Limit to avoid IP ban by Google (googletrans)

    # WebSocket Configuration
    WEBSOCKET_ENABLED: bool = True
    WEBSOCKET_PING_INTERVAL: int = 30  # seconds
    WEBSOCKET_PING_TIMEOUT: int = 10  # seconds
    WEBSOCKET_CONNECTION_TIMEOUT: int = 30  # seconds
    WEBSOCKET_MAX_CONNECTIONS_PER_USER: int = 5
    WEBSOCKET_MESSAGE_QUEUE_SIZE: int = 100
    WEBSOCKET_BUFFER_SIZE: int = 1024  # KB
    CONVERSATION_SESSION_TIMEOUT: int = 300  # 5 minutes
    CONVERSATION_MAX_AUDIO_SIZE: int = 50  # MB
    CONVERSATION_MAX_SESSIONS_PER_USER: int = 3
    AUDIO_CHUNK_SIZE: int = 4096  # bytes
    AUDIO_SAMPLE_RATE: int = 16000  # Hz
    AUDIO_CHANNELS: int = 1  # mono
    AUDIO_FORMAT: str = "pcm_s16le"

    # Conversation Pipeline (silence-based VAD)
    CONVERSATION_SILENCE_RMS_THRESHOLD: float = 0.008  # normalised RMS (raw ≈ 250 / 32768)
    CONVERSATION_SILENCE_DURATION_MS: int = 1500        # trailing silence to finalize
    CONVERSATION_SILENCE_WINDOW_MS: int = 100           # RMS scanning window
    CONVERSATION_MAX_UTTERANCE_SECONDS: int = 30        # hard cap per utterance
    CONVERSATION_DRAIN_TIMEOUT_SECONDS: int = 30        # session_end queue drain
    CONVERSATION_PCM_SAMPLE_RATE: int = 16000           # required sample rate

    WEBSOCKET_POOL_SIZE: int = 100
    WEBSOCKET_MESSAGE_RATE_LIMIT: int = 1000  # messages per minute
    WEBSOCKET_AUDIO_RATE_LIMIT_MB: int = 50  # MB per minute
    WEBSOCKET_LOG_LEVEL: str = "INFO"

    # Logging Configuration
    LOG_LEVEL: str = Field(default="INFO")
    LOG_FORMAT: str = Field(default="json")  # json or standard
    FLUENTD_ENABLED: bool = True
    FLUENTD_HOST: str = "log_aggregator"
    FLUENTD_PORT: int = 24224
    FLUENTD_BUFFER_LIMIT: str = "256m"
    FLUENTD_FLUSH_INTERVAL: str = "10s"
    REALTIME_SESSION_LOGGING_ENABLED: bool = True
    REALTIME_SESSION_VERBOSE: bool = False
    SESSION_LOG_RETENTION_DAYS: int = 30
    SESSION_LOG_COMPRESSION: bool = True
    PERFORMANCE_METRICS_ENABLED: bool = True
    METRICS_FLUSH_INTERVAL: int = 60  # seconds
    AUDIT_LOGGING_ENABLED: bool = True
    AUDIT_LOG_ADMIN_ACTIONS: bool = True
    AUDIT_LOG_USER_LOGIN: bool = True
    ERROR_RATE_ALERT_THRESHOLD: float = 0.1  # 10%
    LATENCY_ALERT_THRESHOLD_MS: int = 5000  # 5 seconds

    # Query Profiler (N+1 detection — dev/staging only)
    # Set QUERY_PROFILER_ENABLED=true in .env to activate.
    # Logs a WARNING and adds X-Query-Count header when queries/request > threshold.
    QUERY_PROFILER_ENABLED: bool = False
    QUERY_PROFILER_THRESHOLD: int = 10  # warn when a single request runs more than N queries

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
            stripped = v.strip()
            if stripped.startswith("["):
                try:
                    parsed = json.loads(stripped)
                    if isinstance(parsed, list):
                        return parsed
                except json.JSONDecodeError:
                    pass
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
