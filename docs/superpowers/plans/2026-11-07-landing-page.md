# Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fast, indexable landing page at Selah's root address. It shares why knowing God through His Word matters and explains how Selah works, for both members and church leaders. Returning members skip it and go straight to Today.

**Architecture:**
- **The app moves off the root.** Today moves to `/hoje`, and a router redirect sends `/` there, so in-app links and the native apps don't change.
- **The landing page is a static site** in `site/` with no framework. A small Python build script renders one HTML template into Spanish (`/`), Portuguese (`/pt/`) and English (`/en/`) pages from three JSON string files.
- **One build assembles both.** `app/tool/build_web.sh` builds Flutter, renames its `index.html` to `app.html`, copies the landing pages in, and writes a Cloudflare `_redirects` file that sends every app route to `app.html`.
- **Skipping the landing page.** A tiny inline script on the landing page sends returning members to `/hoje`, and forwards auth returns (email links), before the page paints.

**Tech Stack:** Flutter 3.47.4 and go_router for the app; plain HTML/CSS for the site, plus Python 3 stdlib for building it; Node 22 (`/usr/local/n/versions/node/22.21.0/bin/node`) for testing the redirect script; Cloudflare Pages.

**Spec:** `docs/superpowers/specs/2026-11-07-design-system-and-responsive-web-design.md` (section "Landing page"). Look and tokens: `DESIGN.md`.

## Global Constraints

- **Purpose** (owner): first, share the importance of knowing God by studying His Word, which leads the page and isn't a feature list; then explain how Selah works.
- **Audience:** church members first, plus a clear section for leaders.
- **Sections, in order:**
  1. Verse-led opening with "start reading".
  2. How it works in three steps: the church's Sunday sermon → a short daily study → read and reflect.
  3. A glimpse of the product on a phone and a laptop.
  4. For members: find your church and start reading.
  5. For leaders: bring your church's sermons to Selah.
- **Screenshots** use a made-up demo church, never a real church's name or sermons.
- **Same address and deploy as the app.**
  - The landing page takes `/`.
  - Returning members (a church picked, or signed in) skip it and go to Today.
  - Someone who uses the app can still see it at `/?home`.
- **Every existing deep link keeps working:** `/c/…`, `/join/…`, `/studies/…`, `/login`, `/welcome`, `/churches…`, `/profile`, `/admin`, `/requests`. So do the Supabase auth returns.
- **Fast and indexable:**
  - No JavaScript framework. The only script is the inline redirect check.
  - Budget: HTML + CSS + fonts ≤ 250 KB per page before images.
  - Real `<title>`, meta description, `hreflang` alternates, Open Graph and Twitter card tags, and a 1200×630 preview image.
- **Look:**
  - `DESIGN.md` colors (light and dark through `prefers-color-scheme`), the Source Serif 4 serif for headings and Scripture, and the system sans for interface text.
  - No anti-patterns from `DESIGN.md`, and in particular not the centered hero with three icon cards.
- **Languages:** Spanish, Portuguese and English, with Spanish at `/` (the app's default language). A language switcher sits on every page.
- **Copy rules:**
  - Scripture quotes come from a translation that allows quoting, cited inline.
    - Spanish: RVR1960, which permits short quotations with attribution.
    - Portuguese: Almeida Revista e Corrigida.
    - English: KJV.
  - No invented testimonials or statistics.

## Review Focus

1. **Email confirmation and password links that land on `/`** with `#access_token=…`, `#error=…` or `?code=…`. They must reach the app with the hash and query intact, never the landing page. → Task 4, tests `auth returns go to the app with hash and query`.
2. **A member whose browser blocks storage** (private mode, `localStorage` throws). The landing page shows normally, with no script error and no redirect loop. → Task 4, test `storage that throws shows the landing page`.
3. **Reloading or sharing `/hoje`, `/c/<slug>/studies/<s>/day/2` and `/join/<token>`** on the deployed site. Each loads the app, not the landing page and not a 404. → Task 2, test `app routes are served app.html` (local server) and Task 8, step 4 (preview deploy).
4. **A Portuguese or English browser on its first visit** gets its language once. Choosing another language on the switcher sticks, and a returning member is never sent to `/pt/` instead of the app. → Task 4, tests `first visit follows the browser language` and `a chosen language wins`.
5. **The native apps and in-app links to `/`** still open Today. → Task 1, test `the root redirects to /hoje`.

---

### Task 1: Today moves to `/hoje`

**Files:**
- Modify: `app/lib/src/app/app.dart` (the Hoy branch route at line ~85, plus a top-level `redirect`), `app/lib/src/app/shell.dart` (`tabIndexFor`, `goToBranch`)
- Test: `app/test/shell_test.dart`, `app/test/site_header_test.dart`

**Interfaces:**
- Produces: route `/hoje` → `TodayPage`. `GoRouter.redirect` maps exactly `/` (with any query) to `/hoje`. `tabIndexFor('/hoje') == 0`. `goToBranch(…, 0)` goes to `/hoje`.
- The existing `context.go('/')` calls stay as they are; the redirect covers them. *(Why: about a dozen call sites, and the native apps start at `/`.)*

- [ ] **Step 1: Write the failing tests.**
  - In `shell_test.dart`, add `expect(tabIndexFor('/hoje'), 0);` to `tabIndexFor maps locations to tabs`.
  - New test `the root redirects to /hoje`: `createRouter(initialLocation: '/')`, pumped as in `site_header_test`, ends at path `/hoje`, with `TodayPage` found.
  - In `site_header_test`, change `the header on the study page goes to Hoje` to expect `/hoje`.

- [ ] **Step 2: Run them and confirm they fail.**
  Run `cd app && flutter test test/shell_test.dart test/site_header_test.dart`.
  Expected: FAIL. The path stays `/`, and `tabIndexFor('/hoje')` already returns 0 through its fallback, so that one passes; the redirect test and the header test fail.

- [ ] **Step 3: Implement it.** Change the branch path to `/hoje`, add the router `redirect`, and point `goToBranch` branch 0 at `/hoje`.

- [ ] **Step 4: Run all tests.** Run `flutter test`. Expected: PASS. Update other tests that assert the location `/` after an action to expect `/hoje`, keeping what they test.

- [ ] **Step 5: Commit** with the message "Move Today to /hoje so the root can hold the landing page".

---

### Task 2: One build for the app and the site, with routing

**Files:**
- Create: `app/tool/build_web.sh`, `app/tool/routes.py`, `app/tool/test_routes.py`
- Modify: `app/tool/serve.py` (route with `routes.py`), `README.md` (the "Run the app" and "Live app" commands)

**Interfaces:**
- `routes.py`:
  - `APP_ROUTES`: the list of path patterns served by `app.html`: `/hoje`, `/c/*`, `/profile`, `/churches`, `/churches/*`, `/login`, `/welcome`, `/join/*`, `/requests`, `/studies/*`, `/admin`.
  - `def redirects_file() -> str`: one line per pattern, `<pattern> /app.html 200`. Cloudflare `_redirects` syntax; the exact path and the `/*` form are listed separately where both apply.
  - `def resolve(root: str, path: str) -> str`: the local server's mirror of Cloudflare's behavior.
    - An existing file is returned as is.
    - A directory with `index.html` returns that file.
    - A path matching `APP_ROUTES` returns `app.html`.
    - Anything else returns `404.html` if it exists, otherwise `app.html`. *(My call: keeps old unknown links working the way they do today.)*
- `build_web.sh`, run from `app/`:
  1. `flutter build web --release --dart-define-from-file=config/beta.json`
  2. `mv build/web/index.html build/web/app.html`
  3. `python3 ../site/build.py --out build/web`
  4. `python3 -c 'from tool.routes import redirects_file; print(redirects_file())' > build/web/_redirects`, or the equivalent from `tool/`.

  The script exits non-zero on any failure (`set -euo pipefail`).
- `serve.py` serves through `resolve` and keeps `Cache-Control: no-cache`.
- README: local run is `tool/build_web.sh && python3 tool/serve.py 3100`, and deploy is `tool/build_web.sh && npx --yes wrangler pages deploy build/web …`.

- [ ] **Step 1: Write the failing tests** in `test_routes.py` (unittest, with a temp dir holding `app.html`, `index.html`, `pt/index.html` and `main.dart.js`):
  - `test_root_is_the_landing_page`: `resolve(root, '/')` ends with `/index.html` and is not `app.html`.
  - `test_language_pages`: `/pt/` resolves to `pt/index.html`.
  - `test_app_routes_are_served_app_html`: `/hoje`, `/c/x/studies/s/day/2`, `/join/abc`, `/login`, `/profile` and `/churches/new` resolve to `app.html`.
  - `test_assets_are_served_as_files`: `/main.dart.js` resolves to the file itself.
  - `test_redirects_file_lists_every_app_route`: every `APP_ROUTES` entry appears in `redirects_file()` with `/app.html 200`, and `/` doesn't.

- [ ] **Step 2: Run them and confirm they fail.**
  Run `cd app && python3 -m unittest tool/test_routes.py -v`.
  Expected: FAIL with `ModuleNotFoundError: routes`.

- [ ] **Step 3: Implement `routes.py`, `build_web.sh` and the `serve.py` change.**

- [ ] **Step 4: Run the tests again.** Same command. Expected: PASS.

- [ ] **Step 5: Commit** with the message "Build the app and the landing site together and route app paths to app.html". `build_web.sh` can't succeed until Task 3 adds `site/build.py`; Task 3's verification runs it.

---

### Task 3: Site scaffold, design tokens and the localized build

**Files:**
- Create:
  - `site/build.py` and `site/test_build.py`
  - `site/src/index.html` (template)
  - `site/src/styles.css`
  - `site/src/strings/es.json`, `pt.json`, `en.json`
  - `site/src/fonts/` (Source Serif 4 Regular, It and Semibold `.woff2`, plus `OFL.txt`)
- Modify: `.gitignore` (add `site/dist/`)

**Interfaces:**
- `build.py`: `def build(out_dir: str) -> None` and a `--out` CLI.
  - Renders `index.html` with `string.Template` once per language, to `<out>/index.html` (es), `<out>/pt/index.html` and `<out>/en/index.html`.
  - Copies `styles.css`, `fonts/` and `img/` to `<out>/site/`. Pages reference `/site/...` with absolute paths.
  - Fails if any `${…}` placeholder is left unreplaced, or if a strings file is missing a key that `es.json` has.
- The template's `<html lang>` and `hreflang` alternates (es, pt, en and `x-default` → `/`) come from the strings. `<link rel="canonical">` points at the page's own URL. The origin is `https://selah-226.pages.dev`, kept as one constant in `build.py`. *(My call: a custom domain can change it in one place.)*
- `styles.css`:
  - Tokens as CSS custom properties copied from `DESIGN.md`: paper, raised paper, ink, muted ink, green, terracotta, plus the dark values under `@media (prefers-color-scheme: dark)`. Spacing, radii, the type scale, and `@font-face` for the three woff2 files with `font-display: swap`.
  - Layout: content max 1200; reading text max 680; 16 px minimum side gutter at phone width; no horizontal scroll at 360 px.
- Fonts: the woff2 files come from Adobe's `adobe-fonts/source-serif` 4.005 release (`source-serif-4.005_WOFF2.zip`), the same release as the app's TTFs.

- [ ] **Step 1: Write the failing tests** in `test_build.py` (unittest, building into a temp dir):
  - `test_three_language_pages`: `index.html`, `pt/index.html` and `en/index.html` exist, with `lang="es"`, `"pt"` and `"en"`.
  - `test_no_unreplaced_placeholders`: no page contains `${`.
  - `test_hreflang_alternates`: each page links all three languages and `x-default`.
  - `test_strings_have_the_same_keys`: `pt.json` and `en.json` have exactly `es.json`'s keys.
  - `test_assets_copied`: `site/styles.css` and the three woff2 files exist in the output.
  - `test_page_weight_budget`: each page's HTML + `styles.css` + fonts is ≤ 250 KB.

- [ ] **Step 2: Run them and confirm they fail.**
  Run `python3 -m unittest site/test_build.py -v`.
  Expected: FAIL, because `build` isn't defined.

- [ ] **Step 3: Implement the scaffold** with placeholder section copy (headings only), so the build and tests pass. Task 6 writes the real content.

- [ ] **Step 4: Run the tests again** (expected: PASS). Then run `cd app && tool/build_web.sh && python3 tool/serve.py 3100`:
  - `/` shows the landing scaffold.
  - `/hoje` loads the app.

- [ ] **Step 5: Commit** with the message "Add the landing site scaffold with tokens, fonts and a localized build".

---

### Task 4: Returning members skip the landing page

**Files:**
- Create: `site/src/redirect.js`, `site/redirect.test.mjs`
- Modify: `site/build.py` (inline `redirect.js` into `<head>`, before any stylesheet), `site/src/index.html`

**Interfaces:**
- `redirect.js` defines `function landingDecision({ search, hash, pathname, language, storage })`, which returns a target URL string or `null`.
  - `storage` is a `getItem(key)`/`keys()` facade over `localStorage`; it may throw.
  - The file ends with a self-run: `(function(){ try { const t = landingDecision({...from window...}); if (t) location.replace(t); } catch (e) {} })();`. It's also exported for Node with `if (typeof module !== 'undefined') module.exports = { landingDecision };`.
- The rules, in order:
  1. **Auth return:** the hash contains `access_token=`, `error=` or `type=`, or the query has `code` or `error`. Return `/hoje` + the original search + hash.
  2. **`?home` in the query:** return `null`.
  3. **Returning member:** `storage.getItem('flutter.church')` is non-null, or any key matches `/^sb-.*-auth-token$/`. Return `/hoje`.
  4. **First visit on the Spanish page** (`pathname === '/'`) with no `site.lang` choice stored, and `language` starting with `pt` or `en`: return `/pt/` or `/en/`.
  5. Otherwise return `null`.
- The language switcher links set `localStorage['site.lang']` (inside try/catch) before navigating.

- [ ] **Step 1: Write the failing tests** in `redirect.test.mjs` with `node:test`:
  - `auth returns go to the app with hash and query`: `{hash: '#access_token=x&type=signup'}` → `'/hoje#access_token=x&type=signup'`, and `{search: '?code=abc'}` → `'/hoje?code=abc'`.
  - `?home shows the landing page even for members`: with a stored church → `null`.
  - `a stored church goes to Today` and `a Supabase session goes to Today`.
  - `first visit follows the browser language`: `{pathname: '/', language: 'pt-BR'}` → `'/pt/'`, and `en-US` → `'/en/'`.
  - `a chosen language wins`: with `site.lang: 'es'` stored and `language: 'en-US'` → `null`.
  - `storage that throws shows the landing page`: `getItem` throws → `null`.
  - `a member on a Portuguese browser goes to the app, not /pt/`: a stored church plus `pt-BR` → `'/hoje'`.

- [ ] **Step 2: Run them and confirm they fail.**
  Run `/usr/local/n/versions/node/22.21.0/bin/node --test site/redirect.test.mjs`.
  Expected: FAIL, because the module doesn't exist.

- [ ] **Step 3: Implement `redirect.js`.** Inline it in the build, and add `test_redirect_inlined_first` to `test_build.py`: the first `<script>` in `<head>` appears before the first `<link rel="stylesheet">`.

- [ ] **Step 4: Run both test files.** Expected: PASS.

- [ ] **Step 5: Commit** with the message "Send returning members and auth returns from the landing page to the app".

---

### Task 5: Demo church screenshots

**Files:**
- Create: `app/tool/demo_main.dart` (an entry point the app build never uses)
- Create: `site/src/img/phone-hoje-light.webp`, `phone-hoje-dark.webp`, `laptop-hoje-light.webp`, `laptop-estudos-light.webp`

**Interfaces:**
- `demo_main.dart` runs `SelahApp` inside a `ProviderScope` that overrides the data providers (`repositoryProvider`, `currentChurchProvider`, `newestStudyProvider`, `publishedStudiesProvider`, `upcomingEventsProvider`, `userIdProvider`) with in-memory demo data:
  - **Church:** "Iglesia Esperanza" (slug `esperanza`).
  - **Studies:** three, written for this demo. Original short text about well-known passages (e.g. Psalm 23, John 15, Philippians 4), with no real sermon, preacher or church.
  - **Events:** two.
  - The clock is fixed so day 2 of the first study shows, with one part ticked.
- Build it with `flutter build web -t tool/demo_main.dart -o build/demo` and serve that folder.
- **Captures** (light and dark): Hoje at 390×844 for the phone, and Hoje and Estudos at 1280×800 for the laptop. Save as WebP at most 120 KB each. *(Use `cwebp` if installed; otherwise keep JPEG at quality 82 and record it.)*

- [ ] **Step 1: Write `demo_main.dart` and build it.**
  Run `flutter build web -t tool/demo_main.dart -o build/demo` and check that `flutter analyze tool/demo_main.dart` is clean. Expected: the build succeeds. *(No unit test: this is a capture tool. Its check is the build plus the screenshots.)*
- [ ] **Step 2: Serve and capture** the four images in the browser pane at the sizes above. Each image shows no real church name or sermon title (check by eye against the demo data).
- [ ] **Step 3: Commit** `tool/demo_main.dart` and `site/src/img/` with the message "Add a demo church entry point and landing page screenshots".

---

### Task 6: Landing page content and design

**Files:**
- Modify: `site/src/index.html`, `site/src/styles.css`, `site/src/strings/*.json`
- Test: `site/test_build.py` (add)

**Interfaces:**
- **Process:** design with the Impeccable skill in its Persuade mode (`~/.claude/skills/impeccable`). Respect `DESIGN.md` and the anti-goals. One deliberate, distinctive idea is enough; for example, the opening set like the first page of a well-made book.
- **Sections and their calls to action:**
  1. **Opening:** a serif headline about knowing God through His Word; a short Scripture quote in serif italic with its citation; one paragraph; a primary button "Start reading" → `/churches`.
  2. **How it works:** three steps in the order the spec gives. Numbering is right here because it is a sequence. Each step has one sentence and no icon cards.
  3. **Glimpse:** the phone and laptop screenshots from Task 5, light by default. In dark mode, swap them for the dark phone image through `<picture>` with `prefers-color-scheme`. Every image has a real `alt` text and `width`/`height` attributes so nothing shifts while loading.
  4. **For members:** "Find your church" → `/churches`.
  5. **For leaders:** what Selah does for a church (it turns Sunday sermons into a week of reviewed studies, and leaders review before anything is published), and "Bring your church" → `/login?next=%2Fwelcome%3Fstep%3Dleader`.
  6. **Footer:** the language switcher, "Open the app" → `/hoje`, and nothing else.
- **Copy:** write it in Spanish first, then Portuguese and English with the same meaning. Plain, warm and direct, following the writing rules in `DESIGN.md`. No invented quotes, numbers or testimonials.

- [ ] **Step 1: Write the failing tests** in `test_build.py`:
  - `test_calls_to_action_point_at_the_app`: each page has links to `/churches`, `/login?next=%2Fwelcome%3Fstep%3Dleader` and `/hoje`.
  - `test_images_have_alt_and_size`: every `<img>` has a non-empty `alt` and `width` and `height` attributes.
  - `test_one_h1_per_page`.
  - `test_scripture_is_cited`: each page has a `<blockquote>` with a `<cite>`.

- [ ] **Step 2: Run them and confirm they fail.** Run `python3 -m unittest site/test_build.py -v`. Expected: the new tests FAIL against the scaffold.

- [ ] **Step 3: Write the content and design.**

- [ ] **Step 4: Run the tests (expected: PASS), then check visually.** Run `cd app && tool/build_web.sh && python3 tool/serve.py 3100`, and look at `/`, `/pt/` and `/en/` in light and dark mode at 360, 390, 768, 1280 and 1920.
  Pass criteria:
  - No horizontal scroll.
  - Reading text ≤ 680.
  - Terracotta only in small marks.
  - Images don't shift the layout.
  - It looks like a website, not like the app.

- [ ] **Step 5: Commit** with the message "Write and design the landing page".

---

### Task 7: Link previews and search

**Files:**
- Create: `site/src/img/og.png` (1200×630)
- Modify: `site/src/index.html`, `site/build.py`, `site/test_build.py`
- Create: `site/src/robots.txt` and a generated `sitemap.xml` (copied to the output root)

**Interfaces:**
- **Per page:** `<title>` (≤ 60 chars), `<meta name="description">` (≤ 160 chars), `og:title`, `og:description`, `og:image` (absolute URL), `og:url`, `og:locale`, `twitter:card=summary_large_image`, and a favicon (reuse `app/web/favicon.png`).
- **`og.png`:** the Selah wordmark and the opening headline on paper, beside the phone screenshot. Build it as a small HTML file and capture it at 1200×630 in the browser pane.
- **`robots.txt`:** allows `/`, `/pt/` and `/en/`, disallows `/hoje` and `/c/`, and names the sitemap. *(My call: app pages render client-side and add nothing to search.)*
- **`sitemap.xml`:** lists the three landing pages with `xhtml:link` alternates.

- [ ] **Step 1: Write the failing tests:**
  - `test_meta_tags`: each page has every tag above, and the title and description are within the limits.
  - `test_og_image_is_absolute_and_exists`.
  - `test_robots_and_sitemap`.
- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests and confirm they pass.**
- [ ] **Step 5: Commit** with the message "Add link previews, robots and sitemap to the landing page".

---

### Task 8: End-to-end check and preview deploy

**Files:**
- Modify: `DESIGN.md` (a short "Landing page" section: where it lives, how it's built, its sections)

- [ ] **Step 1: Run every test.**
  `cd app && flutter test`, `python3 -m unittest tool/test_routes.py site/test_build.py` (from the right directories), and the Node test. Expected: all pass.

- [ ] **Step 2: Check the flows locally**, with `tool/build_web.sh && python3 tool/serve.py 3100` in the browser pane:
  - A fresh profile at `/` sees the landing page.
  - "Start reading" → `/churches`. Pick a church; then `/` goes straight to `/hoje`.
  - `/?home` shows the landing page.
  - `/#access_token=test&type=signup` lands on `/hoje#access_token=test&type=signup`.
  - Reloading `/c/<slug>/studies/<s>/day/1` and `/join/x` loads the app.
  - `/pt/` and `/en/` show their language. Choosing Español on the switcher sticks across a reload of `/`.

- [ ] **Step 3: Update `DESIGN.md`** and commit with the message "Document the landing page".

- [ ] **Step 4: Preview deploy.** Ask the owner first; deploying publishes to the web. With their yes, run `npx --yes wrangler pages deploy build/web --project-name selah --branch landing-preview` and repeat Step 2's checks against the preview URL, especially that the `_redirects` rules route app paths. Record the preview URL.

- [ ] **Step 5: Report** the preview URL and anything that behaved differently on Cloudflare than locally. Production deploy is the owner's call after merge.
