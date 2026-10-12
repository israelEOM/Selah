from datetime import datetime, timezone
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.api.deps import admin_user, current_user
from app.core.config import settings
from app.core.security import create_token, verify_password
from app.db.session import get_db
from app.models.models import AIJob, BibleReference, BibleVersion, DevotionalDay, Role, Sermon, SermonAnalysis, SermonStatus, Study, StudyStatus, Transcript, TranscriptSegment, User, UserNote, UserStudyProgress
from app.schemas.contracts import LoginRequest, ManualTranscriptIn, MetadataOut, NoteIn, ProgressIn, SermonCreate, SermonPatch, StudyPatch, TokenOut, UserOut, YouTubeUrlRequest
from app.services.bible import provider
from app.services.transcripts import normalize, parse_manual, within_interval
from app.services.youtube import YouTubeError, extract_video_id, metadata, transcript_languages
from app.tasks import analyze_sermon, generate_devotional, generate_summary, retrieve_transcript
from app.services.ai import PROMPT_VERSION

router=APIRouter()
def user_out(u): return {"id":u.id,"email":u.email,"display_name":u.display_name,"role":u.role.value}
def sermon_out(s): return {"id":s.id,"youtube_video_id":s.youtube_video_id,"youtube_url":s.youtube_url,"original_title":s.original_title,"suggested_title":s.suggested_title,"channel_name":s.channel_name,"speaker":s.speaker,"duration_seconds":s.duration_seconds,"thumbnail_url":s.thumbnail_url,"start_seconds":s.start_seconds,"end_seconds":s.end_seconds,"status":s.status.value,"original_language":s.original_language,"transcript_language":s.transcript_language,"study_language":s.study_language,"bible_version_code":s.bible_version_code}
def study_out(study, db):
    sermon=db.get(Sermon,study.sermon_id); days=list(db.scalars(select(DevotionalDay).where(DevotionalDay.study_id==study.id).order_by(DevotionalDay.day_number)))
    return {"id":study.id,"slug":study.slug,"title":study.title,"language":study.language,"status":study.status.value,"summary":study.summary,"published_at":study.published_at,"sermon":sermon_out(sermon),"days":[{"id":d.id,"day_number":d.day_number,"title":d.title,"main_reference":d.main_reference,"content":d.content,"estimated_reading_minutes":d.estimated_reading_minutes} for d in days]}
def make_job(db, sermon_id, job_type):
    existing=db.scalar(select(AIJob).where(AIJob.sermon_id==sermon_id,AIJob.job_type==job_type,AIJob.status.in_(["PENDING","RUNNING"])))
    if existing: return existing,False
    job=AIJob(sermon_id=sermon_id,job_type=job_type,status="PENDING",model=settings.openai_model,prompt_version=PROMPT_VERSION); db.add(job); db.commit(); db.refresh(job); return job,True

@router.post("/auth/login", response_model=TokenOut)
def login(body:LoginRequest,response:Response,db:Session=Depends(get_db)):
    user=db.scalar(select(User).where(User.email==body.email.lower()))
    if not user or not verify_password(body.password,user.password_hash): raise HTTPException(status_code=401,detail="Correo o contraseña incorrectos")
    token=create_token(str(user.id),user.role.value); response.set_cookie("session",token,httponly=True,secure=False,samesite="lax",max_age=settings.access_token_hours*3600)
    return {"access_token":token,"user":user_out(user)}
@router.post("/auth/logout",status_code=204)
def logout(response:Response): response.delete_cookie("session")
@router.get("/auth/me",response_model=UserOut)
def me(user:User=Depends(current_user)): return user_out(user)

@router.post("/youtube/metadata",response_model=MetadataOut)
async def youtube_metadata(body:YouTubeUrlRequest,user:User=Depends(admin_user)):
    try:return await metadata(body.url)
    except YouTubeError as exc:raise HTTPException(status_code=422,detail=str(exc))
@router.get("/youtube/{video_id}/transcript-languages")
def youtube_languages(video_id:str,user:User=Depends(admin_user)):
    try:return transcript_languages(video_id)
    except YouTubeError as exc:raise HTTPException(status_code=502,detail=str(exc))

@router.get("/sermons")
def sermons(db:Session=Depends(get_db),user:User=Depends(admin_user)): return [sermon_out(x) for x in db.scalars(select(Sermon).order_by(Sermon.created_at.desc()))]
@router.post("/sermons",status_code=201)
async def create_sermon(body:SermonCreate,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    try: data=await metadata(body.youtube_url)
    except YouTubeError as exc: raise HTTPException(status_code=422,detail=str(exc))
    if body.end_seconds and data["duration_seconds"] and body.end_seconds>data["duration_seconds"]: raise HTTPException(status_code=422,detail="El final excede la duración del video")
    if body.end_seconds and body.end_seconds<=body.start_seconds: raise HTTPException(status_code=422,detail="El final debe ser mayor que el inicio")
    if db.scalar(select(Sermon).where(Sermon.youtube_video_id==data["video_id"])): raise HTTPException(status_code=409,detail="Este video ya fue importado")
    sermon=Sermon(**data,original_language=body.original_language,transcript_language=body.transcript_language,study_language=body.study_language,bible_version_code=body.bible_version_code,start_seconds=body.start_seconds,end_seconds=body.end_seconds,created_by=user.id)
    db.add(sermon);db.commit();db.refresh(sermon);return sermon_out(sermon)
@router.get("/sermons/{sermon_id}")
def sermon(sermon_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    item=db.get(Sermon,sermon_id)
    if not item:raise HTTPException(404,"Sermón no encontrado")
    return sermon_out(item)
@router.patch("/sermons/{sermon_id}")
def patch_sermon(sermon_id:int,body:SermonPatch,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    item=db.get(Sermon,sermon_id)
    if not item:raise HTTPException(404,"Sermón no encontrado")
    for k,v in body.model_dump(exclude_unset=True).items():setattr(item,k,v)
    if item.end_seconds and item.end_seconds<=item.start_seconds:raise HTTPException(422,"El final debe ser mayor que el inicio")
    db.commit();return sermon_out(item)
@router.post("/sermons/{sermon_id}/transcript",status_code=202)
def enqueue_transcript(sermon_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    if not db.get(Sermon,sermon_id):raise HTTPException(404,"Sermón no encontrado")
    job,new=make_job(db,sermon_id,"TRANSCRIPT")
    if new:retrieve_transcript.delay(sermon_id,job.id)
    return {"id":job.id,"status":job.status,"job_type":job.job_type}
@router.post("/sermons/{sermon_id}/transcript/manual",status_code=201)
def manual_transcript(sermon_id:int,body:ManualTranscriptIn,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    sermon=db.get(Sermon,sermon_id)
    if not sermon:raise HTTPException(404,"Sermón no encontrado")
    segments=parse_manual(body.text,body.format); segments=within_interval(segments,sermon.start_seconds,sermon.end_seconds) if body.format.lower()!="txt" else segments
    transcript=Transcript(sermon_id=sermon_id,language=body.language,source="MANUAL",is_auto_generated=False,raw_text=body.text,normalized_text=" ".join(x["text"] for x in segments),status="READY");db.add(transcript);db.flush()
    for i,s in enumerate(segments):db.add(TranscriptSegment(transcript_id=transcript.id,start_seconds=s["start"],duration_seconds=s["duration"],text=s["text"],sequence=i))
    sermon.status=SermonStatus.TRANSCRIPT_READY;db.commit();return {"transcript_id":transcript.id,"timestamp_features_enabled":body.format.lower()!="txt"}
@router.get("/sermons/{sermon_id}/transcript")
def get_transcript(sermon_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    t=db.scalar(select(Transcript).where(Transcript.sermon_id==sermon_id).order_by(Transcript.id.desc()))
    if not t:raise HTTPException(404,"Transcript no encontrado")
    return {"id":t.id,"language":t.language,"source":t.source,"segments":[{"start_seconds":s.start_seconds,"duration_seconds":s.duration_seconds,"text":s.text,"sequence":s.sequence} for s in db.scalars(select(TranscriptSegment).where(TranscriptSegment.transcript_id==t.id).order_by(TranscriptSegment.sequence))]}
@router.post("/sermons/{sermon_id}/analyze",status_code=202)
def enqueue_analysis(sermon_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    if not db.get(Sermon,sermon_id):raise HTTPException(404,"Sermón no encontrado")
    job,new=make_job(db,sermon_id,"ANALYSIS")
    if new:analyze_sermon.delay(sermon_id,job.id)
    return {"id":job.id,"status":job.status,"job_type":job.job_type}
@router.get("/sermons/{sermon_id}/analysis")
def get_analysis(sermon_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    a=db.scalar(select(SermonAnalysis).where(SermonAnalysis.sermon_id==sermon_id))
    if not a:raise HTTPException(404,"Análisis no encontrado")
    refs=db.scalars(select(BibleReference).where(BibleReference.sermon_id==sermon_id)).all();return {"content":a.structured_content,"references":[{"id":r.id,"reference":r.canonical_reference,"classification":r.classification,"verification_status":r.verification_status,"confidence":r.confidence} for r in refs]}

@router.get("/studies")
def studies(db:Session=Depends(get_db),user:User|None=Depends(current_user)):
    query=select(Study).order_by(Study.published_at.desc().nullslast()) if user.role==Role.ADMIN else select(Study).where(Study.status==StudyStatus.PUBLISHED)
    return [study_out(x,db) for x in db.scalars(query)]
@router.post("/studies/{study_id}/generate-summary",status_code=202)
def enqueue_summary(study_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    st=db.get(Study,study_id)
    if not st:raise HTTPException(404,"Estudio no encontrado")
    job,new=make_job(db,st.sermon_id,"SUMMARY")
    if new:generate_summary.delay(st.sermon_id,job.id)
    return {"id":job.id,"status":job.status,"job_type":job.job_type}
@router.post("/sermons/{sermon_id}/generate-summary",status_code=202)
def summary_from_sermon(sermon_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    job,new=make_job(db,sermon_id,"SUMMARY")
    if new:generate_summary.delay(sermon_id,job.id)
    return {"id":job.id,"status":job.status,"job_type":job.job_type}
@router.get("/studies/{study_id}")
def study(study_id:int,db:Session=Depends(get_db),user:User=Depends(current_user)):
    st=db.get(Study,study_id)
    if not st or (st.status!=StudyStatus.PUBLISHED and user.role!=Role.ADMIN):raise HTTPException(404,"Estudio no encontrado")
    return study_out(st,db)
@router.get("/public/studies/{slug}")
def public_study(slug:str,db:Session=Depends(get_db),user:User=Depends(current_user)):
    st=db.scalar(select(Study).where(Study.slug==slug))
    if not st or (st.status!=StudyStatus.PUBLISHED and user.role!=Role.ADMIN):raise HTTPException(404,"Estudio no encontrado")
    return study_out(st,db)
@router.patch("/studies/{study_id}")
def patch_study(study_id:int,body:StudyPatch,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    st=db.get(Study,study_id)
    if not st:raise HTTPException(404,"Estudio no encontrado")
    for k,v in body.model_dump(exclude_unset=True).items():setattr(st,k,v)
    db.commit();return study_out(st,db)
@router.post("/studies/{study_id}/generate-devotional",status_code=202)
def enqueue_devotional(study_id:int,days:int=5,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    if days not in (1,3,5,7):raise HTTPException(422,"La duración debe ser 1, 3, 5 o 7 días")
    st=db.get(Study,study_id)
    if not st:raise HTTPException(404,"Estudio no encontrado")
    job,new=make_job(db,st.sermon_id,"DEVOTIONAL")
    if new:generate_devotional.delay(st.sermon_id,job.id,days)
    return {"id":job.id,"status":job.status,"job_type":job.job_type}
@router.post("/studies/{study_id}/publish")
def publish(study_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    st=db.get(Study,study_id)
    if not st or not db.scalar(select(DevotionalDay).where(DevotionalDay.study_id==study_id)):raise HTTPException(422,"El estudio requiere resumen y devocionales antes de publicarse")
    st.status=StudyStatus.PUBLISHED;st.reviewed_by=user.id;st.published_at=datetime.now(timezone.utc);sermon=db.get(Sermon,st.sermon_id);sermon.status=SermonStatus.PUBLISHED;db.commit();return study_out(st,db)
@router.post("/studies/{study_id}/unpublish")
def unpublish(study_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    st=db.get(Study,study_id)
    if not st:raise HTTPException(404,"Estudio no encontrado")
    st.status=StudyStatus.DRAFT;st.published_at=None;db.commit();return study_out(st,db)

@router.get("/bible/versions")
def bible_versions(db:Session=Depends(get_db),user:User=Depends(current_user)): return [{"code":x.code,"name":x.name,"language":x.language,"attribution":x.copyright_notice} for x in db.scalars(select(BibleVersion).where(BibleVersion.is_enabled==True))]
@router.get("/bible/references/{reference}")
async def bible_reference(reference:str,version:str|None=None,user:User=Depends(current_user)): return await provider.validate(reference,version or "RVR1960")
@router.get("/jobs/{job_id}")
def job(job_id:int,db:Session=Depends(get_db),user:User=Depends(admin_user)):
    j=db.get(AIJob,job_id)
    if not j:raise HTTPException(404,"Trabajo no encontrado")
    return {"id":j.id,"status":j.status,"job_type":j.job_type,"error_message":j.error_message,"started_at":j.started_at,"completed_at":j.completed_at}

@router.get("/me/progress")
def progress(db:Session=Depends(get_db),user:User=Depends(current_user)):return [{"study_id":x.study_id,"day_number":x.day_number,"completed_at":x.completed_at} for x in db.scalars(select(UserStudyProgress).where(UserStudyProgress.user_id==user.id))]
@router.post("/me/progress",status_code=201)
def complete(body:ProgressIn,db:Session=Depends(get_db),user:User=Depends(current_user)):
    st=db.get(Study,body.study_id)
    if not st or st.status!=StudyStatus.PUBLISHED:raise HTTPException(404,"Estudio no encontrado")
    entry=db.scalar(select(UserStudyProgress).where(UserStudyProgress.user_id==user.id,UserStudyProgress.study_id==body.study_id,UserStudyProgress.day_number==body.day_number))
    if not entry:entry=UserStudyProgress(user_id=user.id,study_id=body.study_id,day_number=body.day_number);db.add(entry);db.commit()
    return {"study_id":entry.study_id,"day_number":entry.day_number,"completed_at":entry.completed_at}
@router.get("/me/notes")
def notes(db:Session=Depends(get_db),user:User=Depends(current_user)):return [{"id":x.id,"study_id":x.study_id,"devotional_day_id":x.devotional_day_id,"content":x.content,"updated_at":x.updated_at} for x in db.scalars(select(UserNote).where(UserNote.user_id==user.id))]
@router.post("/me/notes",status_code=201)
def add_note(body:NoteIn,db:Session=Depends(get_db),user:User=Depends(current_user)):
    note=UserNote(user_id=user.id,**body.model_dump());db.add(note);db.commit();db.refresh(note);return {"id":note.id,"content":note.content}
@router.patch("/me/notes/{note_id}")
def update_note(note_id:int,body:NoteIn,db:Session=Depends(get_db),user:User=Depends(current_user)):
    note=db.get(UserNote,note_id)
    if not note or note.user_id!=user.id:raise HTTPException(404,"Nota no encontrada")
    note.content=body.content;db.commit();return {"id":note.id,"content":note.content}
@router.delete("/me/notes/{note_id}",status_code=204)
def delete_note(note_id:int,db:Session=Depends(get_db),user:User=Depends(current_user)):
    note=db.get(UserNote,note_id)
    if not note or note.user_id!=user.id:raise HTTPException(404,"Nota no encontrada")
    db.delete(note);db.commit()
