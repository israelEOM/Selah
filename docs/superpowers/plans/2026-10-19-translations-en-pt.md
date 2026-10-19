# English and Brazilian Portuguese Translations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Members can read Selah in English or Brazilian Portuguese: the app's interface, and every published study translated from the church's reviewed Spanish.

**Architecture:** Publishing a study queues one `translate` job. The worker sends the published Spanish text, never the transcript, to Gemini once per language and checks that the structure came back intact. It writes Bible references itself with the existing parser, and stores one row per language in a new `study_translations` table. Members choose a language in the app; the choice is kept on the device. Study pages show the translation with an "automatic translation" notice and a link to the original, and fall back to Spanish with a short note when there is none. The admin can hide a translation or redo it from the sermon page.

**Tech Stack:** Supabase Postgres (migration + RLS), Python worker (Gemini structured output, pytest), Flutter (gen-l10n ARB files, Riverpod 3, shared_preferences).

**Spec:** the request of 2026-10-19: "a translation for English and Portuguese from Brazil… only for the published content (in Spanish from my church)". Context in [docs/MVP_PLAN.md](../../MVP_PLAN.md): §5 (AI fidelity) and the product principle that the sermon and Scripture stay the source.

## Decisions this plan makes (confirm at review)

- **Translations go live without a separate approval.** They translate content the admin already reviewed, every page shows "Traducción automática" in the reader's language with a link to the Spanish, and the admin can hide either language. If you would rather approve each translation before members see it, Task 1's `hidden` defaults to `true` instead, and the admin switch becomes "publish translation"; nothing else changes.
- **Only the study is translated, not the sermon.** Admin screens and the YouTube video stay as they are.
- **Bible versions:** Portuguese readings link to **ARA** (Almeida Revista e Atualizada) and English readings to **NIV**. Selah only links to an outside reader, so no Bible text is stored either way.

## Global Constraints

- Content languages: source `es`; targets exactly `en` and `pt`. `pt` means Brazilian Portuguese wording ("você", Brazilian spelling). These codes match `ai.LANGUAGES` and `studies.output_language`.
- App UI locales: `es` (default), `en`, `pt`. ARB files `app_es.arb`, `app_en.arb`, `app_pt.arb`; every key exists in all three.
- Only studies with `status = 'published'` are translated, and members can only read a translation while its study is published.
- The translator receives the published study text only, never the transcript, so it cannot add sermon content.
- Bible references are never translated by the model. The worker relabels them with `selah_worker.bible.parse_reference(reference, language)`.
- Bible version per target language: `pt` → `ARA`, `en` → `NIV`.
- Every translated page says it is an automatic translation, in the reader's language, and offers the original.
- Supabase CLI and Wrangler need Node 20+: `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH`.

## Review Focus

1. **A study is unpublished, or regenerated and republished, after translating.** Expected: members never see an old translation. RLS hides it while the study is unpublished, and republishing queues a fresh `translate` job that overwrites it. Pinned in Task 1 (anon check) and Task 6 (publish queues the job).
2. **A member picks English before the translation exists, or after it failed or was hidden.** Expected: the Spanish study with the note "This study is not available in English yet.", never an empty page. Pinned in Task 5.
3. **The model returns fewer days, points or questions than the original.** Expected: the job fails with a readable message and nothing is saved. Pinned in Task 2.
4. **Bible references in the translation.** Expected: "2 Reyes 2:25" becomes exactly "2 Kings 2:25" and "2 Reis 2:25", whatever the model wrote. Pinned in Task 2.
5. **Device language `pt-PT`, `en-GB` or `fr`.** Expected: `pt`, `en` and `es` respectively on first open. Pinned in Task 4.

---

### Task 1: `study_translations` table

**Files:**
- Create: `supabase/migrations/202610190001_study_translations.sql`

**Interfaces:**
- Produces table `public.study_translations`:
  `id uuid pk`, `study_id uuid not null references studies on delete cascade`, `language text not null check (language in ('en','pt'))`, `title text not null`, `central_message text`, `summary jsonb not null`, `days jsonb not null` (array of day objects, same keys as `devotional_days` rows minus ids), `bible_version_code text not null references bible_versions(code)`, `hidden boolean not null default false`, `source_updated_at timestamptz not null`, `model text not null`, `prompt_version text not null`, `input_tokens int`, `output_tokens int`, `created_at timestamptz not null default now()`, `unique (study_id, language)`.
- RLS: anon and authenticated can `select` when `not hidden` and the parent study's `status = 'published'`. Admins have all rights (`is_admin()`). The worker writes with the service role.
- `jobs.step` check also allows `'translate'` (drop and re-create the constraint).
- `grant select on public.study_translations to anon`.

- [ ] **Step 1: Write the migration** with the definitions above.

- [ ] **Step 2: Apply it**

  Run: `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx --yes supabase db push --yes`
  Expected: `Applying migration 202610190001_study_translations.sql...` then `Finished supabase db push.`

- [ ] **Step 3: Verify RLS as an anonymous visitor**

  With the worker's service client, insert one translation for the published study and one for a study in `review`. With the publishable key from `app/config/beta.json`:
  `GET /rest/v1/study_translations?select=study_id` must return only the published study's row. Set that row's `hidden = true`: the same request returns `[]`. Delete both rows afterwards.

- [ ] **Step 4: Commit**

  ```bash
  git add supabase/migrations/202610190001_study_translations.sql
  git commit -m "Add study_translations table and the translate job step"
  ```

### Task 2: Worker translate step

**Files:**
- Create: `worker/selah_worker/translation.py`
- Modify: `worker/selah_worker/schemas.py` (translation output models)
- Modify: `worker/selah_worker/ai.py` (`TRANSLATE` prompt, `translate()`)
- Modify: `worker/selah_worker/pipeline.py` (`translate(job)` handler, add it to `HANDLERS`)
- Test: `worker/tests/test_translation.py`

**Interfaces:**
- Consumes: the Task 1 table; `parse_reference(reference, language)` from `selah_worker.bible`.
- Produces:
  - In `schemas.py`: `TranslatedPoint(title, summary, subpoints: list[str], application: Optional[str])`; `TranslatedSummary(introduction: Optional[str], points: list[TranslatedPoint], conclusion: Optional[str], key_takeaways: list[str], quotes: list[str])`; `TranslatedDay(day_number: int, title, main_idea, reflection, application, questions: list[str], prayer)`; `TranslationOut(title, central_message: Optional[str], summary: TranslatedSummary, days: list[TranslatedDay])`.
  - In `translation.py`:
    - `BIBLE_VERSION = {"pt": "ARA", "en": "NIV"}`
    - `source_for_translation(study: dict, days: list[dict]) -> dict`: only the text fields, in the `TranslationOut` shape. No references, timestamps or ids.
    - `merge_translation(study: dict, days: list[dict], out: TranslationOut, language: str) -> dict`: returns `{title, central_message, summary, days, bible_version_code}` ready for `study_translations`. It keeps from the source every non-text field (`start_seconds`, `end_seconds`, `day_number`, each quote's `start_seconds`). It relabels `main_passage`, each point's `references` and each day's `bible_reading` with `parse_reference(..., language)`, keeping the original string when it does not parse. It raises `RuntimeError("La traducción no conserva la estructura del estudio.")` when any of these differ from the source: number of days, day numbers, number of points, subpoints per point, questions per day, key takeaways or quotes.
  - In `ai.py`: `translate(source: dict, language: str) -> tuple[TranslationOut, dict]`, using `generate(TRANSLATE.format(language=…), json.dumps(source, ensure_ascii=False), TranslationOut)`. The prompt says: translate from Spanish into `English` or `português do Brasil`; keep meaning, tone and structure exactly; add and remove nothing; keep quotes faithful to the preacher's words; leave `[` `]` and proper names as they are.
  - In `pipeline.py`: `translate(job: dict) -> dict`. Payload `{"languages": ["en", "pt"]}`. It loads the study by `job["sermon_id"]` and requires `status == 'published'`, else raises `RuntimeError("Solo se traducen estudios publicados.")`. It loads its days, then per language calls `ai.translate`, `merge_translation`, and upserts on `(study_id, language)` with `source_updated_at = study["updated_at"]` and usage. The upsert does not send `hidden`, so an admin's choice survives a redo. Returns `{"languages": [...]} | usage of the last call`.

- [ ] **Step 1: Write the failing tests** in `worker/tests/test_translation.py`, with a fixture study of 2 days (2 questions each), 1 point (2 subpoints, references `["2 Reyes 2:25"]`, `start_seconds: 2183.0`), 2 key takeaways, 1 quote, `main_passage: "2 Reyes 2:25"`, and day 1 `bible_reading: "Salmo 27:14"`:
  - `test_source_has_no_references_or_times` → `"references"`, `"start_seconds"`, `"bible_reading"` and `"main_passage"` do not occur anywhere in `json.dumps(source_for_translation(...))`.
  - `test_merge_relabels_references_in_english` → with a matching `TranslationOut`, `result["summary"]["main_passage"] == "2 Kings 2:25"`, `result["summary"]["points"][0]["references"] == ["2 Kings 2:25"]`, `result["days"][0]["bible_reading"] == "Psalms 27:14"`, `result["bible_version_code"] == "NIV"`.
  - `test_merge_relabels_references_in_portuguese` → `"2 Reis 2:25"`, `"Salmos 27:14"`, `"ARA"`.
  - `test_merge_keeps_times_and_day_numbers` → `result["summary"]["points"][0]["start_seconds"] == 2183.0`, `[d["day_number"] for d in result["days"]] == [1, 2]`, and each day's `start_seconds` and `end_seconds` equal the source's.
  - `test_merge_rejects_missing_day` → output with one day raises `RuntimeError` matching `"estructura"`.
  - `test_merge_rejects_missing_question` → day 2 with one question raises `RuntimeError`.

- [ ] **Step 2: Run them to see them fail**

  Run: `cd worker && .venv/bin/python -m pytest tests/test_translation.py -v`
  Expected: FAIL with `ModuleNotFoundError: No module named 'selah_worker.translation'`

- [ ] **Step 3: Implement** the schemas, `translation.py`, `ai.translate` and `pipeline.translate` with the signatures above. Bump `PROMPT_VERSION` to `"2026-10-19.1"`.

- [ ] **Step 4: Run the whole worker suite**

  Run: `cd worker && .venv/bin/python -m pytest -q`
  Expected: all pass (31 existing + 6 new).

- [ ] **Step 5: Run it once for real**

  Insert a `translate` job for the published study (`sermon_id` of "Eliseo continúa su ministerio", payload `{"languages": ["en","pt"]}`) and run `cd worker && .venv/bin/python -m selah_worker run` until it finishes.
  Expected: job `succeeded`; two `study_translations` rows; the English row's day 1 `bible_reading` starts with an English book name. Read both titles and day 1 to check the translation is faithful and the Portuguese is Brazilian.

- [ ] **Step 6: Commit**

  ```bash
  git add worker/selah_worker worker/tests/test_translation.py
  git commit -m "Translate published studies into English and Portuguese"
  ```

### Task 3: App models and data for translations

**Files:**
- Modify: `app/lib/src/core/models.dart`
- Modify: `app/lib/src/data/repository.dart` (`publishedStudies`, `studyBySlug` selects)
- Test: `app/test/translation_models_test.dart`

**Interfaces:**
- Produces:
  - `PublicStudy` gains `outputLanguage` (`output_language`), `translations` (`Map<String, StudyTranslation>`, from the joined `study_translations(*)` rows; RLS already removes hidden ones) and `translatedFrom` (`String?`, null on the original).
  - `PublicStudy localizedTo(String language)` returns `this` when `language == outputLanguage` or there is no translation for it. Otherwise it returns a copy with `title`, `centralMessage`, `summary`, `days` and `bibleVersionCode` taken from the translation and `translatedFrom = outputLanguage`. Sermon and ids stay the same.
  - `class StudyTranslation { String language; String title; String? centralMessage; Map<String, dynamic> summary; List<DevotionalDay> days; String bibleVersionCode; }` with `fromJson`. Days are sorted by number.
  - `StudyCard` gains `translatedTitles` (`Map<String, String>`, from `study_translations(language, title)`) and `StudyCard localizedTo(String language)`, which swaps the title when one exists.
  - `studyBySlug` selects `output_language` and `study_translations(*)`; `publishedStudies` selects `study_translations(language, title, central_message)`.

- [ ] **Step 1: Write the failing tests**
  - `localizedTo returns the translation` → from JSON with an `en` translation titled `"The need for spiritual retreat"`: `study.localizedTo('en').title == "The need for spiritual retreat"`, `.translatedFrom == 'es'`, `.bibleVersionCode == 'NIV'`, and `.days.first.title` is the English day title.
  - `localizedTo the original language returns the original` → `study.localizedTo('es')` is identical to `study`, and `.translatedFrom` is null.
  - `localizedTo a missing language returns the original` → `study.localizedTo('pt').translatedFrom == null`.
  - `StudyCard.localizedTo swaps the title` → `'en'` gives the English title; `'pt'` with no row gives the Spanish title.

- [ ] **Step 2: Run them to see them fail**

  Run: `cd app && flutter test test/translation_models_test.dart`
  Expected: FAIL, `localizedTo` is not defined.

- [ ] **Step 3: Implement** the model changes and the two select changes.

- [ ] **Step 4: Run all app tests**

  Run: `cd app && flutter test && flutter analyze`
  Expected: all pass, "No issues found!"

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib/src/core/models.dart app/lib/src/data/repository.dart app/test/translation_models_test.dart
  git commit -m "Read study translations in the app"
  ```

### Task 4: Interface languages and the language picker

**Files:**
- Create: `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_pt.arb`
- Create: `app/lib/src/l10n/locale.dart`
- Create: `app/lib/src/features/home/language_menu.dart`
- Modify: `app/lib/src/app/app.dart` (`locale:` comes from `appLocaleProvider`)
- Modify: `app/lib/src/features/home/home_page.dart`, `app/lib/src/features/study/study_page.dart`, `app/lib/src/features/study/reader_page.dart` (show `LanguageMenu` in the app bar)
- Modify: `app/lib/main.dart` (read the saved locale before `runApp`)
- Test: `app/test/locale_test.dart`

**Interfaces:**
- Produces, in `locale.dart`:
  - `const supportedLanguages = ['es', 'en', 'pt'];`
  - `String languageFor(Locale device)` → the device's language code when it is in `supportedLanguages`, else `'es'`.
  - `final appLocaleProvider = NotifierProvider<AppLocale, Locale>(AppLocale.new);` The initial value is the saved preference under key `'language'`, else `languageFor(PlatformDispatcher.instance.locale)`. `Future<void> AppLocale.set(String language)` updates state and saves it.
- Produces `LanguageMenu()`: an app-bar `PopupMenuButton` with a translate icon and three items, "Español", "English", "Português". Each item is in its own language whatever the current locale, and choosing one calls `set`.
- New strings in all three ARB files (Spanish / English / Portuguese):

| Key | es | en | pt |
|---|---|---|---|
| `language` | Idioma | Language | Idioma |
| `translationNotice` | Traducción automática del original en {original}. | Automatic translation from the original in {original}. | Tradução automática do original em {original}. |
| `showOriginal` | Ver original | Show original | Ver original |
| `showTranslation` | Ver traducción | Show translation | Ver tradução |
| `translationMissing` | Este estudio aún no está disponible en español. | This study is not available in English yet. | Este estudo ainda não está disponível em português. |
| `languageNameEs` | español | Spanish | espanhol |

  Existing keys the tests pin: `signIn` → "Sign in" / "Entrar"; `readReference` → "Read {reference} ({version})" / "Ler {reference} ({version})"; `nextDay` → "Next day" / "Próximo dia".

  `translationNotice` takes `{original}` (String) and is filled with `languageNameEs`. `translationMissing` names the reader's own language, so each locale's text is fixed. Every existing key gets an English and a Brazilian Portuguese text; keep the Spanish tone (warm, short). Brand words stay: "Selah", "La Palabra que permanece" becomes "The Word that remains" and "A Palavra que permanece".

- [ ] **Step 1: Write the failing tests**
  - `languageFor maps device locales` → `Locale('pt','PT')` → `'pt'`, `Locale('pt','BR')` → `'pt'`, `Locale('en','GB')` → `'en'`, `Locale('fr')` → `'es'`, `Locale('es','MX')` → `'es'`.
  - `choosing English changes the interface and is remembered` (widget) → pump `HomePage` under `SelahApp`'s localization setup with `appLocaleProvider`, `SharedPreferences.setMockInitialValues({})` and the home overrides from `home_page_test.dart`. Open `LanguageMenu`, tap "English". Expect `find.text('Sign in')` and `(await SharedPreferences.getInstance()).getString('language') == 'en'`.
  - `every key exists in every language` → load the three ARB files as JSON; the sets of non-`@` keys are equal.

- [ ] **Step 2: Run them to see them fail**

  Run: `cd app && flutter test test/locale_test.dart`
  Expected: FAIL, `locale.dart` not found.

- [ ] **Step 3: Implement** `locale.dart`, `LanguageMenu`, both ARB files and the wiring; then run `flutter gen-l10n`.

- [ ] **Step 4: Run all app tests**

  Run: `cd app && flutter test && flutter analyze`
  Expected: all pass, "No issues found!". Existing tests that pin `Locale('es')` stay Spanish.

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib app/test/locale_test.dart
  git commit -m "Add English and Brazilian Portuguese interface with a language picker"
  ```

### Task 5: Show translated studies

**Files:**
- Modify: `app/lib/src/features/home/home_page.dart`, `app/lib/src/features/study/study_page.dart`, `app/lib/src/features/study/reader_page.dart`
- Create: `app/lib/src/features/study/translation_banner.dart`
- Test: `app/test/study_translation_test.dart`

**Interfaces:**
- Consumes: `PublicStudy.localizedTo`, `StudyCard.localizedTo` (Task 3); `appLocaleProvider` (Task 4).
- Produces:
  - `final showOriginalProvider = StateProvider.autoDispose.family<bool, String>((ref, studyId) => false);` declared in `translation_banner.dart`. Use a `NotifierProvider` if `StateProvider` is not available in Riverpod 3.4; the behaviour is the same.
  - `TranslationBanner({required PublicStudy shown, required PublicStudy original, required String language})`:
    - When `shown.translatedFrom != null`, it shows `translationNotice(languageNameEs)` and a `showOriginal` button.
    - When the reader chose a language the study lacks (`language != original.outputLanguage` and `original.localizedTo(language).translatedFrom == null`), it shows `translationMissing`.
    - While the original is shown on request, it shows a `showTranslation` button.
- Behaviour: study and reader pages render `showOriginal ? study : study.localizedTo(language)`, with `TranslationBanner` at the top. Home cards use `card.localizedTo(language)`. Bible reading links use the shown study's `bibleVersionCode`.

- [ ] **Step 1: Write the failing widget tests** (reuse the `_json` fixture style of `test/study_test.dart`, adding `output_language: 'es'` and an `en` translation)
  - `English reader shows the translated day and the notice` → locale `en`, `/studies/retiro-espiritual/day/1`: finds the English day title and `'Automatic translation from the original in Spanish.'`.
  - `Show original switches to Spanish` → tap `'Show original'`: finds the Spanish day title and `'Show translation'`.
  - `missing translation shows Spanish with a note` → locale `pt`, no `pt` row: finds the Spanish day title and `'Este estudo ainda não está disponível em português.'`.
  - `Spanish reader sees no banner` → locale `es`: `find.textContaining('Traducción automática')` finds nothing.
  - `English reading link uses NIV` → finds `'Read Psalms 27:1 (NIV)'` (the English `readReference` with the relabelled reference).

- [ ] **Step 2: Run them to see them fail**

  Run: `cd app && flutter test test/study_translation_test.dart`
  Expected: FAIL, the English title is not found.

- [ ] **Step 3: Implement** the banner and the page changes.

- [ ] **Step 4: Run all app tests**

  Run: `cd app && flutter test && flutter analyze`
  Expected: all pass, "No issues found!"

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib app/test/study_translation_test.dart
  git commit -m "Show translated studies with a notice and the original one tap away"
  ```

### Task 6: Translate on publish; admin controls

**Files:**
- Modify: `app/lib/src/data/repository.dart` (`translations(studyId)`, `setTranslationHidden(id, hidden)`)
- Modify: `app/lib/src/features/admin/sermon_page.dart` (publish queues the job; "Traducciones" section)
- Modify: `app/lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb`
- Test: `app/test/admin_translations_test.dart`

**Interfaces:**
- Consumes: `createJob` (existing), the Task 1 table, `sermonJobsProvider` (existing; the `translate` step appears in its map).
- Produces:
  - `Future<List<Map<String, dynamic>>> translations(String studyId)` (admin view, includes hidden rows) and `Future<void> setTranslationHidden(String id, bool hidden)`.
  - Publishing (when `!published`) calls `setStudyPublished(id, true)` and then `createJob('translate', {'languages': ['en', 'pt']}, sermonId: sermonId)`.
  - Section "Traducciones" under the study, for a published study. Per language it shows the name, the state, a `Visible` switch (calls `setTranslationHidden`) and a retry/"Traducir de nuevo" button that queues the same job. The state is one of: queued/running from the latest `translate` job, `failed` with its error, or the row's `created_at`.
- New strings (es / en / pt): `translationsSection` Traducciones / Translations / Traduções; `translateAgain` Traducir de nuevo / Translate again / Traduzir novamente; `visible` Visible / Visible / Visível; `stepTranslate` Traducir al inglés y al portugués / Translate into English and Portuguese / Traduzir para inglês e português.

- [ ] **Step 1: Write the failing tests** with a fake repository that records `createJob` calls (same pattern as `_FakeRepository` in `test/login_page_test.dart`) and a `SermonDetail` fixture whose study is in `review` with 3 days:
  - `publishing queues the translation` → tap "Publicar"; the fake recorded `setStudyPublished(id, true)` then `createJob('translate', {'languages': ['en','pt']}, sermonId: …)`.
  - `unpublishing does not translate` → study `published`; tap "Retirar publicación"; no `translate` job recorded.
  - `hiding a translation` → with an `en` row, toggle its switch off; the fake recorded `setTranslationHidden(<row id>, true)`.

- [ ] **Step 2: Run them to see them fail**

  Run: `cd app && flutter test test/admin_translations_test.dart`
  Expected: FAIL, no `translate` job recorded.

- [ ] **Step 3: Implement** the repository methods, publish change, section and strings.

- [ ] **Step 4: Run all app tests**

  Run: `cd app && flutter test && flutter analyze`
  Expected: all pass, "No issues found!"

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib app/test/admin_translations_test.dart
  git commit -m "Translate on publish and let the admin hide or redo translations"
  ```

### Task 7: Deploy and check on a phone

**Files:**
- Modify: `README.md` (short "Translations" section)
- Modify: `docs/MVP_PLAN.md` (status line)

- [ ] **Step 1: Deploy** (ask the owner first; it goes live)

  ```bash
  cd app && flutter build web --release --dart-define-from-file=config/beta.json
  PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx --yes wrangler pages deploy build/web --project-name selah --branch main
  ```
  Expected: "Deployment complete!"

- [ ] **Step 2: Check on a phone at https://selah-226.pages.dev**

  | Case | Expected |
  |---|---|
  | Language → English on the home page | Interface in English; the published study's English title on the card |
  | Open the study, then Day 1 | English text; "Automatic translation from the original in Spanish."; reading link says NIV |
  | "Show original" | Spanish day; "Show translation" brings English back |
  | Language → Português | Brazilian Portuguese text and the ARA link |
  | Admin hides the Portuguese translation | Portuguese reader sees Spanish with "Este estudo ainda não está disponível em português." |
  | Reload the page | The chosen language is kept |

- [ ] **Step 3: Document and commit**

  README "Translations": when they are made (on publish), which versions are linked, how to hide or redo one, and that they use the same Gemini key and worker. MVP_PLAN status line mentions translations.

  ```bash
  git add README.md docs/MVP_PLAN.md
  git commit -m "Document translations"
  ```
