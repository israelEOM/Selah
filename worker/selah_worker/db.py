from functools import lru_cache

from supabase import Client, create_client

from selah_worker.config import settings


@lru_cache
def client() -> Client:
    """Service-role client: bypasses row-level security, so it never leaves the worker."""
    if not settings.supabase_url or not settings.supabase_secret_key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SECRET_KEY must be set in .env")
    return create_client(settings.supabase_url, settings.supabase_secret_key)
