from datetime import datetime, timedelta, timezone
import jwt
from passlib.context import CryptContext
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)

def create_token(subject: str, role: str) -> str:
    expires = datetime.now(timezone.utc) + timedelta(hours=settings.access_token_hours)
    return jwt.encode({"sub": subject, "role": role, "exp": expires}, settings.api_secret_key, algorithm="HS256")

def decode_token(token: str) -> dict:
    return jwt.decode(token, settings.api_secret_key, algorithms=["HS256"])
