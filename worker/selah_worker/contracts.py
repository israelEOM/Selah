from datetime import datetime
from pydantic import BaseModel, EmailStr, Field, field_validator

class LoginRequest(BaseModel): email: EmailStr; password: str = Field(min_length=8)
class UserOut(BaseModel): id: int; email: EmailStr; display_name: str | None; role: str
class TokenOut(BaseModel): access_token: str; token_type: str = "bearer"; user: UserOut
class YouTubeUrlRequest(BaseModel): url: str
class MetadataOut(BaseModel): video_id: str; title: str | None = None; channel_name: str | None = None; duration_seconds: int | None = None; thumbnail_url: str | None = None; published_at: datetime | None = None
class SermonCreate(BaseModel):
    youtube_url: str
    original_language: str = "es"
    transcript_language: str = "es"
    study_language: str = "es"
    bible_version_code: str = "RVR1960"
    start_seconds: int = Field(ge=0)
    end_seconds: int | None = Field(default=None, gt=0)
    @field_validator("original_language", "transcript_language", "study_language")
    @classmethod
    def supported_language(cls, value: str):
        if value not in {"es", "pt", "en"}: raise ValueError("Solo se admiten es, pt y en inicialmente")
        return value
class SermonPatch(BaseModel): speaker: str | None = None; suggested_title: str | None = None; start_seconds: int | None = Field(default=None, ge=0); end_seconds: int | None = Field(default=None, gt=0)
class ManualTranscriptIn(BaseModel): text: str = Field(min_length=1); format: str = "txt"; language: str = "es"
class JobOut(BaseModel): id: int; status: str; job_type: str; error_message: str | None = None
class StudyPatch(BaseModel): title: str | None = None; summary: dict | None = None
class ProgressIn(BaseModel): study_id: int; day_number: int = Field(ge=1)
class NoteIn(BaseModel): study_id: int; devotional_day_id: int | None = None; content: str = Field(min_length=1, max_length=10000)

class BiblicalReference(BaseModel):
    reference: str
    classification: str = "EXPLICIT_REFERENCE"
    confidence: float = Field(ge=0, le=1)
    timestamp_seconds: float | None = None
    source_excerpt: str | None = None

class SermonPoint(BaseModel): title: str; explanation: str; timestamp_seconds: float | None = None; references: list[str] = []
class SermonAnalysisOutput(BaseModel):
    suggested_title: str
    main_theme: str
    main_passage: str | None = None
    introduction: str
    main_points: list[SermonPoint]
    conclusion: str
    applications: list[str]
    memorable_quotes: list[str] = []
    references: list[BiblicalReference] = []
    grounding_note: str

class SummaryOutput(BaseModel):
    executive_summary: str
    introduction: str
    main_points: list[SermonPoint]
    applications: list[str]
    conclusion: str
    ai_generated_notice: str

class DevotionalDayOutput(BaseModel):
    day_number: int; title: str; main_reference: str; reading_references: list[str]
    central_teaching: str; reflection: str; practical_application: str; questions: list[str]
    suggested_prayer: str; source_timestamp_seconds: float | None = None; estimated_reading_minutes: int = 4
class DevotionalOutput(BaseModel): days: list[DevotionalDayOutput]
