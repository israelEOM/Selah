# Premium App Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Selah app a calm, premium feel through part colours and icons, week rings you can walk through, a finishing moment, an always-visible tick bar in the reader, an illustration library picked per study, and considered motion on every screen.

**Architecture:**
- **Progress:** stays on the device in `SharedPreferences`. Each tick gains a recorded date, so the week rings can show *when* things were done. Study days stay self-paced.
- **Illustrations:** bundled app assets described by one `manifest.json`. The Python worker reads the same manifest so Gemini can choose an image key per study and per day, which is stored in new `art_key` columns.
- **Motion and styling:** new focused widgets under `features/today/`, `features/study/` and `app/design/`, built on the existing `Motion`, `Pressable`, `SpringIn`, `Entrance` and `SelahHaptics`.

**Tech Stack:** Flutter (Riverpod 3, go_router), Supabase (Postgres migration), Python worker (pydantic, google-genai, pytest).

**Spec:** `docs/superpowers/specs/2026-11-11-premium-app-feel-design.md`

## Global Constraints

- **Reduce Motion:** honoured everywhere through `reduceMotion(context)`. With it on, everything is a plain fade or an instant change. Motion constants go in `Motion` (`app/lib/src/app/design/tokens.dart`).
- **Part colours (light mode):**

  | Part | Colour | Tint | Soft |
  |---|---|---|---|
  | reading | `#2F5D4A` | `#E6EEE8` | `#D3E2D8` |
  | reflection | `#B8732E` | `#F5EBDD` | `#EEDCC2` |
  | prayer | `#5E6A9C` | `#E8E9F2` | `#D7DAEA` |

  Dark values are the builder's choice, but must pass `test/contrast_test.dart`.
- **Part colour rule:** part colours mark the three parts of a day, and only those. Terracotta keeps its role. `DESIGN.md` and `theme.dart` must agree.
- **Anti-goals:** no streak counts, no confetti, no sounds, no badges, no guilt copy, and no celebration that blocks the user or needs dismissing.
- **Copy:** all new copy goes in `app_en.arb`, `app_es.arb` and `app_pt.arb`, then `flutter gen-l10n`. Admin screens stay Spanish-only. Fixed copy:
  - "That's today." / "Go in peace."
  - "Day complete." / "Nothing lost."
  - "Not too late. You can still finish this day."
  - "Tap to tick"
  - "Day complete · back to Today"
  - "Yesterday"
- **Progress format:** saved progress (`progress:<studyId>` and legacy `read:<studyId>`) must keep loading unchanged.
- **Dependencies:** no new animation packages. Rive and Lottie are out of scope.
- **Platform:** Android must keep building and passing tests, but nothing is tuned for it.
- **Website layout:** the desktop `siteLayout` gets no new layout work. Shared widgets may change, but it must keep passing its tests.
- **Tests:**
  - App: `cd app && flutter test`
  - Worker: `cd worker && pytest`
  - Run `cd app && flutter analyze` before each commit.

## Review Focus

1. **Older saved progress shows on the rings.** Legacy `read:` marks and `progress:` entries without part dates should show as filled on their `doneOn` date when they have one, and should never crash or count today. (Test in Task 2.)
2. **Days with fewer than three parts.** A day without a prayer finishes after two ticks, its ring still turns full, and the reader's tick bar shows only the parts the day has. (Tests in Tasks 4 and 6.)
3. **Past-day ticks land on the past date,** even when the app was left open over midnight. Selecting yesterday, then ticking, records yesterday. The selection falls back to today when Today refreshes on a new day. (Test in Task 5.)
4. **Unknown, empty or missing illustrations fall back.** This covers a key not in the manifest, a null key, and a key whose image file isn't bundled yet. Each shows a deterministic placeholder and never throws. (Test in Task 7.)
5. **At 200% text size, the reader's tick bar and the week rings must not overflow.** (Tests in Tasks 4 and 6.)

---

### Task 1: Part palette in the theme and the design doc

**Files:**
- Modify: `app/lib/src/app/theme.dart` (new `ThemeExtension` next to `SelahTones`, registered in both light and dark themes)
- Modify: `DESIGN.md` (colors front matter and the Colors section: add the part colours and the rule)
- Test: `app/test/theme_test.dart`, `app/test/contrast_test.dart`

**Interfaces:**
- Produces:
  - `class PartTone { const PartTone({required Color color, required Color tint, required Color soft}); }`
  - `class PartPalette extends ThemeExtension<PartPalette> { final PartTone reading, reflection, prayer; }`
  - `extension PartPaletteX on BuildContext { PartPalette get partPalette; }`

- [ ] **Step 1: Write failing tests**

```dart
// theme_test.dart
test('light part palette matches the spec', () {
  final p = selahLightTheme().extension<PartPalette>()!;
  expect(p.reading.color, const Color(0xFF2F5D4A));
  expect(p.reflection.color, const Color(0xFFB8732E));
  expect(p.prayer.color, const Color(0xFF5E6A9C));
  expect(p.reflection.tint, const Color(0xFFF5EBDD));
  expect(p.prayer.soft, const Color(0xFFD7DAEA));
});
test('dark theme has a part palette', () => expect(selahDarkTheme().extension<PartPalette>(), isNotNull));

// contrast_test.dart: for light and dark, each part's `color` against its `tint`
// reaches 3:1 (non-text UI), and the paper/onPrimary check colour on `color` reaches 4.5:1.
```

- [ ] **Step 2: Run** `cd app && flutter test test/theme_test.dart test/contrast_test.dart`. Expected: FAIL, because `PartPalette` isn't defined.
- [ ] **Step 3: Implement `PartTone` and `PartPalette`** in `theme.dart`, with `copyWith` and `lerp` (lerp each colour), and add the extension to both themes. Pick dark values that pass the contrast test.
- [ ] **Step 4: Update `DESIGN.md`.** Add `part-reading`, `part-reflection` and `part-prayer` (with tint and soft) to the colors front matter. Add a "Part colours" subsection under Colors with the rule from Global Constraints.
- [ ] **Step 5: Run** the same tests. Expected: PASS.
- [ ] **Step 6: Commit:** `git commit -m "Add part colours for reading, reflection and prayer"`

### Task 2: Record the date of every tick

**Files:**
- Modify: `app/lib/src/data/progress.dart`
- Modify: `app/lib/src/features/today/today_state.dart` (remove `weekCircles`)
- Test: `app/test/progress_test.dart`, `app/test/today_state_test.dart`

**Interfaces:**
- Produces:
  - `DayProgress({Set<DayPart> parts, String? doneOn, Map<DayPart, String> partsOn = const {}})`
  - `Future<StudyProgress> togglePart(String studyId, DevotionalDay day, DayPart part, DateTime now, {String? on})`. Here `on` is a `yyyy-MM-dd` date to record instead of `localDate(now)`. Unticking removes the part's date.
  - `class DateTicks { final Set<DayPart> parts; final bool complete; final ({String studyId, int day})? lastDay; }`
  - `Future<Map<String, DateTicks>> loadTicksByDate()` and `final ticksByDateProvider = FutureProvider.autoDispose<Map<String, DateTicks>>`
  - `Future<void> tickPart(WidgetRef ref, String studyId, DevotionalDay day, DayPart part, DateTime now, {String? on})`. It invalidates `studyProgressProvider(studyId)` and `ticksByDateProvider`.
  - Removed: `loadDoneDates`, `doneDatesProvider` and `weekCircles`. Update their callers in `today_page.dart` minimally: Task 5 replaces the week row, so for now render the existing row from `ticksByDateProvider` (`complete` per date).

- [ ] **Step 1: Write failing tests** in `progress_test.dart`. Replace the `loadDoneDates` tests with:

```dart
test('each tick records its own date', () async {
  final d = day(1);
  await togglePart('s1', d, DayPart.reading, DateTime(2026, 10, 27, 9));
  final p = await togglePart('s1', d, DayPart.reflection, DateTime(2026, 10, 28, 9));
  expect(p.days[1]!.partsOn, {DayPart.reading: '2026-10-27', DayPart.reflection: '2026-10-28'});
  final byDate = await loadTicksByDate();
  expect(byDate['2026-10-27']!.parts, {DayPart.reading});
  expect(byDate['2026-10-28']!.parts, {DayPart.reflection});
  expect(byDate['2026-10-28']!.complete, isFalse);
});

test('a tick made for a past date lands on that date and finishes the day there', () async {
  final d = day(1);
  for (final part in DayPart.values) {
    await togglePart('s1', d, part, DateTime(2026, 10, 28, 9), on: '2026-10-27');
  }
  final byDate = await loadTicksByDate();
  expect(byDate['2026-10-27']!.complete, isTrue);
  expect(byDate['2026-10-27']!.lastDay, (studyId: 's1', day: 1));
  expect(byDate.containsKey('2026-10-28'), isFalse);
  expect((await loadProgress('s1')).days[1]!.doneOn, '2026-10-27');
});

test('unticking removes the part from its date', () async {
  await togglePart('s1', day(1), DayPart.reading, now);
  await togglePart('s1', day(1), DayPart.reading, now);
  expect(await loadTicksByDate(), isEmpty);
});

test('progress saved before part dates still loads and lands on doneOn', () async {
  SharedPreferences.setMockInitialValues({
    'progress:s1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-20"},"2":{"parts":["reading"],"doneOn":null}}',
    'read:s2': ['1'],
  });
  final byDate = await loadTicksByDate();
  expect(byDate.keys, ['2026-10-20']);
  expect(byDate['2026-10-20']!.complete, isTrue);
  expect((await loadProgress('s1')).days[2]!.parts, {DayPart.reading});
});
```

- [ ] **Step 2: Run** `cd app && flutter test test/progress_test.dart`. Expected: FAIL, because `partsOn` and `loadTicksByDate` aren't defined.
- [ ] **Step 3: Implement it.**
  - `_encode`/`_decode` gain a `partsOn` map (part name → date). A missing map decodes as `{}`.
  - `togglePart` sets or removes `partsOn[part]`. When the day becomes done, `doneOn` is the `on` date, or `localDate(now)` if there is none.
  - `loadTicksByDate` walks every `progress:` key. Each dated part adds to its date's `parts`. A done day sets `complete` on its `doneOn` date, and adds its undated parts there. `lastDay` is the study and day of the latest tick on that date, in load order.
- [ ] **Step 4: Remove `weekCircles`** and its tests in `today_state_test.dart`. Point `today_page.dart`'s `_WeekRow` at `ticksByDateProvider`.
- [ ] **Step 5: Run** `cd app && flutter test`. Expected: PASS.
- [ ] **Step 6: Commit:** `git commit -m "Record the date of every tick"`

### Task 3: Part icons, coloured ticks and part rows

**Files:**
- Create: `app/lib/src/features/today/part_style.dart`
- Create: `app/lib/src/features/today/part_row.dart`
- Modify: `app/lib/src/features/today/part_tick.dart`
- Modify: `app/lib/src/app/design/tokens.dart` (add `Motion.hop = Duration(milliseconds: 600)` and `Motion.ripple = Duration(milliseconds: 600)`)
- Test: `app/test/part_style_test.dart`

**Interfaces:**
- Consumes: `PartPalette` (Task 1).
- Produces:
  - `PartTone partTone(BuildContext context, DayPart part)`
  - `String partLabel(AppLocalizations l, DayPart part)`
  - `class PartIcon extends StatelessWidget { const PartIcon({required DayPart part, double size = 42}); }`. It's a rounded tile in the part's `soft` colour showing `assets/art/parts/<part.name>.png`. The `errorBuilder` falls back to `Icons.menu_book_rounded`, `Icons.lightbulb_rounded` or `Icons.volunteer_activism_rounded` in the part colour.
  - `PartTick({required DayPart part, required String label, required bool ticked, required VoidCallback onTap})`. Its colour comes from `part`.
    - On a false → true change: the check springs in (the existing `SpringIn`), and a ring ripples out from 1.0 to 1.9 scale while its opacity goes from 0.7 to 0 over `Motion.ripple`.
    - On tap: `SelahHaptics.tick()`.
    - With Reduce Motion: no ripple.
  - `PartRow({required DayPart part, required String title, String? subtitle, required bool ticked, required VoidCallback onTick, required VoidCallback onOpen})`. It's a `Pressable` row with the part's `tint` background and `Radii.row`, then a `PartIcon`, title and subtitle, then a `PartTick`. When `ticked` goes false → true, the icon hops: scale 1 → 1.25 → 1 with up to −8° of rotation, an `easeOutBack` curve over `Motion.hop`.
  - `class PartHop extends StatefulWidget { const PartHop({required bool active, required Widget child}); }`. It's exported for reuse in Task 6.

- [ ] **Step 1: Write failing tests**

```dart
testWidgets('PartRow paints its part tint and shows the tick', (tester) async { /* pump PartRow(part: DayPart.prayer, ...) in selahLightTheme;
  expect the row's DecoratedBox colour == Color(0xFFE8E9F2); expect find.bySemanticsLabel('Prayer') checked == false */ });
testWidgets('ticking ripples once without Reduce Motion', (tester) async { /* flip ticked; pump 100ms; expect find.byKey(const ValueKey('tick-ripple')) findsOneWidget; pumpAndSettle; findsNothing */ });
testWidgets('no ripple and no hop with Reduce Motion', (tester) async { /* MediaQuery(disableAnimations: true); flip ticked; pump 100ms; expect ripple findsNothing */ });
testWidgets('PartIcon falls back to an icon when the image is missing', (tester) async { /* pump PartIcon(part: DayPart.reading); pumpAndSettle; expect find.byIcon(Icons.menu_book_rounded) findsOneWidget */ });
```

- [ ] **Step 2: Run** `cd app && flutter test test/part_style_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the files above. Give the ripple the key `ValueKey('tick-ripple')` while it animates.
- [ ] **Step 4: Run** `cd app && flutter test`. Expected: PASS. Fix existing `PartTick` call sites by adding `part:`.
- [ ] **Step 5: Commit:** `git commit -m "Give each part of a day its colour, icon and a livelier tick"`

### Task 4: Week rings

**Files:**
- Create: `app/lib/src/features/today/week_rings.dart`
- Test: `app/test/week_rings_test.dart`

**Interfaces:**
- Consumes: `DateTicks` (Task 2) and `partTone` (Task 3).
- Produces:
  - `class PartRing extends StatelessWidget { const PartRing({required Set<DayPart> parts, required bool complete, String? label, double size = 30, bool today = false}); }`
    - It's a `CustomPainter` with three arcs (reading, reflection, prayer, in that order from 12 o'clock), a 3.2 stroke and a small gap between arcs.
    - Ticked arcs use the part colour, and the others a pale neutral (`tones.surface` darkened).
    - When `complete`, it shows a filled `tones.done` circle with a check, springing in through `SpringIn`.
    - Arcs tween their sweep over `Motion.medium` with `Curves.easeOutBack`.
    - `label` (the date number) is drawn inside, in `tones.today` when `today`.
  - `class WeekRings extends StatelessWidget { const WeekRings({required Map<String, DateTicks> ticks, required DateTime now, required String selected, required ValueChanged<String> onSelect}); }`
    - It shows Monday to Sunday of `now`'s week, each with the weekday initial above a `PartRing`.
    - The selected day sits on a `tones.surface` pill.
    - Future days have opacity 0.4 and aren't tappable.
    - Tapping a different day calls `SelahHaptics.selection()` and `onSelect(localDate(date))`.
    - The key of each day is `ValueKey('week-$i')`, as today.

- [ ] **Step 1: Write failing tests**

```dart
testWidgets('a date with reading ticked paints one coloured arc', ...);      // golden-free: expose PartRing.parts via find.byWidgetPredicate
testWidgets('a complete date shows a check', ...);                           // find.byIcon(Icons.check) inside week-1
testWidgets('future days cannot be selected', ...);                          // tap week-5 when now is Wednesday → onSelect not called
testWidgets('tapping yesterday selects it with a selection haptic', ...);    // mock SystemChannels.platform like design_test.dart; expect 'HapticFeedback.vibrate' with 'HapticFeedbackType.selectionClick'; onSelect('2026-10-26') for now = Tue 2026-10-27
testWidgets('week rings fit at 200% text on a 320pt-wide screen', ...);     // tester.takeException() isNull
```

- [ ] **Step 2: Run** `cd app && flutter test test/week_rings_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `PartRing` and `WeekRings`.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit:** `git commit -m "Add week rings that show each day's parts"`

### Task 5: Today: walk the week, tick a past day, moment A

**Files:**
- Create: `app/lib/src/features/today/today_selection.dart`
- Create: `app/lib/src/features/today/finish_moment.dart`
- Modify: `app/lib/src/features/today/today_page.dart` (replace `_WeekRow` and the `SelahRow` part rows; `tickWithFeedback`)
- Modify: `app/lib/src/features/today/today_state.dart` (add `dayOnDate`)
- Modify: `app/lib/src/app/design/hero_card.dart` (add `glow` and `art` slots)
- Modify: `app/lib/l10n/app_{en,es,pt}.arb` (new strings, see Global Constraints)
- Test: `app/test/today_page_test.dart`, `app/test/today_state_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces:
  - `final selectedDateProvider = NotifierProvider<SelectedDate, String?>`, where `null` means today. Watching `todayRefreshProvider` resets it to `null`.
  - `final justFinishedProvider = NotifierProvider<JustFinished, ({String studyId, int day})?>`. It's set when a tick finishes a day. Today reads it once and clears it after moment A starts.
  - `DevotionalDay? dayOnDate({required PublicStudy study, required Map<String, DateTicks> ticks, required String date})`. It returns the newest study's day matching `ticks[date]?.lastDay` when `studyId == study.id`, otherwise `null`. The caller then falls back to `todayFor`'s day.
  - `Future<bool> tickWithFeedback(WidgetRef ref, String progressId, DevotionalDay day, DayPart part, DateTime now, {String? on})`. It returns `true` when this tick finished the day, and also sets `justFinishedProvider` and plays `SelahHaptics.success()`.
  - `HeroCard({..., bool glow = false, bool animateGlow = false, Widget? art})`
    - `glow` paints a radial highlight (`rgba(250,247,242,.38)` from the bottom centre, fading out by 65%).
    - `animateGlow` fades it in over 1800ms. Add `Motion.glow = Duration(milliseconds: 1800)`.
    - `art` sits bottom-right at 100×100, clipped to a circle, at 0.85 opacity, offset −14/−18.
  - `class FinishLine extends StatelessWidget { const FinishLine({required bool past, required bool animate}); }`. It shows the serif line ("That's today." / "Go in peace.", or "Day complete." / "Nothing lost." when `past`). When `animate`, it rises 8px and fades in over 1000ms after a 700ms delay. Otherwise it's shown as-is.

- [ ] **Step 1: Write failing tests** in `today_page_test.dart`. `_now` is Tuesday 2026-10-27.

```dart
testWidgets('tapping Monday shows the day worked on Monday titled with its weekday', ...);
  // prefs: progress:study-1 with day 1 reading ticked on 2026-10-26; tap week-0 → expect 'Día 1 del camino' and the weekday title (DateFormat.EEEE es, capitalised)
testWidgets('tapping yesterday titles the page Yesterday in each language', ...); // es 'Ayer', pt 'Ontem', en 'Yesterday'
testWidgets('a past date with nothing done shows the day Today shows', ...);
testWidgets('ticks made on a past date fill that date and say Not too late until done', ...);
  // select week-0, tick reading → ticksByDate['2026-10-26'] has reading; text 'Not too late…' (es copy) shown; tick the rest → FinishLine past copy shown
testWidgets('finishing today plays moment A once', ...);
  // tick all three today → find FinishLine with animate: true, HeroCard glow true; re-pump TodayPage → FinishLine animate false, glow true
testWidgets('the selection returns to today when Today refreshes on a new day', ...);
  // select week-0, then advance the clock to Wednesday and invalidate todayRefreshProvider → selected ring is week-2
testWidgets('moment A is instant with Reduce Motion', ...);
testWidgets('the finished-study quote sets in word by word', ...);
  // AllDone state: the takeaway is split into words, each wrapped in Entrance-like fades staggered by Motion.staggerStep (40ms); with Reduce Motion it is one Text
```

- [ ] **Step 2: Run** `cd app && flutter test test/today_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `today_selection.dart`, `finish_moment.dart`, the `HeroCard` slots and `dayOnDate`.
- [ ] **Step 4: Rebuild `_Today`.**
  - Header order: eyebrow, then title (Today / Yesterday / weekday), then `WeekRings`, then the hero card (`art: SelahArt(...)` arrives in Task 7; leave the slot null for now), then one `PartRow` per `partsFor(day)`, then the "Not too late" line on an unfinished past date, then `FinishLine` when that date's day is done, then the Sermon summary button.
  - The content below the rings switches with an `AnimatedSwitcher`. It slides ±24px plus a fade over 250ms in the direction of travel. With Reduce Motion it's only a fade.
  - Ticks pass `on: selected` when a past date is selected.
- [ ] **Step 5: Run** `cd app && flutter test`. Expected: PASS.
- [ ] **Step 6: Commit:** `git commit -m "Walk the week on Today, tick a past day, and finish a day with a quiet moment"`

### Task 6: Reader: the always-visible tick bar

**Files:**
- Create: `app/lib/src/features/study/tick_dock.dart`
- Modify: `app/lib/src/features/study/reader_page.dart` (remove the inline ticks, add the dock and section keys)
- Modify: `app/lib/src/features/study/study_widgets.dart` (`ReadingSection` gains `DayPart? part` for a 3px left rule and eyebrow in the part colour; remove its `tick` slot)
- Test: `app/test/study_test.dart`

**Interfaces:**
- Consumes: `PartIcon`, `PartHop`, `partTone`, `partLabel` (Task 3); `tickWithFeedback` and `justFinishedProvider` (Task 5).
- Produces:
  - `class TickDock extends StatelessWidget { const TickDock({required List<DayPart> parts, required Set<DayPart> ticked, required DayPart current, required ValueChanged<DayPart> onTick, required VoidCallback onComplete}); }`
    - It's a floating pill 64 high, inset 12 from the sides and 14 from the safe bottom, translucent paper at 0.72 with a 16 blur (`BackdropFilter`), `Elevation.raised` and `Radii.chip`.
    - Each part is a chip: `PartIcon(size: 36)` plus a check badge on its corner when ticked (springing in), with the icon hopping when ticked.
    - The `current` chip has flex 2.8 and its tint, and shows its name with "Tap to tick" underneath. The others have flex 1 and show only their icon.
    - Flex animates over `Motion.medium` on a spring-like curve (`Curves.easeOutBack`).
    - When every part in `parts` is ticked, the bar is replaced, by sliding up from below over 600ms, with a green pill showing "Day complete · back to Today ›". Tapping it calls `onComplete`.
    - Semantics: each chip is a checkable button labelled with the part name.
  - In the reader:
    - Every section holder gets a `GlobalKey`. A `NotificationListener<ScrollNotification>` sets `current` to the last part whose section top is above 45% of the viewport.
    - The dock sits in a `Stack` above the `SelahPage` content, on phones only (`!siteLayout(context)`). The site layout keeps today's inline ticks: pass `ReadingSection.trailing` there, or keep a small `PartTick` row. Don't add new layout work.
    - The page bottom padding grows by the dock height.
    - `onComplete`: if the reader was opened from Today, `context.go('/today')`. Otherwise pop. Moment A plays there through `justFinishedProvider`.

- [ ] **Step 1: Write failing tests** in `study_test.dart`.

```dart
testWidgets('the tick bar stays on screen while scrolling to the prayer', ...);
  // phone size 390x844; drag the list up 2000px; expect find.byType(TickDock) hitTestable; find.text('Tap to tick') findsOneWidget
testWidgets('the current part follows the section in view', ...);
  // at top: the reading chip shows its name; after scrolling to prayer: the prayer chip shows 'Oración'
testWidgets('ticking from the bar marks the part on the study page', ...);   // replaces the old inline-tick test
testWidgets('a day without prayer shows only two chips and completes after two ticks', ...);
testWidgets('completing the day shows the back to Today pill and does not navigate on its own', ...);
testWidgets('the tick bar fits at 200% text', ...);                          // tester.takeException() isNull
testWidgets('the desktop reader keeps inline ticks and no dock', ...);
```

- [ ] **Step 2: Run** `cd app && flutter test test/study_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `TickDock` and the reader changes. In the reader header, replace the dots accessory with a `PartRing` for the day (from Task 4) beside "Day N of M".
- [ ] **Step 4: Run** `cd app && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit:** `git commit -m "Keep the three ticks within reach while reading"`

### Task 7: Illustration library in the app

**Files:**
- Create: `app/assets/art/manifest.json`
- Create: `app/assets/art/README.md` (the brief for producing the images)
- Create: `app/lib/src/app/design/art.dart`
- Create: `supabase/migrations/202611110001_art_keys.sql`
- Modify: `app/pubspec.yaml` (`assets: - assets/art/ - assets/art/parts/`)
- Modify: `app/lib/src/core/models.dart` (`artKey` on `PublicStudy`, `DevotionalDay` and `StudyCard`)
- Modify: `app/lib/src/data/repository.dart` (select `art_key` in the `publishedStudies`, `studyBySlug` and `newestStudy` study columns; `devotional_days(*)` already includes it)
- Modify: `app/lib/src/features/study/translation_banner.dart` (`studyToShow` keeps the original's study and day `artKey` by day number)
- Test: `app/test/art_test.dart`, `app/test/translation_models_test.dart`

**Interfaces:**
- Produces:
  - `manifest.json`: `{"style": "<one-paragraph style prompt>", "images": [{"key": "vine-grapes", "tags": ["vine","abide","fruit","john 15"], "pickable": true, "alt": {"en": "...", "es": "...", "pt": "..."}}]}`
    - About 36 pickable scenes:
      - Landscapes: `hillside-dawn`, `quiet-lake`, `desert-path`, `wheat-field`, `olive-grove`, `mountain-mist`, `river-bend`, `night-stars`, `garden-gate`, `seashore`, `forest-light`, `snowy-field`.
      - Bible imagery: `vine-grapes`, `bread-cup`, `oil-lamp`, `sheep-field`, `fishing-boat`, `open-door`, `well-water`, `fig-tree`, `mustard-seed`, `lost-coin`, `shepherd-staff`, `cross-hill`, `empty-tomb`, `dove`, `ark-rainbow`, `tent-desert`, `city-wall`, `harvest-baskets`, `salt-light`, `stone-jar`, `loaves-fish`, `pruning-shears`, `scroll-table`, `table-feast`.
    - Plus fixed, non-pickable scenes: `scene-welcome`, `scene-signin`, `scene-invite`, `scene-churches`, `scene-empty-studies`, `scene-empty-events`.
    - Each image lives at `assets/art/<key>.webp`. The part icons are `assets/art/parts/{reading,reflection,prayer}.png`.
    - The style paragraph: soft painterly illustration, warm paper tones harmonious with `#FAF7F2` and `#2F5D4A`, no text, no faces of Jesus.
  - `class ArtEntry { final String key; final List<String> tags; final bool pickable; final Map<String, String> alt; }`
  - `final artLibraryProvider = FutureProvider<List<ArtEntry>>`, loaded from `rootBundle`.
  - `String resolveArtKey(String? key, String seed, List<ArtEntry> library)`. It returns `key` if it's a pickable entry. Otherwise it returns a pickable entry chosen by a stable FNV-1a hash of `seed` (not `String.hashCode`).
  - `class SelahArt extends ConsumerWidget { const SelahArt({String? artKey, required String seed, ArtShape shape = ArtShape.rounded, double? width, double? height, Object? heroTag}); }`
    - `ArtShape` is `rounded` (`Radii.card`) or `circle`.
    - `Image.asset` with `errorBuilder` and loading fallback to `ArtPlaceholder(seed)`: a deterministic two-stop gradient from a small paper/sage/sand set, plus a soft sun circle.
    - The semantics label is the entry's alt text in the app language.
    - It's wrapped in a `Hero` when `heroTag` is given and Reduce Motion is off.
  - `Object studyArtTag(String studyId)` and `Object churchArtTag(String churchId)`
  - Migration: `alter table public.studies add column art_key text; alter table public.devotional_days add column art_key text;` Existing RLS already covers the columns.

- [ ] **Step 1: Write failing tests** in `art_test.dart`.

```dart
test('a known pickable key resolves to itself', () => expect(resolveArtKey('vine-grapes', 's', lib), 'vine-grapes'));
test('an unknown or null key resolves to the same pickable key for the same seed', () {
  expect(resolveArtKey('nope', 'study-1', lib), resolveArtKey(null, 'study-1', lib));
  expect(lib.where((e) => e.pickable).map((e) => e.key), contains(resolveArtKey(null, 'study-1', lib)));
});
test('a fixed scene is never picked for a study', () => expect(resolveArtKey('scene-welcome', 'x', lib), isNot('scene-welcome')));
test('the bundled manifest parses and every entry has alt text in en, es and pt', ...);
testWidgets('SelahArt shows a placeholder when the image file is missing', ...); // no exception; find.byType(ArtPlaceholder)
test('models read art_key', ...);   // PublicStudy.fromJson with art_key and a day art_key
```

  In `translation_models_test.dart`: a translated study keeps the original's study and day `artKey`.
- [ ] **Step 2: Run** `cd app && flutter test test/art_test.dart test/translation_models_test.dart`. Expected: FAIL.
- [ ] **Step 3: Write `manifest.json`** with the keys, tags and alt text listed above, and write `README.md`: the style paragraph, the file naming, sizes (1200×900 WebP for scenes, 256×256 PNG with transparency for part icons) and the per-image prompts.
- [ ] **Step 4: Implement `art.dart`,** the model fields, the repository selects, `studyToShow`, `pubspec.yaml` and the migration.
- [ ] **Step 5: Wire the art into the daily loop.**
  - Today's `HeroCard(art: SelahArt(artKey: day.artKey, seed: '${study.id}-${day.number}', shape: ArtShape.circle))`.
  - The reader gets a 120-tall `SelahArt` for the day under its header.
  - Test: "Today's hero card shows the day's art" in `today_page_test.dart`.
- [ ] **Step 6: Run** `cd app && flutter test`. Expected: PASS. Then apply the migration locally (`supabase db reset` or `supabase migration up`, per `README.md`) and confirm it applies cleanly.
- [ ] **Step 7: Commit:** `git commit -m "Add the illustration library and art keys for studies and days"`

### Task 8: The worker picks illustrations

**Files:**
- Create: `worker/selah_worker/art.py`
- Modify: `worker/selah_worker/schemas.py` (`SummaryOut.art_key: Optional[str]`, `DayOut.art_key: Optional[str]`, each with a Field description naming the menu)
- Modify: `worker/selah_worker/ai.py` (`summarize` and `devotional` append `art.menu()` to the instruction)
- Modify: `worker/selah_worker/pipeline.py` (`summary` stores `studies.art_key`, `devotional` rows store `art_key`, both through `art.valid_key`)
- Test: `worker/tests/test_art.py`

**Interfaces:**
- Consumes: `app/assets/art/manifest.json` (Task 7), at `Path(__file__).resolve().parents[2] / "app/assets/art/manifest.json"`.
- Produces:
  - `def pickable() -> list[dict]`
  - `def menu() -> str`. It returns lines like `vine-grapes: vine, abide, fruit, john 15`, introduced by "Choose art_key from this list only; pick the image whose tags best fit the theme."
  - `def valid_key(key: str | None) -> str | None`. It returns `key` if it's a pickable key, otherwise `None`.

- [ ] **Step 1: Write failing tests**

```python
def test_menu_lists_only_pickable_keys():
    assert "vine-grapes:" in art.menu()
    assert "scene-welcome" not in art.menu()

def test_valid_key_rejects_unknown_and_fixed_scenes():
    assert art.valid_key("vine-grapes") == "vine-grapes"
    assert art.valid_key("scene-welcome") is None
    assert art.valid_key("made-up") is None
    assert art.valid_key(None) is None

def test_schemas_accept_art_key():
    assert DayOut.model_validate({**DAY, "art_key": "dove"}).art_key == "dove"
    assert DayOut.model_validate(DAY).art_key is None
```

- [ ] **Step 2: Run** `cd worker && pytest tests/test_art.py -v`. Expected: FAIL, because there's no module named `selah_worker.art`.
- [ ] **Step 3: Implement** `art.py`, the schema fields, the prompt menu and the pipeline storage.
- [ ] **Step 4: Run** `cd worker && pytest`. Expected: PASS.
- [ ] **Step 5: Commit:** `git commit -m "Let the worker pick an illustration for each study and day"`

### Task 9: Admin: swap a study's or a day's illustration

**Files:**
- Create: `app/lib/src/features/admin/art_picker.dart`
- Modify: `app/lib/src/features/admin/sermon_page.dart` (`_Study`: art above the study, a "Cambiar imagen" button; each day row gets a small art thumbnail that opens the same picker)
- Modify: `app/lib/src/data/repository.dart`
- Test: `app/test/art_picker_test.dart`

**Interfaces:**
- Consumes: `artLibraryProvider` and `SelahArt` (Task 7).
- Produces:
  - `Future<void> SelahRepository.setStudyArt(String studyId, String? key)`
  - `Future<void> SelahRepository.setDayArt(String studyId, int dayNumber, String? key)`
  - `Future<String?> showArtPicker(BuildContext context, {String? current})`. It's a modal bottom sheet with a 3-column grid of pickable `SelahArt` tiles, the current one ringed in green. It returns the chosen key, or `null` if dismissed.
  - Copy: add ARB keys `changeImage` ("Cambiar imagen") and `pickImage` ("Elige una imagen") with the Spanish text in all three ARB files, as the other admin keys do.

- [ ] **Step 1: Write failing tests.** Override `repositoryProvider` with a fake, as in `test/admin_home_test.dart`. Open a sermon with a study, tap "Cambiar imagen", tap the `dove` tile, then expect `fake.studyArt == ('study-1', 'dove')` and the study art to show `dove`. Do the same for a day thumbnail with `setDayArt`.
- [ ] **Step 2: Run** `cd app && flutter test test/art_picker_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the picker, the repository methods (`update({'art_key': key})` filtered by id, or by study_id and day_number) and the sermon page wiring.
- [ ] **Step 4: Run** `cd app && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit:** `git commit -m "Let admins change a study's illustration"`

### Task 10: Getting in: welcome, sign in, choosing a church, invitation, empty states

**Files:**
- Modify: `app/lib/src/features/welcome/welcome_page.dart`
- Modify: `app/lib/src/features/auth/login_page.dart`
- Modify: `app/lib/src/features/home/church_picker_page.dart`
- Modify: `app/lib/src/features/church/join_page.dart`
- Modify: `app/lib/src/features/church/church_page.dart` (the empty state)
- Modify: `app/lib/src/features/events/events_page.dart` (the empty state)
- Modify: `app/lib/src/features/today/today_page.dart` (the no-studies state)
- Test: the existing page tests (`welcome_page_test.dart`, `login_page_test.dart`, `church_picker_test.dart`, `join_page_test.dart`) plus the new cases below

**Interfaces:**
- Consumes: `SelahArt` and `churchArtTag` (Task 7), `PartIcon` (Task 3) and `Entrance`.
- Behaviour, per spec section 9:
  - **Welcome:** `SelahArt(artKey: 'scene-welcome', height: 250)` fades and rises 12px over 600ms. Then the title, then two choice rows (`Pressable` rows with a `PartIcon` tile: reading for member, reflection for leader) staggered through `Entrance`. Tapping a choice gives a selection haptic.
  - **Sign in:** `scene-signin` art at height 200, with a slow parallax drift of ±6px over a 20s repeating loop, off with Reduce Motion. A failed sign-in shakes the field (3 oscillations, 8px, 400ms) and calls `HapticFeedback.heavyImpact`. Add `SelahHaptics.warning()` for it.
  - **Choose your church:** each row shows `SelahArt(seed: church.id, shape: circle, width: 42, heroTag: churchArtTag(church.id))`. The rows stagger in through `Entrance`. Follow springs into a "✓ Following" chip.
  - **Invitation:** `scene-invite`, round at 120.
  - **Empty states:** each gets its scene above the existing copy.
  - Fixed scenes are never picked for studies (Task 7), so these pages pass the fixed key directly. Add `bool fixed = false` to `SelahArt`; when it's true, `SelahArt` skips `resolveArtKey` and uses the key as given.

- [ ] **Step 1: Write failing tests:** "welcome shows its scene and both choices", "a wrong password shakes and warns" (expect a `HapticFeedbackType.heavyImpact` platform call), "church rows carry the church art hero tag", "the empty studies page shows its scene", "the welcome scene does not move with Reduce Motion".
- [ ] **Step 2: Run** those test files. Expected: FAIL.
- [ ] **Step 3: Implement** the page changes.
- [ ] **Step 4: Run** `cd app && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit:** `git commit -m "Welcome people in with illustration and gentle motion"`

### Task 11: Studies, study page, events and profile

**Files:**
- Modify: `app/lib/src/features/church/church_page.dart` (Studies tab)
- Modify: `app/lib/src/features/study/study_page.dart`
- Modify: `app/lib/src/features/events/events_page.dart`
- Modify: `app/lib/src/features/profile/profile_page.dart`
- Modify: `app/lib/src/app/design/adaptive_controls.dart` (`AdaptiveSegmented` calls `SelahHaptics.selection()` on change)
- Test: `church_page_test.dart`, `study_test.dart`, `events_page_test.dart`, `profile_page_test.dart`

**Interfaces:**
- Consumes: `SelahArt`, `studyArtTag` and `churchArtTag` (Task 7), `PartRing` (Task 4) and `ticksByDateProvider`/`studyProgressProvider` (Task 2).
- Behaviour:
  - **Studies:**
    - The newest study is a featured card: art at height 130 on top (`heroTag: studyArtTag(id)`), then "Devotional of the week", the title, "{n}-day devotional · Day x of n", a progress line that fills from 0 over `Motion.long` on first build, and Continue.
    - Recent studies are rows with 52×52 rounded art (with the hero tag), staggered through `Entrance`.
  - **Study page:**
    - The header art (`heroTag: studyArtTag(id)`) is 150 tall and collapses into the title bar on scroll. Use a `SliverAppBar` with `flexibleSpace`, or the existing `SelahPage` with a new `header` slot. On iOS, keep the large-title behaviour that `design_test.dart` pins.
    - Each devotional path row shows a `PartRing` of that day's ticked parts (`studyProgressProvider`) before "Day n · title".
  - **Events:**
    - Groups (Today / Tomorrow / weekday / Later) get sticky headings. Use `SliverMainAxisGroup` with `SliverPersistentHeader(pinned: true)`, or keep the existing list with `StickyHeader`-like pinned slivers, without a new package.
    - Each row has a 44×48 date tile with the month in terracotta and the day number in serif. The number counts in once (0 → n over `Motion.long`) on first view.
    - Tapping a row opens details in `showModalBottomSheet` instead of leaving the page.
  - **Profile:**
    - An avatar circle with the initial on `SelahArt(seed: userId, shape: circle)`.
    - The church row with round church art.
    - Language and theme stay `AdaptiveSegmented`, which now has the haptic.
    - Changing theme crossfades through `AnimatedTheme` over `Motion.medium`. Check that `MaterialApp`'s `themeAnimationDuration` is `Motion.medium`.

- [ ] **Step 1: Write failing tests:**
  - "the featured study shows its art and day progress"
  - "study rows share the art hero tag with the study page"
  - "the devotional path shows a ring per day"
  - "events stick their group heading while scrolling" (scroll so the heading would leave, then expect it still hit-testable at the top)
  - "tapping an event opens a sheet"
  - "switching language plays a selection haptic"
- [ ] **Step 2: Run** those test files. Expected: FAIL.
- [ ] **Step 3: Implement** the four screens.
- [ ] **Step 4: Run** `cd app && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit:** `git commit -m "Bring art, rings and motion to Studies, the study page, Events and Profile"`

### Task 12: Managing a church: motion on the admin screens

**Files:**
- Modify: `app/lib/src/features/admin/admin_home_page.dart`
- Modify: `app/lib/src/features/admin/sermon_page.dart` (`_Progress`)
- Test: `admin_home_test.dart`, plus a new case in the sermon page tests (`admin_translations_test.dart` already pumps `SermonPage`; follow it)

**Interfaces:**
- Behaviour:
  - **Admin home:**
    - The "{used} de {limit} este mes" bar fills from 0 over `Motion.long` in terracotta.
    - Sermon rows show 46×46 `SelahArt` for their study.
    - Status chips use green for Publicado and terracotta for En revisión.
    - Generando shows a slow shimmer: a 1.6s repeating gradient sweep, static with Reduce Motion.
  - **Sermon progress:**
    - Each step's dot fills green with a check when done (`SpringIn`).
    - The running step's dot is amber (`PartPalette.reflection.color`) and breathes slowly (opacity 0.6 ↔ 1 over 1.4s, repeating, static with Reduce Motion).
    - Pending dots are neutral.
    - Publishing calls `SelahHaptics.success()`.

- [ ] **Step 1: Write failing tests:** "the generating chip shimmers and stops with Reduce Motion" (find the shimmer by `ValueKey('shimmer')`) and "publishing plays the success haptic".
- [ ] **Step 2: Run** those tests. Expected: FAIL.
- [ ] **Step 3: Implement** both screens.
- [ ] **Step 4: Run** `cd app && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit:** `git commit -m "Give the admin screens progress you can watch"`

### Task 13: App-wide motion, the tab bar and docs

**Files:**
- Modify: `app/lib/src/app/design/selah_page.dart` (children arrive)
- Create: `app/lib/src/app/design/content_switcher.dart`
- Modify: the pages with a loading → data switch: `today_page.dart`, `church_page.dart`, `study_page.dart`, `reader_page.dart`, `events_page.dart`
- Modify: `app/lib/src/app/design/adaptive_tab_bar.dart` (colours only)
- Modify: `app/lib/src/features/church/join_page.dart` (success haptic on join)
- Modify: `DESIGN.md` (the Motion section: arrival, the finishing moment, ticks, rings, the dock, the haptic vocabulary)
- Test: `design_test.dart`, `adaptive_tab_bar_test.dart`

**Interfaces:**
- Produces:
  - `SelahPage({..., bool arrive = true})`. When `arrive` is true and `lazy` is false, each child is wrapped in `Entrance(index: i)` once per page build lifetime (the existing `Entrance` already runs once). Pages that build their own `Entrance`s (Today's part rows) pass `arrive: false`, or the children opt out with a wrapper `NoArrive`.
  - `class ContentSwitcher extends StatelessWidget { const ContentSwitcher({required Widget child}); }`. It's an `AnimatedSwitcher` with a fade over `Motion.medium`, or `Duration.zero` with Reduce Motion, keyed by the child's runtime type plus key. Use it so skeletons crossfade into content.
  - Tab bar: the active tab tint is `tones.done` with a soft 10% pill behind it where the platform allows. Keep the native Liquid Glass bar from `cupertino_native_better` on iOS, and change only the colours it exposes.
  - Haptic vocabulary audit:
    - `selection`: week day switch (Task 4) and segmented controls (Task 11)
    - `tick`: part ticks (Task 3)
    - `success`: finishing a day (Task 5), joining a church (here), publishing (Task 12)

- [ ] **Step 1: Write failing tests:**
  - "SelahPage children fade in staggered" (the first child's opacity is < 1 at 50ms and 1 after settle)
  - "SelahPage children are shown at once with Reduce Motion"
  - "ContentSwitcher crossfades a skeleton into content"
  - "joining a church plays the success haptic"
  - "the active tab uses the done tone"
- [ ] **Step 2: Run** `cd app && flutter test test/design_test.dart test/adaptive_tab_bar_test.dart test/join_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the `SelahPage` arrival, `ContentSwitcher` and its use on the five pages, the tab bar colours and the join haptic.
- [ ] **Step 4: Update the Motion section in `DESIGN.md`** so it matches the code: durations, Reduce Motion behaviour and the haptic vocabulary.
- [ ] **Step 5: Run** `cd app && flutter test && flutter analyze`. Expected: all pass, no issues.
- [ ] **Step 6: Check on the iOS Simulator.** Run the app on the simulator and go through Today, a past day, finishing a day, the reader dock, Studies, the study page, Events, Profile, Welcome and Sign in, in both light and dark. Then repeat with Reduce Motion on (Settings → Accessibility → Motion). Note anything that feels off and fix it before committing.
- [ ] **Step 7: Commit:** `git commit -m "Make every screen arrive gently and document the motion system"`
