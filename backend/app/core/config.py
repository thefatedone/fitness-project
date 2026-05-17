from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    REDIS_URL: str = "redis://localhost:6379"
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    ANTHROPIC_API_KEY: str
    USDA_API_KEY: str = "DEMO_KEY"
    FRONTEND_URL: str = "http://localhost:3000"
    ELASTIC_APM_SERVICE_NAME: str = "nutrimind-backend"
    ELASTIC_APM_SERVER_URL: str = "http://localhost:8200"
    ELASTIC_APM_ENABLED: bool = False
    CACHE_TTL: int = 300

    class Config:
        env_file = ".env"

    @property
    def async_database_url(self) -> str:
        if self.DATABASE_URL.startswith("postgresql+asyncpg://"):
            return self.DATABASE_URL
        return self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)


settings = Settings()