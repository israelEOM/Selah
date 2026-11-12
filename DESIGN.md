---
name: Selah
description: A church's Sunday sermon, turned into a short daily study you read through the week.
colors:
  paper: "#FAF7F2"
  paper-raised: "#F1EBE1"
  ink: "#262320"
  ink-muted: "#6F655A"
  selah-green: "#2F5D4A"
  selah-green-deep: "#244A3B"
  terracotta: "#A65033"
  charcoal-dark: "#1E1C1A"
  charcoal-raised-dark: "#272421"
  ink-dark: "#EDE8E1"
  ink-muted-dark: "#A39B91"
  sage-dark: "#A9CDB8"
  hero-green-dark: "#26332C"
  hero-green-deep-dark: "#1F2A24"
  terracotta-dark: "#E0906E"
  part-reading: "#2F5D4A"
  part-reading-tint: "#E6EEE8"
  part-reading-soft: "#D3E2D8"
  part-reflection: "#B8732E"
  part-reflection-text: "#8F561F"
  part-reflection-tint: "#F5EBDD"
  part-reflection-soft: "#EEDCC2"
  part-prayer: "#5E6A9C"
  part-prayer-text: "#545F90"
  part-prayer-tint: "#E8E9F2"
  part-prayer-soft: "#D7DAEA"
  part-reading-dark: "#A9CDB8"
  part-reading-tint-dark: "#27332C"
  part-reading-soft-dark: "#33443A"
  part-reflection-dark: "#E2B27A"
  part-reflection-tint-dark: "#392F23"
  part-reflection-soft-dark: "#4A3C2A"
  part-prayer-dark: "#B4BDEB"
  part-prayer-tint-dark: "#2B2F42"
  part-prayer-soft-dark: "#393E58"
typography:
  display:
    fontFamily: "Inter, sans-serif"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.15
  headline:
    fontFamily: "Inter, sans-serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
  headline-small:
    fontFamily: "Inter, sans-serif"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "Inter, sans-serif"
    fontSize: "19px"
    fontWeight: 700
    lineHeight: 1.3
  title-ui:
    fontFamily: "Inter, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.35
  body:
    fontFamily: "Inter, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  body-secondary:
    fontFamily: "Inter, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.45
  body-small:
    fontFamily: "Inter, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Inter, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.2
  label-small:
    fontFamily: "Inter, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.3
  eyebrow:
    fontFamily: "Inter, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    letterSpacing: "0.6px"
  quote:
    fontFamily: "Georgia, Source Serif 4, serif"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: 1.35
  reading:
    fontFamily: "Georgia, Source Serif 4, serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.7
rounded:
  control: "10px"
  row: "12px"
  card: "16px"
  bar: "28px"
  chip: "999px"
spacing:
  xs: "4px"
  s: "8px"
  m: "12px"
  l: "16px"
  xl: "24px"
  xxl: "32px"
  section: "40px"
  xxxl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.selah-green}"
    textColor: "{colors.paper}"
    rounded: "{rounded.chip}"
    padding: "10px 18px"
    height: "40px"
  button-secondary:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.chip}"
    padding: "10px 18px"
    height: "40px"
  row:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.row}"
  hero-card:
    backgroundColor: "{colors.selah-green}"
    textColor: "{colors.paper}"
    rounded: "{rounded.card}"
    padding: "22px"
  input:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
---

# Design System: Selah

The code is the source of truth: `app/lib/src/app/theme.dart` (palette, `SelahTones`, type scale) and `app/lib/src/app/design/tokens.dart` (spacing, radii, elevation, layout widths) plus `breakpoints.dart`. If this file and the code disagree, fix whichever is wrong. Never let them drift apart.

## Overview

**Creative North Star: "The devotional book"**

Selah should feel like a well-made devotional book or journal: calm, warm and personal, not a tech dashboard. The page is cream paper in light mode and warm charcoal in dark mode. Scripture and long reading text are set in a serif, as in a printed book; everything around them (titles, labels, buttons, lists) is a clean, compact sans, Inter, sized after the YouVersion Bible app so the screen feels light and the words of the study stand out. Selah green carries the identity in a few large places. Terracotta marks small things that need a glance. Everything else steps back so the words of the study lead.

The website and the app are the same people's product in two shapes. On a computer it is a website; on a phone it is an app. Neither is the other one stretched or squeezed.

**Key characteristics:**
- Warm paper and warm charcoal; never pure white or pure black backgrounds.
- One strong color (green) for large areas, one (terracotta) only for small marks.
- Serif for reading, Inter for everything else.
- Generous but consistent spacing; long text keeps a book-like line length.

## Colors

Warm, low-saturation neutrals with one deep green and one earthy highlight.

### Primary
- **Selah green** (`#2F5D4A`; dark mode **sage** `#A9CDB8`): the hero card, primary buttons, the active tab, links and done ticks. In dark mode controls use sage so they don't glow, and the hero card uses deep green `#26332C` → `#1F2A24`.

### Secondary
- **Terracotta** (`#A65033`; dark `#E0906E`): highlights only. Use it for today's marker in the week row, unread or new items, progress, small badges and eyebrow labels on paper or raised paper. It's never a fill for a card, button, banner or gradient, and never sits on the green hero card (it fails contrast there).

### Part colours
Each day has three parts, and each has its own colour, from `PartPalette` (`context.partPalette`) in `theme.dart`. A tone has a `color` for marks, rules, icons and fills, a `text` for small labels in the part's colour (section eyebrows, the tick bar's chip name), a `tint` for a quiet background and a `soft` for an unfilled track.

| Part | Colour | Text | Tint | Soft | Dark colour (= text) | Dark tint | Dark soft |
|---|---|---|---|---|---|---|---|
| Reading (green) | `#2F5D4A` | `#2F5D4A` | `#E6EEE8` | `#D3E2D8` | `#A9CDB8` | `#27332C` | `#33443A` |
| Reflection (amber) | `#B8732E` | `#8F561F` | `#F5EBDD` | `#EEDCC2` | `#E2B27A` | `#392F23` | `#4A3C2A` |
| Prayer (dusk blue) | `#5E6A9C` | `#545F90` | `#E8E9F2` | `#D7DAEA` | `#B4BDEB` | `#2B2F42` | `#393E58` |

**The rule:** part colours mark the three parts of a day, and only those. Don't use them as general accents, and terracotta keeps its role as the small highlight. Each colour reaches 3:1 on its own tint, and a paper check mark on it reaches 3:1 (non-text); each `text` colour reaches 4.5:1 on paper and on its tint. All enforced by `app/test/contrast_test.dart`. Never set text in `color`: the amber and the blue are too light for it.

On the green hero card (the reader's header ring, `PartRing(onHero: true)`) the reading arc and a finished day's disc take the hero's text colour, the other arcs are lightened halfway towards it, and the track is a faint wash of it, so nothing is green on green.

### Neutral
- **Paper** (`#FAF7F2`; dark **charcoal** `#1E1C1A`): the page background.
- **Raised paper** (`#F1EBE1`; dark `#272421`): cards, rows, inputs and the tab bar. In dark mode, surfaces get lighter as they rise.
- **Ink** (`#262320`; dark `#EDE8E1`): text.
- **Muted ink** (`#6F655A`; dark `#A39B91`): secondary text, dates and captions.
- **Text on the hero card:** paper `#FAF7F2` in light mode, ink `#EDE8E1` in dark mode (`onPrimary` / `onSurface`).

**Contrast:** every text pair above meets WCAG AA (4.5:1) on both the page and raised surfaces, in both themes; borders (`outline`, muted ink) meet 3:1. `app/test/contrast_test.dart` enforces it, so run it whenever a color changes.

**Material roles:** the Material `ColorScheme` is pinned to this palette. The `surfaceContainer*` roles step from paper to raised paper, `outline` is muted ink, and snackbars are ink on paper. No cool green-gray roles come from the seed color.

## Typography

- **Sans: Inter** (4.1, bundled in `app/assets/fonts/`, SIL Open Font License, `Inter-OFL.txt`), the same face on iOS, Android and the web. Use it for titles, headings, labels, buttons, lists, navigation, forms and metadata. Headings are bold, tracked in slightly (-0.5 from 24 px up, -0.2 below).
- **Serif: Georgia**, only for reading: the hero quote (italic) and long reading text such as reflection, prayer and the reader. The web and Android have no Georgia, so they fall back to **Source Serif 4** (bundled, SIL Open Font License) rather than a sans serif.

| Role (`TextTheme`) | Family | Size / line height | Weight |
|---|---|---|---|
| `displaySmall` | Inter | 32 / 1.15 | 700 |
| `headlineMedium` (page titles) | Inter | 28 / 1.2 | 700 |
| `headlineSmall` | Inter | 22 / 1.25 | 700 |
| `titleLarge` | Inter | 19 / 1.3 | 700 |
| `titleMedium` | Inter | 16 / 1.35 | 600 |
| `bodyLarge` | Inter | 16 / 1.5 | 400 |
| `bodyMedium` | Inter, muted | 14 / 1.45 | 400 |
| `bodySmall` | Inter, muted | 13 / 1.4 | 400 |
| `labelLarge` | Inter | 15 / 1.2 | 600 |
| `labelMedium` | Inter | 12 / 1.3 | 600 |
| `labelSmall` (eyebrow) | Inter, terracotta | 12, +0.6 tracking | 600 |
| `serifQuote()` | serif italic | 22 / 1.35 | 400 |
| `serifReading()` | serif | 18 / 1.7 | 400 |

`ThemeData.fontFamily` is Inter, and the iOS bar titles use it too through `cupertinoOverrideTheme`. Pages use these roles; they never set a raw `fontSize`. The only exceptions are the frosted tab bar's 12 px label and Google's sign-in button (brand rules).

## Layout

**Spacing scale** (`Space`): 4, 8, 12, 16, 24, 32, 40 (`section`), 48. Use the scale; don't invent in-between values.

**Widths** (`Layout`):
- `maxContent` 1200: the widest the desktop content area gets.
- `readingMeasure` 680: long text never runs wider (about 60–75 characters).
- `formWidth` 440: forms never stretch.
- `bottomGap` 16: the space between the last item and the tab bar or the bottom edge.

**Page header** (`SelahPage`, app layout): a compact title bar pinned right under the status bar, as in the YouVersion app, instead of iOS's tall large title. The title is `headlineMedium` (28, bold, left-aligned) on a tab's root page and `headlineSmall` next to a back button, with the page actions on the right, all in a 52 px row. An optional `subtitle` line is pinned under it (Today's date and church, 24 px). The bar sits on paper; a 0.5 px `outlineVariant` hairline fades in once content scrolls under it. Content starts `Space.s` below it. A page with no title (the reader) keeps the slim bar with only the back button and actions.

**Screen sizes** (`screenSizeOf(context)`):

| Size | Width | Web | iOS / Android |
|---|---|---|---|
| Phone | < 600 | App layout: bottom tab bar, one column | App layout (glass tab bar on iOS 26) |
| Tablet | 600–1023 | Bottom bar; two columns where they fit | Same |
| Desktop | ≥ 1024 | Website layout: top navigation, centered content up to 1200, multi-column pages | n/a |

**Website layout** (`siteLayout(context)`: not iOS, and at least 1024 px wide). iOS, iPad included, always keeps the glass tab bar.
- **`SiteHeader`** replaces the tab bar:
  - left: the Selah wordmark (serif),
  - next to it: the same destinations as text links, the selected one green with a 2 px underline,
  - right: the church (a menu for people in several churches) and the language menu.

  The study page and reader get it too, through `SiteFrame`.
- **Pages have no app bar.** The back link and the `headlineMedium` title sit at the top of the content, which is centered at the page's `maxWidth`, or at `Layout.maxContent` for `SelahPage(wide: true)`.
- **Page layouts:**
  - **Hoje:** the day in the main column; the date, the week and the next three events in a 340 px side column.
  - **Estudos:** the intro at reading width, the featured study as a horizontal card (thumbnail left, text right), and recent studies in a `CardGrid` of up to three columns.
  - **Study page:** the summary at reading width, with the devotional path in a 380 px side column.
  - **Reader:** the text at 680, with the study's days in a 280 px side column. The current day is marked green and isn't a link. The side column scrolls with the page.
  - **Eventos:** the next event at reading width; later events in two columns.
  - **Perfil:** one 640 px column.
- **Language menu:** page-action copies of the language menu hide in this layout, because the header has it.

Tablets (600–1023) keep the app layout and one column for now.

### Landing page

The public front door at `/` (Spanish), `/pt/` and `/en/`. It's a static site in `site/`, not a Flutter screen: one template rendered per language by `site/build.py`, styled in `site/src/styles.css`.
- **Its own look: soft blue-gray, with a blue-hour hero.** The landing page is always this mid-light tone and doesn't follow the device's dark mode. Its pieces:
  - **Surfaces:** a soft blue-gray canvas (`#DDE2E8`, a daytime echo of the hero's blue hour) with lighter cards (`#EDF0F3`, 12 radius, 32 padding). There are no borders and no shadows.
  - **Hero:** the hero photo and the top bar over it stay dark, with light text.
  - **Type:** Inter for UI and headings, at intermediate weights (480 for headings, 530 for the H1). Source Serif italic is used only for the verse.
  - **Color:** Selah's green (`#2F5D4A`) is the one accent, and it fills exactly one control, the hero's "start reading" pill. Every other control is a ghost pill with a hairline outline.
- **Returning members** (a church picked, or signed in) skip it and go straight to `/today`. Sign-in email links are forwarded to the app with their hash and query intact, and `/?home` always shows the page. The logic is `site/src/redirect.js`, inlined first in `<head>`.
- **Sections, in order:**
  0. The header, after Mercury. It stays fixed at the top:
     - see-through over the photo while the page is at the top, then frosted dark glass (a 72% dark fill with a 20px blur) once it scrolls;
     - the wordmark on the left and the three section links in the middle (How it works, The app → the Today demo, For churches; shown from 960px wide);
     - "Sign in" (shown from 600px wide) and a solid ivory "Open the app" pill on the right.

     The pill is ivory rather than green so the hero's button stays the only accent. Without the script the header is just always frosted.
  1. The full-bleed hero: a photo of someone reading the Bible at dawn, with the conviction, the verse under a short green rule, the lede and the two pills. The top bar floats over it. `site/hero.py <photo>` writes `hero-{720,1280,1920}.webp` and `og.png`. Without those files the hero falls back to a blue-hour gradient. On load the photo eases out of a slight zoom and the words rise in turn.
  2. How it works: three numbered light cards through the week (Sunday, during the week, each day), each topped with a painting from the app's library.
  3. **Today, live** (`#today`): the app's Today page rebuilt in HTML inside a phone, beside three short points (the parts, the week rings, the quiet finish). It shows the app's motion as the app does it, with the app's own tokens and part colours, scoped to `.app-screen`: each tick hops its icon, ripples and fills its arc of today's ring; the last one springs the ring into a green disc with a check, lets the light rise in the hero card and fades up "That's today. / Go in peace." It plays itself once when it comes into view, the ticks are real buttons, and "Play again" replays it. The week's letters come from `week_days`; the rings are written by `build.py`.
  4. **The reader, scroll-driven** (`#reader`): a phone stays in place while the page scrolls through a day (reading, reflection with practice and questions, prayer). The part in view widens in the floating tick bar, each part ticks once it's been read past, and at the end the bar slides away for the green "Day complete · back to Today" pill. A legend beside it marks the part in view. Without motion it's a still phone at the top of the day.
  5. **The illustration library** (`#art`): two rows of the app's paintings drifting in opposite directions (80s and 95s a loop, paused on hover). Without motion, one still row each, scrollable by hand. The paintings and their alt text in three languages are listed in `site/src/art.json` (from `app/assets/art/manifest.json`); the files are 640-wide copies in `site/src/img/art/`, with the part icons at 128.
  6. The app on a laptop (Today) and a phone (a finished day), on a light card, captured from the made-up demo church in `app/tool/demo_main.dart` with headless Chrome.
  7. Members and leaders: two light cards side by side.
  8. The footer, with the language switcher.
- **Motion, after Mercury.** Section headings, cards and the app copy rise about 24px and fade in over 670ms, once, the first time they reach the screen. Cards in a row are staggered by 100ms. The laptop and phone slide in from the right instead, the phone following 180ms behind. Content is hidden only after `site/src/motion.js` has run. With reduced motion nothing moves: the demos don't play themselves, the reader and the gallery stand still, and a tick simply shows checked.
- **Part colours** appear only inside the two app demos, where they mark the three parts as they do in the app. The page's own controls keep the one-accent rule.
- **No eyebrow labels and no icons on the cards** (the paintings are illustrations, not icons). Two scripts only: the redirect check and `motion.js`, which drives the header, the section motion and both demos. Each page stays within 250 KB of HTML, CSS and fonts before images.
- **Routing:** the app answers its own addresses from `app.html`. The list lives once in `app/tool/routes.py`, which writes Cloudflare's `_redirects`.

## Elevation & Depth

The design is mostly flat and tonal. Depth comes from surface lightness (paper → raised paper), not shadows. `Elevation.raised(brightness)` (one soft shadow at 8% ink, 24 blur, 6 down, in light mode, and none in dark mode) is reserved for floating elements; nothing uses it yet. The desktop top navigation and floating buttons will. On iOS 26 the tab bar is native Liquid Glass.

## Shapes

Gently rounded, after the YouVersion app: corners are soft but small, never sharp and never bubbly.
- `Radii.control` 10: inputs, small buttons.
- `Radii.row` 12: rows, cards in lists, images, the selected day in the week.
- `Radii.card` 16: the hero card and large cards.
- `Radii.bar` 28: the frosted floating tab bar's capsule.
- `Radii.chip`: fully rounded pills, tags and primary buttons (stadium shape).

## Components

All components live in `app/lib/src/app/design/` and read only tokens.
- **Site header** (`SiteHeader`, `SiteFrame`): the desktop top bar, 64 px tall, on paper with an `outlineVariant` hairline. Links are text buttons, so they can take keyboard focus.
- **Two columns** (`TwoColumn`): a main column and a fixed side column, `Space.xxl` apart. Use it only in the website layout.
- **Card grid** (`CardGrid`): as many columns as fit (default 280 px minimum, three at most). Tiles in a row share a top edge and keep their width when a row isn't full.
- **Hero card** (`HeroCard`): today's study. It has a green gradient (`heroStart` → `heroEnd`), paper-colored text in light mode (ink in dark mode), `Radii.card` and 22 padding. It holds an eyebrow, a bold Inter title and a serif italic quote. It's the one large green surface per screen. A finished day's card holds a soft light (`glow`): a pale radial highlight from the bottom centre. Optional `art` fills the right 60% of the card behind the text, fading from transparent at its left edge to 35% at the right, so the title and quote run the full width and stay legible: across the whole library the title keeps at least 3.8:1 in light mode and 4.5:1 in dark. Today's card shows only the eyebrow and the title; the reader's card adds the quote. Both show the day's art, and until its file exists the card is plain green, with no placeholder.
- **Row** (`SelahRow`): raised paper, `Radii.row`, ink title, muted subtitle. Presses spring (`Pressable`).
- **Tab bar** (`AdaptiveTabBar`): native glass on iOS 26, a frosted pill elsewhere on iOS, and a Material `NavigationBar` on raised paper on Android and web. The native glass bar gets no padding of ours, since it keeps its own margins: that puts it full width and just above the home indicator, where the system's tab bars sit. The frosted pill sits 12 px in from the sides and 14 px into the bottom inset (at least 8 px above the edge). The selected tab takes the done green (`tones.done`) over a soft pill of the same green at 10%; the native glass bar takes only the tint, and keeps its own glass and selection.
- **Buttons:** compact stadiums, 40 px tall with 18 × 10 padding and 15 px semibold text (tap targets stay 48 px). Primary is filled green with paper-colored text. Secondary (`OutlinedButton`) is a soft raised-paper pill with ink text and no border. Text buttons are green, 36 px tall.
- **Inputs:** a raised paper fill with no border, `Radii.control`, and a 1.5 px green border on focus.
- **Eyebrow** (`Eyebrow`): `labelSmall`, upper case, terracotta. It sits above a section heading.
- **Skeletons** (`skeleton.dart`): raised-paper shapes matching the content while it loads; never a bare spinner on member screens.
- **Week rings** (`WeekRings`, Today): seven rings, one arc per part in its part colour; a finished day is a filled green circle with a check (it springs in when the day finishes on screen, and is simply there otherwise), and today's number is terracotta. Today or an earlier day can be tapped to show it; the content slides 24 px the way the selection moved (a fade only with Reduce Motion), and the title becomes "Yesterday" or the weekday.
- **Finishing a day (moment A):** the light rises in the hero card (`Motion.glow`), then the serif `FinishLine` ("That's today. / Go in peace.", or "Day complete. / Nothing lost." on a past date) rises 8 px and fades in, with one success haptic. It plays once, live; later the day shows in that settled state. Nothing pops up or needs dismissing.
- **Tick bar** (`TickDock`, the reader everywhere): a floating pill, 64 px tall, 12 px in from the sides and 14 px above the safe bottom (on the website it spans the text column instead), in paper at 72% over a 16 px blur (94% on the web, whose blur is weak), `Elevation.raised`. One chip per part the day has; the part whose section is in view widens (flex 2.8, `Motion.medium`, a spring curve) to show its name and "Tap to tick", the others show only their icon. A ticked part's icon hops and gets a check badge. When every part is ticked the bar slides away and a green "Day complete · back to Today ›" pill rises in its place (`Motion.dockSwap`, 600 ms; a fade with Reduce Motion). It never navigates on its own. Reading sections carry a 3 px rule in their part colour and an eyebrow in its `text` colour.

## Motion

Calm and brief: things settle into place, nothing bounces for attention, and nothing has to finish before you can act. Every duration and spring lives in `Motion` (`tokens.dart`); add a token there before using a new value.

- **Durations:** `short` 150 ms, `medium` 280 ms, `long` 420 ms, `staggerStep` 40 ms. Presses spring to 0.97 (`Motion.press`) and ignore a second tap within 400 ms.
- **Screens arrive** (`SelahPage`, `Entrance`): on a page's first build each block rises 12 px and fades in over `medium`, 40 ms after the one before, capped at the seventh so a long page's tail never waits. Spacers take no turn. It plays once per page, not on rebuilds. Long lazy lists (the church list, a church's studies) don't arrive as a whole; pages that stagger their own content (Today's parts, Welcome) turn it off with `arrive: false`, and a block with its own motion or a Hero is marked `NoArrive` (a study's days, the reader's hero card). A church's studies are lazy, so only their first block arrives, then crossfades from its skeleton. The website layout doesn't arrive.
- **Skeleton to content** (`ContentSwitcher`): a crossfade over `medium` on Today, a church's studies, a study, the reader and Events. A rebuild of the same content updates in place, so a Hero, a scroll position or the reader's state survives fresh data.
- **Shared elements:** the Today hero card flies into the reader's header, a study's art into the study page's header, and a church's art into the next screen.
- **Scenes:** Welcome's scene fades in as it rises 12 px over 600 ms (`sceneIn`). Sign in and the invitation arrive like any page; the sign-in scene then drifts 6 px up and down on a 20 s loop (`drift`), and a refused sign-in shakes the fields 3 times, 8 px, over 400 ms (`shake`).
- **Week rings:** a part's arc fills over `medium`. Picking another day slides the content 24 px the way the selection moved, over 250 ms (`daySwitch`).
- **Ticking a part:** the tick ripples outward in the part colour over 600 ms (`ripple`) and the part's icon hops, up to 1.25× with an 8° tilt and back, over 600 ms (`hop`).
- **Finishing a day (moment A):** the light rises in the hero card over 1.8 s (`glow`); after 700 ms (`finishDelay`) the finish line rises 8 px and fades in over 1 s (`finishRise`). Once, live, and never blocking.
- **The reader's dock:** the current part's chip widens over `medium`; when the day is done the bar slides down and the "Day complete" pill rises in over 600 ms (`dockSwap`).
- **Progress bars** (the featured study, the admin monthly usage) fill from empty over `long` when they first appear; the next event's date counts up to its day the same way.
- **Admin work in progress:** the Generando chip has a slow band of full opacity sweeping across it (`shimmer`, 1.6 s, on repeat; the chip dims to 55% outside the band and keeps its own colours), and the running step breathes between 60% and full opacity (`breathe`, 1.4 s each way).

**Haptics** (`SelahHaptics`, none on the web) form a small vocabulary; use these and nothing else:
- `selection`: switching days in the week, switching a segment or a tab, and picking one of Welcome's two paths.
- `tick`: ticking a part, and pressing a row or a card (light, the same as a tick).
- `success`: finishing a day, joining a church from an invitation, and publishing a study. Once per event.
- `warning`: a refused sign-in.

**Reduce Motion** (`reduceMotion(context)`) is honoured everywhere. Arrival, scenes, rings and progress bars show in place; Today's day switch and the dock become a plain fade; the hero card's glow, a finished ring's disc and bottom sheets appear at once, and skeletons swap at once; the press, hop, ripple, drift, shake, shimmer and breathing don't play; the finish line simply appears. Haptics still play.

## Do's and Don'ts

**Do**
- Use tokens and text-theme roles; add a token before adding a one-off value.
- Keep terracotta small: dots, rings, eyebrows, badges.
- Keep long text at `readingMeasure` on every screen size.
- Design each screen size on purpose: website on desktop, app on phone.
- Check light and dark mode, and 200% text size, for every new screen.

**Don't**
- Stretch the phone layout across a desktop, or squeeze a desktop layout onto a phone.
- Use pure white or pure black backgrounds, or terracotta as a large fill.
- Use generic template design: stock gradients, glowing cards, emoji icons, or a centered hero with three icon cards.
- Set `fontSize`, `Color(0x…)` or a numeric radius in a page.
- Put a second large green surface competing with the hero card on the same screen.
