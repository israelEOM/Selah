# Selah — Improved MVP Plan (web, iOS, Android)

Written 2026-10-12 after reviewing the original brief, the current repository, and the NeoSkin project.

## 1. Goal

One church admin pastes a YouTube sermon URL and, after review, publishes a devotional study that members read on the web, on iPhone and on Android. The 21-step acceptance scenario from the original brief (§29) still defines "done", with one addition: steps 17–21 must pass on all three platforms.

## 2. What exists today

The repository is a first-pass scaffold (about 1,000 lines) of Next.js + FastAPI + Celery + Redis + Postgres. It has never been run end to end: there is no git history, `OPENAI_API_KEY` is empty, and no Selah containers exist.

### Worth keeping

| Piece | File | Notes |
|---|---|---|
| YouTube URL parsing and metadata (oEmbed, optional Data API) | `apps/api/app/services/youtube.py` | Works for `watch`, `live`, `youtu.be`; has tests |
| Range filtering and SRT/VTT manual import | `apps/api/app/services/transcripts.py` | Manual upload is a useful fallback; has tests |
| Bible provider abstraction (reference only, links to external reader) | `apps/api/app/services/bible.py` | Right licensing stance for RVR1960 |
| Pydantic output contracts for analysis, summary, devotional | `apps/api/app/schemas/contracts.py` | Good base; needs the changes in §5 |
| Job record with model, prompt version, tokens, error | `AIJob` in `models.py` | Keep the idea, move to the new schema |
| Visual identity: deep green, cream, soft gold, serif headings | `apps/web/tailwind.config.ts`, `globals.css` | Carry the tokens into the Flutter theme |
| Spanish UI copy | all pages | Reuse as the first l10n catalogue |

### Broken or missing

These block the acceptance scenario and are the reason this plan differs from "finish the scaffold".

1. **Members cannot read anything.** `GET /studies` and `GET /public/studies/{slug}` both require a signed-in user, so the public home, library, study page and reader return 401 for anonymous visitors.
2. **Timestamps are not grounded.** The analysis call receives the transcript as plain text with the timestamps stripped, then asks the model for `timestamp_seconds`. Any timestamp it returns is a guess. The "watch this part of the sermon" feature cannot be trusted as built.
3. **Summary and devotional get no source text.** They receive `str(analysis)` (a Python dict repr) with no transcript excerpts, so the devotional is two steps removed from what the preacher said.
4. **Output language is ignored.** The system prompt hard-codes "Responde en español"; `study_language` is stored but never used.
5. **Language selection is not real.** The import form offers a fixed es/pt/en list. The endpoint that lists the captions actually available is never called. `is_auto_generated` is always saved as `False`.
6. **No regeneration.** `analyze_sermon` returns early when an analysis exists. A failed job sets the sermon to `FAILED` with no way back.
7. **No editor, preview or settings.** There is no endpoint to edit devotional days or Bible references. The admin screen can only publish. Settings and members pages are placeholder text. The day count is hard-coded to 5.
8. **No progress display.** The admin page refetches every 5 seconds and shows a status word; the step-by-step progress the brief requires (§25) does not exist.
9. **Migrations are not migrations.** The single Alembic revision calls `Base.metadata.create_all`, and the app also calls it on startup.
10. **Auth is weak.** The JWT is kept in `localStorage`, the cookie is `secure=False`, there is no rate limiting, no sign-up, no password reset, and the "Administrar" link is shown to everyone.
11. **Smaller defects.** Slugs keep accents and punctuation; `youtube-transcript-api` is pinned to an old release; the web code uses Tailwind classes that do not exist (`h-18`, `prose` without the typography plugin); `.env` has `API_BIBLE_*` keys the code no longer reads; most source files are single very long lines.

## 3. Decisions that change the original brief

### 3.1 One Flutter client instead of Next.js (recommended)

The original brief excludes native apps. You now want web, iOS and Android, as with NeoSkin. A single Flutter codebase covers all three and reuses the NeoSkin structure (Riverpod, go_router, repository layer, l10n, Cloudflare Pages deploy). Keeping Next.js would mean building and maintaining every screen twice.

Costs to accept:

- The Next.js app (about 150 lines of real UI) is discarded.
- Flutter web gives no link previews or SEO by itself. Members will share study links in WhatsApp, so Phase 5 adds a small Cloudflare Pages Function that returns Open Graph tags (title, thumbnail) for `/studies/*`.
- NeoSkin has no `android/` folder yet, so Android is new ground: signing, Play Console and device testing are included in Phase 5.

### 3.2 Supabase for data and auth, plus a small Python worker (recommended)

| Concern | Original brief | This plan |
|---|---|---|
| Database | Postgres + SQLAlchemy + Alembic | Supabase Postgres + SQL migrations |
| Auth and roles | Custom bcrypt/JWT | Supabase Auth + row-level security |
| CRUD API | FastAPI routes | Direct Supabase access from the app, guarded by RLS |
| Pipeline (YouTube, AI) | FastAPI + Celery + Redis | One Python FastAPI worker, jobs stored in a Postgres table |
| Live job status | Polling | Supabase Realtime on the jobs table |

Why: it removes Redis, Celery, custom auth and most of `routes.py`, which are the weakest parts of the scaffold, and it matches what you already run for NeoSkin. Python stays where it earns its place: `youtube-transcript-api` and the AI pipeline.

The alternative is to keep FastAPI + Postgres for everything and point Flutter at it. That preserves more of the existing code but means writing auth, password reset, RLS-equivalent checks and hosting a database yourself. **This is the one decision I need you to confirm before implementation starts.**

### 3.3 Members read without an account

Published studies are public. Progress ("day 3 of 5 done") is stored on the device. This satisfies the brief's "member authentication is optional" and avoids App Store requirements that come with member accounts (Sign in with Apple, in-app account deletion). Member accounts, synced progress and notes move to Phase 2 of the roadmap. Only admins sign in.

### 3.4 Fewer tables than the brief's data model

Sermon points, subpoints and reflection questions stay as validated JSON inside their parent rows rather than separate tables. They are always read and edited together with the parent, and nothing in the MVP queries them independently. Bible references stay as rows, because admins approve and edit them one by one.

### 3.5 YouTube blocks caption requests from cloud servers

`youtube-transcript-api` works from a home connection and is frequently blocked from datacenter IPs. The brief does not mention this, and it decides where the worker can run. The plan:

- The worker accepts an optional proxy setting (the library supports rotating residential proxies).
- Manual SRT/VTT upload stays as the fallback in the admin UI.
- Phase 1 tests caption retrieval from the intended host before anything else is built on it.

## 4. Target architecture

```text
Flutter app (web · iOS · Android)
   │  reads published studies (anonymous)            ┌──────────────┐
   │  admin CRUD, edits, publish (RLS: admin only) ─▶│   Supabase   │
   │  live job status (Realtime)                    ◀│ Postgres/Auth│
   │                                                 └──────▲───────┘
   │  import / generate / regenerate (admin JWT)            │ service role
   └────────────────────────────────────────────▶ Python worker (FastAPI)
                                                    ├─ YouTube metadata + captions
                                                    ├─ OpenAI structured outputs
                                                    └─ Bible reference parser
```

Repository layout after restructuring:

```text
app/        Flutter client (lib/src/{app,core,data,features,l10n}, ios, android, web)
supabase/   migrations, RLS policies, seed (RVR1960, church settings), config
worker/     Python pipeline (from apps/api: services, schemas, tests)
docs/
```

`apps/web`, `packages/shared`, `infra`, Redis and Celery are removed.

### Data model

| Table | Key columns |
|---|---|
| `profiles` | user id, name, role (`admin` / `member`) |
| `church_settings` | church name, default languages, default Bible version, default days |
| `bible_versions` | code, name, language, provider, provider id, copyright notice, active |
| `sermons` | video id, url, title, slug, channel, preacher, thumbnail, sermon date, duration, original language, start/end seconds |
| `transcripts` | sermon id, language, source (`youtube` / `manual`), is auto-generated, segments (JSON array of `{text, start, duration}`), raw text |
| `sermon_analyses` | sermon id, content (JSON), model, prompt version, tokens |
| `bible_references` | sermon id, reference, book/chapter/verse, classification, confidence, start seconds, excerpt, approved |
| `studies` | sermon id, title, slug, output language, Bible version, number of days, summary (JSON), status, published at |
| `devotional_days` | study id, day number, title, reading, main idea, reflection, application, questions (JSON), prayer, start/end seconds |
| `jobs` | sermon id, step, status, error, model, prompt version, tokens, timestamps |

Study status: `draft → generating → review → published` (and back to `review` on unpublish). Failures live on the job, never on the sermon, so every step can be retried.

## 5. AI pipeline

The four changes that matter most for fidelity:

1. **Timestamped input.** Caption segments are merged into windows of about 30 seconds and sent as numbered lines, for example `[#42 00:21:10] …`. The model cites window numbers; the worker converts them to seconds. The model never writes a timestamp itself.
2. **Quotes are checked.** Every "important quote" is matched against the transcript. Quotes that are not found are dropped and logged.
3. **References are parsed, not trusted.** A deterministic parser maps Spanish, Portuguese and English book names to canonical book/chapter/verse and rejects impossible references. `POSSIBLE` references are shown only to the admin until approved.
4. **Devotional sees source text.** Summary and devotional calls receive the analysis as JSON plus the transcript windows for the sections they draw on, and an explicit output language.

Calls per sermon:

| Step | Input | Output |
|---|---|---|
| Analysis | Full timestamped transcript (once) | Title, theme, main passage, objective, intro, points and subpoints, conclusion, applications, illustrations, quotes, references, window numbers |
| Summary | Analysis JSON | Readable summary in the output language |
| Devotional | Analysis JSON + relevant windows + day count | 1, 3, 5 or 7 days in the format of the brief §12 |

A 60–90 minute sermon fits in one analysis call, so no chunk-and-merge stage is needed. Regenerating a devotional with a different day count reuses the stored analysis. The model name stays in an environment variable; every run stores model, prompt version, tokens and duration.

Spanish auto-captions have no punctuation and often mis-hear book names. The analysis prompt will say so, and the admin review step exists for exactly this.

## 6. Phases

Each phase ends with something you can verify.

### Phase 0 — Foundations

- `git init`, first commit of the current state, then restructure to the layout in §4.
- Create the Supabase project; write migrations, RLS policies and seed data.
- Create the Flutter app with web, iOS and Android targets; port the theme tokens and Spanish copy.

Done when: the app shell runs on Chrome, the iOS Simulator and an Android emulator, and an admin can sign in.

### Phase 1 — Real pipeline, no UI

- Port `youtube.py`, `transcripts.py`, `bible.py`; update `youtube-transcript-api`; record real `is_generated`.
- Implement windowing, the three AI steps, quote check and reference parser.
- A command-line run takes a real sermon URL and writes transcript, analysis, references, summary and a 5-day devotional to Supabase.
- Test caption retrieval from the intended worker host.

Done when: one real Spanish sermon from the church produces a devotional you consider faithful, and every timestamp link lands on the right moment.

### Phase 2 — Admin import and generation

- Import wizard: URL → metadata and thumbnail → captions actually available → original language, output language, Bible version → full sermon or range → day count.
- One "Generate" action runs all steps; a live stepper shows each one, with a retry button on failure.
- Sermon list, transcript view, analysis view.

Done when: acceptance steps 1–13 pass from the browser.

### Phase 3 — Review, edit, publish

- Editor for title, theme, summary, points, references (approve, edit, remove), each devotional day, questions and prayer.
- Regenerate summary or devotional; change day count.
- Preview that uses the same widgets as the member reader.
- Publish and unpublish; settings page.

Done when: acceptance steps 14–16 pass.

### Phase 4 — Member experience

- Home with the devotional of the week and recent studies; library; study page.
- Devotional reader: day progress dots, reading link to the external Bible reader, reflection, application, questions, prayer, "watch this part of the sermon", previous/next day.
- Progress stored on the device; share button.

Done when: acceptance steps 17–21 pass on a phone browser.

### Phase 5 — Three platforms and hardening

- iOS and Android builds: icons, splash, bundle ids, signing, TestFlight and Play internal testing.
- Web deploy to Cloudflare Pages with Open Graph tags for study links; worker deploy with secrets and optional proxy.
- UI languages es / pt / en; error states for every case in the brief §26; rate limit on generation endpoints.
- Tests: worker unit tests with recorded fixtures, RLS tests (anonymous sees only published), Flutter widget tests for reader and editor, one scripted end-to-end run.

Done when: the full acceptance scenario passes on web, an iPhone and an Android phone against the hosted backend.

## 7. What I need from you

| Item | Needed for |
|---|---|
| Confirm §3.2 (Supabase + worker) or choose FastAPI-only | Phase 0 |
| OpenAI API key | Phase 1 |
| Supabase project (new, or an organisation to create it in) | Phase 0 |
| Two or three real sermon URLs from the church, with Spanish captions | Phase 1 |
| Where the worker should run (your machine for the pilot, or a cloud host) | Phase 1 |
| Apple Developer and Google Play accounts, bundle id | Phase 5 |

## 8. Still out of scope

Unchanged from the brief §30, except that iOS and Android apps are now in scope: payments, multiple churches, comments, chatbot, Whisper transcription, audio download, analytics, push notifications, gamification. Member accounts, synced progress and notes move to the post-MVP roadmap.
