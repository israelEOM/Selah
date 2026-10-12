"""initial Selah schema

Revision ID: 20260927_01
Revises:
Create Date: 2026-09-27
"""
from alembic import op
from app.db.base import Base
from app.models import models  # noqa: F401 - registers tables

revision = "20260927_01"
down_revision = None
branch_labels = None
depends_on = None

def upgrade() -> None:
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)

def downgrade() -> None:
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
