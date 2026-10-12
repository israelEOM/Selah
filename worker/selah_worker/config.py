from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ROOT / ".env", extra="ignore")
    supabase_url: str = ""
    supabase_secret_key: str = ""
    gemini_api_key: str = ""
    gemini_model: str = "gemini-3.5-flash-lite"
    youtube_proxy_url: str = ""
    youtube_api_key: str = ""
    # Selah links to an external reader rather than storing licensed Bible text.
    bible_external_reader_base_url: str = "https://www.biblegateway.com/passage/"
    poll_seconds: float = 3.0


settings = Settings()
