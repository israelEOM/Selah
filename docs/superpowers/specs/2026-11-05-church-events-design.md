# Church events tab — design

Date: 2026-11-05

## Why

Churches already publish their upcoming meetings on their own websites (for example https://icpresbiteriana.com/events/, a WordPress site using The Events Calendar). Members open Selah on a Sunday morning to read, and it's the natural place to also see what's coming up at their church. The owner wants each church to opt in by pasting one link, with no extra data entry in Selah.

Success: an owner pastes their church's calendar link once, and from then on members of that church see an "Eventos" tab with what's coming up, kept current without anyone touching Selah and without the owner's Mac being on.

## Goals

- **Church settings (owner only):** a new optional field, "Enlace del calendario" (events calendar link). Saving checks the link straight away and tells the owner what it found ("Se encontraron 4 próximos eventos") or that it couldn't read it.
- **Members:** a new 4th tab, **Eventos**, after Estudios and before Perfil. It shows the current church's upcoming events, next one first (layout B from the brainstorm, see **Members' Eventos tab**).
- **Freshness:** events refresh on Supabase's side every few hours, independent of the worker on the owner's Mac.
- Works for any church that has a standard calendar feed, not just this one.

## Non-goals

- No creating or editing events inside Selah. The church's website or calendar stays the source of truth.
- No event detail page inside Selah; tapping an event opens the church's own event page.
- No reminders, notifications, RSVPs or "add to my calendar" button.
- No events on the Hoy tab.
- The worker on the Mac is not involved.

## Anti-goals (failure even if it "works")

- Getting past a website's bot protection (fake browser headers, challenge solvers, proxies). If a church's site blocks Selah's server, the fix is the site owner allowing the feed, or a different feed. Selah only makes plain, honest requests.
- A tab that shows up empty, broken or stale. If there's nothing to show, the tab isn't there.
- Event times shown in the phone's timezone when that differs from the church's (these are in-person meetings).
- One church's broken feed affecting other churches' refreshes.

## Constraints

- Flutter app (Riverpod + go_router), all data access through `app/lib/src/data/repository.dart`. Schema and row-level security in `supabase/migrations/`, with database tests in `supabase/tests/database/`.
- `churches` is readable by anyone (`churches_read`), and owners may update only an explicit column list (`grant update (...)` in `202610280002_church_policies.sql`). The new column must be added to that grant.
- Member screens are localized es/en/pt; admin screens stay in Spanish.
- Selah has no Supabase Edge Functions or `pg_cron` jobs yet. This feature adds the first ones, so deploy steps belong in the README.
- **Known dependency:** icpresbiteriana.com sits behind a Cloudflare bot check that challenges non-browser requests. The church's website admin will add a rule letting the events feed through (the owner is asking them). Until then that church's link will fail the save-time check, and that is the expected, correct behavior.

## How it's built (decided)

### The link

- New nullable column `churches.events_calendar_url` (text, `https://` or `webcal://`, which is stored as `https://`).
- Accepted links, in order of preference:
  1. An iCalendar feed (`.ics` / `webcal://` / any URL that returns `text/calendar`). This is the universal format: Google Calendar, Outlook and The Events Calendar all publish one.
  2. A The Events Calendar events page such as `https://site/events/`. The function turns it into that site's iCal feed (`https://site/?post_type=tribe_events&ical=1&eventDisplay=list`).
- Clearing the field turns the feature off for that church and deletes its stored events.

### Refresh (Supabase, every few hours)

- A Supabase Edge Function, `sync-church-events`, fetches each church's feed, parses it, and replaces that church's upcoming events in a new `church_events` table using the service role.
- `pg_cron` (calling the function via `pg_net`) runs it every 3 hours for all churches with a link.
- The same function, called for one church, does the save-time check. It returns how many upcoming events it found or why it failed, and it also stores them, so the tab appears straight away.
- Each church is fetched on its own with a timeout; a failure is recorded on that church and doesn't stop the others. On failure the previously stored events stay until they pass.
- Requests identify honestly as Selah with a fixed User-Agent, `Selah-Calendar/1.0 (+https://selah-226.pages.dev)`, which must not change once churches rely on it. No retry tricks beyond one ordinary retry. *(My call.)*
- **What the website admin allows** *(my call)*: Supabase functions have no fixed IP, so the rule matches the request path, not an address. For The Events Calendar sites, the owner pastes the site's own "subscribe" feed link (`https://site/?post_type=tribe_events&ical=1&eventDisplay=list`, the `webcal://` link behind the events page's export button), and Selah requests exactly that URL. The admin's Cloudflare rule skips the bot check for requests whose query contains `ical=1`. When the owner pastes the `/events/` page instead, the function converts it to that same URL, so the rule still matches. The README gets a short note an owner can forward to their website admin.
- The save-time error tells a blocked request apart from other failures: a Cloudflare challenge response (HTTP 403/503 with an HTML challenge page) shows "El sitio web bloquea el acceso automático. Pide al administrador de la web que permita el calendario." rather than a generic error.

### `church_events` table

- One row per upcoming event: `church_id`, a stable id from the feed (iCal `UID` plus start time for repeating events), `title`, `starts_at` / `ends_at` (timestamptz), `all_day`, `location` (text), `url` (the event's page), `timezone` (the church calendar's TZID).
- **Timezone** *(my call)*: the event's `TZID`, else the feed's `X-WR-TIMEZONE`, else the church's new `churches.timezone` column (IANA name, default `Europe/Madrid`). Floating times are read in that timezone. Windows zone names (Outlook) are mapped to IANA names. `churches.timezone` is added to the owner `grant update` and appears on Church settings as a dropdown of common zones.
- Only events from now through the next **60 days**, at most **20** per church *(my call)*.
- Anyone can read (`anon` and `authenticated`, like `churches`); only the service role writes.
- `churches` also gets `events_synced_at` and `events_sync_error` so the owner's settings page can show the last refresh or the last problem.

### Members' Eventos tab

- Shows only when the member's current church has at least one upcoming event in `church_events`. No church picked, no link, or no upcoming events: no tab (the bar keeps its 3 tabs).
- Layout B from the brainstorm:
  - Eyebrow with the church name, title "Eventos".
  - The next event in the green hero card (`heroStart`→`heroEnd`), with a small orange label ("Hoy", "Mañana", "Este sábado", or the date), the title, day and time range, place, and a "Ver detalles" button.
  - A "Después" list below: date badge (day number and short weekday) on the left, title and time on the right.
- Times are shown in the church calendar's timezone. All-day events show the date without a time.
- Tapping the hero card or a row opens the event's `url` outside the app, the same way Bible readings open in YouVersion. An event with no `url` isn't tappable.
- Pull to refresh re-reads `church_events` (it doesn't trigger a feed fetch).
- Event titles from feeds may contain HTML entities (`&#8211;`); they're decoded before storing.

### Church settings

- The field sits on `ChurchSettingsPage` with a short hint: "Pega el enlace del calendario de tu iglesia (iCal, Google Calendar o la página de eventos de tu web)."
- On save, if the link changed, the page calls the function for this church and shows the result under the field. The link is saved even if the check fails, so the refresh keeps trying (useful while the website admin is still setting things up), and the error is shown.
- Below the field: "Última actualización: …" or the last error, from `events_synced_at` / `events_sync_error`.

## Left to the builder

- iCal parsing library for Deno, and how much of RRULE to expand (at minimum, weekly and monthly repeats within the 60-day window).
- Exact tab icon (a calendar symbol, matching how the other tabs pair a Material icon with an SF Symbol).
- How the shell's tab indexes and `tabIndexFor` change when the 4th tab may or may not be there.
- Where the function's secret for the cron call lives, following Supabase's recommended pattern.
- Copy for en/pt.
