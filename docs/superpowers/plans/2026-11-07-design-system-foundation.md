# Design System Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Selah its new look (warm paper and Selah green with terracotta, a gray dark mode, a bundled serif), its design tokens, a written `DESIGN.md`, and a visual style guide, then stop for the owner's review.

**Architecture:** All visual values live in `app/lib/src/app/theme.dart` (palette, `SelahTones`, type) and `app/lib/src/app/design/tokens.dart` (spacing, radii, elevation, layout widths), plus a new `design/breakpoints.dart`. Pages and components read tokens and never hard-code values. `DESIGN.md` at the repo root states the same rules in words. The style guide is a published artifact built from these values.

**Tech Stack:** Flutter 3.47.4 / Dart 3.13, `flutter_test`. Source Serif 4 is bundled as font assets under the SIL Open Font License.

**Spec:** `docs/superpowers/specs/2026-11-07-design-system-and-responsive-web-design.md`

**Scope:** this is the first of several plans. It ends at the spec's hard stop, when the owner reviews the style guide. The shell and top navigation, the member screen layouts, the landing page and admin each get their own plan after approval, because the review may change values set here.

## Global Constraints

- Feeling: "a well-made devotional book or journal. Calm, warm and personal, not a tech dashboard."
- Rules:
  - One strong color for big areas (green).
  - One color only for small marks (terracotta). Terracotta is never a large fill.
  - Dark mode is gray, never pure black. Pure white and pure black never appear as backgrounds.
- Text and controls meet WCAG AA in both themes.
- No new features, routes, data or backend changes. The iOS glass tab bar, navigation, haptics and Reduce Motion behavior stay as they are.
- Member screens stay localized (pt/es/en). Admin stays Spanish.
- All existing tests in `app/test/` keep passing. Update only assertions about values this plan changes on purpose (palette, fonts, padding).
- Run the commands below from `app/` unless a step says otherwise.

## Review Focus

1. **Portuguese and Spanish characters in the serif** (ã, õ, ç, é, ñ, ¿, ¡, curly quotes “ ”) must render in Source Serif 4 without fallback-font glyphs. → Task 2, visual check of the accent string.
2. **Large text (accessibility text size 200%)** must not clip or overlap the hero card, rows or week row in the new type scale. → Task 4, visual check with `textScaler: 2.0`.
3. **Font loading on the web:** the first paint must not show Georgia or Times, then jump to the new serif. → Task 2, check on a cold load of the release web build.
4. **Pages with no tab bar** (reader, study page, login) must still clear the home indicator after the bottom gap is reduced. → Task 3 test `bottom gap without a tab bar still clears the safe area`.
5. **Terracotta drifting into a large fill**, for example a hero gradient or a full-width button picking up `colorScheme.secondary`. → Task 4, a sweep for `secondary` and `accent` uses, plus the visual check.

---

### Task 1: New palette and contrast guarantees

**Files:**
- Modify: `app/lib/src/app/theme.dart` (the `_light` and `_dark` palettes, lines ~115–150; `_Palette` gains `surface` handling only through `tones`, so no new fields)
- Modify: `app/test/theme_test.dart` (replace the two palette tests)
- Create: `app/test/contrast_test.dart`

**Interfaces:**
- Produces:
  - `selahLightTheme()` and `selahDarkTheme()` with the values below.
  - The `SelahTones` field names stay as they are (`surface, muted, accent, done, today, heroStart, heroEnd`). `accent` now means the terracotta highlight.

Values, from the spec. Muted is darkened from the mockup's values to pass AA, as the spec allows:

| | Light | Dark |
|---|---|---|
| background | `0xFFFAF7F2` | `0xFF1E1C1A` |
| text | `0xFF262320` | `0xFFEDE8E1` |
| primary / onPrimary | `0xFF2F5D4A` / `0xFFFAF7F2` | `0xFFA9CDB8` / `0xFF1E1C1A` |
| tones.surface | `0xFFF1EBE1` | `0xFF272421` |
| tones.muted | `0xFF6F655A` | `0xFF9C948A` |
| tones.accent (terracotta) | `0xFFB0573A` | `0xFFE0906E` |
| tones.done | `0xFF2F5D4A` | `0xFFA9CDB8` |
| tones.today | `0xFFB0573A` | `0xFFE0906E` |
| tones.heroStart / heroEnd | `0xFF2F5D4A` / `0xFF244A3B` | `0xFF26332C` / `0xFF1F2A24` |

- [ ] **Step 1: Write the failing tests**

In `theme_test.dart`, replace `light scheme uses the church palette` and `dark scheme is near-black with green accent` with:

```dart
test('light theme is warm paper with Selah green and terracotta', () {
  final t = selahLightTheme();
  final tones = t.extension<SelahTones>()!;
  expect(t.scaffoldBackgroundColor, const Color(0xFFFAF7F2));
  expect(t.colorScheme.onSurface, const Color(0xFF262320));
  expect(t.colorScheme.primary, const Color(0xFF2F5D4A));
  expect(tones.surface, const Color(0xFFF1EBE1));
  expect(tones.accent, const Color(0xFFB0573A));
  expect(tones.heroStart, const Color(0xFF2F5D4A));
});

test('dark theme is warm gray, not black, with sage and terracotta', () {
  final t = selahDarkTheme();
  final tones = t.extension<SelahTones>()!;
  expect(t.scaffoldBackgroundColor, const Color(0xFF1E1C1A));
  expect(t.colorScheme.primary, const Color(0xFFA9CDB8));
  expect(tones.surface, const Color(0xFF272421));
  expect(tones.accent, const Color(0xFFE0906E));
  expect(tones.heroStart, const Color(0xFF26332C));
});
```

Create `contrast_test.dart`. It contains a `double contrast(Color a, Color b)` helper using the WCAG 2.x relative-luminance formula (sRGB linearization, `(L1 + 0.05) / (L2 + 0.05)`), and the following test for each theme (`for (final (name, theme) in [('light', selahLightTheme()), ('dark', selahDarkTheme())])`):

```dart
test('$name theme meets WCAG AA', () {
  final s = theme.colorScheme;
  final tones = theme.extension<SelahTones>()!;
  final bg = theme.scaffoldBackgroundColor;
  expect(contrast(s.onSurface, bg), greaterThanOrEqualTo(4.5));
  expect(contrast(s.onSurface, tones.surface), greaterThanOrEqualTo(4.5));
  expect(contrast(tones.muted, bg), greaterThanOrEqualTo(4.5));
  expect(contrast(tones.muted, tones.surface), greaterThanOrEqualTo(4.5));
  expect(contrast(s.primary, bg), greaterThanOrEqualTo(4.5)); // links and labels
  expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5)); // button text
  expect(contrast(tones.accent, bg), greaterThanOrEqualTo(4.5)); // small terracotta labels
  expect(contrast(const Color(0xFFF5F0E6), tones.heroStart), greaterThanOrEqualTo(4.5)); // text on hero
  expect(contrast(const Color(0xFFF5F0E6), tones.heroEnd), greaterThanOrEqualTo(4.5));
});

test('$name background is neither pure white nor pure black', () {
  expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFFFFFFF)));
  expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
});
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/theme_test.dart test/contrast_test.dart`
Expected: FAIL. The palette tests fail with the old colors, and light `muted` vs `surface` fails contrast.

- [ ] **Step 3: Set the palettes in `theme.dart`**

Replace the `_light` and `_dark` values with the table above. If the hero card's text color is computed from the hero colors (`onHero` in `hero_card.dart`), confirm it resolves to a light text color on both gradients. If it doesn't, pin it to `0xFFF5F0E6`.

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: PASS. If another test asserts an old palette value, update that value only.

- [ ] **Step 5: Commit**

```bash
git add lib/src/app/theme.dart test/theme_test.dart test/contrast_test.dart
git commit -m "Warm paper and Selah green palette with a gray dark mode"
```

---

### Task 2: Bundled serif and the type scale

**Files:**
- Create: `app/assets/fonts/SourceSerif4-Regular.ttf`, `-It.ttf`, `-Semibold.ttf`, `-SemiboldIt.ttf`, `-Bold.ttf`, `app/assets/fonts/OFL.txt`
- Modify: `app/pubspec.yaml` (the `flutter:` → `fonts:` section)
- Modify: `app/lib/src/app/theme.dart` (`_serif`, `_heading`, `textTheme`, `serifQuote`, `serifReading`)
- Modify: `app/test/theme_test.dart` (replace `UI text uses the system font`)

**Interfaces:**
- Produces:
  - Font family `'Source Serif 4'`.
  - The `TextTheme` roles below, which later plans use by name.
  - `serifQuote(context)` and `serifReading(context)` keep their signatures.

Type scale (*the builder's values within the spec*). Serif means `'Source Serif 4'`; sans means the system font, with no `fontFamily` set:

| Role | Family | Size / height | Weight |
|---|---|---|---|
| displaySmall | serif | 40 / 1.1 | w600 |
| headlineMedium | serif | 30 / 1.15 | w600 |
| headlineSmall | serif | 24 / 1.25 | w600 |
| titleLarge | serif | 20 / 1.3 | w600 |
| titleMedium | sans | 17 / 1.35 | w600 |
| bodyLarge | sans | 17 / 1.55 | w400 |
| bodyMedium | sans | 15 / 1.5 | w400, color `muted` |
| labelLarge | sans | 15 / 1.2 | w600 |
| labelSmall (eyebrow) | sans | 11, letterSpacing 1.5 | w700, color `accent` |
| serifQuote | serif italic | 22 / 1.35 | w400 |
| serifReading | serif | 18 / 1.7 | w400 |

- [ ] **Step 1: Get the font files**

Download the static TTFs listed above and the OFL license from Adobe's official `adobe-fonts/source-serif` GitHub release (the `TTF/` folder of the latest 4.x release). Put them in `app/assets/fonts/`. Register them in `pubspec.yaml` as family `Source Serif 4`, with weights 400, 600 and 700 and italic styles for 400 and 600.

- [ ] **Step 2: Write the failing test**

Replace `UI text uses the system font` with:

```dart
testWidgets('headings and reading text use Source Serif 4, UI text does not', (tester) async {
  final text = selahLightTheme().textTheme;
  for (final style in [text.displaySmall, text.headlineMedium, text.headlineSmall, text.titleLarge]) {
    expect(style!.fontFamily, 'Source Serif 4');
  }
  for (final style in [text.titleMedium, text.bodyLarge, text.bodyMedium, text.labelLarge, text.labelSmall]) {
    expect(style!.fontFamily, isNot('Source Serif 4'));
  }
  expect(text.labelSmall!.color, selahLightTheme().extension<SelahTones>()!.accent);
  late TextStyle quote, reading;
  await tester.pumpWidget(MaterialApp(
    theme: selahLightTheme(),
    home: Builder(builder: (context) {
      quote = serifQuote(context);
      reading = serifReading(context);
      return const SizedBox();
    }),
  ));
  expect(quote.fontFamily, 'Source Serif 4');
  expect(quote.fontStyle, FontStyle.italic);
  expect(reading.fontFamily, 'Source Serif 4');
  expect(reading.fontSize, 18);
});
```

- [ ] **Step 3: Run it and confirm it fails**

Run: `flutter test test/theme_test.dart`
Expected: FAIL. `fontFamily` is null or `Georgia`.

- [ ] **Step 4: Apply the type scale in `theme.dart`**

- Set `_serif = 'Source Serif 4'`, keeping a fallback to `['Georgia', 'serif']`.
- Make `_heading` take the family.
- Fill `textTheme` from the table.

- [ ] **Step 5: Run all tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Visual check of glyphs and web font loading**

- Temporarily put `“Coração, ação, irmãos — ¿Señor? ¡Sí!”` in `serifQuote` and `headlineSmall` on the Today page. Run the app in Chrome and confirm every glyph is the serif, with no fallback glyphs. Remove the temporary text afterward.
- Build the release web app (`flutter build web --release --dart-define-from-file=config/beta.json`) and serve it (`python3 tool/serve.py 3100`). Do a hard reload and watch the first paint: headings must not flash in a different serif. If they do, preload the font (Flutter web's font manifest loads it before the first frame by default; check that it's listed in `build/web/assets/FontManifest.json`).

- [ ] **Step 7: Commit**

```bash
git add assets/fonts pubspec.yaml lib/src/app/theme.dart test/theme_test.dart
git commit -m "Bundle Source Serif 4 and set the type scale"
```

---

### Task 3: Spacing, radii, elevation, layout tokens and the bottom gap

**Files:**
- Modify: `app/lib/src/app/design/tokens.dart`
- Create: `app/lib/src/app/design/breakpoints.dart` (export it from `theme.dart` like the other design files)
- Modify: `app/lib/src/app/design/selah_page.dart:108` and `app/lib/src/app/theme.dart` (`PageBody` padding; card, button and input radii)
- Test: `app/test/design_test.dart` (add tests)

**Interfaces:**
- Produces (later plans use these exact names):
  - `Space`: existing values plus `xxxl = 48.0` and `section = 40.0`.
  - `Radii`: existing `row = 20.0` and `card = 28.0`, plus `control = 14.0` (inputs, small buttons) and `chip = 999.0`.
  - `Elevation.raised`, a `List<BoxShadow>`: a soft single shadow for floating elements such as the tab bar. Its opacity is 0 in dark mode, where surfaces rely on lightness. Expose it as `List<BoxShadow> raisedShadow(Brightness b)`.
  - `Layout.maxContent = 1200.0`, `Layout.readingMeasure = 680.0`, `Layout.formWidth = 440.0`, `Layout.bottomGap = Space.l` (16).
  - In `breakpoints.dart`: `enum ScreenSize { phone, tablet, desktop }`, `ScreenSize screenSizeFor(double width)` (phone < 600, tablet < 1024, desktop otherwise), and `ScreenSize screenSizeOf(BuildContext context)` reading `MediaQuery.sizeOf`.

- [ ] **Step 1: Write the failing tests**

Add to `design_test.dart`:

```dart
test('screen sizes switch at 600 and 1024', () {
  expect(screenSizeFor(375), ScreenSize.phone);
  expect(screenSizeFor(599), ScreenSize.phone);
  expect(screenSizeFor(600), ScreenSize.tablet);
  expect(screenSizeFor(1023), ScreenSize.tablet);
  expect(screenSizeFor(1024), ScreenSize.desktop);
  expect(screenSizeFor(1920), ScreenSize.desktop);
});

testWidgets('bottom gap under the tab bar is small', (tester) async {
  // Under the shell, the bottom inset already includes the tab bar's height.
  await tester.pumpWidget(MaterialApp(
    theme: selahLightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(bottom: 90)),
      child: const SelahPage(title: 'Hoje', children: [SizedBox(height: 10)]),
    ),
  ));
  final padding = tester.widget<SliverPadding>(find.byType(SliverPadding).last).padding.resolve(TextDirection.ltr);
  expect(padding.bottom, 90 + Layout.bottomGap);
});

testWidgets('bottom gap without a tab bar still clears the safe area', (tester) async {
  // Same setup with padding bottom 34 (home indicator only).
  // expect(padding.bottom, 34 + Layout.bottomGap);
});
```

Write the second test in full in the same shape as the first.

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/design_test.dart`
Expected: FAIL. `screenSizeFor` and `Layout` aren't defined.

- [ ] **Step 3: Add the tokens and `breakpoints.dart`, then use them**

- `selah_page.dart:108` becomes `Layout.bottomGap + MediaQuery.paddingOf(context).bottom`.
- `PageBody` uses the same expression.
- In `theme.dart`, the card radius `18` becomes `Radii.row`, and the input radius `14` becomes `Radii.control`.
- Leave `kRailBreakpoint` and the shell alone; the shell plan replaces them.

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/app/design/tokens.dart lib/src/app/design/breakpoints.dart lib/src/app/design/selah_page.dart lib/src/app/theme.dart test/design_test.dart
git commit -m "Add layout and elevation tokens, breakpoints, and tighten the gap above the tab bar"
```

---

### Task 4: Bring the components and screens onto the new tokens

**Files:**
- Modify as needed:
  - `app/lib/src/app/design/hero_card.dart`
  - `adaptive_tab_bar.dart` (`FrostedTabBar` capsule color and shadow)
  - `selah_row.dart`
  - `skeleton.dart`
  - `app/lib/src/features/today/today_page.dart` (week row)
  - `part_tick.dart`
  - `study_page.dart`
  - `events_page.dart`
- Leave `features/auth/google_button.dart` alone (Google's brand colors are required).

**Interfaces:**
- Consumes: the Task 1–3 tokens.
- Produces: no new API.

- [ ] **Step 1: Sweep for raw values**

Run: `grep -rnE "Color\(0x|fontSize: [0-9]|BorderRadius\.circular\([0-9]|EdgeInsets\.[a-z]+\([0-9]" lib --exclude=theme.dart --exclude=tokens.dart --exclude=google_button.dart`

Replace each hit with the matching token or text style. Where a value has no token and is used once for layout, such as a fixed icon size, leave it.

Also run: `grep -rn "colorScheme.secondary\|tones.accent" lib`

Confirm that every hit is a small mark: an eyebrow, a dot, a badge, today's ring or a progress tick. A large fill, button background or gradient must use green or surface instead.

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 3: Visual check, both themes**

Run the app in Chrome at 375 × 812 and 1280 × 800 in light and dark mode, then on the iOS Simulator (iPhone 17 Pro) in light and dark mode. Check these screens: Hoje, the church page (Estudos), the study page, the reader, Eventos, Perfil and Login.

Pass criteria:
- Cream and warm-gray backgrounds; cards a step lighter in dark mode.
- Green is the hero, buttons and the active tab.
- Terracotta appears only as small marks.
- Headings are in the serif.
- The gap above the tab bar is about 16 px.
- On iOS 26, the glass tab bar is unchanged and readable over the new backgrounds.

Then repeat Hoje and the reader once with large text (`MediaQuery` `textScaler: TextScaler.linear(2.0)`, or the simulator's largest accessibility size). Nothing may clip or overlap.

Save a phone screenshot of Hoje in each theme as `docs/design/hoje-light.png` and `docs/design/hoje-dark.png` (repo root) for the style guide.

- [ ] **Step 4: Commit**

```bash
git add lib ../docs/design
git commit -m "Move components and screens onto the new design tokens"
```

---

### Task 5: `DESIGN.md`

**Files:**
- Create: `DESIGN.md` (repo root)

**Interfaces:**
- Consumes: the final values from Tasks 1–3.

- [ ] **Step 1: Write `DESIGN.md`**

Use the Impeccable skill's `document` command (`~/.claude/skills/impeccable`), which generates `DESIGN.md` from the code, then edit the result so it covers these sections in plain words:
1. Feeling and principles (from the spec's Why and look sections).
2. Color roles in a table for light and dark mode, with the green and terracotta rule and the no-pure-white or no-pure-black rule.
3. The type scale table and when to use serif versus sans.
4. Spacing, radii, elevation and layout widths, by token name.
5. Responsive rules: the three screen sizes and the layout for each (from the spec's layout table). Mark the top navigation and desktop page layouts as "coming in the next plan".
6. Components: hero card, row, tab bar, buttons, inputs, skeletons, eyebrow. For each, say what it's for and the tokens it uses.
7. Do's and don'ts, from the spec's anti-goals.

Every value in it must match the code; spot-check five values against `theme.dart` and `tokens.dart`.

- [ ] **Step 2: Commit**

```bash
git add ../DESIGN.md
git commit -m "Write DESIGN.md"
```

---

### Task 6: Style guide for the owner's review (hard stop)

**Files:**
- Create: the style guide page in the session's scratchpad. It's published as an artifact, not committed.

- [ ] **Step 1: Choose how to build it**

Call the Artifact tool with `action: "quickstart"` and `intent: "other"`.
- If it offers a Design System type, create the style guide from that type with the values from `DESIGN.md`.
- Otherwise, load the `artifact-design` skill and write the page by hand.

- [ ] **Step 2: Build the content**

The style guide shows, in light and dark mode side by side:
- the palette with role names and hex values,
- the type scale set in Source Serif 4 (loaded from Google Fonts) and the system sans, with Portuguese sample text,
- spacing and radii,
- these components drawn with the real tokens: primary button, row, hero card, week row with today in terracotta, eyebrow, input and tab bar,
- the two Hoje screenshots from Task 4.

It also includes one short "what changed" note: the old palette next to the new one.

- [ ] **Step 3: Publish and stop**

Publish the artifact and send the owner the link. **Stop here.** Don't start the shell or screen work. Ask the owner to approve the look or say what to change.
- If they ask for changes, apply them to the tokens (Tasks 1–3 values), rerun `flutter test`, update `DESIGN.md`, and republish the style guide.
- The next plan (shell and top navigation, then member screen layouts) is written only after approval.
