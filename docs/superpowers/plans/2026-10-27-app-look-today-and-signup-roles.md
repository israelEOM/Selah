# New Look, Today Page and Sign-up Roles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Selah feels like a daily devotional app: a light theme in the icpresbiteriana.com colors and a Verbo-like dark theme, a bottom tab bar (Hoy, Estudios, Perfil), a Today page that walks a member through the newest study one day at a time with a tick per part, and a sign-up step where people join a church as members or ask to bring their church.

**Architecture:** Theme colors live in two `ThemeData`s plus a `ThemeExtension` (`SelahTones`) for colors Material has no slot for; nothing reads `SelahColors` directly any more. A go_router `ShellRoute` wraps the member pages with the tab bar. Device-only state (theme mode, current church, per-part progress, welcome skipped) sits in SharedPreferences behind Riverpod notifiers, following `l10n/locale.dart`. The Today page is a pure function (`todayFor`) over the newest study, the device progress and the clock, rendered by a thin widget. Church requests are a new table with two `security definer` RPCs; approval reuses the church-creation rules.

**Tech Stack:** Flutter (Riverpod 3, go_router, gen-l10n, shared_preferences), Supabase Postgres (migrations, RLS, pgTAP via `npx supabase test db`).

**Spec:** [docs/superpowers/specs/2026-10-27-app-look-today-and-signup-roles-design.md](../specs/2026-10-27-app-look-today-and-signup-roles-design.md)

## Global Constraints

- Light colors exactly: text navy `#0E2341`, primary forest green `#2E4A38`, background white `#FFFFFF`, surface grey `#EDEFF3`, muted `#697380`, accent orange `#F15A24` (sparingly: today's ring in the week row).
- Dark colors: background `#0B0B0C`, surface `#1A1A1C`, text `#F2F2F2`, muted `#8B8B90`, accent green `#5BC49A`, warm gold `#C9A46A` for finished-day circles, hero gradient `#5A4630 → #2A2016`.
- UI font is the platform system font (no `fontFamily`); serif `Georgia` (fallback `Times New Roman`, `serif`) only for the hero quote and long reading text (reflection, application, prayer).
- SharedPreferences keys: `theme` (`system`|`light`|`dark`), `church` (slug), `progress:<studyId>` (JSON, Task 5), `welcomeSkipped:<userId>` (bool). Existing `language` and `read:<studyId>` keys are read, never deleted.
- Dates for progress are the device's **local** calendar date, formatted `yyyy-MM-dd`.
- Routes: tabs `/` (Hoy), `/c/:church` and its `studies/...` children (Estudios), `/profile` (Perfil); new non-tab routes `/churches` (church picker), `/welcome`, `/requests` (platform admin, Spanish). Every existing route keeps working.
- Every new ARB key exists in `app_es.arb`, `app_en.arb`, `app_pt.arb`; admin-only keys (the `/requests` page) hold the same Spanish text in all three. Spanish copy given in this plan is exact; write natural en/pt equivalents.
- SQL error codes the app matches on: existing `church_slug_taken`, `church_slug_invalid`, `not_allowed`; new `request_pending_exists`, `request_not_pending`.
- Members never need an account to read or tick. Nobody gets Owner or Editor without a person approving it.
- Run app tests with `cd app && flutter test`; DB tests with `cd supabase/.. && PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx supabase db reset && npx supabase test db`.
- The working tree has the user's uncommitted edits to `app/lib/src/l10n/locale.dart` and `app/test/locale_test.dart`. Don't commit or revert them unless your task changes those files; if it does, ask first.

## Review Focus

1. **A day with no Bible reading or no prayer.** Expected: that row isn't shown, and the day is done once the rows that exist are ticked. Pinned in Task 5 (`partsFor` tests).
2. **Finishing at 23:50 and opening again at 00:10.** Expected: Today now offers the next day; the circle is on the earlier date. Pinned in Task 6 (`todayFor` midnight test).
3. **A new study is published on Thursday after the member finished days of the old one Mon–Wed.** Expected: Today jumps to Day 1 of the new study and the week row still shows Mon–Wed. Pinned in Task 6 (`weekCircles` across studies).
4. **A device with old "Marcar como leído" marks.** Expected: those days count as fully done (Today skips them) but add no week circle. Pinned in Task 5.
5. **Approving a request whose suggested address is taken, or approving it twice.** Expected: a clear error, the request stays pending (or the second approve is refused with `request_not_pending`), and no half-created church. Pinned in Task 9.

---

## Phase 1 — New look and app layout

### Task 1: Light and dark themes

**Files:**
- Modify: `app/lib/src/app/theme.dart`
- Modify (replace `SelahColors.*` / hard-coded white/black with theme reads): `app/lib/src/features/admin/sermon_page.dart`, `app/lib/src/features/auth/google_button.dart`, `app/lib/src/features/church/church_page.dart`, `app/lib/src/features/study/reader_page.dart`, `app/lib/src/features/study/study_page.dart`, `app/lib/src/features/study/study_widgets.dart`
- Test: `app/test/theme_test.dart`

**Interfaces:**
- Produces: `ThemeData selahLightTheme()`, `ThemeData selahDarkTheme()` (replace `selahTheme()`); `class SelahTones extends ThemeExtension<SelahTones>` with fields `Color surface, muted, accent, done, today, heroStart, heroEnd`; `extension SelahThemeX on BuildContext { SelahTones get tones; }`; `TextStyle serifReading(BuildContext)` and `TextStyle serifQuote(BuildContext)`. `Eyebrow` and `PageBody` stay.
- `SelahColors` is deleted.

- [ ] **Step 1: Write failing tests** in `theme_test.dart`:
  - `light scheme uses the church palette`: `selahLightTheme().colorScheme.primary == Color(0xFF2E4A38)`, `.onSurface == Color(0xFF0E2341)`, `scaffoldBackgroundColor == Colors.white`, `extension<SelahTones>()!.accent == Color(0xFFF15A24)`.
  - `dark scheme is near-black with green accent`: `brightness == Brightness.dark`, `scaffoldBackgroundColor == Color(0xFF0B0B0C)`, `tones.accent == Color(0xFF5BC49A)`, `tones.done == Color(0xFFC9A46A)`.
  - `UI text uses the system font`: `selahLightTheme().textTheme.titleLarge!.fontFamily` is null; `serifQuote` of a pumped context has `fontFamily == 'Georgia'`.
- [ ] **Step 2: Run** `cd app && flutter test test/theme_test.dart`. Expected: FAIL (functions not defined).
- [ ] **Step 3: Implement** both themes from one private builder taking the palette, mapping: `primary` = green, `onPrimary` white (dark: `#0B0B0C`), `surface` = background, `surfaceContainerHighest` = surface grey, cards/inputs/filled buttons on the new colors, `labelSmall` (Eyebrow) in primary. Headings drop the serif. Then replace every `SelahColors` use in the listed files with `Theme.of(context).colorScheme.*` or `context.tones.*`, and the reader's reflection/application/prayer text with `serifReading(context)`.
- [ ] **Step 4: Run** `flutter test`. Expected: all tests PASS (existing ones included; fix any that asserted old colors).
- [ ] **Step 5: Commit** `git commit -m "Light and dark themes in the church palette"`.

### Task 2: Theme choice saved on the device

**Files:**
- Create: `app/lib/src/app/theme_mode.dart`
- Modify: `app/lib/main.dart`, `app/lib/src/app/app.dart`
- Test: `app/test/theme_mode_test.dart`

**Interfaces:**
- Produces: `final savedThemeModeProvider = Provider<String?>`, `final themeModeProvider = NotifierProvider<AppThemeMode, ThemeMode>`, `Future<void> AppThemeMode.set(ThemeMode)`, `Future<String?> loadSavedThemeMode()`. Mirrors `l10n/locale.dart`.
- `SelahApp` sets `theme: selahLightTheme(), darkTheme: selahDarkTheme(), themeMode: ref.watch(themeModeProvider)`.

- [ ] **Step 1: Write failing tests:** `defaults to system` (no saved value → `ThemeMode.system`); `reads a saved choice` (override `savedThemeModeProvider` with `'dark'` → `ThemeMode.dark`); `ignores junk` (`'blue'` → system); `set saves it` (after `set(ThemeMode.light)`, `SharedPreferences` key `theme` == `'light'`; use `SharedPreferences.setMockInitialValues({})`).
- [ ] **Step 2: Run** `flutter test test/theme_mode_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** and wire into `main.dart` (load before `runApp`, override like the language) and `app.dart`.
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Follow the phone's light or dark setting, with a saved override"`.

### Task 3: Current church

**Files:**
- Create: `app/lib/src/data/current_church.dart`
- Modify: `app/lib/main.dart`
- Test: `app/test/current_church_test.dart`

**Interfaces:**
- Consumes: `myChurchesProvider`, `churchProvider(slug)`.
- Produces: `final savedChurchProvider = Provider<String?>` (overridden in `main`), `final chosenChurchSlugProvider = NotifierProvider<ChosenChurch, String?>` with `Future<void> choose(String slug)` (saves key `church`), and `final currentChurchProvider = FutureProvider<Church?>`.
- Rule for `currentChurchProvider`: if the chosen slug is set and (signed out, or it's one of my memberships, or I have no memberships) → that church; else if I have memberships → the first membership's church; else null.

- [ ] **Step 1: Write failing tests** with provider overrides: `signed out uses the saved church`; `a member with no saved church gets their church`; `a saved church that is one of mine wins over the first membership`; `a saved church I don't belong to loses to my membership`; `nothing saved and no membership is null`; `choose saves the slug`.
- [ ] **Step 2: Run** `flutter test test/current_church_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** in `current_church.dart`; load the saved slug in `main.dart` beside the language.
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Remember the current church on the device"`.

### Task 4: Tab bar, church picker and Perfil

**Files:**
- Create: `app/lib/src/app/shell.dart` (`SelahShell`, floating rounded tab bar)
- Create: `app/lib/src/features/profile/profile_page.dart`
- Rename/modify: `app/lib/src/features/home/home_page.dart` → `app/lib/src/features/home/church_picker_page.dart` (`ChurchPickerPage`)
- Modify: `app/lib/src/app/app.dart`, `app/lib/src/features/church/church_page.dart`, `app/lib/src/features/church/church_scope.dart`, `app/lib/l10n/app_{es,en,pt}.arb`
- Test: `app/test/shell_test.dart`, `app/test/profile_page_test.dart`, rename `app/test/home_page_test.dart` → `app/test/church_picker_test.dart`; update `church_page_test.dart`, `church_routes_test.dart`

**Interfaces:**
- Consumes: `currentChurchProvider`, `chosenChurchSlugProvider.choose`, `themeModeProvider`, `appLocaleProvider`, `churchRoleProvider`, `isPlatformAdminProvider`.
- Produces: routes `/` (placeholder `TodayPage` until Task 7 — a `Text` with the church name is enough), `/profile`, `/churches`; the shell wraps `/`, `/profile`, `/c/:church`, `/c/:church/studies/:slug`, `/c/:church/studies/:slug/day/:number`. Admin, login, join, `/churches/new`, `/churches`, `/welcome`, `/requests` are outside it. `int tabIndexFor(String location)` in `shell.dart`: `/` → 0, `/c/...` → 1, `/profile` → 2.
- Tapping Estudios goes to `/c/<current slug>`, or `/churches` when there is no current church. Hoy with no current church shows the church picker list inline.
- Opening any `/c/<slug>` page while no church is chosen calls `choose(slug)` (in `ChurchScope`).
- ARB keys (es): `tabToday` "Hoy", `tabStudies` "Estudios", `tabProfile` "Perfil", `pickChurch` "Elige tu iglesia", `yourChurch` "Tu iglesia", `changeChurch` "Cambiar de iglesia", `theme` "Tema", `themeSystem` "Sistema", `themeLight` "Claro", `themeDark` "Oscuro", `adminArea` "Administrar la iglesia".

- [ ] **Step 1: Write failing tests:**
  - `shell_test`: `tabIndexFor` returns 0/1/1/2 for `/`, `/c/x`, `/c/x/studies/s/day/2`, `/profile`; pumping the router at `/profile` shows three tab labels "Hoy", "Estudios", "Perfil"; tapping "Estudios" with current church `vida-nueva` lands on `/c/vida-nueva`; at `/c/vida-nueva/admin` no tab bar is shown.
  - `church_picker_test` (ported from `home_page_test`): tapping a church saves its slug (`church` pref) and goes to `/`.
  - `profile_page_test`: shows current church name and "Cambiar de iglesia"; selecting "Oscuro" sets `themeModeProvider` to dark; an editor sees "Administrar la iglesia" linking to `/c/vida-nueva/admin`, a member doesn't; signed out shows "Iniciar sesión", signed in shows "Cerrar sesión"; a platform admin sees "Crear iglesia".
- [ ] **Step 2: Run** `flutter test`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.** The church page app bar keeps only the title and the "Seguir" (follow) button; switcher, language, sign in/out and "Gestionar" move to Perfil (`ChurchSwitcher` stays for admin pages). The picker is the old home list without the hero text. Tab bar: floating, rounded, `context.tones.surface` background, selected tab in `colorScheme.primary` with a pill behind it, icons `Icons.wb_sunny_outlined`, `Icons.menu_book_outlined`, `Icons.person_outline`. Content stays width-capped by `PageBody`; the tab bar is capped to the same width on desktop.
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Look at it.** `flutter run -d chrome --dart-define-from-file=config/beta.json` (or build + `tool/serve.py`) and check `/`, `/c/<slug>`, a study, a reader day, `/profile`, an admin page and `/login` in light and dark at phone width (375 px) and desktop. Fix anything unreadable (contrast, leftover hard-coded colors). Expected: every page readable in both themes, no horizontal scroll.
- [ ] **Step 6: Commit** `git commit -m "Bottom tabs, church picker and profile page"`.

---

## Phase 2 — Today page

### Task 5: Per-part progress on the device

**Files:**
- Create: `app/lib/src/data/progress.dart`
- Test: `app/test/progress_test.dart`

**Interfaces:**
- Produces:
  - `enum DayPart { reading, reflection, prayer }`
  - `List<DayPart> partsFor(DevotionalDay day)` — `reading` iff `bibleReading != null`; `reflection` iff any of `reflection`, `application`, `questions` present; `prayer` iff `prayer != null`. A day with none of them has `[reflection]` (it can still be ticked).
  - `class DayProgress { final Set<DayPart> parts; final String? doneOn; }`
  - `class StudyProgress { final Map<int, DayProgress> days; bool isDone(DevotionalDay d); }` — done when `partsFor(d)` ⊆ `parts`.
  - `Future<StudyProgress> loadProgress(String studyId)`; `Future<StudyProgress> togglePart(String studyId, DevotionalDay day, DayPart part, DateTime now)`; `Future<Set<String>> loadDoneDates()` (every `doneOn` across all studies).
  - Providers: `final studyProgressProvider = FutureProvider.autoDispose.family<StudyProgress, String>`, `final doneDatesProvider = FutureProvider.autoDispose<Set<String>>`.
- Storage: `progress:<studyId>` is JSON `{"<day>": {"parts": ["reading", ...], "doneOn": "yyyy-MM-dd" | null}}`. When a toggle makes the day done, set `doneOn` to `now`'s local date; unticking a part clears it. `loadDoneDates()` scans every `progress:*` key and collects the `doneOn` values, so the week row spans studies and there is no second list to keep in step.
- Legacy: a day number in `read:<studyId>` counts as all its parts done with `doneOn == null`.

- [ ] **Step 1: Write failing tests:**
  - `partsFor`: full day → all three; no `bibleReading` → `[reflection, prayer]`; no prayer → `[reading, reflection]`; only questions → `[reflection]`.
  - `ticking every part marks the day done today`: toggle the three parts at `DateTime(2026, 10, 28, 9)` → `isDone`, `doneOn == '2026-10-28'`, `loadDoneDates()` contains it.
  - `done dates span studies`: a day finished in `s1` and one in `s2` on different dates → both in `loadDoneDates()`.
  - `a day without prayer is done after reading and reflection`.
  - `unticking clears done`.
  - `old read marks count as done without a date`: `setMockInitialValues({'read:s1': ['1','2']})` → days 1 and 2 `isDone`, `doneDates` empty.
  - `progress is per study`: ticks on `s1` don't show on `s2`.
- [ ] **Step 2: Run** `flutter test test/progress_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** in `progress.dart`.
- [ ] **Step 4: Run** `flutter test test/progress_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Save each part of a devotional day on the device"`.

### Task 6: What Today shows

**Files:**
- Create: `app/lib/src/features/today/today_state.dart`
- Test: `app/test/today_state_test.dart`

**Interfaces:**
- Consumes: `PublicStudy`, `StudyProgress`, `partsFor` (Task 5).
- Produces:
  - `sealed class TodayState` with `NoStudy()`, `DayToDo(DevotionalDay day)`, `DoneForToday(DevotionalDay day, DevotionalDay? next)`, `AllDone(String? passage, String? takeaway)`.
  - `TodayState todayFor({required PublicStudy? study, required StudyProgress progress, required DateTime now})`.
  - `List<bool> weekCircles(Set<String> doneDates, DateTime now)` — 7 entries Mon..Sun of `now`'s week, true when that date is in `doneDates`.
- Rules (in order): no study → `NoStudy`. If some day has `doneOn == today` → `DoneForToday(highest such day, lowest unfinished day or null)`. Else if an unfinished day exists → `DayToDo(lowest-numbered unfinished)`. Else → `AllDone(summary['main_passage'], takeaway)`, takeaway = `key_takeaways[dayOfYear(now) % length]` or null when empty.

- [ ] **Step 1: Write failing tests:**
  - `no study`; `fresh study shows day 1`; `skipping ahead still shows the lowest unfinished` (day 3 done, day 1 not → day 1).
  - `finishing today holds until tomorrow`: day 1 `doneOn '2026-10-28'`, now `2026-10-28 23:50` → `DoneForToday(day1, next: day2)`; now `2026-10-29 00:10` → `DayToDo(day2)`.
  - `last day finished today` → `DoneForToday(day5, next: null)`; next day → `AllDone('Lucas 9:23-27', <a takeaway>)`.
  - `all done with no summary` → `AllDone(null, null)`.
  - `weekCircles` for now = Thu `2026-10-29` and doneDates `{2026-10-26, 2026-10-27, 2026-10-28, 2026-10-21}` → `[true, true, true, false, false, false, false]` (last week's date ignored) — this is the new-study-midweek case: dates are global, not per study.
- [ ] **Step 2: Run** `flutter test test/today_state_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** in `today_state.dart`.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Decide what the Today page shows"`.

### Task 7: Today page

**Files:**
- Create: `app/lib/src/features/today/today_page.dart`
- Modify: `app/lib/src/data/repository.dart`, `app/lib/src/data/providers.dart`, `app/lib/src/app/app.dart` (route `/` → `TodayPage`), `app/lib/l10n/app_{es,en,pt}.arb`
- Test: `app/test/today_page_test.dart`

**Interfaces:**
- Consumes: `currentChurchProvider` (Task 3), `studyProgressProvider`, `doneDatesProvider`, `togglePart` (Task 5), `todayFor`, `weekCircles` (Task 6), `studyToShow` (existing, for the reader's language).
- Produces: `Future<PublicStudy?> SelahRepository.newestStudy(String churchId)` (same select as `studyBySlug`, `order('published_at', ascending: false).limit(1).maybeSingle()`); `final newestStudyProvider = FutureProvider.autoDispose.family<PublicStudy?, String>`; `final clockProvider = Provider<DateTime Function()>((_) => DateTime.now)` so tests pin the time.
- Layout, top to bottom: church name; week row (7 circles labelled with localized one-letter weekday names, today ringed in `tones.today`, done circles in `tones.done` with a check); localized long date; study title; eyebrow "Devocional de hoy · Día N de M"; hero card (gradient `tones.heroStart → heroEnd`, day title as eyebrow, main idea in `serifQuote`); one row per `partsFor(day)` with a round tick on the right — tapping the tick toggles the part, tapping the row opens `/c/<slug>/studies/<study>/day/<n>` (the Bible-reading row opens the external Bible link as the reader does); a "Resumen del sermón" outlined button to `/c/<slug>/studies/<study>` on every state.
- `DoneForToday`: the same card with a "Hecho por hoy" badge and ticks shown done, plus a "Leer el siguiente" text button to the next day's reader route when `next != null`.
- `AllDone`: title "Para meditar hoy"; hero card with eyebrow "Pasaje principal · <passage>" and the takeaway quote; a row "Leer <passage>" opening `bibleReaderUrl(passage, study.bibleVersionCode)`. Missing pieces are left out.
- `NoStudy`: "Tu iglesia aún no ha publicado estudios." and a button to Estudios.
- No current church: the church picker list (Task 4).
- ARB keys (es): `todayDevotional` "Devocional de hoy", `bibleReading` "Lectura bíblica", `doneForToday` "Hecho por hoy", `readNext` "Leer el siguiente", `sermonSummaryButton` "Resumen del sermón", `meditateToday` "Para meditar hoy", `mainPassage` "Pasaje principal", `readPassage` "Leer {reference}", `noStudiesYetToday` "Tu iglesia aún no ha publicado estudios.", `goToStudies` "Ver estudios". Reuse existing `reflection`, `prayer`, `dayOfTotal`.

- [ ] **Step 1: Write failing widget tests** (override `currentChurchProvider`, `newestStudyProvider`, `clockProvider`, `SharedPreferences.setMockInitialValues`):
  - `shows day 1 of a fresh study` (title, "Día 1 de 5", main idea, rows "Lectura bíblica", "Reflexión", "Oración").
  - `a day without prayer has no prayer row`.
  - `ticking all parts shows Hecho por hoy and Leer el siguiente`, and the week row has one done circle on the pinned date.
  - `Leer el siguiente opens day 2 in the reader` (route `/c/vida-nueva/studies/seguir/day/2`).
  - `the summary button opens the study page`.
  - `all done shows the main passage and a takeaway`.
  - `no study shows the empty message`.
  - `shows the study in the chosen language` (a `pt` translation's day title appears with locale `pt`).
- [ ] **Step 2: Run** `flutter test test/today_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the repository method, providers and `TodayPage`; point `/` at it.
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Today page"`.

### Task 8: Reader and study page use the per-part ticks

**Files:**
- Modify: `app/lib/src/features/study/reader_page.dart`, `app/lib/src/features/study/study_page.dart`, `app/lib/src/data/providers.dart` (remove `readDaysProvider`, `markDayRead`)
- Test: `app/test/study_test.dart` (update)

**Interfaces:**
- Consumes: `studyProgressProvider`, `togglePart`, `partsFor` (Task 5).
- The reader replaces "Marcar como leído" with a tick beside each of its sections that maps to a part (Bible reading link → `reading`; reflection/application/questions block → `reflection`; prayer → `prayer`). Its day dots and the study page's day boxes show done from `StudyProgress.isDone`.

- [ ] **Step 1: Update tests:** `ticking the three parts in the reader marks the day done on the study page`; `old read marks still show as done` (`read:<id>` preset); remove assertions on "Marcar como leído".
- [ ] **Step 2: Run** `flutter test test/study_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Tick each part of a day in the reader"`.

---

## Phase 3 — Sign-up choice and church requests

### Task 9: Church requests in the database

**Files:**
- Create: `supabase/migrations/202610300001_church_requests.sql`
- Test: `supabase/tests/database/church_requests_test.sql`

**Interfaces:**
- Produces:
  - `create type public.church_request_status as enum ('pending', 'approved', 'rejected')`
  - `public.church_requests (id uuid pk default gen_random_uuid(), requested_by uuid not null references auth.users on delete cascade, church_name text not null check (char_length(btrim(church_name)) between 2 and 80), note text check (note is null or char_length(note) <= 500), status church_request_status not null default 'pending', church_id uuid references public.churches on delete set null, created_at timestamptz not null default now(), decided_at timestamptz, decided_by uuid references auth.users)`; unique partial index on `(requested_by) where status = 'pending'`.
  - RLS: select when `requested_by = auth.uid()` or `is_platform_admin()`. No direct insert/update/delete policies.
  - `public.request_church(p_name text, p_note text) returns public.church_requests` — signed in only (`not_allowed`, errcode `42501` for anon); a second pending request raises `request_pending_exists`.
  - `public.decide_church_request(p_request uuid, p_approve boolean, p_slug text) returns public.church_requests` — platform admin only (`not_allowed`); request must be pending (`request_not_pending`); on approve validates `p_slug` with the existing regex (`church_slug_invalid`), inserts the church with `created_by = requested_by` (`church_slug_taken` on conflict), adds the requester as `owner`, sets `status`, `church_id`, `decided_at`, `decided_by`. All in one function, so a failure leaves nothing behind. On reject `p_slug` is ignored.
  - `public.pending_church_requests() returns table (id uuid, church_name text, note text, status public.church_request_status, created_at timestamptz, requester_email text)` — platform admin only (`not_allowed`), pending rows oldest first, email from `auth.users` (RLS can't reach it, as with `church_people`).
  - `grant execute` on the three functions to `authenticated`.

- [ ] **Step 1: Write failing pgTAP tests:** a user requests a church; `pending_church_requests()` returns it with the requester's email to a platform admin and raises `not_allowed` for anyone else; a second pending request is refused (`request_pending_exists`); anon can't request (`42501`); the requester reads only their own requests, a stranger sees none; a non-admin can't decide (`not_allowed`); approving with a taken slug is refused (`church_slug_taken`) and the request is still `pending` and no church was added; approving with a valid slug creates the church with the requester as `owner` (`church_role_of` as the requester) and status `approved`; approving again is refused (`request_not_pending`); a rejected requester can request again.
- [ ] **Step 2: Run** `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx supabase db reset && npx supabase test db`. Expected: FAIL (table missing).
- [ ] **Step 3: Write the migration.**
- [ ] **Step 4: Run** the same command. Expected: all DB tests PASS.
- [ ] **Step 5: Commit** `git commit -m "Church requests that a platform admin approves"`.

### Task 10: Requests in the app data layer

**Files:**
- Modify: `app/lib/src/core/models.dart`, `app/lib/src/data/repository.dart`, `app/lib/src/data/providers.dart`
- Test: `app/test/church_models_test.dart` (extend)

**Interfaces:**
- Produces: `enum ChurchRequestStatus { pending, approved, rejected }`; `class ChurchRequest { id, churchName, note, status, createdAt, requesterEmail? ; factory fromJson }`; repository `Future<ChurchRequest> requestChurch(String name, String? note)`, `Future<ChurchRequest?> myLatestChurchRequest()` (own rows, newest first, limit 1), `Future<List<ChurchRequest>> pendingChurchRequests()`, `Future<void> decideChurchRequest(String id, {required bool approve, String? slug})`; providers `myChurchRequestProvider` (watches `userIdProvider`) and `pendingChurchRequestsProvider`.
- `pendingChurchRequests()` calls the RPC `pending_church_requests` (Task 9), which adds the requester's email.

- [ ] **Step 1: Write failing tests:** `ChurchRequest.fromJson` parses each status and a null note.
- [ ] **Step 2: Run** `flutter test test/church_models_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Church requests in the app's data layer"`.

### Task 11: "Who are you?" after the first sign-in

**Files:**
- Create: `app/lib/src/features/welcome/welcome_page.dart`
- Modify: `app/lib/src/features/auth/login_page.dart` (destination), `app/lib/src/app/app.dart` (route `/welcome`), `app/lib/src/features/profile/profile_page.dart`, `app/lib/l10n/app_{es,en,pt}.arb`
- Test: `app/test/welcome_page_test.dart`, `app/test/login_page_test.dart` (extend), `app/test/profile_page_test.dart` (extend)

**Interfaces:**
- Consumes: `myChurchesProvider`, `isPlatformAdminProvider`, `myChurchRequestProvider`, `requestChurch`, `joinChurch`, `chosenChurchSlugProvider.choose`, `publicChurchesProvider`.
- Produces: `final needsWelcomeProvider = FutureProvider<bool>` — true when signed in, not platform admin, no memberships, no pending request, and `welcomeSkipped:<userId>` not set. `Future<void> skipWelcome(WidgetRef ref)`.
- Login destination: when there's no safe `next` and `needsWelcomeProvider` is true → `/welcome`; otherwise the current rule. Invite links carry `next=/join/...`, so they skip the step.
- Welcome page, three states:
  1. Choice: heading "¿Cómo vas a usar Selah?", cards "Soy miembro de una iglesia" and "Soy pastor o líder: quiero traer mi iglesia a Selah", text button "Ahora no" (calls `skipWelcome`, goes to `/`).
  2. Member: the public church list; tapping one calls `joinChurch`, `choose(slug)`, invalidates `myChurchesProvider`, goes to `/`.
  3. Leader: fields "Nombre de la iglesia" (2–80 chars) and "Algo sobre tu iglesia (opcional)" (≤500), button "Enviar solicitud"; on success shows "Solicitud enviada. Te avisaremos aquí cuando esté aprobada." with a button "Mientras tanto, unirme a una iglesia" (→ state 2) and "Ir a Hoy".
  - `request_pending_exists` shows "Ya tienes una solicitud pendiente."
- Perfil gains a "Tu solicitud" line when `myChurchRequestProvider` has one: pending "Pendiente de aprobación"; rejected "Tu solicitud no fue aprobada" with "Enviar otra"; approved shows nothing (the church appears as theirs). Signed-in people with no membership see "Unirme a una iglesia" and "Traer mi iglesia a Selah" (→ `/welcome` states 2 and 3, via `?step=member|leader`).
- ARB keys (es): `welcomeTitle`, `welcomeMember`, `welcomeLeader`, `notNow` "Ahora no", `churchNameLabel` "Nombre de la iglesia", `churchNoteLabel` "Algo sobre tu iglesia (opcional)", `sendRequest` "Enviar solicitud", `requestSent` (text above), `joinMeanwhile`, `goToToday` "Ir a Hoy", `requestPendingExists`, `yourRequest` "Tu solicitud", `requestPending` "Pendiente de aprobación", `requestRejected` "Tu solicitud no fue aprobada", `sendAnother` "Enviar otra", `joinAChurch` "Unirme a una iglesia", `bringMyChurch` "Traer mi iglesia a Selah".

- [ ] **Step 1: Write failing tests:**
  - `login_page_test`: `a new account with no church goes to /welcome`; `a platform admin with no church goes to /`; `an invite next skips welcome`; `someone who skipped goes to /`.
  - `welcome_page_test`: `choosing member and a church joins it and opens Today` (repository fake records `joinChurch('A')`, `church` pref == `vida-nueva`); `the leader form sends a request and shows it was sent`; `a second request shows the pending message`; `Ahora no remembers the skip` (`welcomeSkipped:user-1` true).
  - `profile_page_test`: `a rejected request offers Enviar otra`; `a pending request shows Pendiente de aprobación`.
- [ ] **Step 2: Run** `flutter test`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Ask new accounts whether they're members or bringing a church"`.

### Task 12: Requests page for the platform admin

**Files:**
- Create: `app/lib/src/features/admin/requests_page.dart`
- Modify: `app/lib/src/app/app.dart` (route `/requests`, wrapped in `inSpanish`), `app/lib/src/features/profile/profile_page.dart` (link "Solicitudes de iglesias" for platform admins), `app/lib/l10n/app_{es,en,pt}.arb`
- Test: `app/test/requests_page_test.dart`

**Interfaces:**
- Consumes: `pendingChurchRequestsProvider`, `decideChurchRequest`, `slugFromName` (existing, `create_church_page.dart`).
- Each pending request shows church name, note, requester email, date, an address field prefilled with `slugFromName(churchName)` and validated with the existing slug pattern, a preview `<host>/c/<slug>`, buttons "Aprobar" and "Rechazar". Errors `church_slug_taken` / `church_slug_invalid` reuse the existing `slugTaken` / `slugInvalid` messages; `request_not_pending` → "Esta solicitud ya fue resuelta." and refresh. Non-platform-admins opening `/requests` see `l.notAllowed` (or the existing admin-gate message).
- ARB keys (same Spanish in all three): `churchRequests` "Solicitudes de iglesias", `approve` "Aprobar", `reject` "Rechazar", `requestAlreadyDecided` "Esta solicitud ya fue resuelta.", `noPendingRequests` "No hay solicitudes pendientes."

- [ ] **Step 1: Write failing tests:** `lists pending requests with a suggested address` (`"Iglesia Vida Nueva"` → field `iglesia-vida-nueva`); `approve sends the edited slug`; `a taken slug shows the message and keeps the request`; `reject sends approve: false`; `an empty list says so`.
- [ ] **Step 2: Run** `flutter test test/requests_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Platform admins approve church requests in the app"`.

### Task 13: Docs and release

**Files:**
- Modify: `README.md` (Churches and roles: sign-up choice, church requests, Owners promote Editors from People; Platform admin: approving requests in the app), `docs/MVP_PLAN.md` (status line)

- [ ] **Step 1: Update the docs** as above.
- [ ] **Step 2: Full check:** `cd app && flutter analyze && flutter test`, and the DB tests. Expected: no analyzer issues, all PASS.
- [ ] **Step 3: Commit** `git commit -m "Document the Today page, themes and church requests"`.
- [ ] **Step 4: Release — ask the user first.** Pushing the migration (`npx supabase db push`) and deploying (`flutter build web --release --dart-define-from-file=config/beta.json` then `npx --yes wrangler pages deploy build/web --project-name selah --branch main`) change the live app. The migration only adds a table and functions, so it is safe to push before the app deploy.
