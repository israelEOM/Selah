from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    database_url: str = "postgresql+psycopg://selah:change-me@db:5432/selah"
    redis_url: str = "redis://redis:6379/0"
    api_secret_key: str = "development-only-change-me"
    openai_api_key: str | None = None
    openai_model: str = "gpt-4.1"
    openai_base_url: str | None = None
    # Selah's MVP links to an external reader rather than storing licensed Bible text.
    bible_external_reader_base_url: str = "https://www.biblegateway.com/passage/"
    youtube_api_key: str | None = None
    cors_origins: str = "http://localhost:3000"
    access_token_hours: int = 24 * 7
    bootstrap_admin_email: str | None = None
    bootstrap_admin_password: str | None = None

settings = Settings()
