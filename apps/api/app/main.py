from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from app.api.routes import router
from app.core.config import settings
from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.models import BibleVersion, ChurchSettings, Role, User
from app.core.security import hash_password

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine) # Development bootstrap; production uses Alembic migration.
    db=SessionLocal()
    try:
        if not db.scalar(select(ChurchSettings)): db.add(ChurchSettings())
        rvr1960 = db.scalar(select(BibleVersion).where(BibleVersion.code=="RVR1960"))
        if not rvr1960:
            db.add(BibleVersion(code="RVR1960",name="Reina-Valera 1960",language="es",provider="EXTERNAL_LINK",provider_translation_id="RVR1960",copyright_notice="Texto bíblico: Reina-Valera 1960 ® © Sociedades Bíblicas en América Latina, 1960. Renovado © Sociedades Bíblicas Unidas, 1988. Selah no almacena ni reproduce el texto; enlaza al lector externo."))
        elif rvr1960.provider != "EXTERNAL_LINK":
            rvr1960.provider = "EXTERNAL_LINK"
            rvr1960.provider_translation_id = "RVR1960"
            rvr1960.copyright_notice = "Texto bíblico: Reina-Valera 1960 ® © Sociedades Bíblicas en América Latina, 1960. Renovado © Sociedades Bíblicas Unidas, 1988. Selah no almacena ni reproduce el texto; enlaza al lector externo."
        if settings.bootstrap_admin_email and settings.bootstrap_admin_password and not db.scalar(select(User).where(User.email == settings.bootstrap_admin_email.lower())):
            db.add(User(email=settings.bootstrap_admin_email.lower(), password_hash=hash_password(settings.bootstrap_admin_password), role=Role.ADMIN, display_name="Administrador Selah"))
        db.commit()
    finally: db.close()
    yield

app=FastAPI(title="Selah API",version="0.1.0",description="La Palabra que permanece.",lifespan=lifespan)
app.add_middleware(CORSMiddleware,allow_origins=settings.cors_origins.split(","),allow_credentials=True,allow_methods=["*"],allow_headers=["*"])
app.include_router(router)
@app.get("/health")
def health(): return {"status":"ok"}
