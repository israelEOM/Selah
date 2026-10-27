# New look, Today page and sign-up roles — design

Date: 2026-10-27

## Why

Selah works, but it reads like a website: a list of churches, then a list of studies, then a reader. The goal is for it to feel like a daily devotional app in the style of Verbo: you open it, it shows you today's devotional, you tick it off, and you come back tomorrow. Two other rough edges go with this: the look should belong to the church (the palette of icpresbiteriana.com) with a dark mode for night reading, and creating an account should let people say who they are instead of depending on an invite link for everything.

Success: a member opens the app, lands on Today, sees the next part of this week's study, ticks it off as they go, and can see the week's progress at a glance, without needing an account.

## Order of work

Three pieces, built and shipped in this order. Each builds on the one before.

1. New look and app layout
2. Today page
3. Sign-up choice and church requests

---

## 1. New look and app layout

### Light theme (default) — from icpresbiteriana.com

Colors measured from the live site:

| Use | Color |
|---|---|
| Text, headings | navy `#0E2341` |
| Main color (buttons, selected tab, done ticks, hero card) | forest green `#2E4A38` |
| Page background | white `#FFFFFF` |
| Cards, rows, secondary surfaces | light grey `#EDEFF3` |
| Muted text | `#697380` |
| Accent, used sparingly (today's ring in the week row, small highlights) | orange `#F15A24` |

This replaces the current cream/ink/gold palette in `app/lib/src/app/theme.dart`.

### Dark theme — Verbo-like

Near-black background (`#0B0B0C`), dark grey cards and rows (`#1A1A1C`), off-white text, green accent (`#5BC49A`) for ticks and the selected tab, warm brown/gold for completed days in the week row and for the hero card. Exact values are the builder's call within that direction; the mockup in the brainstorm session used these.

### Choosing the theme

Follows the phone's light/dark setting. A switch in Perfil overrides it (Sistema / Claro / Oscuro), saved on the device like the language choice. *(My call.)*

### Type

The plain system font for UI, as the church site uses. A serif (Georgia, as now) only for the devotional quote on the hero card and long reading text (reflection, prayer). *(My call.)*

### App layout

A bottom tab bar, floating and rounded as in Verbo, with three tabs *(my call; the user did not pick the tabs)*:

- **Hoy** — the Today page (piece 2). The app opens here.
- **Estudios** — the current church's published studies: today's church page.
- **Perfil** — current church and switching churches, language, theme, sign in / sign out, and the admin area link for Owners and Editors. Platform admins also see church requests here (piece 3).

Deep links keep working: `/c/<slug>/studies/...`, `/join/<token>` and admin routes still open the same pages; the tab bar is shown on the main member pages (Hoy, Estudios, Perfil, study and reader), not on admin, login or join pages *(builder can adjust where it shows)*.

**Current church.** Today and Estudios need one church. For a signed-in person it is the church they belong to (if several, the last one chosen, switchable in Perfil). For someone without an account, they pick a church once on first open and the device remembers it. The existing home page (list of all churches) becomes that picker. *(My call.)*

All existing pages, admin included, are restyled to the new themes. Admin pages stay in Spanish as now.

---

## 2. Today page

### Which devotional it shows

Always from the current church's **newest published study**.

- It shows **your next unfinished day** of that study — the lowest-numbered day not yet done *(my call)*, not the day matching the calendar (the user's words: members complete devotionals on different days, not necessarily starting Monday). Start on Tuesday → Tuesday shows Day 1. Skip a day → you pick up where you left off.
- When a newer study is published, Today moves to it. Unfinished days of the old study stay reachable from its study page but don't follow you. *(Confirmed by the user.)*

### The day card — only content Selah already has

From the existing `devotional_days` row:

- Header: study title, "Día N de M", date.
- Hero card: the day's title and its main idea (serif quote).
- Three rows, **each with its own tick**:
  - **Lectura bíblica** — the day's `bible_reading`; tapping opens the existing external Bible link.
  - **Reflexión** — reflection, application and questions; tapping opens that day in the existing reader.
  - **Oración** — the prayer; tapping opens the reader at the prayer.
- A day is done when all its parts are ticked. If a day has no Bible reading or no prayer, that row isn't shown and the day is done when the rows that exist are ticked.
- A **"Resumen del sermón"** button opening the existing study page (summary and day boxes). It shows on every Today state.

The per-part ticks replace the reader's "Marcar como leído" button. Existing "read" marks on devices (`read:<studyId>` in SharedPreferences) should count as all parts done for that day, so nobody loses progress.

### After finishing a day

Once all parts of a day are ticked, Today shows that day's card as **"Hecho por hoy ✓"** for the rest of the local calendar day, and offers the next unfinished day from the next local day onward. *(Confirmed by the user.)* A small **"Leer el siguiente"** link under the done card opens the next day in the reader for people who want to keep going; finishing it there counts as done (and, if finished on the same date, adds no extra circle to the week row).

### The week row (Mon–Sun)

A row of seven circles for the current week. A circle is marked on each day the person **finished a devotional day** (all its parts ticked that day). Today's circle is highlighted. It is a streak for the week, not a map of Day 1–7. This means completion dates must be stored, not just which days are done.

### When there is nothing left to do

When every day of the newest study is done, or the study is shorter than the week and the person has finished it, Today shows instead:

- the sermon's **main passage** (`summary.main_passage`) with a link to read it in the Bible, and
- one of the sermon's **key takeaways** (`summary.key_takeaways`) as the quote.

Selah stores Bible references but not verse text, so it shows the reference and a link rather than the verse wording. *(Since Today always shows the lowest unfinished day, this state only appears once every day is done; there is no separate catch-up row.)* *(Rule for picking the takeaway — e.g. rotating by date — is the builder's call.)*

If the church has no published study yet, Today says so plainly and links to Estudios.

### Where progress lives

On the device, like today, so members still need no account. *(My call; syncing progress to an account is out of scope.)*

---

## 3. Sign-up choice and church requests

After creating an account (email or Google), people choose who they are. Nobody can give themselves editing power.

Because Google sign-in skips the sign-up form, the choice is a step shown right after the first sign-in for anyone who belongs to no church and has no pending request, not a field on the form. *(My calls below.)*

- The step can be skipped ("Ahora no"); skipping is remembered on the device so it doesn't return every launch. Someone signed in with no church keeps using the church already picked on the device, without joining it.
- Platform admins never see the step. Accounts that already have a church don't either.
- The same two choices stay available later from Perfil, so a person who skipped, or whose request was rejected, can join a church or send a new request.

### "Soy miembro de una iglesia"

Pick a church from the list → join immediately as **Member** (the existing `join_church` function). That church becomes their current church.

### "Soy pastor o líder: quiero traer mi iglesia a Selah"

Enter the church name and a short note → creates a **church request**. The church's address (slug, permanent once created) is suggested from the name and the platform admin can edit it on the approve screen before approving; approval fails with a clear message if it's taken. *(My call.)* The person sees that it's waiting for approval. A platform admin sees pending requests in the app (Perfil → Solicitudes) and approves or rejects. Approving creates the church (as `create_church` does today) with the requester as **Owner**. Rejecting tells the requester next time they open the app. *(Email notifications are out of scope; the admin checks in the app.)*

The person can also join a church as a member while their request waits.

### Editors

Never chosen at sign-up. An Owner promotes an existing Member from the People page (the existing `set_member_role`), or sends an Editor invite link as now.

### Invite links

Unchanged. Someone arriving through an invite link gets the link's role and skips the choice.

### Data

A new `church_requests` table (requester, church name, note, status, timestamps) with row-level security: requesters read their own, platform admins read and decide all. Approval goes through a security-definer function so the church and the Owner membership are created together.

---

## Non-goals

- Syncing reading progress across devices or to an account.
- Showing Bible verse text inside the app.
- Community, prayer-request or "Explorar" features from Verbo; likes, comments, shares.
- Letting anyone request or self-select the Editor role.
- Notifications (push or email) for new devotionals or church requests.
- Changing how sermons are imported or how studies are generated.

## Anti-goals

- Members being forced to create an account to read or tick off devotionals.
- Any path where someone gets Owner or Editor without a person approving it.
- Breaking existing links (`/c/...`, `/studies/...`, `/join/...`) or losing existing "read" marks.

## Constraints

- Flutter (Riverpod + go_router), all data access through `lib/src/data/repository.dart`; Supabase with row-level security; new schema as migrations in `supabase/migrations/`.
- Web, iOS and Android; must look right at phone width and on desktop (content stays width-capped as `PageBody` does now).
- Member pages are in Spanish, Portuguese and English (existing localization files); admin pages stay Spanish.

## Left to the builder

- Exact dark-theme values, spacing, icons, animation.
- Where exactly the tab bar shows and hides.
- How the takeaway is picked on "nothing left" days.
- Data shapes for local progress (must record which parts are done and the date each day was finished).
