# Premium Look and Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Selah's Flutter app feel premium and native on each platform: real Liquid Glass tab bar on iOS, native back navigation, fluid motion, haptics and skeleton loading. Android and web stay native to themselves.

**Architecture:** This plan adds a small design layer in `app/lib/src/app/design/` (tokens, platform detection, adaptive widgets, motion components) that screens build on. No screen imports platform packages directly. The router moves to a `StatefulShellRoute` for the three tabs. The study page and reader sit above it on the root navigator, so they're pushed and popped and back returns to wherever they were opened from. Native glass comes from `cupertino_native_better`, used only by `AdaptiveTabBar`.

**Tech Stack:** Flutter 3.47.4 / Dart 3.13, go_router 18, flutter_riverpod 3, cupertino_native_better 1.8.1 (iOS only, via Swift Package Manager).

**Spec:** `docs/superpowers/specs/2026-10-28-premium-ui-design.md`. Read it first; this plan argues from it.

**Reference:** spike commit `5fabbdb` on local branch `spike/glass-tabbar` shows `CNTabBar` wired into `SelahShell`, `PageBody` scrolling under the bar, and `lib/spike_main.dart` (runs the app on sample data with no backend). Copy ideas from it, but never merge it.

## Global Constraints

- Brand colors are unchanged: navy `#0E2341`, forest green `#2E4A38`, orange `#F15A24`, plus the existing dark palette in `theme.dart`. The light background may be tinted slightly warm, but must stay close to white.
- Native glass is used only for floating chrome (the tab bar in this plan). It is never used inside a scrolling list.
- Only files under `app/lib/src/app/design/` may import `cupertino_native_better`.
- iOS 26+ gets real glass, iOS 15–25 gets the package's Cupertino fallback, and Android and web get Selah's own Material widgets.
- No new features. Copy, data and routes (URLs) stay the same. Only navigation behavior changes, as the spec's Navigation section describes.
- Admin screens stay Spanish (`inSpanish`). Member screens stay localized (es/en/pt). Any new user-visible string goes in all three `.arb` files.
- Reduce Motion (`MediaQuery.disableAnimationsOf`) turns springs, staggers and the hero flight into plain fades or no motion.
- The existing 222 tests keep passing. Only change a test when a finder depends on a widget type or destination that this plan deliberately changes, and keep what it asserts.
- After every task, `cd app && flutter analyze` is clean and `flutter test` is green.
- Work on a branch `premium-ui` cut from `main`, with one commit per task.

## Review Focus

1. **Deep links and web reloads:** if the reader or study page is opened with nothing beneath it, back must still lead somewhere sensible (study page, then church page) and must never close the app or do nothing. *(Task 3)*
2. **Large text (text scale 2.0):** Hoy's rows, hero card and tab bar must not overflow or clip. *(Task 6)*
3. **The last item on a page must scroll clear of the floating tab bar**, so the final row or button is never stuck behind the glass. *(Task 4)*
4. **Fast double-taps on a row must open one reader, not two stacked readers**, so that one back returns home. *(Task 2, guarded in `Pressable`)*
5. **Changing language inside the reader must keep you in the reader with the same back stack.** *(Task 3)*

---

## File structure

**Create (design layer, `app/lib/src/app/design/`):**
- `platform.dart`: `UiPlatform`, `uiPlatformOf`, `nativeGlassAvailable`, `reduceMotion`
- `tokens.dart`: `Space`, `Radii`, `Motion`
- `haptics.dart`: `SelahHaptics`
- `transitions.dart`: `selahPageTransitions()`
- `navigation.dart`: `popOr`
- `pressable.dart`: `Pressable`
- `selah_row.dart`: `SelahRow`
- `hero_card.dart`: `HeroCard`, `dayHeroTag`
- `skeleton.dart`: `Skeleton`, `SkeletonList`, `Entrance`
- `selah_page.dart`: `SelahPage`
- `adaptive_tab_bar.dart`: `SelahTab`, `AdaptiveTabBar`, `FrostedTabBar` (and the private native bar)
- `adaptive_controls.dart`: `AdaptiveSegmented<T>`

**Modify:**
- `app/lib/src/app/theme.dart`: page transitions, the `PageBody` bottom inset, and a re-export of the design layer
- `app/lib/src/app/app.dart`: router
- `app/lib/src/app/shell.dart`: the shell
- `app/lib/src/features/today/today_page.dart` and `part_tick.dart`
- `app/lib/src/features/study/reader_page.dart`, `study_page.dart`, `study_widgets.dart`
- `app/lib/src/features/church/church_page.dart`, `church_scope.dart`, `join_page.dart`, `create_church_page.dart`
- `app/lib/src/features/home/church_picker_page.dart`
- `app/lib/src/features/profile/profile_page.dart`
- `app/lib/src/features/auth/login_page.dart`, `welcome/welcome_page.dart`
- `app/lib/src/features/admin/admin_gate.dart`
- `app/pubspec.yaml`, and the iOS SwiftPM `Package.resolved` files the dependency adds

**Tests (new):** `app/test/design_test.dart`, `app/test/navigation_test.dart`, `app/test/adaptive_tab_bar_test.dart`

---

### Task 1: Design tokens, platform helpers, haptics and page transitions

**Files:**
- Create: `app/lib/src/app/design/platform.dart`, `tokens.dart`, `haptics.dart`, `transitions.dart`
- Modify: `app/lib/src/app/theme.dart` (`_build`: add `pageTransitionsTheme`; add `export 'design/…'` lines so screens keep importing only `theme.dart`)
- Test: `app/test/design_test.dart`

**Interfaces:**
- Produces:
  - `enum UiPlatform { ios, android, web }`
  - `UiPlatform uiPlatformOf(BuildContext context)`: `kIsWeb` gives `web`. Otherwise `Theme.of(context).platform` iOS or macOS gives `ios`, and anything else gives `android`. This respects `debugDefaultTargetPlatformOverride`.
  - `const bool kUseNativeGlass = true;`: the VoiceOver kill switch from the spec.
  - `bool get nativeGlassAvailable => kUseNativeGlass && !kIsWeb && Platform.isIOS;`: the real host OS, never the override, so tests never build platform views.
  - `bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);`
  - `abstract final class Space { static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0; }`
  - `abstract final class Radii { static const row = 20.0, card = 28.0; }`
  - `abstract final class Motion { short = Duration(milliseconds: 150); medium = 280ms; long = 420ms; staggerStep = 40ms; tapDebounce = 400ms; pressScale = 0.97; press = SpringDescription(mass: 1, stiffness: 500, damping: 28); }`
  - `abstract final class SelahHaptics { static Future<void> selection(); static Future<void> tick(); static Future<void> success(); }`: these map to `HapticFeedback.selectionClick`, `lightImpact` and `mediumImpact`, and do nothing on web.
  - `PageTransitionsTheme selahPageTransitions()`:
    - On web: `FadeForwardsPageTransitionsBuilder` for every `TargetPlatform`.
    - Otherwise: iOS and macOS get `CupertinoPageTransitionsBuilder`, and Android gets `PredictiveBackPageTransitionsBuilder`.
    - Each builder is wrapped so that when `reduceMotion(context)` is true, it returns a plain `FadeTransition` on the primary animation.

- [ ] **Step 1: Write the failing tests** in `app/test/design_test.dart`:
  - `uiPlatformOf follows the target platform`: under `debugDefaultTargetPlatformOverride = TargetPlatform.iOS`, a pumped `Builder` reports `UiPlatform.ios`; under `android` it reports `UiPlatform.android`. Reset the override in `tearDown`.
  - `native glass is never used in tests`: `expect(nativeGlassAvailable, isFalse)`.
  - `iOS pages slide and Android pages use predictive back`:
    - `selahLightTheme().pageTransitionsTheme.builders[TargetPlatform.iOS]` wraps a `CupertinoPageTransitionsBuilder`.
    - The `TargetPlatform.android` entry wraps a `PredictiveBackPageTransitionsBuilder`.
    - Assert through a public `inner` getter on the wrapper.
  - `Reduce Motion turns page transitions into a fade`: build the iOS builder's `buildTransitions` inside `MediaQuery(data: MediaQueryData(disableAnimations: true))` and expect a `FadeTransition`, with no `CupertinoPageTransition` in the tree.
  - `tick, selection and success haptics call the platform`: mock `SystemChannels.platform`, call each method, and expect `HapticFeedback.vibrate` calls with arguments `HapticFeedbackType.lightImpact`, `HapticFeedbackType.selectionClick` and `HapticFeedbackType.mediumImpact`.
- [ ] **Step 2: Run** `cd app && flutter test test/design_test.dart`. Expected: FAIL to compile, because `design/platform.dart` does not exist.
- [ ] **Step 3: Implement** the four files with the interfaces above. Wire `pageTransitionsTheme: selahPageTransitions()` into `_build` in `theme.dart`, and add exports for `design/platform.dart`, `tokens.dart`, `haptics.dart`.
- [ ] **Step 4: Run** `flutter test test/design_test.dart`, then `flutter test` and `flutter analyze`. Expected: all PASS.
- [ ] **Step 5: Commit** `git add app/lib/src/app app/test/design_test.dart && git commit -m "Add design tokens, platform helpers, haptics and adaptive page transitions"`

### Task 2: Motion components: Pressable, SelahRow, HeroCard, Skeleton, Entrance

**Files:**
- Create: `app/lib/src/app/design/pressable.dart`, `selah_row.dart`, `hero_card.dart`, `skeleton.dart`
- Modify: `app/lib/src/app/theme.dart` (exports)
- Test: `app/test/design_test.dart` (append)

**Interfaces:**
- Consumes: `Motion`, `Radii`, `Space`, `reduceMotion`, `SelahHaptics` (Task 1)
- Produces:
  - `Pressable({Key? key, required Widget child, required VoidCallback? onPressed, BorderRadius? borderRadius, bool haptic = false, String? semanticLabel})`:
    - Scales to `Motion.pressScale` on pointer down and springs back with `Motion.press`.
    - On Android it also shows an ink ripple clipped to `borderRadius`.
    - It ignores a second press within `Motion.tapDebounce` of the last one.
    - With reduce motion it doesn't scale.
    - It has `Semantics(button: true)`.
  - `SelahRow({Key? key, required String label, String? detail, required VoidCallback onOpen, Widget? trailing})`: a `Pressable` with surface color `context.tones.surface` and radius `Radii.row`. The trailing slot defaults to a chevron (`CupertinoIcons.chevron_forward` on iOS, `Icons.chevron_right` elsewhere). It replaces today's private `_Row`.
  - `HeroCard({Key? key, String? eyebrow, String? title, String? quote, String? badge, Widget? footer})`: today's `_HeroCard` look (gradient `heroStart` to `heroEnd`, serif quote, colors on the hero), with radius `Radii.card`. `title` renders above `quote` in `headlineSmall` in the on-hero color. The badge animates in (scale and fade, `Motion.medium`) when it changes from null to a value, and appears instantly with reduce motion.
  - `Object dayHeroTag(String studyId, int dayNumber) => 'day-hero-$studyId-$dayNumber';`
  - `Skeleton({Key? key, double? width, required double height, double radius = 12})`: a shimmering placeholder in `tones.surface`. With reduce motion it's static.
  - `SkeletonList({Key? key, int rows = 4, bool hero = false})`: an optional hero-shaped block followed by `rows` row-shaped blocks.
  - `Entrance({Key? key, required int index, required Widget child})`: fades and slides up 12px, with a delay of `index × Motion.staggerStep` and duration `Motion.medium`. It plays once per mount, and with reduce motion the child is shown immediately.

- [ ] **Step 1: Write the failing tests** (append to `design_test.dart`):
  - `Pressable shrinks while pressed and springs back`: `tester.startGesture` on it, `pump(100ms)`, and the `Transform` scale is less than 1. Release and `pumpAndSettle`, and the scale is exactly 1.
  - `Pressable does not shrink with Reduce Motion`: same as above inside `MediaQuery(disableAnimations: true)`, and the scale stays 1.
  - `Pressable ignores a double tap`: tap twice 100ms apart and expect `onPressed` called once. After `Motion.tapDebounce` passes, a third tap counts.
  - `SelahRow shows its label, detail and a chevron by default`.
  - `HeroCard shows its badge after it is set`: pump with `badge: null`, then `badge: 'Hecho por hoy'`, `pumpAndSettle`, and the text is found.
  - `Entrance shows its child immediately with Reduce Motion`: right after the first pump, the opacity is 1.
  - `SkeletonList with a hero draws rows + 1 blocks`: `find.byType(Skeleton)` finds `rows + 1` widgets.
- [ ] **Step 2: Run** `flutter test test/design_test.dart`. Expected: FAIL to compile.
- [ ] **Step 3: Implement** the four files and export them from `theme.dart`. Don't change any screen yet.
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Add Pressable, SelahRow, HeroCard, skeletons and entrance animation"`

### Task 3: Navigation with a real back stack

**Files:**
- Create: `app/lib/src/app/design/navigation.dart`
- Modify: `app/lib/src/app/app.dart` (`createRouter`), `app/lib/src/app/shell.dart`
- Modify (navigation calls only):
  - `features/today/today_page.dart` lines 104, 121, 188
  - `features/study/study_page.dart` lines 29, 105
  - `features/study/reader_page.dart` lines 36, 188, 194
  - `features/church/church_page.dart` line 113 (already `push`)
- Test: `app/test/navigation_test.dart` (new). Update `app/test/shell_test.dart` only where it constructs `SelahShell` directly.

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `final rootNavigatorKey = GlobalKey<NavigatorState>();` in `app.dart`.
  - `createRouter({String initialLocation = '/'})` keeps its signature. Its tree becomes:
    - `StatefulShellRoute.indexedStack` with three branches, in order:
      - `/` (TodayPage)
      - `/c/:church` (ChurchPage)
      - `/profile`
    - Top-level `GoRoute`s on the root navigator for:
      - `/c/:church/studies/:slug` (StudyPage)
      - `/c/:church/studies/:slug/day/:number` (ReaderPage)
    - All the other existing top-level routes, unchanged.
    - `observers: [CNTabBarRouteObserver()]` is added in Task 4, not here.
  - `SelahShell({Key? key, required StatefulNavigationShell navigationShell})`: replaces `location` and `child`. `tabIndexFor(String)` stays as it is, since it's still used to find which church Estudios last showed.
  - `void popOr(BuildContext context, String fallback)` in a new `app/lib/src/app/design/navigation.dart`, exported from `theme.dart`: `context.canPop() ? context.pop() : context.go(fallback)`. Every member back button uses it.
  - Navigation rules:
    - Opening the study page or the reader uses `context.push`.
    - The reader's previous and next day buttons use `context.pushReplacement`.
    - The study page's back uses `popOr(context, '/c/<church>')`.
    - The reader's back uses `popOr(context, '/c/<church>/studies/<slug>')`.
  - Tab taps:
    - Hoy and Perfil call `navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex)`.
    - Estudios uses the existing `_openStudies` logic (`/c/<current church>`, or push `/churches` when there's none) unless the Estudios branch is already showing the current church, in which case it calls `goBranch(1)`.
    - If `StatefulShellBranch` asserts that it needs an `initialLocation` for the `/c/:church` branch, give it `initialLocation: '/'`. Estudios is never entered through `goBranch` before `_openStudies` has run.
  - `ChurchScope` keeps wrapping the church, study and reader builders exactly as now.

- [ ] **Step 1: Write the failing tests** in `app/test/navigation_test.dart`. Reuse the `_FakeRepository` and the `_pump(tester, location)` pattern from `shell_test.dart`, and add overrides for `newestStudyProvider` and `studyProvider` that return the 5-day `seguir` study JSON used in `today_page_test.dart`.
  - `back from a reader opened on Hoy returns to Hoy`: start at `/`, tap the `Reflexión` row, and the path is `/c/vida-nueva/studies/seguir/day/1`. Tap the back button (tooltip `l.backToStudy`), and the path is `/` with `Gracia`/study title text visible.
  - `back from a reader opened on the study page returns to the study page`: start at `/c/vida-nueva/studies/seguir`, open day 2, then back, and the path is `/c/vida-nueva/studies/seguir`.
  - `next day replaces the reader so one back leaves it`: from `/`, open day 1, tap `l.nextDay`, and the path ends `/day/2`. Back once, and the path is `/`.
  - `a reader opened from a link goes back to its study page`: start at `/c/vida-nueva/studies/seguir/day/3`, back, and the path is `/c/vida-nueva/studies/seguir`.
  - `a study page opened from a link goes back to its church`: start at `/c/vida-nueva/studies/seguir`, back, and the path is `/c/vida-nueva`.
  - `the reader and study page cover the tab bar`: on the reader, `find.text('Hoy').hitTestable()` finds nothing.
  - `a tab keeps its scroll position when you come back`: on `/profile`, drag up 300px, tap Hoy, tap Perfil, and the first `Scrollable`'s `position.pixels` is unchanged.
  - `changing language in the reader keeps the reader and its back stack` (Review Focus 5): from `/`, open day 1, pick `English` in the `LanguageMenu`, and the path is still the day 1 reader. Back, and the path is `/`.
- [ ] **Step 2: Run** `flutter test test/navigation_test.dart`. Expected: FAIL. The back button lands on the study page, and the shell's constructor doesn't match.
- [ ] **Step 3: Implement** the router tree, the new `SelahShell`, `popOr`, and the navigation call changes listed above. The tab bar's look is unchanged in this task, so keep the current `_Tab` row, fed from `navigationShell.currentIndex`.
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: all PASS, including the existing `shell_test.dart`, `church_routes_test.dart`, `study_test.dart` and `today_page_test.dart`. If an existing test asserted the old "back always goes to the study page" destination, update that assertion to the new rule and say so in the commit message.
- [ ] **Step 5: Commit** `git commit -m "Give member pages a real back stack and keep each tab's place"`

### Task 4: Adaptive tab bar with native Liquid Glass on iOS

**Files:**
- Create: `app/lib/src/app/design/adaptive_tab_bar.dart`
- Modify:
  - `app/pubspec.yaml` (`cupertino_native_better: ^1.8.1`)
  - `app/lib/src/app/shell.dart` (use `AdaptiveTabBar`, `extendBody: true`, and a rail on wide screens)
  - `app/lib/src/app/app.dart` (`observers: [CNTabBarRouteObserver()]`, via a re-export from `adaptive_tab_bar.dart`)
  - `app/lib/src/app/theme.dart` (`PageBody`)
- Test: `app/test/adaptive_tab_bar_test.dart` (new)

**Interfaces:**
- Consumes:
  - `nativeGlassAvailable`, `uiPlatformOf`, `SelahHaptics.selection`, `Radii` (Task 1)
  - `SelahShell` and `navigationShell` (Task 3)
- Produces:
  - `class SelahTab { const SelahTab({required this.label, required this.icon, required this.selectedIcon, required this.symbol, required this.selectedSymbol}); final String label; final IconData icon, selectedIcon; final String symbol, selectedSymbol; }`. The SF Symbols are `sun.max`/`sun.max.fill`, `book`/`book.fill` and `person`/`person.fill`, as in the spike. The Material icons are the current outlined/filled pairs.
  - `AdaptiveTabBar({Key? key, required List<SelahTab> tabs, required int currentIndex, required ValueChanged<int> onTap})`:
    - When `nativeGlassAvailable`, it renders `CNTabBar` with tint `colorScheme.primary`, padded 24px horizontally inside `SafeArea(top: false)`.
    - Otherwise, when `uiPlatformOf == ios`, it renders `FrostedTabBar`.
    - Otherwise it renders a Material 3 `NavigationBar`.
    - Every tap calls `SelahHaptics.selection()` and then `onTap`.
  - `FrostedTabBar({...same params})`:
    - A Flutter-drawn floating pill (radius `Radii.card`), with a `BackdropFilter` blur of sigma 20 and a surface color at 70% opacity.
    - The selected tab sits on a lighter capsule that animates between tabs over `Motion.medium`.
    - It has `Semantics(selected:)` on each tab.
    - It's both the iOS 15–25 look in tests and the VoiceOver fallback (`kUseNativeGlass = false`).
  - `const double kRailBreakpoint = 840;`. When the platform isn't iOS and the width is at least `kRailBreakpoint`, `SelahShell` shows a `NavigationRail` on the left in place of the bottom bar. *(Plan decision: Android tablets get the rail as well as wide web.)*
  - `const double kFloatingBarClearance = 96;` is the scroll padding pages add so their last item clears a floating bar.
  - `PageBody` changes:
    - It uses `SafeArea(bottom: false)`.
    - Its `ListView` bottom padding becomes `40 + MediaQuery.paddingOf(context).bottom`.
    - The shell's `Scaffold(extendBody: true)` supplies the bar height in that inset on iOS, so content scrolls under the glass.

- [ ] **Step 1: Write the failing tests** in `app/test/adaptive_tab_bar_test.dart`:
  - `on iOS the tab bar is the frosted floating bar in tests`: with the target platform set to iOS, pump `AdaptiveTabBar` and expect `FrostedTabBar` and a `BackdropFilter`, and no `NavigationBar`.
  - `on Android the tab bar is a Material NavigationBar`.
  - `tapping a tab plays a selection haptic and reports the index`: mock the platform channel and expect `HapticFeedbackType.selectionClick`, with `onTap` receiving 2 when Perfil is tapped.
  - `the selected tab is marked selected for screen readers`: `tester.getSemantics(find.text('Hoy'))` has the `isSelected` flag.
  - `a wide Android window shows a navigation rail`: set the surface size to 1000×800 and pump the router at `/profile` (the `shell_test` pump), and expect `NavigationRail` and no `NavigationBar`.
  - `the last item on a page scrolls clear of the floating bar` (Review Focus 3): on iOS, pump the router at `/profile`, scroll to the end, and the bottom of the last button is at or above the top of `FrostedTabBar`.
- [ ] **Step 2: Run** `flutter test test/adaptive_tab_bar_test.dart`. Expected: FAIL to compile.
- [ ] **Step 3: Implement.**
  - Run `flutter pub add cupertino_native_better:^1.8.1`.
  - Build `adaptive_tab_bar.dart`.
  - Swap the shell's `_Tab` row for `AdaptiveTabBar`, or `NavigationRail` when wide.
  - Register the observer.
  - Make the `PageBody` change.
  - Delete `_Tab`.
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS. Then run `cd app && flutter run -d "iPhone 17 Pro" --dart-define-from-file=config/beta.json` and confirm the glass bar renders, the reader text refracts under it, and the bar is gone on the study page and the reader. Take a screenshot.
- [ ] **Step 5: Commit** `git add app/pubspec.yaml app/pubspec.lock app/ios app/lib app/test && git commit -m "Float a native Liquid Glass tab bar on iOS and adaptive bars elsewhere"`

### Task 5: SelahPage, the adaptive page scaffold

**Files:**
- Create: `app/lib/src/app/design/selah_page.dart`, `app/lib/src/app/design/adaptive_controls.dart`
- Modify: `app/lib/src/app/theme.dart` (exports)
- Test: `app/test/design_test.dart` (append)

**Interfaces:**
- Consumes:
  - `uiPlatformOf`, `Space` (Task 1)
  - `popOr` (Task 3)
  - The `PageBody` padding rule (Task 4)
- Produces:
  - `SelahPage({Key? key, String? title, String? backTo, String? backTooltip, List<Widget> actions = const [], required List<Widget> children, Future<void> Function()? onRefresh, double maxWidth = 760})`:
    - A `Scaffold` whose body is a `CustomScrollView`.
    - **iOS:** the header is `CupertinoSliverNavigationBar` with a large `title` that collapses into the translucent bar. The background is `scaffoldBackgroundColor` at 85% opacity with the built-in blur. Pull to refresh is `CupertinoSliverRefreshControl` when `onRefresh` is set.
    - **Elsewhere:** the header is `SliverAppBar.large` with the Material 3 scroll-under tint, and pull to refresh is `RefreshIndicator`.
    - When `backTo` is set, there's a leading back button: `CupertinoNavigationBarBackButton` on iOS and `BackButton` elsewhere, both calling `popOr(context, backTo)` with tooltip `backTooltip ?? l.back`.
    - The children are laid out in a centered column of `maxWidth`, with horizontal padding `Space.xl - 4` (20) and bottom padding `40 + MediaQuery.paddingOf(context).bottom`.
    - With `title == null`, there's no large title, only the slim bar (for the reader).
  - `AdaptiveSegmented<T extends Object>({Key? key, required Map<T, String> segments, required T selected, required ValueChanged<T> onChanged})`: `CupertinoSlidingSegmentedControl` on iOS, and `SegmentedButton<T>` with a single selection elsewhere.

- [ ] **Step 1: Write the failing tests:**
  - `SelahPage on iOS uses a large collapsing title`: expect `CupertinoSliverNavigationBar`, and `find.text(title)` before scrolling.
  - `SelahPage on Android uses a large Material app bar`: expect a `SliverAppBar`.
  - `SelahPage back pops when it can and goes to backTo when it cannot`: use a two-route `GoRouter`. When pushed, back pops. When it's the initial location, back goes to `backTo`.
  - `SelahPage pull to refresh calls onRefresh`, on both platforms.
  - `AdaptiveSegmented picks the platform control and reports changes`.
- [ ] **Step 2: Run** the tests. Expected: FAIL to compile.
- [ ] **Step 3: Implement** both files.
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Add SelahPage and adaptive segmented control"`

### Task 6: Hoy redesign

**Files:**
- Modify: `app/lib/src/features/today/today_page.dart`, `app/lib/src/features/today/part_tick.dart`
- Test: `app/test/today_page_test.dart` (append; keep existing tests)

**Interfaces:**
- Consumes: `SelahPage`, `SelahRow`, `HeroCard`, `dayHeroTag`, `SkeletonList`, `Entrance`, `Pressable`, `SelahHaptics` (Tasks 1–5)
- Produces:
  - `PartTick` keeps its constructor. It now:
    - animates fill and check with a spring scale (0.8 → 1.0 over `Motion.medium`, or no scale with reduce motion);
    - calls `SelahHaptics.tick()` on tap;
    - grows its hit target to at least 44×44, as now.
  - A new top-level function in `today_page.dart` that `tickPart` callers use: `Future<void> tickWithFeedback(WidgetRef ref, String progressId, DevotionalDay day, DayPart part, DateTime now)`. It calls the existing `tickPart`, and when that tick completes the day, it calls `SelahHaptics.success()`. The reader uses it too (Task 7).
- Layout:
  - `SelahPage(title: l.tabToday)`, whose large title reads `Hoy`. Above it sits the church-name and date eyebrow, as in the mockup.
  - The week row is next. A day that becomes done fills with a spring.
  - Then `Hero(tag: dayHeroTag(original.id, day.number), child: HeroCard(eyebrow: '${study.title} · ${l.dayOfTotal(...)}', title: day.title, quote: day.mainIdea, badge: done ? l.doneForToday : null))`. Tapping the card opens the day, the same as tapping Reflexión.
  - Then the part rows as `SelahRow`s with `PartTick` trailing, wrapped in `Entrance(index: i)`.
  - Finally the summary button.
  - Loading states (church, study and progress) show `SkeletonList(hero: true, rows: 3)` inside the page instead of a `CircularProgressIndicator`.
  - The no-church state uses `SelahPage(title: l.pickChurch)` around `ChurchList`.

- [ ] **Step 1: Write the failing tests** (append):
  - `while the study loads Hoy shows skeletons, not a spinner`: `newest` is a never-completing `Completer().future`. Expect `find.byType(Skeleton)` to find widgets and `find.byType(CircularProgressIndicator)` to find nothing.
  - `the hero card carries the day's hero tag`: expect a `Hero` whose tag is `dayHeroTag('study-1', 1)`.
  - `tapping the hero card opens the day in the reader`: expect `READER seguir 1`.
  - `ticking a part plays a tick haptic and finishing the day plays success`: mock the platform channel. Tick reading and reflection, and the calls include `lightImpact` twice and no `mediumImpact`. Tick prayer, and the calls include `mediumImpact` once.
  - `Hoy fits at 200% text size` (Review Focus 2): pump with `MediaQuery(textScaler: TextScaler.linear(2))` at 390×844, and `tester.takeException()` is null.
- [ ] **Step 2: Run** `flutter test test/today_page_test.dart`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the layout and the `PartTick` and `tickWithFeedback` changes. Delete `_HeroCard` and `_Row` in favor of the shared components. Keep the keys `week`, `week-$i` and `tick-${part.name}`, which the tests use.
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: all PASS, including every existing Hoy test.
- [ ] **Step 5: Commit** `git commit -m "Redesign Hoy with the hero card, springy ticks and skeleton loading"`

### Task 7: Reader with the hero header

**Files:**
- Modify: `app/lib/src/features/study/reader_page.dart`, `app/lib/src/features/study/study_widgets.dart` (restyle `ReadingSection` and `ExternalLink` with tokens only)
- Test: `app/test/study_test.dart` (append)

**Interfaces:**
- Consumes: `SelahPage` (no title, `backTo: '/c/<church>/studies/<slug>'`, `backTooltip: l.backToStudy`, `actions: [LanguageMenu()]`), `HeroCard`, `dayHeroTag`, `tickWithFeedback`, `SkeletonList`
- Layout:
  - Translation banner.
  - Then `Hero(tag: dayHeroTag(original.id, day.number), child: HeroCard(eyebrow: l.dayOfTotal(...), title: day.title, quote: day.mainIdea))`, where the eyebrow carries the progress dots. It replaces the separate `Eyebrow`, dots row, title `Text` and main-idea blockquote.
  - Then the reading link and tick, the sections, and previous/next as now.
  - Loading shows `SkeletonList(hero: true, rows: 5)`.
  - *(Plan decision: no extra glass buttons in this plan. On iOS the reader's back and language controls sit in the slim translucent `CupertinoSliverNavigationBar`. The spec allows up to a few, so they can be added later on top of `AdaptiveTabBar`'s pattern.)*

- [ ] **Step 1: Write the failing tests** (append):
  - `the reader header carries the same hero tag as Hoy`: expect a `Hero` whose tag is `dayHeroTag('study-1', 1)`, wrapping both `day.title` and `day.mainIdea` text.
  - `the main idea appears once in the reader`: `find.text('Idea principal 1')` finds one widget.
  - `the reader shows skeletons while the study loads`.
- [ ] **Step 2: Run** `flutter test test/study_test.dart`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS. In the simulator, check that opening a day from Hoy flies the card into the reader header and back again on back-swipe.
- [ ] **Step 5: Commit** `git commit -m "Give the reader a hero header that the Hoy card flies into"`

### Task 8: Estudios screens: church page, study page, church picker

**Files:**
- Modify: `features/church/church_page.dart`, `features/study/study_page.dart`, `features/home/church_picker_page.dart`, `features/church/church_scope.dart` (its loading and error scaffolds)
- Test: append to `app/test/church_page_test.dart`, `study_test.dart`, `church_picker_test.dart`

**Interfaces:**
- Consumes: `SelahPage`, `SelahRow`, `Entrance`, `SkeletonList`, `Pressable`
- Rules:
  - Each page becomes a `SelahPage`, keeping its existing `onRefresh`. Study cards and day rows become `Pressable` cards or `SelahRow`s wrapped in `Entrance(index:)`.
  - The study page uses `backTo: '/c/<church>'`.
  - The church switcher stays in the church page's actions.
  - Every bare `CircularProgressIndicator` on these pages becomes `SkeletonList(rows: 4)`.
- [ ] **Step 1: Write the failing tests:** `church page shows skeletons while studies load`, `study page shows skeletons while it loads`, and `church picker shows skeletons while churches load` (each: `Skeleton` found, no `CircularProgressIndicator`).
- [ ] **Step 2: Run** the three files. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Redesign the church, study and church picker pages"`

### Task 9: Perfil, sign-in, welcome, join and create church

**Files:**
- Modify: `features/profile/profile_page.dart`, `features/auth/login_page.dart`, `features/welcome/welcome_page.dart`, `features/church/join_page.dart`, `features/church/create_church_page.dart`
- Test: append to `profile_page_test.dart`, `join_page_test.dart`

**Interfaces:**
- Consumes: `SelahPage`, `AdaptiveSegmented`, `Pressable`, `SkeletonList`, `popOr`
- Rules:
  - Each page becomes a `SelahPage`. Pages reached by `push` from Perfil get `backTo: '/profile'` (sign-in, welcome, create church). Join gets `backTo: '/'`.
  - Profile's theme picker becomes `AdaptiveSegmented<ThemeMode>`.
  - Full-page loading spinners become skeletons. In-button progress spinners (create church line 140) stay.
  - Sign-in and welcome keep every field, button and copy.
- [ ] **Step 1: Write the failing tests:**
  - `profile theme picker is the sliding control on iOS`: expect `CupertinoSlidingSegmentedControl<ThemeMode>`, and choosing `Oscuro` still saves the theme mode, as the existing Android test asserts.
  - `join page shows skeletons while the invite loads`.
- [ ] **Step 2: Run** the tests. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Redesign Perfil, sign-in, welcome, join and create church"`

### Task 10: Admin screens get the theme and transitions

**Files:**
- Modify: `features/admin/admin_gate.dart` (its scaffold becomes `SelahPage`, with `backTo` as the existing `backTo` and no `onRefresh`), `features/admin/requests_page.dart` (`SelahPage`)
- Test: the existing admin tests stay green. No new behavior.

**Rules:** Admin pages that render through `AdminGate` inherit the new header automatically. Spinners may stay (spec). Swap `SegmentedButton`s in admin pages only if their tests still pass untouched. Otherwise leave them.

- [ ] **Step 1: Run** `flutter test test/admin_*_test.dart test/requests_page_test.dart test/people_page_test.dart test/church_settings_page_test.dart test/import_picker_test.dart` to establish the baseline. Expected: PASS.
- [ ] **Step 2: Implement** the two scaffold swaps.
- [ ] **Step 3: Run** `flutter test` and `flutter analyze`. Expected: PASS.
- [ ] **Step 4: Commit** `git commit -m "Bring the admin pages onto the new page scaffold"`

### Task 11: Device verification

No code, unless a check fails. A failure goes back to the owning task.

- [ ] **Step 1: iOS Simulator.** Run `cd app && flutter run -d "iPhone 17 Pro" --dart-define-from-file=config/beta.json`. Walk every member screen in light and dark mode: the glass bar, large titles collapsing, back-swipe from the reader to Hoy and to the study page, the hero flight, ticks and haptics, and skeletons on a slow network (Network Link Conditioner, or temporarily delay a provider). Screenshot each screen.
- [ ] **Step 2: Reduce Motion.** Turn it on in Settings › Accessibility › Motion on the simulator. Springs, staggers and the hero flight become fades.
- [ ] **Step 3: Chrome.** Run `flutter run -d chrome --dart-define-from-file=config/beta.json`. Check at 390px wide (bottom `NavigationBar`, fade transitions, no glass) and at 1280px wide (`NavigationRail`, centered column). Use the browser back button through Hoy → reader → back.
- [ ] **Step 4: Physical iPhone.** Run `flutter run --profile -d PoneiPhone --dart-define-from-file=config/beta.json`. Scroll the reader under the glass bar and confirm in the DevTools performance overlay that there are no janky frames.
- [ ] **Step 5: VoiceOver on the physical iPhone.** Every tab is reachable and announced with its label and selected state, including while a page has scrolled under the bar. **If any tab can't be reached, set `kUseNativeGlass = false`** (the frosted Flutter bar), run `flutter test`, commit `"Use the frosted tab bar until native glass works with VoiceOver"`, and record the finding in the PR.
- [ ] **Step 6:** Run `flutter test` and `flutter analyze` one final time. Expected: all PASS. Then open the PR.
