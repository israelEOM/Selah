from fastapi import Cookie, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from app.core.security import decode_token
from app.db.session import get_db
from app.models.models import Role, User

def current_user(request: Request, session: str | None = Cookie(default=None), db: Session = Depends(get_db)) -> User:
    header=request.headers.get("Authorization", "")
    token=header.removeprefix("Bearer ") if header.startswith("Bearer ") else session
    if not token: raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Autenticación requerida")
    try: payload=decode_token(token); user=db.get(User, int(payload["sub"]))
    except Exception: raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sesión inválida")
    if not user or not user.is_active: raise HTTPException(status_code=403, detail="Usuario inactivo")
    return user

def admin_user(user: User = Depends(current_user)) -> User:
    if user.role != Role.ADMIN: raise HTTPException(status_code=403, detail="Se requieren permisos administrativos")
    return user
