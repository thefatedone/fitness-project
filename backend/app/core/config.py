from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    # Test-only override. When set, `tests/conftest.py` rebinds
    # the SQLAlchemy engine to this URL, creates the schema
    # against it, and tears it down at session end. The conftest
    # REFUSES to run if this is missing OR equal to DATABASE_URL
    # — the latter is a guard so a developer who forgets to set
    # it locally can't accidentally run tests against the live
    # data. The intent is "tests can never touch the live DB";
    # the conftest's early-exit is what enforces it.
    TEST_DATABASE_URL: str = ""
    REDIS_URL: str = "redis://localhost:6379"
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    GOOGLE_GEMINI_API_KEY: str
    USDA_API_KEY: str = "DEMO_KEY"
    FRONTEND_URL: str = "http://localhost:3000"
    ELASTIC_APM_SERVICE_NAME: str = "nutrimind-backend"
    ELASTIC_APM_SERVER_URL: str = "http://localhost:8200"
    ELASTIC_APM_ENABLED: bool = False
    CACHE_TTL: int = 300
    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_OWNER_CHAT_ID: str = ""
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash-lite"
    # Meal-photo analysis needs more capable portion/macro estimation
    # than the chat/recognition flows. `gemini-2.5-flash` is the
    # balanced tier — more accurate than `flash-lite` (which has
    # been over-estimating portion sizes by 2-3× on rich dishes
    # like carbonara) without paying the full `pro` premium. Override
    # via env to use a different tier per deployment.
    MEAL_PHOTO_GEMINI_MODEL: str = "gemini-2.5-flash"
    # Google sign-in: comma-separated list of OAuth client IDs that
    # are allowed to mint ID tokens the backend will trust. The
    # web client ID is always included (it doubles as the "server
    # client ID" the Flutter SDK uses to obtain ID tokens); iOS and
    # Android client IDs are added on top. Tokens whose `aud` claim
    # doesn't match one of these are rejected as wrong-audience
    # (401). Never put this list in source — the env-var round-
    # trip is the only path; see `.env.example` for the placeholder.
    GOOGLE_AUTH_CLIENT_IDS: str = ""
    # iOS URL scheme is the reversed iOS client ID. The Flutter
    # Google sign-in SDK needs the reversed string at build time
    # (via `--dart-define`); the backend doesn't read this — kept
    # here only so the same env file documents the full Google
    # sign-in configuration in one place.
    GOOGLE_IOS_CLIENT_ID: str = ""
    SMTP_HOST: str = "mailhog"
    SMTP_PORT: int = 1025
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = "noreply@nutrimind.app"
    SMTP_FROM_NAME: str = "NutriMind"
    SMTP_TLS: bool = False

    class Config:
        env_file = ".env"

    @property
    def async_database_url(self) -> str:
        if self.DATABASE_URL.startswith("postgresql+asyncpg://"):
            return self.DATABASE_URL
        return self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

    @property
    def google_auth_client_id_list(self) -> list[str]:
        """The parsed [GOOGLE_AUTH_CLIENT_IDS] list.

        Splits on comma, strips whitespace, drops empties. Returns
        an empty list when the env var is unset — callers MUST
        treat that as "endpoint is misconfigured" and surface a
        502 (the IdP can't have produced a token with an audience
        we don't know about, so the right read is "upstream is
        unreachable" rather than 401). Used by
        `app.services.auth_identity` to build the `audiences`
        argument passed to `google.oauth2.id_token.verify_oauth2_token`.
        """
        return [
            piece.strip()
            for piece in self.GOOGLE_AUTH_CLIENT_IDS.split(",")
            if piece.strip()
        ]


settings = Settings()