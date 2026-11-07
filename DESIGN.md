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
  ink-muted-dark: "#9C948A"
  sage-dark: "#A9CDB8"
  hero-green-dark: "#26332C"
  hero-green-deep-dark: "#1F2A24"
  terracotta-dark: "#E0906E"
typography:
  display:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "40px"
    fontWeight: 600
    lineHeight: 1.1
  headline:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "30px"
    fontWeight: 600
    lineHeight: 1.15
  headline-small:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.25
  title:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.3
  title-ui:
    fontFamily: "system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.35
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.55
  body-secondary:
    fontFamily: "system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  body-small:
    fontFamily: "system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.2
  label-small:
    fontFamily: "system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.3
  eyebrow:
    fontFamily: "system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 700
    letterSpacing: "1.5px"
  quote:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: 1.35
  reading:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.7
rounded:
  control: "14px"
  row: "20px"
  card: "28px"
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
    padding: "16px 22px"
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

Selah should feel like a well-made devotional book or journal: calm, warm and personal, not a tech dashboard. The page is cream paper in light mode and warm charcoal in dark mode. Headings and Scripture are set in a serif, as in a printed book; the interface around them (labels, buttons, lists) is a quiet sans-serif. Selah green carries the identity in a few large places. Terracotta marks small things that need a glance. Everything else steps back so the words of the study lead.

The website and the app are the same people's product in two shapes. On a computer it is a website; on a phone it is an app. Neither is the other one stretched or squeezed.

**Key characteristics:**
- Warm paper and warm charcoal; never pure white or pure black backgrounds.
- One strong color (green) for large areas, one (terracotta) only for small marks.
- Serif for reading and headings, sans for interface.
- Generous but consistent spacing; long text keeps a book-like line length.

## Colors

Warm, low-saturation neutrals with one deep green and one earthy highlight.

### Primary
- **Selah green** (`#2F5D4A`; dark mode **sage** `#A9CDB8`): the hero card, primary buttons, the active tab, links and done ticks. In dark mode controls use sage so they don't glow, and the hero card uses deep green `#26332C` → `#1F2A24`.

### Secondary
- **Terracotta** (`#A65033`; dark `#E0906E`): highlights only. Use it for today's marker in the week row, unread or new items, progress, small badges and eyebrow labels on paper or raised paper. It's never a fill for a card, button, banner or gradient, and never sits on the green hero card (it fails contrast there).

### Neutral
- **Paper** (`#FAF7F2`; dark **charcoal** `#1E1C1A`): the page background.
- **Raised paper** (`#F1EBE1`; dark `#272421`): cards, rows, inputs and the tab bar. In dark mode, surfaces get lighter as they rise.
- **Ink** (`#262320`; dark `#EDE8E1`): text.
- **Muted ink** (`#6F655A`; dark `#9C948A`): secondary text, dates and captions.
- **Text on the hero card:** paper `#FAF7F2` in light mode, ink `#EDE8E1` in dark mode (`onPrimary` / `onSurface`).

**Contrast:** every text pair above meets WCAG AA (4.5:1) on both the page and raised surfaces, in both themes; borders (`outline`, muted ink) meet 3:1. `app/test/contrast_test.dart` enforces it, so run it whenever a color changes.

**Material roles:** the Material `ColorScheme` is pinned to this palette. The `surfaceContainer*` roles step from paper to raised paper, `outline` is muted ink, and snackbars are ink on paper. No cool green-gray roles come from the seed color.

## Typography

- **Serif: Source Serif 4** (bundled in `app/assets/fonts/`, SIL Open Font License). Use it for display, headlines, titles, the hero quote (italic) and long reading text such as reflection, prayer and the reader.
- **Sans: the system font.** Use it for everything you operate: labels, buttons, lists, navigation, forms and metadata.

| Role (`TextTheme`) | Family | Size / line height | Weight |
|---|---|---|---|
| `displaySmall` | serif | 40 / 1.1 | 600 |
| `headlineMedium` | serif | 30 / 1.15 | 600 |
| `headlineSmall` | serif | 24 / 1.25 | 600 |
| `titleLarge` | serif | 20 / 1.3 | 600 |
| `titleMedium` | sans | 17 / 1.35 | 600 |
| `bodyLarge` | sans | 17 / 1.55 | 400 |
| `bodyMedium` | sans, muted | 15 / 1.5 | 400 |
| `bodySmall` | sans, muted | 13 / 1.45 | 400 |
| `labelLarge` | sans | 15 / 1.2 | 600 |
| `labelMedium` | sans | 12 / 1.3 | 600 |
| `labelSmall` (eyebrow) | sans, terracotta | 11, +1.5 tracking | 700 |
| `serifQuote()` | serif italic | 22 / 1.35 | 400 |
| `serifReading()` | serif | 18 / 1.7 | 400 |

iOS large and slim page titles use the same serif through `cupertinoOverrideTheme`. Pages use these roles; they never set a raw `fontSize`. The only exceptions are the frosted tab bar's 12 px label and Google's sign-in button (brand rules).

## Layout

**Spacing scale** (`Space`): 4, 8, 12, 16, 24, 32, 40 (`section`), 48. Use the scale; don't invent in-between values.

**Widths** (`Layout`):
- `maxContent` 1200: the widest the desktop content area gets.
- `readingMeasure` 680: long text never runs wider (about 60–75 characters).
- `formWidth` 440: forms never stretch.
- `bottomGap` 16: the space between the last item and the tab bar or the bottom edge.

**Screen sizes** (`screenSizeOf(context)`):

| Size | Width | Web | iOS / Android |
|---|---|---|---|
| Phone | < 600 | App layout: bottom tab bar, one column | App layout (glass tab bar on iOS 26) |
| Tablet | 600–1023 | Bottom bar; two columns where they fit | Same |
| Desktop | ≥ 1024 | Website layout: top navigation, centered content up to 1200, multi-column pages | n/a |

*The top navigation and the desktop page layouts are coming in the next plan.* Until then, wide web screens still show the navigation rail and a centered column.

Desktop page direction:
- **Hoje:** the reading in a main column; the week and events in a side column.
- **Estudos:** a grid of study cards.
- **Study page:** the overview and the days side by side.
- **Reader:** one reading column, with the days in a sticky side column.
- **Forms:** narrow and centered.

## Elevation & Depth

The design is mostly flat and tonal. Depth comes from surface lightness (paper → raised paper), not shadows. `Elevation.raised(brightness)` (one soft shadow at 8% ink, 24 blur, 6 down, in light mode, and none in dark mode) is reserved for floating elements; nothing uses it yet. The desktop top navigation and floating buttons will. On iOS 26 the tab bar is native Liquid Glass.

## Shapes

Soft, rounded and friendly, never sharp.
- `Radii.control` 14: inputs, small buttons.
- `Radii.row` 20: rows, cards in lists, images.
- `Radii.card` 28: the hero card and large cards.
- `Radii.chip`: fully rounded pills, tags and primary buttons (stadium shape).

## Components

All components live in `app/lib/src/app/design/` and read only tokens.
- **Hero card** (`HeroCard`): today's study. It has a green gradient (`heroStart` → `heroEnd`), paper-colored text in light mode (ink in dark mode), `Radii.card` and 22 padding. It holds an eyebrow, a serif title and a serif italic quote. It's the one large green surface per screen.
- **Row** (`SelahRow`): raised paper, `Radii.row`, ink title, muted subtitle. Presses spring (`Pressable`).
- **Tab bar** (`AdaptiveTabBar`): native glass on iOS 26, a frosted pill elsewhere on iOS, and a Material `NavigationBar` on raised paper on Android and web. The selected tab is green.
- **Buttons:** primary is a filled green stadium with paper-colored text. Secondary is an outlined stadium with green text and a green border.
- **Inputs:** a raised paper fill with no border, `Radii.control`, and a 1.5 px green border on focus.
- **Eyebrow** (`Eyebrow`): `labelSmall`, upper case, terracotta. It sits above a section heading.
- **Skeletons** (`skeleton.dart`): raised-paper shapes matching the content while it loads; never a bare spinner on member screens.
- **Week row** (Today): seven circles on raised paper. Done days are green, and today has a terracotta ring.

Motion: `Motion.short` 150 ms, `medium` 280 ms, `long` 420 ms, and a spring press scale of 0.97. With Reduce Motion on, everything becomes a simple fade.

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
