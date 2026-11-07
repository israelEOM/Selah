# Design system, responsive web and landing page — design

Date: 2026-11-07

## Why

Selah's screens work, and the 2026-10-28 redesign gave the phone app real polish: the Liquid Glass tab bar on iOS, spring presses, the hero card and skeletons. Two things still keep it from feeling like a premium product:

- **On a computer it is a phone app in a browser tab.** At 840 px and wider, the shell swaps the bottom bar for a `NavigationRail` and every page centers one 760 px column (`SelahPage`/`PageBody`). The result is mobile content floating in a big screen, not a website.
- **The look isn't settled.** The owner is unhappy with the current green, wants a dark gray instead of today's near-black dark mode, and feels the spacing is loose. For example, the gap between the last item and the bottom tab bar is too big.

The owner wants both surfaces to look like premium products: **the website should look like a website, and the app like an app**, responsive and good at every size. They also want a written design system so that every screen, and every future screen, follows the same rules.

The audience is the same on both surfaces: church members reading their church's studies. A new **landing page** is added for people who don't know Selah yet, both members and church leaders.

Success: someone opening Selah on a laptop sees a real website, with top navigation, content in columns and a comfortable reading width. Someone opening it on a phone sees a native-feeling app. Both share one identity that feels like a well-made devotional book: calm, warm and personal. A stranger arriving at the landing page understands how Selah works and why studying God's Word matters.

## Goals

1. **A design system**, written down and built in code: colors, type, spacing, radii, elevation, motion and the shared components, for light and dark mode.
2. **A new look** applied to every screen (members first, then admin): the palette, type and spacing below.
3. **Responsive web layouts.** Wide screens get a website layout with top navigation and multi-column pages instead of a stretched phone column.
4. **A landing page** that explains how Selah works and shares the importance of knowing God through His Word, for members and church leaders.
5. **Spacing fixes** the owner called out, starting with the extra space above the bottom tab bar.

## Non-goals

- No new app features, data or backend changes. Pages keep their routes, data, copy and behavior, except where a desktop layout rearranges *where* things sit.
- The native-platform decisions of 2026-10-28 stand: Liquid Glass tab bar on iOS 26, Material on Android, platform page transitions, haptics, Reduce Motion support. This project re-skins and re-lays them out; it doesn't replace them.
- No native iPad- or tablet-specific redesign beyond what the responsive rules below give for free.
- No marketing extras on the landing page: no blog, pricing, testimonials carousel or newsletter.

## Anti-goals (failure even if it "works")

- **The phone layout stretched onto a desktop**, or a desktop layout squeezed onto a phone. Each size must look designed for itself.
- **Reading lines that run across a wide screen.** Long text (reflection, prayer, the reader) keeps a comfortable measure of about 60–75 characters at every width.
- **Terracotta used as a large fill.** It's a highlight color only. A screen that looks orange has failed.
- **Generic "AI template" design:** stock gradients, glowing cards, emoji icons, centered hero plus three icon cards that could belong to any product.
- **A slow or unindexable landing page.** It's the front door: it must load fast and be readable by search engines and link previews.
- **Losing what works:** the iOS glass tab bar, back navigation, deep links, the tests in `app/test/`, or VoiceOver/TalkBack access.
- **Poor contrast.** Text and controls meet WCAG AA in both themes, including terracotta and sage on their backgrounds.

## Constraints

- Flutter app as today (Flutter 3.47.4, Riverpod, go_router), deployed to Cloudflare Pages (README). iOS, Android and web builds keep working.
- Member screens stay localized (pt/es/en); admin screens stay in Spanish (`inSpanish`).
- **This supersedes the brand colors** in `2026-10-27-app-look-today-and-signup-roles-design.md` and the "no new hues" constraint in `2026-10-28-premium-ui-design.md`. Those came from one church's website (icpresbiteriana.com). Selah now serves many churches and gets its own palette. *(Decided by the owner in this brainstorm.)*

## The look (decided by the owner)

Chosen from mockups in the brainstorm (`.superpowers/brainstorm/…/look-mix.html`, local only): **"warm paper" (A) mixed with "green, refined" (C), with terracotta as the second color.**

**Feeling:** a well-made devotional book or journal. Calm, warm and personal, not a tech dashboard.

**Palette.** Starting values from the chosen mockup. The builder may adjust them for contrast and harmony, but must keep the direction.

| Role | Light | Dark |
|---|---|---|
| Page background | cream paper `#FAF7F2` | warm charcoal gray `#1E1C1A` (not black) |
| Raised surface (cards, rows) | `#F1EBE1` | `#272421` (one step lighter than the page) |
| Text | warm charcoal `#262320` | warm off-white `#EDE8E1` |
| Muted text | `#857B6F` | `#9C948A` |
| Primary: Selah green (hero card, main buttons, active tab, links) | forest `#2F5D4A` | soft sage `#A9CDB8` for controls; deep green `#26332C` for the hero card |
| Highlight: terracotta (today's marker, unread/new, progress, small badges) | `#B0573A` | `#E0906E` |

Rules:
- **One strong color for big areas (green), one only for small marks (terracotta).** *(My call, from the owner's choice.)*
- Dark mode is gray, never pure black; surfaces get lighter as they rise.
- Pure white and pure black don't appear as backgrounds.

**Type.**
- **Serif** for headings, Scripture, the hero quote and long reading text. *(Decided: the chosen mockups use serif headings.)* Georgia is replaced by a bundled serif with real italics, so it looks the same on every device and on the web. *(My call; the builder picks the face. It must have Latin Extended coverage for pt/es accents and a good italic, for example Source Serif 4, Literata or Newsreader, all open-licensed.)*
- **Sans-serif** for UI: labels, buttons, lists, navigation and forms. System font, or one bundled sans if the serif needs a better partner. *(Builder's call.)*
- A defined type scale, used everywhere (no ad-hoc font sizes in pages).

**Spacing.** Keep the 4/8-based scale in `tokens.dart`, applied consistently. Tighten where the owner found it loose. Concretely, the scroll padding below content on tab pages is currently `40 + bottom inset` (`selah_page.dart:108`), and it should leave only a small, consistent gap above the tab bar.

## Layout by screen size (decided by the owner: option B, "website" on desktop)

Chosen from the layout mockups (`.superpowers/brainstorm/…/desktop-layout.html`).

| Width | Web | iOS / Android app |
|---|---|---|
| Phone (< 600 px) | App layout: bottom tab bar, one column | App layout, as today (glass bar on iOS) |
| Tablet (600–1023 px) | Bottom bar; pages use two columns where they fit | Same |
| Desktop (≥ 1024 px) | **Website layout:** top navigation bar, centered content area with a maximum width (about 1200 px), multi-column pages | n/a |

*(Breakpoint values are my call; the builder may tune them.)* The current `NavigationRail` on wide screens goes away.

**Top navigation (desktop web):** the Selah wordmark on the left; Hoje / Estudos / Eventos as text links; on the right, the church picker and the profile or sign-in entry. It replaces the tab bar and keeps the same destinations, routes and tab-memory behavior.

**Pages at desktop width.** These are directions; the builder lays out the details.
- **Hoje:** a main column with the hero card (today's reading) and today's parts. A side column with this week and upcoming events.
- **Estudos (church page):** studies as a grid of cards (2–3 across) instead of a list.
- **Study page:** the study's overview and its days side by side.
- **Reader:** the text stays one comfortable reading column. A side column (sticky) shows the study's days and parts for navigation. *(My call.)*
- **Eventos:** a two-column grid or a list with dates set apart.
- **Perfil, sign-in, join, welcome, create church:** forms stay narrow and centered; they never stretch.
- **Admin:** the same top navigation and theme. Lists and the sermon page use the wider space where it helps (for example, two panes on the sermon page). Lower priority than member screens.

## Landing page

**Who it's for:** strangers. Mostly church members who want to read, and also church leaders deciding whether to bring their church onto Selah. *(Owner.)*

**What it must do:** *(Owner.)*
1. Share the importance of knowing God by studying His Word. This leads; it's not a feature list.
2. Explain how Selah works.

**Shape.** *(My proposal, which the owner accepted as a direction. Copy and exact sections are the builder's.)*
1. A verse-led opening about why the Word matters, with a "start reading" action.
2. How it works in three steps: the church's Sunday sermon → a short daily study → read and reflect through the week.
3. A glimpse of the product on a phone and a laptop: screenshots of the real app in the new look. *(My call: the screenshots use a made-up demo church and studies, not a real church's name or sermons, because the page is public and indexed. Run the app on sample data for the captures, as the 2026-10-28 spike's `spike_main.dart` did. Add no demo church to the database. The owner can swap in a real church later with that church's consent.)*
4. For members: find your church and start reading.
5. For leaders: a clear section on bringing your church's sermons to Selah, leading to the existing church-request flow (`/churches/new` / sign-up).

**How it's built.** *(My call, which the owner accepted.)* A separate, lightweight static website, not a Flutter screen, so it loads fast, is indexable and feels like a website. It lives in the repo as its own folder (for example `site/`), uses the same palette and fonts as the app, and links into the app for every action. Plain HTML/CSS or a small static generator: the builder's call, preferring the fewest dependencies. It's localized in pt/es/en like the member app.

**Where it lives.** It uses the same address and the same Cloudflare Pages deploy as the app.
- **The landing page takes the root, `/`.** *(My call.)*
- **The app's Today page moves to its own path** (for example `/hoje`). The router, the shell's Hoje branch, tab memory and any links or redirects to `/` move with it. The native apps still open on Today. Supabase auth redirects and every existing deep link (`/c/…`, `/join/…`, legacy `/studies/…`) must keep working.
- **Returning members skip the landing page.** *(Decided by the owner.)* A visitor who has already picked a church or is signed in goes straight to Today; only newcomers see the landing page. The app stores that state in the browser on the same origin, so a small check on the static page can redirect before it paints. The builder picks the mechanism.
- **The builder needs a way to show the landing page to someone who already uses the app**, for example a link in Perfil or the footer, or a query flag like `/?home`.

## How the design system is delivered

*(My call.)*
1. **`DESIGN.md`** at the repo root: the rules in plain words (palette and roles, type scale, spacing, radii, elevation, motion, components, responsive rules, do's and don'ts). It's the source of truth that people and agents read.
2. **Flutter tokens and components:** `app/lib/src/app/theme.dart` and `app/lib/src/app/design/` updated to match: palette, type scale, spacing, radii, elevation and motion tokens, plus the shared components, including the new top navigation and a responsive layout helper (columns at breakpoints). Pages use tokens and components, not raw values.
3. **Landing page styles** use the same tokens (as CSS custom properties).
4. **A visual style guide** page showing the colors, type and components in both themes, published as a shareable artifact for the owner to review before screens are redone. **This review is a hard stop.** *(My call: the owner cares most about the look, and changing the palette after screens are redone costs far more.)* Work pauses after the tokens, `DESIGN.md` and the style guide until the owner approves, and color or type changes from that review are expected.

## Tools

*(Recommended to the owner in the brainstorm.)* The **Impeccable** skill (installed at `~/.claude/skills/impeccable`) is used for critique, audits and polish passes per screen, and for structuring `DESIGN.md`. Its code advice is web-oriented, so for Flutter screens use its design principles, not its CSS suggestions. Its "Persuade" mode applies to the landing page, "Read" to the reader and studies, and "Operate" to admin.

## Testing and verification

- Existing tests in `app/test/` keep passing. Update a finder only where a widget type changed on purpose, and keep what it asserts.
- Add widget tests for the responsive shell: top navigation at desktop width, bottom bar below it, and the same destinations in both.
- Check every member screen in both themes at phone (375), tablet (768) and desktop (1280 and 1920) widths in Chrome, and on the iOS Simulator.
- Check contrast (AA) for text, terracotta and sage in both themes.
- Check the landing page at phone and desktop widths, its link preview (title, description, image) and its load time.

## Left to the builder

- Exact color values within the direction above, the serif face and the sans choice.
- Exact breakpoints, max widths and column ratios.
- The landing page's copy, section details and static tooling.
- The order of work. Recommended: design system (tokens, components, `DESIGN.md`, style guide) → shell and top navigation → member screens (Hoje, Estudos, study, reader, Eventos, Perfil) → landing page → admin.
- How to split the work into PRs (one per step above is a good default).
