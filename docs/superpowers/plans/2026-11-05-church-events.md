# Church Events Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An owner pastes their church's calendar link in Church settings, a Supabase function keeps that church's upcoming events in the database, and members see an "Eventos" tab (next event first) whenever there's something coming up.

**Architecture:** A Deno Edge Function `sync-church-events` fetches and parses each church's iCal feed and replaces its rows in a new `church_events` table through a service-role-only SQL function. `pg_cron` calls it every 3 hours for all churches; Church settings calls it for one church when the link changes. The Flutter app only reads `church_events` and shows a 4th shell tab when the current church has rows.

**Tech Stack:** Supabase (Postgres, pgTAP, pg_cron, pg_net, Vault, Edge Functions on Deno), `npm:ical.js@2.1.0` for parsing and recurrence, `npm:@date-fns/tz@1.2.0` for wall-clock ↔ UTC in IANA zones, Flutter (Riverpod, go_router, url_launcher).

**Spec:** `docs/superpowers/specs/2026-11-05-church-events-design.md`

## Global Constraints

- Window: events whose end is after now and whose start is within the next **60 days**, at most **20** per church, ordered by start.
- Refresh every **3 hours** for every church with a link.
- User-Agent on every feed request, exactly: `Selah-Calendar/1.0 (+https://selah-226.pages.dev)`. No other browser-like headers, no challenge handling, at most one ordinary retry.
- The Events Calendar conversion: `https://<host>/events/` (with or without trailing slash) → `https://<host>/?post_type=tribe_events&ical=1&eventDisplay=list`. `webcal://` is stored and fetched as `https://`.
- Timezone resolution: event `TZID` → feed `X-WR-TIMEZONE` → `churches.timezone` (default `Europe/Madrid`). Windows zone names map to IANA.
- Blocked-site copy (es): "El sitio web bloquea el acceso automático. Pide al administrador de la web que permita el calendario."
- Member copy is localized es/en/pt; admin pages stay Spanish (`inSpanish`), but still use ARB keys.
- Owners may update only explicitly granted `churches` columns; the new owner-editable columns are `events_calendar_url` and `timezone`. `events_synced_at` / `events_sync_error` are written only by the service role.
- Tests: `cd app && flutter analyze && flutter test`; `npx supabase test db` (README → Tests); `deno test` in `supabase/functions/sync-church-events/`.

## Review Focus

1. **A feed with no timezone anywhere** (floating times, no `X-WR-TIMEZONE`): times are read in `churches.timezone`, never UTC or the phone's zone. → Task 2 test `floating times use the church timezone`.
2. **The church's site still blocks Selah** (Cloudflare challenge page, HTTP 403/503 HTML): the owner sees the specific blocked message, the link is still saved, and previously stored events are kept. → Task 3 test `challenge page reports blocked and keeps events`; Task 5 test `blocked check still saves the link`.
3. **A weekly repeating meeting**: each occurrence inside the 60-day window appears, each with its own row id. → Task 2 test `weekly rule expands inside the window`.
4. **Owner clears the link**: events disappear and the tab goes away on the next read. → Task 1 test `clearing the link deletes events`.
5. **An event with no URL**: shown but not tappable, and no crash. → Task 6 test `event without url is not tappable`.

---

### Task 1: Schema — calendar columns, `church_events`, replace function

**Files:**
- Create: `supabase/migrations/202611050001_church_events.sql`
- Test: `supabase/tests/database/church_events_test.sql`

**Interfaces:**
- Produces:
  - `churches.events_calendar_url text null` (check: `~ '^https://'`), `churches.timezone text not null default 'Europe/Madrid'` (check: `public.is_timezone(timezone)`), `churches.events_synced_at timestamptz null`, `churches.events_sync_error text null`.
  - `public.is_timezone(p text) returns boolean` — true when `p` is in `pg_timezone_names`.
  - Table `public.church_events(church_id uuid references churches on delete cascade, uid text, title text not null, starts_at timestamptz not null, ends_at timestamptz not null, all_day boolean not null default false, local_starts_at timestamp not null, local_ends_at timestamp not null, location text, url text, timezone text not null, primary key (church_id, uid))`. `local_*` are the church's wall-clock times, so the app needs no timezone database.
  - `public.replace_church_events(p_church uuid, p_events jsonb) returns int` — security definer, executable by `service_role` only; deletes the church's rows, inserts the array (keys = column names above minus `church_id`), sets `events_synced_at = now()`, `events_sync_error = null`, returns the count.
  - `public.record_church_events_error(p_church uuid, p_error text) returns void` — service role only; sets `events_sync_error`, leaves rows alone.
  - Trigger on `churches`: when `events_calendar_url` changes to null, delete that church's `church_events` and null `events_synced_at` / `events_sync_error`.

- [ ] **Step 1: Write the failing pgTAP test** `church_events_test.sql`, using `tests.create_user` / `tests.act_as` / `tests.act_as_anon` from `00_helpers.sql`:
  - `has_table('public','church_events')`
  - anon can `select` from `church_events` (`lives_ok`)
  - owner can update `events_calendar_url` and `timezone` on their church (`lives_ok`); owner updating `events_synced_at` throws `42501`
  - `events_calendar_url = 'http://x'` throws `23514`; `timezone = 'Mars/Base'` throws `23514`
  - authenticated calling `replace_church_events` throws `42501`
  - as `service_role`: `replace_church_events(church_a, '[{"uid":"1",...}]')` returns `1` and `events_synced_at` is not null
  - **clearing the link deletes events:** after the replace, owner sets `events_calendar_url = null` → `select count(*) from church_events where church_id = church_a` is `0`

- [ ] **Step 2: Run it to see it fail**

Run (README → Tests): `npx supabase db reset && npx supabase test db`
Expected: `church_events_test.sql` fails at `has_table`.

- [ ] **Step 3: Write the migration** with the columns, function, table, RLS (`church_events_read` for `anon, authenticated` using `true`; no write policies), grants (`grant select on church_events to anon, authenticated`; extend the owner `grant update (...)` on `churches` with `events_calendar_url, timezone`; `revoke execute ... from public, anon, authenticated` and `grant execute ... to service_role` on both functions), and the trigger. Follow `202610280002_church_policies.sql` style (`set search_path = ''`).

- [ ] **Step 4: Run the database tests**

Run: `npx supabase db reset && npx supabase test db`
Expected: all files pass.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/202611050001_church_events.sql supabase/tests/database/church_events_test.sql
git commit -m "Store church calendar links and upcoming events"
```

---

### Task 2: Feed parsing (pure Deno module)

**Files:**
- Create: `supabase/functions/sync-church-events/feed.ts`, `supabase/functions/sync-church-events/deno.json` (imports for `ical.js` and `@date-fns/tz`, `test` task)
- Create: `supabase/functions/sync-church-events/feed_test.ts`, fixtures in `supabase/functions/sync-church-events/fixtures/` (`tribe.ics`, `google_utc.ics`, `floating.ics`, `weekly.ics`, `outlook_windows_tz.ics`) — small hand-written feeds, not downloaded

**Interfaces:**
- Produces:
  - `feedUrl(link: string): string` — normalizes per Global Constraints (webcal → https, `/events/` page → tribe ical URL, anything else unchanged).
  - `type ParsedEvent = { uid: string; title: string; starts_at: string; ends_at: string; all_day: boolean; local_starts_at: string; local_ends_at: string; location: string | null; url: string | null; timezone: string }` — `starts_at`/`ends_at` are UTC ISO strings, `local_*` are `YYYY-MM-DDTHH:mm:ss` with no offset.
  - `parseFeed(ics: string, opts: { now: Date; churchTimezone: string }): ParsedEvent[]` — applies the window, the 20 limit, start order, timezone resolution, and decodes HTML entities in title and location. Throws `NotCalendarError` when `ics` isn't a `VCALENDAR`.
  - `class NotCalendarError extends Error`

- [ ] **Step 0: Install Deno if missing** — `brew install deno`; `deno --version` prints 2.x.

- [ ] **Step 1: Write failing tests** in `feed_test.ts` (`now` fixed at `2026-11-05T10:00:00Z`, church zone `Europe/Madrid` unless noted):
  - `feedUrl`: `'webcal://a.org/x.ics'` → `'https://a.org/x.ics'`; `'https://icpresbiteriana.com/events/'` and `'https://icpresbiteriana.com/events'` → `'https://icpresbiteriana.com/?post_type=tribe_events&ical=1&eventDisplay=list'`; a Google ics URL is unchanged.
  - `tribe feed`: first event title `'Reunión de Mujeres – Mi hermana y amiga en la Fe'` (from `&#8211;`), `local_starts_at '2026-11-14T17:30:00'`, `starts_at '2026-11-14T16:30:00.000Z'`, `timezone 'Europe/Madrid'`, `url` set.
  - `google feed in UTC with X-WR-TIMEZONE America/Bogota`: `timezone 'America/Bogota'`, `local_*` in Bogotá wall-clock.
  - **`floating times use the church timezone`**: `floating.ics` with church zone `Europe/Lisbon` → `timezone 'Europe/Lisbon'`, `local_starts_at` equals the feed's literal time.
  - `outlook Windows zone`: `TZID:Romance Standard Time` → `timezone 'Europe/Paris'`.
  - **`weekly rule expands inside the window`**: `RRULE:FREQ=WEEKLY` starting `2026-11-08` → 9 occurrences (Nov 8 … Jan 3), distinct `uid`s of the form `<UID>@<starts_at>`.
  - window and cap: an event that ended yesterday and one 61 days out are dropped; 25 events in range → 20 returned, earliest first.
  - all-day: `DTSTART;VALUE=DATE:20261120` → `all_day true`, `local_starts_at '2026-11-20T00:00:00'`.
  - `parseFeed('<!DOCTYPE html>…')` throws `NotCalendarError`.

- [ ] **Step 2: Run to see them fail** — `cd supabase/functions/sync-church-events && deno test` → fails on missing exports.

- [ ] **Step 3: Implement `feed.ts`.** Use `ical.js` for parsing and `ICAL.RecurExpansion` / `Event.iterator()` for repeats; build UTC instants from wall-clock + zone with `TZDate` from `@date-fns/tz`. Keep the Windows→IANA map to the zones Outlook commonly emits (a dozen entries; unknown names fall through to the next step of the resolution chain).

- [ ] **Step 4: Run tests** — `deno test` → all pass.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/sync-church-events
git commit -m "Parse church calendar feeds into upcoming events"
```

---

### Task 3: The `sync-church-events` function

**Files:**
- Create: `supabase/functions/sync-church-events/sync.ts`, `supabase/functions/sync-church-events/index.ts`
- Test: `supabase/functions/sync-church-events/sync_test.ts`
- Modify: `supabase/config.toml` — add `[functions.sync-church-events]` with `verify_jwt = false` (the handler checks auth itself, because the cron call uses a shared secret, not a user JWT)

**Interfaces:**
- Consumes: `feedUrl`, `parseFeed`, `NotCalendarError` (Task 2); `replace_church_events`, `record_church_events_error`, `is_church_owner(p_church uuid)` (Task 1).
- Produces:
  - `type SyncResult = { ok: true; count: number } | { ok: false; error: 'blocked' | 'unreachable' | 'not_calendar' }`
  - `interface EventsStore { churchesWithLinks(): Promise<{ id: string; link: string; timezone: string }[]>; church(id: string): Promise<{ id: string; link: string | null; timezone: string } | null>; replace(id: string, events: ParsedEvent[]): Promise<number>; recordError(id: string, error: string): Promise<void> }`
  - `syncChurch(church: { id; link; timezone }, deps: { fetch: typeof fetch; store: EventsStore; now: Date }): Promise<SyncResult>` — fetches `feedUrl(link)` with the User-Agent, 15 s timeout, one retry on network error or 5xx that isn't a challenge; challenge = status 403/503 with `cf-mitigated: challenge` header or an HTML body containing `challenge-platform`; on failure calls `store.recordError` with the error code and leaves events alone.
  - HTTP contract of `index.ts` (POST JSON):
    - `{ "church_id": "<uuid>" }` with the caller's `Authorization: Bearer <user JWT>` → 403 unless `is_church_owner` is true for that user; else 200 with the `SyncResult`.
    - `{ "all": true }` with header `x-selah-cron: <SYNC_SECRET env>` → syncs every church with a link one after another (a failure doesn't stop the rest), 200 `{ "synced": n, "failed": m }`.
    - anything else → 400.

- [ ] **Step 1: Write failing tests** in `sync_test.ts` with a fake `fetch` and an in-memory `EventsStore`:
  - happy path: fake returns `tribe.ics` → `{ ok: true, count: 4 }`, store has 4 events, request carried `User-Agent: Selah-Calendar/1.0 (+https://selah-226.pages.dev)` and went to the converted tribe URL.
  - **`challenge page reports blocked and keeps events`**: store pre-seeded with 2 events; fake returns 403 + `cf-mitigated: challenge` → `{ ok: false, error: 'blocked' }`, store still has 2 events, recorded error `'blocked'`, fetched once (no retry).
  - HTML 200 that isn't a calendar → `not_calendar`.
  - network error twice → `unreachable`, fetched twice.
  - `all` mode: three churches, middle one fails → `{ synced: 2, failed: 1 }`.

- [ ] **Step 2: Run to see them fail** — `deno test` → fails on missing `sync.ts`.

- [ ] **Step 3: Implement `sync.ts`** (logic above) and **`index.ts`** (`Deno.serve`; builds a service-role client from `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` for the `EventsStore`, and a user client from the request's `Authorization` header for the `is_church_owner` RPC).

- [ ] **Step 4: Run tests** — `deno test` → all pass. Then serve locally: `npx supabase functions serve sync-church-events` and `curl` with `{ "all": true }` and the local secret → `200 {"synced":0,"failed":0}`.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/sync-church-events supabase/config.toml
git commit -m "Sync church calendars from a Supabase function"
```

---

### Task 4: Schedule every 3 hours, and release notes

**Files:**
- Create: `supabase/migrations/202611050002_church_events_cron.sql`
- Modify: `supabase/tests/database/church_events_test.sql` (one more assertion)
- Modify: `README.md` — new section "Church calendars"

**Interfaces:**
- Consumes: the HTTP contract of Task 3.
- Produces: cron job named `sync-church-events`, schedule `0 */3 * * *`, which `net.http_post`s `{ "all": true }` to `<project_url>/functions/v1/sync-church-events` with header `x-selah-cron`, reading `project_url` and `sync_church_events_secret` from `vault.decrypted_secrets` at run time (Supabase's documented pattern; no secret in the migration).

- [ ] **Step 1: Add the failing assertion** — `select is((select schedule from cron.job where jobname = 'sync-church-events'), '0 */3 * * *')`, and bump `plan(n)`.
- [ ] **Step 2: Run** `npx supabase db reset && npx supabase test db` → that assertion fails.
- [ ] **Step 3: Write the migration** — `create extension if not exists pg_cron` / `pg_net`, then `cron.schedule(...)`.
- [ ] **Step 4: Run** the database tests → all pass.
- [ ] **Step 5: README "Church calendars"** — release order: push migrations; `npx supabase functions deploy sync-church-events`; `npx supabase secrets set SYNC_SECRET=…`; create the two Vault secrets (`select vault.create_secret('<url>', 'project_url')`, `select vault.create_secret('<same secret>', 'sync_church_events_secret')`); then ship the app. Plus a short note owners can forward to their website admin: allow requests whose query contains `ical=1` past the bot check (Cloudflare: a WAF custom rule with action *Skip*), and that Selah identifies as `Selah-Calendar/1.0 (+https://selah-226.pages.dev)`.
- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/202611050002_church_events_cron.sql supabase/tests/database/church_events_test.sql README.md
git commit -m "Refresh church calendars every three hours"
```

---

### Task 5: App data layer and Church settings

**Files:**
- Modify: `app/lib/src/core/models.dart` (Church fields, new `ChurchEvent`, `EventsSyncResult`)
- Modify: `app/lib/src/data/repository.dart`, `app/lib/src/data/providers.dart`
- Modify: `app/lib/src/features/admin/church_settings_page.dart`
- Modify: `app/lib/l10n/app_es.arb`, `app_en.arb`, `app_pt.arb` (then `flutter gen-l10n`; generated files are committed)
- Test: `app/test/church_models_test.dart`, `app/test/church_settings_page_test.dart`

**Interfaces:**
- Consumes: Task 1 columns/table; Task 3 HTTP contract (called through `supabase.functions.invoke('sync-church-events', body: {'church_id': id})`).
- Produces:
  - `Church` gains `eventsCalendarUrl` (`String?`), `timezone` (`String`, default `'Europe/Madrid'` when absent), `eventsSyncedAt` (`DateTime?`), `eventsSyncError` (`String?`).
  - `class ChurchEvent { uid, title, startsAt (DateTime utc), endsAt, allDay, localStart (DateTime, wall-clock), localEnd, location (String?), url (Uri?) }` with `ChurchEvent.fromJson`. `local_*` are parsed as naive DateTimes and never converted.
  - `sealed class EventsSyncResult` → `EventsSynced(int count)` | `EventsSyncFailed(String error)`.
  - `SelahRepository.upcomingEvents(String churchId) → Future<List<ChurchEvent>>` (`ends_at > now()`, ordered by `starts_at`, limit 20).
  - `SelahRepository.syncChurchEvents(String churchId) → Future<EventsSyncResult>`.
  - `upcomingEventsProvider = FutureProvider.family<List<ChurchEvent>, String>` (by church id).

- [ ] **Step 1: Write failing tests**
  - models: `Church.fromJson` reads the four new fields and defaults `timezone`; `ChurchEvent.fromJson` keeps `localStart` as `DateTime(2026, 11, 14, 17, 30)` (not UTC-shifted) and `url` null when missing.
  - settings page (fake repo records `updates` and `syncCalls`):
    - typing `webcal://icpresbiteriana.com/?post_type=tribe_events&ical=1` and saving sends `events_calendar_url: 'https://icpresbiteriana.com/?post_type=tribe_events&ical=1'` and then calls `syncChurchEvents('A')`; with `EventsSynced(4)` the page shows "Se encontraron 4 próximos eventos".
    - **`blocked check still saves the link`**: `EventsSyncFailed('blocked')` → the update was sent and the page shows the blocked-site copy from Global Constraints.
    - saving with an unchanged link does not call `syncChurchEvents`.
    - clearing the field sends `events_calendar_url: null` and no sync call.
    - an `http://` or non-URL value shows a validation error and sends nothing.
    - choosing `Europe/Lisbon` in the timezone dropdown sends `timezone: 'Europe/Lisbon'`.
    - with `eventsSyncError: 'unreachable'` the page shows "No se pudo leer el calendario."; with `eventsSyncedAt` it shows "Última actualización: …".
- [ ] **Step 2: Run** `cd app && flutter test test/church_models_test.dart test/church_settings_page_test.dart` → fail.
- [ ] **Step 3: Implement.** Field label "Enlace del calendario", hint from the spec. Timezone dropdown: `Europe/Madrid`, `Europe/Lisbon`, `Europe/London`, `America/Bogota`, `America/Mexico_City`, `America/Sao_Paulo`, `America/New_York`, `America/Los_Angeles` (plus the church's current value if not in the list). Error codes map to copy: `blocked` → Global Constraints copy; `unreachable` → "No se pudo leer el calendario."; `not_calendar` → "Ese enlace no es un calendario." Add en/pt for each key.
- [ ] **Step 4: Run** `flutter analyze && flutter test` → all pass.
- [ ] **Step 5: Commit**

```bash
git add app/lib app/test
git commit -m "Let church owners add a calendar link"
```

---

### Task 6: The Eventos page

**Files:**
- Create: `app/lib/src/features/events/events_page.dart`, `app/lib/src/features/events/event_labels.dart`
- Modify: ARB files (+ `flutter gen-l10n`)
- Test: `app/test/events_page_test.dart`

**Interfaces:**
- Consumes: `ChurchEvent`, `upcomingEventsProvider` (Task 5); `HeroCard`, `SelahPage` (`onRefresh`), `SelahRow` from `app/lib/src/app/design/`.
- Produces:
  - `EventsPage({required Church church, void Function(Uri)? open})` — `open` defaults to `launchUrl(uri, mode: LaunchMode.externalApplication)`; tests pass a recorder.
  - `String heroDayLabel(DateTime localStart, DateTime today, AppLocalizations l, String locale)` — "Hoy" / "Mañana" / "Este sábado" (start within the next 6 days) / short date "sáb 14 nov".

- [ ] **Step 1: Write failing tests** (es locale, `today` = 2026-11-12 where it matters):
  - `heroDayLabel`: same day → "Hoy"; next day → "Mañana"; 2026-11-14 → "Este sábado"; 2026-11-21 → "sáb 21 nov".
  - page with the three spec events: the hero shows "Reunión de Mujeres – Mi hermana y amiga en la Fe", "17:30 – 19:30" and "Ver detalles"; "Después" lists the other two with date badges "14"/"sáb" and "21"/"sáb".
  - tapping "Ver detalles" calls `open` with the first event's URL; tapping a row opens that row's URL.
  - **`event without url is not tappable`**: tapping it calls nothing, and the hero shows no "Ver detalles".
  - all-day event shows its date with no time range.
  - pull to refresh invalidates `upcomingEventsProvider` (the fake repo's `upcomingEvents` call count goes from 1 to 2).
- [ ] **Step 2: Run** `flutter test test/events_page_test.dart` → fail.
- [ ] **Step 3: Implement** — eyebrow church name, title "Eventos"; `HeroCard` with the orange `heroDayLabel` as eyebrow-style label and footer holding time/place and a "Ver detalles" pill; "Después" section of rows (date badge + title + time). Times format `HH:mm` from `localStart`/`localEnd`.
- [ ] **Step 4: Run** `flutter analyze && flutter test` → pass.
- [ ] **Step 5: Commit**

```bash
git add app/lib app/test
git commit -m "Show a church's upcoming events"
```

---

### Task 7: The 4th tab, shown only when there are events

**Files:**
- Modify: `app/lib/src/app/app.dart` (new shell branch), `app/lib/src/app/shell.dart`
- Modify: ARB files (`tabEvents`: es "Eventos", en "Events", pt "Eventos"; + `flutter gen-l10n`)
- Test: `app/test/shell_test.dart`

**Interfaces:**
- Consumes: `EventsPage` (Task 6), `upcomingEventsProvider` (Task 5), `currentChurchProvider`.
- Produces:
  - Shell branches in order: Hoy (0), Estudios (1), Eventos (2, route `/c/:church/events`, placeholder `initialLocation: '/c/_/events'` like Estudios), Perfil (3).
  - `tabIndexFor`: `/c/<x>/events` → 2, other `/c/…` → 1, `/profile…` → 3, else 0.
  - The bar/rail lists the Eventos tab only when `currentChurchProvider` has a church and `upcomingEventsProvider(church.id)` has at least one event; the shell maps visible positions ↔ branch indexes so Perfil still works when Eventos is hidden. Tapping Eventos goes to `/c/<current slug>/events`. Icon: `Icons.event_outlined` / `Icons.event`, SF Symbols `calendar` / `calendar` (filled variant if available in the tab bar package).

- [ ] **Step 1: Update/write failing tests** in `shell_test.dart` (fake repo gains `upcomingEvents`):
  - `tabIndexFor('/c/x/events')` is 2 and `tabIndexFor('/profile')` is 3.
  - with one upcoming event: "Eventos" is in the bar between "Estudios" and "Perfil"; tapping it goes to `/c/vida-nueva/events`.
  - with no events: no "Eventos" in the bar, and tapping "Perfil" still goes to `/profile`.
  - with no current church: no "Eventos".
  - the existing "three tabs" test becomes "the profile page shows Hoy, Estudios and Perfil when there are no events".
- [ ] **Step 2: Run** `flutter test test/shell_test.dart` → fail.
- [ ] **Step 3: Implement** the branch and the visible-tab mapping.
- [ ] **Step 4: Run** the full suite: `flutter analyze && flutter test` → pass; `npx supabase test db` → pass; `deno test` in the function folder → pass.
- [ ] **Step 5: Verify in the app** — `flutter run -d chrome --dart-define-from-file=config/beta.json` against a local stack seeded with a church that has `church_events` rows: the Eventos tab appears, shows the hero and list, and disappears after the link is cleared in Church settings.
- [ ] **Step 6: Commit**

```bash
git add app/lib app/test
git commit -m "Add the Eventos tab when a church has upcoming events"
```
