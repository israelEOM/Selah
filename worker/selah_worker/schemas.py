"""Shapes the model must return. Windows are transcript line numbers, never timestamps."""
from typing import Literal, Optional

from pydantic import BaseModel, Field


class ReferenceOut(BaseModel):
    reference: str = Field(description="Book chapter:verse, e.g. '2 Reyes 4:1-7'")
    classification: Literal["explicit", "quoted", "possible"]
    confidence: float = Field(ge=0, le=1)
    window: int = Field(description="Number of the transcript line where it appears")
    excerpt: str = Field(description="The preacher's exact words from that line, at most 30 words")


class PointOut(BaseModel):
    title: str
    summary: str
    subpoints: list[str]
    references: list[str]
    application: Optional[str] = Field(default=None, description="Application the preacher made, or null")
    start_window: int
    end_window: int


class QuoteOut(BaseModel):
    text: str = Field(description="Verbatim words of the preacher, one or two sentences")
    window: int


class AnalysisOut(BaseModel):
    suggested_title: str
    preacher: Optional[str] = None
    central_theme: str
    main_passage: Optional[str] = None
    objective: Optional[str] = None
    introduction: str
    points: list[PointOut]
    conclusion: Optional[str] = None
    applications: list[str]
    illustrations: list[str]
    quotes: list[QuoteOut]
    references: list[ReferenceOut]
    sermon_start_window: int
    sermon_end_window: int


class SummaryPointOut(BaseModel):
    point_index: int = Field(description="Index of the analysis point this summarises, starting at 0")
    title: str
    summary: str
    subpoints: list[str]
    references: list[str]
    application: Optional[str] = None


class SummaryOut(BaseModel):
    title: str
    central_message: str
    introduction: str
    points: list[SummaryPointOut]
    conclusion: Optional[str] = None
    key_takeaways: list[str]


class DayOut(BaseModel):
    day_number: int
    title: str
    bible_reading: str = Field(description="One reference from the sermon, e.g. 'Salmos 27:14'")
    main_idea: str
    reflection: str
    application: str
    questions: list[str]
    prayer: str
    start_window: int
    end_window: int


class DevotionalOut(BaseModel):
    days: list[DayOut]
