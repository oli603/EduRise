from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List, Union
from functools import lru_cache


class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    PORT: int = 8000
    HOST: str = "0.0.0.0"
    CORS_ORIGINS: Union[str, List[str]] = "*"

    FIREBASE_PROJECT_ID: str = "edurise-ethiopia"

    # Gemini Provider Configuration
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-1.5-flash"
    GEMINI_TIMEOUT_SECONDS: int = 15
    GEMINI_MAX_OUTPUT_TOKENS: int = 1024

    # Rate Limiting & Student Quotas
    RATE_LIMIT_PER_MINUTE: int = 30
    DAILY_COACH_LIMIT: int = 15

    # Caching & Idempotency
    CACHE_TTL_HOURS: int = 720
    IDEMPOTENCY_TTL_SECONDS: int = 300
    GENERATION_SCHEMA_VERSION: str = "v1"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    def get_cors_origins_list(self) -> List[str]:
        if isinstance(self.CORS_ORIGINS, list):
            return self.CORS_ORIGINS
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]


@lru_cache()
def get_settings() -> Settings:
    return Settings()
