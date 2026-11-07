# Desktop Website Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a computer, Selah's member screens look like a website: a top navigation bar, content centered up to 1200 px, and multi-column pages. Phones and tablets keep the app layout.

**Architecture:** One predicate, `siteLayout(context)`, decides the website layout: non-iOS and at least 1024 px wide (`ScreenSize.desktop`). The shell swaps the `NavigationRail` for a new `SiteHeader`. The study page and reader sit above the shell, so they get the same header through a `SiteFrame` wrapper in the router. `SelahPage` drops its app bar in site layout and shows the title and back link inside the content. Two layout primitives, `TwoColumn` and `CardGrid`, carry the page layouts. Each member page builds its desktop arrangement with them and leaves its phone arrangement untouched.

**Tech Stack:** Flutter 3.47.4, go_router `StatefulShellRoute`, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-07-design-system-and-responsive-web-design.md` (section "Layout by screen size"). The design tokens and rules come from `DESIGN.md` (owner-approved on 2026-11-07).

**Scope:** shell, top navigation and the member screens (Hoje, Estudos, the study page, the reader, Eventos, Perfil). The landing page and admin each get their own plan. Tablets (600–1023) keep one column here. *(My call: the spec allows two columns on tablets "where they fit", but the desktop layouts are where the owner's complaint is, and tablet columns can reuse `TwoColumn` later.)*

## Global Constraints

- Website layout = `uiPlatformOf(context) != UiPlatform.ios && screenSizeOf(context) == ScreenSize.desktop` (≥ 1024 px).
  - iOS, including iPad, always keeps the floating glass tab bar.
  - Flutter tests report Android, not web, so tests drive this layout with an Android target at 1280 px.
- Below 1024 px, every screen must render exactly as it does today. Phone-width tests must keep passing unchanged.
- Content is never wider than `Layout.maxContent` (1200). Long reading text is never wider than `Layout.readingMeasure` (680). Forms are never wider than `Layout.formWidth` (440).
- Routes, deep links, tab memory, back behavior and the iOS glass bar are unchanged.
- Use only tokens and text-theme roles: no raw colors, font sizes or radii (`DESIGN.md`, Do's and Don'ts).
- Member screens stay localized (pt/es/en). Any new copy gets keys in all three `.arb` files.

## Review Focus

1. **Resizing a browser window across 1024 px** while on a page. The layout must switch between header and tab bar without losing the page's scroll position or the tab's navigation stack. → Task 2, test `crossing 1024 px keeps the tab stack`.
2. **Deep-linking straight to a reader URL on desktop.** The header shows with Estudos selected, and its links work even though no shell is underneath. → Task 3, test `a reader opened from a link shows the header with Estudos selected`.
3. **A church with no upcoming events, or only one study.** The desktop side column and the grids must not leave empty boxes or one stretched card. → Task 4, test `Hoje on desktop with no events has no events section`. Task 5, test `one study on desktop is not stretched across the page`.
4. **Very wide screens (1920+).** Content stays centered at 1200 and doesn't stretch. → Task 1, test `content is capped at 1200 on a 1920 window`.
5. **Keyboard users on the website.** Header links must be reachable with Tab and show a focus ring, and Enter must activate them. → Task 2, test `header links are focusable and activate with Enter`.

---

### Task 1: Layout primitives and page header in site layout

**Files:**
- Create: `app/lib/src/app/design/responsive.dart` (export it from `theme.dart`)
- Modify: `app/lib/src/app/design/selah_page.dart`
- Test: `app/test/responsive_test.dart`

**Interfaces:**
- Produces:
  - `bool siteLayout(BuildContext context)`: the predicate from Global Constraints.
  - `class TwoColumn extends StatelessWidget { const TwoColumn({required Widget main, required Widget side, double sideWidth = 340}) }`
    - Renders a `Row` with `crossAxisAlignment.start`: `Expanded(main)`, a `Space.xxl` gap, then `SizedBox(width: sideWidth, child: side)`.
    - Use it only when `siteLayout` is true. Pages choose their own narrow arrangement.
  - `class CardGrid extends StatelessWidget { const CardGrid({required List<Widget> children, double minTileWidth = 280, int maxColumns = 3}) }`
    - Columns = `clamp(((width + Space.l) / (minTileWidth + Space.l)).floor(), 1, maxColumns)`, measured with a `LayoutBuilder`.
    - Tiles are laid out in rows with `Space.l` gaps. Each row's tiles share a top edge, and each tile's height is set by its content.
    - Tiles in a row that isn't full keep the tile width; they don't stretch across the space.
  - `SelahPage` in site layout:
    - **No app bar** (no `SliverAppBar` or `CupertinoSliverNavigationBar`).
    - **Inside the content, at the top:** an optional back link, then the title.
      - The back link is a `TextButton.icon` with `Icons.arrow_back` and the label `backTooltip ?? l.back`. It does the same thing as today's back button.
      - The title uses `textTheme.headlineMedium`, followed by `Space.xl`.
    - **`actions`** sit in a row on the right of the title.
    - **Width:** content is centered at `min(maxWidth, Layout.maxContent)`. Top padding is `Space.section`.
    - **Pull to refresh** stays off in site layout, because browsers have their own reload.
  - `SelahPage({..., bool wide = false})`: `wide: true` makes the site-layout content width `Layout.maxContent`, ignoring `maxWidth`. Below desktop, `maxWidth` applies as today.

- [ ] **Step 1: Write the failing tests** in `responsive_test.dart`.

  Use a helper `pumpAt(tester, Size size, Widget child)` that sets `tester.view.physicalSize` with DPR 1 and `debugDefaultTargetPlatformOverride = TargetPlatform.android`, then pumps `MaterialApp(theme: selahLightTheme(), localizationsDelegates…, home: child)`.

  - `siteLayout is on at 1024 for Android and never for iOS`: build a probe widget. Check that 1023 → false, 1024 → true, and 1280 with `TargetPlatform.iOS` → false.
  - `TwoColumn puts the side to the right of the main column`: at 1280, `getTopLeft(side).dx > getTopRight(main).dx`, and the side's width is 340.
  - `CardGrid uses three columns at 1000 and one at 375`: six `SizedBox(height: 50, key: ValueKey(i))` tiles.
    - At 1000 (`CardGrid` given the full width): tiles 0, 1 and 2 share `dy`, and tile 3's `dy` is greater.
    - At 375: every tile has a distinct `dy`.
  - `a lone tile in CardGrid keeps its tile width`: at 1000, one tile has width < 400.
  - `SelahPage on desktop has no app bar and shows the title in the content`: `SelahPage(title: 'Hoje', backTo: '/', children: [Text('body')])` at 1280.
    - `find.byType(SliverAppBar)` finds nothing.
    - `find.text('Hoje')` finds one widget, styled `headlineMedium`.
    - `find.byIcon(Icons.arrow_back)` finds one widget.
  - `SelahPage below desktop keeps the large app bar`: the same page at 390 → `find.byType(SliverAppBar)` finds one widget.
  - `content is capped at 1200 on a 1920 window`: `SelahPage(wide: true, children: [Container(key: k, height: 10)])` at 1920. Child width ≤ 1200, centered within 1 px.

- [ ] **Step 2: Run them and confirm they fail.**
  Run `flutter test test/responsive_test.dart`.
  Expected: compile errors, because `siteLayout`, `TwoColumn`, `CardGrid` and `wide` aren't defined.

- [ ] **Step 3: Implement `responsive.dart` and the `SelahPage` site-layout branch.**
  In site layout the page is a plain `CustomScrollView`. The header widgets are the first children of the centered column. Keep the existing iOS and Material branches for narrower widths byte-for-byte.

- [ ] **Step 4: Run all tests.** Run `flutter test`. Expected: PASS.

- [ ] **Step 5: Commit.** `git add lib/src/app/design/responsive.dart lib/src/app/design/selah_page.dart lib/src/app/theme.dart test/responsive_test.dart` and commit with the message "Add site-layout primitives and an in-content page header for desktop".

---

### Task 2: SiteHeader in the shell

**Files:**
- Create: `app/lib/src/app/design/site_header.dart`
- Modify: `app/lib/src/app/shell.dart` (replace the `NavigationRail` branch, lines ~165–186), `app/lib/src/app/design/adaptive_tab_bar.dart` (remove `kRailBreakpoint`)
- Modify: `app/test/adaptive_tab_bar_test.dart` (`_wide` becomes 1280 × 800; the rail test becomes the header test)
- Test: `app/test/site_header_test.dart`

**Interfaces:**
- Consumes: `siteLayout` (Task 1) and `SelahTab` (existing).
- Produces:
  - `class SiteHeader extends StatelessWidget { const SiteHeader({required List<SelahTab> tabs, required int selected, required ValueChanged<int> onSelect, Widget? trailing}) }`, with `static const key = ValueKey('site-header')`.
  - Layout: one bar `64` tall on `paper`, with a bottom hairline in `outlineVariant`. Contents are centered at `Layout.maxContent` with `Space.xl` side padding.
    - **Left:** the "Selah" wordmark in `titleLarge` (serif). It's a link that does the same as selecting tab 0.
    - **Middle-left:** the tab labels as text links, `labelLarge`, `Space.xl` apart.
      - The selected link is `primary` with a 2 px `primary` underline. The others are `ink` with no underline.
      - Each link is a `TextButton`, so it can take focus and responds to Enter.
    - **Right:** `trailing`.
  - In the shell (site layout): `Scaffold(body: Column([SiteHeader(...), Expanded(navigationShell)]))`. `trailing` is a `Row` with:
    - `ChurchSwitcher(current: church, admin: false)` when there's a current church (it hides itself for single-church members),
    - the current church's name as `bodyMedium` text when `ChurchSwitcher` would hide,
    - `LanguageMenu()`.
  - Perfil stays one of the tab links; no separate profile icon. *(My call: it keeps the same four destinations as the tab bar, as the spec asks.)*

- [ ] **Step 1: Write the failing tests.**

  In `adaptive_tab_bar_test.dart`, change `_wide` to `Size(1280, 800)`. Replace `a wide Android window shows a navigation rail` with `a desktop window shows the site header instead of a tab bar`:
  - `find.byKey(SiteHeader.key)` finds one widget.
  - `NavigationRail` and `NavigationBar` find nothing.
  - `find.text('Perfil')` finds a widget inside the header.

  Keep `a wide iPad window keeps the floating bar` as is.

  New `site_header_test.dart`, using that file's router helper pattern (copy `_pumpRouter` or import a shared test helper):
  - `tapping Estudios in the header opens the church`: at `/`, tap the 'Estudios' text inside the header. The router location becomes `/c/<slug>`.
  - `the selected link follows the route`: at `/profile`, the 'Perfil' header text's color is `colorScheme.primary`.
  - `header links are focusable and activate with Enter`: send `tester.sendKeyEvent(LogicalKeyboardKey.tab)` until the 'Estudios' button has focus, then send Enter. Expect the location `/c/<slug>`.
  - `crossing 1024 px keeps the tab stack`: at 1280 on `/c/<slug>/events`, set the size to 390 and pump. The location is unchanged and the `NavigationBar` shows Eventos selected. Set it back to 1280: the header shows Eventos selected.

- [ ] **Step 2: Run them and confirm they fail.**
  Run `flutter test test/adaptive_tab_bar_test.dart test/site_header_test.dart`.
  Expected: FAIL, because `SiteHeader` doesn't exist.

- [ ] **Step 3: Implement `SiteHeader` and switch the shell's wide branch to it.** Remove `kRailBreakpoint` and its import uses.

- [ ] **Step 4: Run all tests.** Run `flutter test`. Expected: PASS.

- [ ] **Step 5: Commit** with the message "Replace the desktop navigation rail with a website header".

---

### Task 3: The header above the study page and reader

**Files:**
- Create: `app/lib/src/app/design/site_frame.dart`
- Modify: `app/lib/src/app/app.dart` (the study and reader routes, lines ~108–124), `app/lib/src/app/shell.dart` (extract the branch-to-location logic)
- Test: `app/test/site_header_test.dart` (add)

**Interfaces:**
- Consumes: `SiteHeader` (Task 2).
- Produces:
  - `class SiteFrame extends ConsumerWidget { const SiteFrame({required Widget child, int selected = 1}) }`
    - In site layout it renders `Column([SiteHeader(tabs, selected, onSelect: (b) => goToBranch(context, ref, b)), Expanded(child)])`. Otherwise it renders `child` unchanged.
  - `Future<void> goToBranch(BuildContext context, WidgetRef ref, int branch)` in `shell.dart`. It maps branches to locations:
    - 0 → `/`
    - 1 → `/c/<current slug>`, or `/churches` when there's no current church
    - 2 → `/c/<current slug>/events`
    - 3 → `/profile`

    `SiteFrame` uses it, and the shell's `_openStudies`/`_openEvents` delegate to it for the URL part.
  - Tab building (`_tabs`, `_visibleBranches`) moves into a function `List<(int, SelahTab)> visibleTabs(WidgetRef ref, AppLocalizations l, {required int current})` so the shell and `SiteFrame` show the same links.
  - In `app.dart`, both reading routes wrap their page in `SiteFrame(child: …)`.

- [ ] **Step 1: Write the failing tests.**
  - `a reader opened from a link shows the header with Estudos selected`: at 1280, start the router at `/c/<slug>/studies/<study>/day/1`. The header is present, and 'Estudios' is `primary`.
  - `the header on the study page goes to Hoje`: from `/c/<slug>/studies/<study>`, tap 'Hoy' in the header. The location becomes `/`.
  - `the study page on a phone has no header`: the same route at 390 → the header finds nothing.

- [ ] **Step 2: Run them and confirm they fail.** Run `flutter test test/site_header_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement `SiteFrame` and `goToBranch`, and wrap the two routes.**

- [ ] **Step 4: Run all tests.** Run `flutter test`. Expected: PASS.

- [ ] **Step 5: Commit** with the message "Show the website header above the study page and reader".

---

### Task 4: Hoje on desktop

**Files:**
- Modify: `app/lib/src/features/today/today_page.dart`
- Modify: `app/lib/src/features/events/events_page.dart` (make `_EventRow` public as `EventRow`, unchanged otherwise)
- Test: `app/test/today_page_test.dart` (add; its `_pump` gains `Size? size` and `TargetPlatform? platform`)

**Interfaces:**
- Consumes: `TwoColumn`, `siteLayout`, `SelahPage(wide: true)`, `EventRow` and `upcomingEventsProvider`.
- Layout in site layout (`wide: true`):
  - **Main column:** the devotional children as today (hero, parts, buttons).
  - **Side column**, in order:
    1. the date and church line,
    2. `_WeekRow`,
    3. if there are upcoming events: `Space.section`, `Eyebrow(l.eventsLater)`, up to 3 `EventRow`s, and a `TextButton` labeled `l.tabEvents` that goes to `/c/<slug>/events`.
  - **Narrow layout:** unchanged.

- [ ] **Step 1: Write the failing tests.**
  - `Hoje on desktop puts the week beside the day`: at 1280 Android, the week row (`ValueKey('week')`) has `getTopLeft.dx >` the hero card's `getTopRight.dx`.
  - `Hoje on desktop lists upcoming events in the side column`: override `upcomingEventsProvider` with two events. Both titles are found.
  - `Hoje on desktop with no events has no events section`: with an empty list, the `l.eventsLater` text finds nothing.
  - `Hoje on a phone is unchanged`: at 390, the event titles find nothing, and the week row's `dy` is less than the hero's `dy`.

- [ ] **Step 2: Run them and confirm they fail.** Run `flutter test test/today_page_test.dart`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement the desktop arrangement.**

- [ ] **Step 4: Run all tests.** Run `flutter test`. Expected: PASS.

- [ ] **Step 5: Commit** with the message "Lay out Hoje in two columns on desktop".

---

### Task 5: Estudos (church page) on desktop

**Files:**
- Modify: `app/lib/src/features/church/church_page.dart`
- Test: `app/test/church_page_test.dart` (add)

**Interfaces:**
- Layout in site layout (`wide: true`):
  - **Intro:** the eyebrow, the `displaySmall` tagline and `heroBody`, constrained to `Layout.readingMeasure`.
  - **Featured study:** a horizontal card. The thumbnail (16:9) takes the left half and the text the right half.
  - **Recent studies:** in a `CardGrid` (`minTileWidth: 300`), using the non-featured tile.
  - **Narrow layout:** unchanged.

- [ ] **Step 1: Write the failing tests.**
  - `recent studies sit in a grid on desktop`: at 1280 with four studies, the three recent tiles share `dy`.
  - `one study on desktop is not stretched across the page`: with one study, the featured card's width is ≤ 1200, and its thumbnail's width is ≤ 0.55 × the card's width.
  - `recent studies stay a list on a phone`: at 390, the recent tiles have distinct `dy`.

- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run `flutter test` and confirm it passes.**
- [ ] **Step 5: Commit** with the message "Show a church's studies as a grid on desktop".

---

### Task 6: The study page and reader on desktop

**Files:**
- Modify: `app/lib/src/features/study/study_page.dart`, `app/lib/src/features/study/reader_page.dart`
- Test: `app/test/study_test.dart` (add; `_pump` gains `Size? size` and `TargetPlatform? platform`)

**Interfaces:**
- **Study page** (site layout, `wide: true`), in a `TwoColumn` with `sideWidth: 380`:
  - **Main:** the translation banner, thumbnail, title, byline, sermon link and central message, constrained to `Layout.readingMeasure`.
  - **Side:** the `ReadingSection` "devotional path" with its day rows.
- **Reader** (site layout), in a `TwoColumn` with `sideWidth: 280`, total width `Layout.readingMeasure + Space.xxl + 280`:
  - **Main:** today's reader content, unchanged.
  - **Side:** `Eyebrow(study.title)`, then a list of the study's days. Each day is a `SelahRow` with the label "`l.dayOfTotal(n, total)` · day title" that replaces the route like the existing previous/next buttons (`_goToDay`). The current day shows a `primary` left marker and isn't tappable.
  - The side column isn't sticky. *(My call: sticky sidebars inside a `CustomScrollView` add complexity for little gain at this content length; revisit if readers ask.)*
- **Narrow layout:** unchanged for both pages.

- [ ] **Step 1: Write the failing tests.**
  - `the study page puts the days beside the summary on desktop`: at 1280, the first day row's `dx` is greater than the title's `getTopRight.dx`.
  - `the reader lists the study's days beside the text on desktop`: at 1280, on day 2, three day labels are found in the side column. 'Reflexión 2' has width ≤ 680.
  - `tapping a day in the reader's side column opens it`: tap the day 3 row. 'Título día 3' shows.
  - `the reader on a phone has no side column`: at 390, the day 1 and day 3 labels find nothing.

- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run `flutter test` and confirm it passes.**
- [ ] **Step 5: Commit** with the message "Lay out the study page and reader in columns on desktop".

---

### Task 7: Eventos and Perfil on desktop

**Files:**
- Modify: `app/lib/src/features/events/events_page.dart`, `app/lib/src/features/profile/profile_page.dart`
- Test: `app/test/events_page_test.dart`, `app/test/profile_page_test.dart` (add)

**Interfaces:**
- **Eventos** (site layout, `wide: true`):
  - The next event's hero card spans `Layout.readingMeasure`.
  - Later events sit below it in a `CardGrid` (`minTileWidth: 340`, `maxColumns: 2`) of `EventRow`s.
- **Perfil** (site layout): `maxWidth: 640`, one centered column. *(My call: settings read best narrow.)*
- **Narrow layout:** unchanged.

- [ ] **Step 1: Write the failing tests.**
  - `later events sit in two columns on desktop`: at 1280 with four events, the second and third events share `dy`.
  - `Perfil is a narrow column on desktop`: at 1280, the "your church" card's width is ≤ 640.

- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run `flutter test` and confirm it passes.**
- [ ] **Step 5: Commit** with the message "Lay out Eventos and Perfil for desktop".

---

### Task 8: Visual verification and DESIGN.md

**Files:**
- Modify: `DESIGN.md` (in the Layout section, replace "coming in the next plan" with what was built; add `SiteHeader`, `TwoColumn` and `CardGrid` to Components)
- Create: `docs/design/desktop-hoje.jpg`, `docs/design/desktop-estudos.jpg`

- [ ] **Step 1: Build and serve the release web app.**
  Run `flutter build web --release --dart-define-from-file=config/beta.json`, then serve it with the `selah-web` launch config.

- [ ] **Step 2: Check every member screen** (Hoje, Estudos, the study page, the reader, Eventos and Perfil) at 1280 × 800 and 1920 × 1080 in light and dark mode, and at 768 and 390 in light mode.

  Pass criteria:
  - At ≥1024: the header is present, content is centered and never wider than 1200, and the columns match Tasks 4–7.
  - Long text is never wider than 680.
  - Below 1024: screens look as they did before this plan.
  - Resizing across 1024 keeps the page.
  - Keyboard: Tab reaches the header links with a visible focus ring.

- [ ] **Step 3: Check iOS.** Launch on the iOS Simulator and confirm Hoje and the reader are unchanged, with the glass tab bar still there.

- [ ] **Step 4: Save desktop screenshots** of Hoje and Estudos (light mode) to `docs/design/`, then update `DESIGN.md`.

- [ ] **Step 5: Commit** with the message "Document the desktop website layout".
