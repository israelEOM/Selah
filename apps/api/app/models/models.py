import enum
from datetime import datetime
from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base

JSON = JSONB

class Role(str, enum.Enum): ADMIN = "ADMIN"; MEMBER = "MEMBER"
class SermonStatus(str, enum.Enum): PENDING="PENDING"; FETCHING_TRANSCRIPT="FETCHING_TRANSCRIPT"; TRANSCRIPT_READY="TRANSCRIPT_READY"; ANALYZING="ANALYZING"; VERIFYING_REFERENCES="VERIFYING_REFERENCES"; GENERATING_SUMMARY="GENERATING_SUMMARY"; GENERATING_DEVOTIONAL="GENERATING_DEVOTIONAL"; AWAITING_REVIEW="AWAITING_REVIEW"; PUBLISHED="PUBLISHED"; FAILED="FAILED"
class StudyStatus(str, enum.Enum): DRAFT="DRAFT"; AWAITING_REVIEW="AWAITING_REVIEW"; PUBLISHED="PUBLISHED"

class Timestamped(Base):
    __abstract__ = True
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class User(Timestamped):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str | None] = mapped_column(String(120))
    role: Mapped[Role] = mapped_column(Enum(Role), default=Role.MEMBER)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

class ChurchSettings(Timestamped):
    __tablename__ = "church_settings"
    id: Mapped[int] = mapped_column(primary_key=True)
    church_name: Mapped[str] = mapped_column(String(160), default="Selah")
    default_original_language: Mapped[str] = mapped_column(String(8), default="es")
    default_study_language: Mapped[str] = mapped_column(String(8), default="es")
    default_bible_version_code: Mapped[str] = mapped_column(String(32), default="RVR1960")
    default_devotional_days: Mapped[int] = mapped_column(Integer, default=5)

class Sermon(Timestamped):
    __tablename__ = "sermons"
    id: Mapped[int] = mapped_column(primary_key=True)
    youtube_video_id: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    youtube_url: Mapped[str] = mapped_column(String(512))
    original_title: Mapped[str | None] = mapped_column(String(500))
    suggested_title: Mapped[str | None] = mapped_column(String(500))
    channel_name: Mapped[str | None] = mapped_column(String(255))
    speaker: Mapped[str | None] = mapped_column(String(255))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_seconds: Mapped[int | None] = mapped_column(Integer)
    thumbnail_url: Mapped[str | None] = mapped_column(String(512))
    original_language: Mapped[str] = mapped_column(String(8), default="es")
    transcript_language: Mapped[str] = mapped_column(String(8), default="es")
    study_language: Mapped[str] = mapped_column(String(8), default="es")
    bible_version_code: Mapped[str] = mapped_column(String(32), default="RVR1960")
    start_seconds: Mapped[int] = mapped_column(Integer, default=0)
    end_seconds: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[SermonStatus] = mapped_column(Enum(SermonStatus), default=SermonStatus.PENDING)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))

class Transcript(Timestamped):
    __tablename__ = "transcripts"
    id: Mapped[int] = mapped_column(primary_key=True)
    sermon_id: Mapped[int] = mapped_column(ForeignKey("sermons.id", ondelete="CASCADE"), index=True)
    language: Mapped[str] = mapped_column(String(8))
    source: Mapped[str] = mapped_column(String(32))
    is_auto_generated: Mapped[bool] = mapped_column(Boolean, default=False)
    raw_text: Mapped[str | None] = mapped_column(Text)
    normalized_text: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(32), default="READY")

class TranscriptSegment(Base):
    __tablename__ = "transcript_segments"
    id: Mapped[int] = mapped_column(primary_key=True)
    transcript_id: Mapped[int] = mapped_column(ForeignKey("transcripts.id", ondelete="CASCADE"), index=True)
    start_seconds: Mapped[float | None] = mapped_column(Float)
    duration_seconds: Mapped[float | None] = mapped_column(Float)
    text: Mapped[str] = mapped_column(Text)
    sequence: Mapped[int] = mapped_column(Integer)
    __table_args__ = (UniqueConstraint("transcript_id", "sequence"),)

class SermonAnalysis(Base):
    __tablename__ = "sermon_analyses"
    id: Mapped[int] = mapped_column(primary_key=True)
    sermon_id: Mapped[int] = mapped_column(ForeignKey("sermons.id", ondelete="CASCADE"), unique=True)
    model: Mapped[str] = mapped_column(String(100))
    prompt_version: Mapped[str] = mapped_column(String(40))
    structured_content: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class BibleVersion(Base):
    __tablename__ = "bible_versions"
    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(32), unique=True)
    name: Mapped[str] = mapped_column(String(160))
    language: Mapped[str] = mapped_column(String(8))
    provider: Mapped[str] = mapped_column(String(64))
    provider_translation_id: Mapped[str | None] = mapped_column(String(128))
    copyright_notice: Mapped[str | None] = mapped_column(Text)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True)

class BibleReference(Base):
    __tablename__ = "bible_references"
    id: Mapped[int] = mapped_column(primary_key=True)
    sermon_id: Mapped[int] = mapped_column(ForeignKey("sermons.id", ondelete="CASCADE"), index=True)
    canonical_reference: Mapped[str] = mapped_column(String(128))
    bible_version_id: Mapped[int | None] = mapped_column(ForeignKey("bible_versions.id"))
    classification: Mapped[str] = mapped_column(String(50))
    confidence: Mapped[float] = mapped_column(Float)
    timestamp_seconds: Mapped[float | None] = mapped_column(Float)
    source_excerpt: Mapped[str | None] = mapped_column(Text)
    verification_status: Mapped[str] = mapped_column(String(32), default="PENDING")

class Study(Timestamped):
    __tablename__ = "studies"
    id: Mapped[int] = mapped_column(primary_key=True)
    sermon_id: Mapped[int] = mapped_column(ForeignKey("sermons.id"), unique=True)
    title: Mapped[str] = mapped_column(String(500))
    slug: Mapped[str] = mapped_column(String(500), unique=True, index=True)
    language: Mapped[str] = mapped_column(String(8), default="es")
    bible_version_id: Mapped[int | None] = mapped_column(ForeignKey("bible_versions.id"))
    summary: Mapped[dict | None] = mapped_column(JSON)
    status: Mapped[StudyStatus] = mapped_column(Enum(StudyStatus), default=StudyStatus.DRAFT)
    reviewed_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

class DevotionalDay(Base):
    __tablename__ = "devotional_days"
    id: Mapped[int] = mapped_column(primary_key=True)
    study_id: Mapped[int] = mapped_column(ForeignKey("studies.id", ondelete="CASCADE"), index=True)
    day_number: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(255))
    main_reference: Mapped[str] = mapped_column(String(128))
    content: Mapped[dict] = mapped_column(JSON)
    estimated_reading_minutes: Mapped[int] = mapped_column(Integer, default=4)
    __table_args__ = (UniqueConstraint("study_id", "day_number"),)

class UserStudyProgress(Base):
    __tablename__ = "user_study_progress"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    study_id: Mapped[int] = mapped_column(ForeignKey("studies.id", ondelete="CASCADE"))
    day_number: Mapped[int] = mapped_column(Integer)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    __table_args__ = (UniqueConstraint("user_id", "study_id", "day_number"),)

class UserNote(Timestamped):
    __tablename__ = "user_notes"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    study_id: Mapped[int] = mapped_column(ForeignKey("studies.id", ondelete="CASCADE"))
    devotional_day_id: Mapped[int | None] = mapped_column(ForeignKey("devotional_days.id", ondelete="CASCADE"))
    content: Mapped[str] = mapped_column(Text)

class AIJob(Timestamped):
    __tablename__ = "ai_jobs"
    id: Mapped[int] = mapped_column(primary_key=True)
    sermon_id: Mapped[int] = mapped_column(ForeignKey("sermons.id", ondelete="CASCADE"), index=True)
    job_type: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(32), default="PENDING")
    model: Mapped[str] = mapped_column(String(100))
    prompt_version: Mapped[str] = mapped_column(String(40))
    input_tokens: Mapped[int | None] = mapped_column(Integer)
    output_tokens: Mapped[int | None] = mapped_column(Integer)
    estimated_cost: Mapped[float | None] = mapped_column(Float)
    error_message: Mapped[str | None] = mapped_column(Text)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

class PromptVersion(Base):
    __tablename__ = "prompt_versions"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(64))
    version: Mapped[str] = mapped_column(String(40))
    template: Mapped[str] = mapped_column(Text)
    __table_args__ = (UniqueConstraint("name", "version"),)
