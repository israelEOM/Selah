from datetime import datetime, timezone
from sqlalchemy import select, delete
from app.db.session import SessionLocal
from app.models.models import AIJob, BibleReference, BibleVersion, DevotionalDay, Sermon, SermonAnalysis, SermonStatus, Study, StudyStatus, Transcript, TranscriptSegment
from app.services import ai
from app.services.transcripts import normalize, within_interval
from app.services.youtube import fetch_transcript
from app.services.bible import syntactically_valid
from app.tasks.celery_app import celery

def _job(db, job_id): return db.get(AIJob, job_id)
def _finish(job, metrics=None):
    job.status="COMPLETED"; job.completed_at=datetime.now(timezone.utc)
    if metrics:
        job.input_tokens=metrics.get("input_tokens"); job.output_tokens=metrics.get("output_tokens")
def _fail(db, job, sermon, error):
    job.status="FAILED"; job.error_message=str(error)[:4000]; job.completed_at=datetime.now(timezone.utc); sermon.status=SermonStatus.FAILED; db.commit()

@celery.task(bind=True, autoretry_for=(ConnectionError,), retry_backoff=True, max_retries=3)
def retrieve_transcript(self, sermon_id: int, job_id: int):
    db=SessionLocal(); job=_job(db, job_id); sermon=db.get(Sermon, sermon_id)
    try:
        job.status="RUNNING"; sermon.status=SermonStatus.FETCHING_TRANSCRIPT; db.commit()
        segments, is_auto = fetch_transcript(sermon.youtube_video_id, sermon.transcript_language)
        segments=within_interval(segments, sermon.start_seconds, sermon.end_seconds)
        db.execute(delete(Transcript).where(Transcript.sermon_id==sermon.id)); db.flush()
        transcript=Transcript(sermon_id=sermon.id, language=sermon.transcript_language, source="YOUTUBE", is_auto_generated=is_auto, raw_text=" ".join(s["text"] for s in segments), normalized_text=" ".join(normalize(s["text"]) for s in segments), status="READY")
        db.add(transcript); db.flush()
        for seq, item in enumerate(segments): db.add(TranscriptSegment(transcript_id=transcript.id, start_seconds=item["start"], duration_seconds=item.get("duration"), text=normalize(item["text"]), sequence=seq))
        sermon.status=SermonStatus.TRANSCRIPT_READY; _finish(job); db.commit()
    except Exception as exc: _fail(db, job, sermon, exc); raise
    finally: db.close()

@celery.task(bind=True, autoretry_for=(ConnectionError,), retry_backoff=True, max_retries=2)
def analyze_sermon(self, sermon_id: int, job_id: int):
    db=SessionLocal(); job=_job(db, job_id); sermon=db.get(Sermon, sermon_id)
    try:
        existing=db.scalar(select(SermonAnalysis).where(SermonAnalysis.sermon_id==sermon_id))
        if existing: _finish(job); db.commit(); return
        transcript=db.scalar(select(Transcript).where(Transcript.sermon_id==sermon_id).order_by(Transcript.id.desc()))
        if not transcript: raise RuntimeError("No hay transcript disponible para analizar.")
        job.status="RUNNING"; sermon.status=SermonStatus.ANALYZING; db.commit()
        output, metrics=ai.analyze(transcript.normalized_text or transcript.raw_text or "")
        data=output.model_dump(); db.add(SermonAnalysis(sermon_id=sermon_id, model=job.model, prompt_version=job.prompt_version, structured_content=data))
        sermon.suggested_title=data["suggested_title"]
        version=db.scalar(select(BibleVersion).where(BibleVersion.code==sermon.bible_version_code))
        for ref in data["references"]:
            db.add(BibleReference(sermon_id=sermon_id, canonical_reference=ref["reference"], bible_version_id=version.id if version else None, classification=ref["classification"], confidence=ref["confidence"], timestamp_seconds=ref["timestamp_seconds"], source_excerpt=ref["source_excerpt"], verification_status="VERIFIED_FORMAT" if syntactically_valid(ref["reference"]) else "REVIEW_REQUIRED"))
        sermon.status=SermonStatus.VERIFYING_REFERENCES; _finish(job,metrics); db.commit()
    except Exception as exc: _fail(db, job, sermon, exc); raise
    finally: db.close()

@celery.task(bind=True)
def generate_summary(self, sermon_id: int, job_id: int):
    db=SessionLocal(); job=_job(db, job_id); sermon=db.get(Sermon, sermon_id)
    try:
        analysis=db.scalar(select(SermonAnalysis).where(SermonAnalysis.sermon_id==sermon_id))
        if not analysis: raise RuntimeError("Primero complete el análisis.")
        job.status="RUNNING"; sermon.status=SermonStatus.GENERATING_SUMMARY; db.commit()
        output,metrics=ai.summarize(analysis.structured_content); version=db.scalar(select(BibleVersion).where(BibleVersion.code==sermon.bible_version_code))
        study=db.scalar(select(Study).where(Study.sermon_id==sermon_id))
        if not study:
            title=sermon.suggested_title or sermon.original_title or "Estudio Selah"; slug=f"{title.lower().replace(' ', '-')[:450]}-{sermon.id}"
            study=Study(sermon_id=sermon.id,title=title,slug=slug,language=sermon.study_language,bible_version_id=version.id if version else None); db.add(study)
        study.summary=output.model_dump(); study.status=StudyStatus.DRAFT; _finish(job,metrics); db.commit()
    except Exception as exc: _fail(db, job, sermon, exc); raise
    finally: db.close()

@celery.task(bind=True)
def generate_devotional(self, sermon_id: int, job_id: int, days: int=5):
    db=SessionLocal(); job=_job(db, job_id); sermon=db.get(Sermon, sermon_id)
    try:
        analysis=db.scalar(select(SermonAnalysis).where(SermonAnalysis.sermon_id==sermon_id)); study=db.scalar(select(Study).where(Study.sermon_id==sermon_id))
        if not analysis or not study: raise RuntimeError("Primero complete el análisis y el resumen.")
        job.status="RUNNING"; sermon.status=SermonStatus.GENERATING_DEVOTIONAL; db.commit()
        output,metrics=ai.devotional(analysis.structured_content,days); db.execute(delete(DevotionalDay).where(DevotionalDay.study_id==study.id))
        for day in output.days: db.add(DevotionalDay(study_id=study.id, day_number=day.day_number, title=day.title, main_reference=day.main_reference, content=day.model_dump(), estimated_reading_minutes=day.estimated_reading_minutes))
        study.status=StudyStatus.AWAITING_REVIEW; sermon.status=SermonStatus.AWAITING_REVIEW; _finish(job,metrics); db.commit()
    except Exception as exc: _fail(db, job, sermon, exc); raise
    finally: db.close()
