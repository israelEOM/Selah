# Premium look and feel — design

Date: 2026-10-28

## Why

Selah works, but it doesn't feel good to use. It's built from stock Material widgets (14 `AppBar`s, 22 bare `CircularProgressIndicator`s, flat grey rows, instant page swaps), so on an iPhone it reads like a generic Android app. The owner's other app, Repwise, is native SwiftUI and feels premium. Its iOS 26 Liquid Glass is the part that matters most to them. We considered a separate native iOS app and rejected it, because every feature would have to be built twice against the same Supabase backend. Selah stays one Flutter app and gets a redesign.

Success: on an iPhone, Selah is hard to tell apart from a well-made native app. It has a real glass tab bar that content scrolls under, native page transitions and back-swipe, and actions that respond with motion and haptics. On Android and web it feels just as polished, but native to those platforms instead of imitating an iPhone.

## Goals

- **iOS:** real Liquid Glass on the floating chrome (the tab bar and a small number of floating buttons), iOS page transitions with edge back-swipe, a large title that collapses on scroll, and haptics on meaningful actions.
- **Android:** the same identity (palette, serif quotes, hero card) on solid surfaces, with a Material 3 navigation bar, Android's predictive back, and Material motion.
- **Web:** the Android look, plus a navigation rail and centered content column on wide screens.
- **Everywhere:**
  - Fluid motion: tappable rows and cards spring when pressed, ticks animate, the hero card leads into the day's reading, and lists animate in.
  - Skeleton placeholders shaped like the content replace bare spinners.
- **Member screens** get the full treatment. Admin screens get the new theme, components and transitions, but no bespoke motion work.

## Non-goals

- No new features and no flow changes. Every screen keeps its routes, data, copy and behavior. The one exception is navigation (see **Navigation** below), which changes so that back works the native way.
- No native SwiftUI app, and no SwiftUI-rendered screens.
- No glass on Android or web.
- No backend, schema or worker changes.
- Home-screen widgets, Live Activities and other iOS extensions are out of scope. They could be a later project.

## Anti-goals (failure even if it "works")

- Glass that stutters while scrolling, or that makes text behind or on it hard to read.
- Android or web looking like a broken iPhone app (glass imitations, iOS chevrons, Cupertino switches on Android).
- A redesign that breaks existing behavior. Today's tests in `app/test/` must keep passing, apart from finders that have to change because a widget type changed.
- Native views in places they're known to hurt, such as inside scrolling lists.
- VoiceOver or TalkBack users losing access to anything they can reach today.

## Constraints

- Flutter 3.47.4 (Impeller on iOS), Dart 3.13, Xcode 26.3, iOS deployment target 15.0. Android and web builds must keep working, and web deploys to Cloudflare Pages as now (README).
- Brand colors stay as decided in `2026-10-27-app-look-today-and-signup-roles-design.md`: navy `#0E2341`, forest green `#2E4A38`, orange accent `#F15A24`, and the existing dark palette. The redesign adds depth, materials and motion, not new hues. *(My call: the brainstorm mockup used a warm off-white page background on iOS. The builder may tint the light background slightly warm if it helps glass and cards stand out, but must keep it close to white.)*
- Admin screens stay in Spanish (`inSpanish`), and member screens stay localized as today (es/en/pt).
- Light and dark mode both need to look right, including the glass.

## How it's built (decided)

### Liquid Glass: native iOS components through `cupertino_native_better`

A spike on 2026-10-28 proved the approach on the iPhone 17 Pro simulator (iOS 26.3). It's committed as `5fabbdb` on the local branch `spike/glass-tabbar`, which is reference only and not to be merged. It used `cupertino_native_better` 1.8.1, added through Swift Package Manager with no Podfile changes, and built with the existing iOS 15.0 deployment target. `lib/spike_main.dart` there runs the app on sample data with no backend. Results:
- `CNTabBar` renders the real `UITabBar` with Liquid Glass.
- Flutter content scrolls under it and refracts through it.
- Taps reach it, and the native "droplet" animation plays when switching tabs.

Other options and why they lost:
- `liquid_glass_renderer` is a shader recreation. It's labeled experimental, depends on the Flutter GPU preview, and has no real glass on web.
- `cupertino_native_ui` renders whole screens in SwiftUI. Each route runs in its own Flutter engine, which would mean re-architecting the app.
- Flutter's official support (`cupertino_ui` package, flutter/flutter#170310) hasn't shipped.

Rules for using it:
- Use native glass only for floating chrome: the tab bar and at most a few floating buttons. Never put it inside a scrolling list. The package warns that platform views are costly there.
- Hide the package behind Selah's own small widgets, so the rest of the app never imports it and a future switch to Flutter's official glass is one change. For example, an adaptive tab bar and an adaptive glass button.
- On iOS 26+, use real glass. On iOS 15–25, the package's Cupertino fallback (frosted look) is acceptable. On Android and web, render Selah's own Material components instead, not the package's fallback.
- Register `CNTabBarRouteObserver` on the router so the bar hides correctly under modals and pushed routes.

### Navigation

Today almost every member move uses `context.go`, which replaces the page, so there is no stack for a back-swipe to pop. The hard-coded back arrows also always land on a fixed page. For example, the reader's back always goes to the study page, even when it was opened from Hoy.

- **Back returns to where you came from.** *(Decided by the owner.)* Drilling into a page pushes it, so the iOS edge back-swipe, Android predictive back and the on-screen back button all pop to the previous page. A reader opened from Hoy goes back to Hoy, and the hero card animates back into place. A reader opened from the study page goes back to the study page. A page opened directly from a deep link, with nothing to pop, goes back to its logical parent (today's fixed destinations).
- **Each tab remembers its place.** *(My call.)* Use a `StatefulShellRoute` with one stack per tab, the way native tab bars behave. Tapping the tab you're already on pops it to its root.
- **The tab bar shows on tab roots and the study page, and hides in the reader.** *(My call.)* Reading is full-screen and focused, and the bar slides away when the reader opens.
- **Previous and next day replace the reader page in place.** *(My call.)* That way back still leaves the reader in one step instead of walking through every day.
- Web keeps working URLs and deep links, and the browser back button follows the same stack.
- Tests that assert a destination after tapping back or a row are updated to the new behavior. Everything else they assert stays.

### Pages scroll under the floating chrome

`PageBody` currently wraps content in a `SafeArea` that stops at the tab bar, and the spike showed that leaves nothing behind the glass. Pages must:
- extend to the bottom edge under the tab bar,
- extend to the top under a translucent or collapsing header,
- pad their scroll content so the last item can still scroll clear of the bar.

### Platform split

Choose per platform at the component level, through a small set of adaptive widgets and theme pieces. Don't fork whole screens.

| | iOS | Android | Web |
|---|---|---|---|
| Tab navigation (see **Navigation**) | Native glass `CNTabBar`, floating | Material 3 `NavigationBar` | `NavigationBar` when narrow, `NavigationRail` when wide |
| Page transitions | Cupertino (slide + parallax, edge back-swipe) | Material predictive back | Fade-through, no swipe |
| Top bar | Large title that collapses into a translucent blurred bar | Material 3 top app bar with scroll-under tint | Same as Android |
| Pull to refresh | Cupertino style | Material `RefreshIndicator` | Same as Android |
| Haptics | Yes (light on tick and tab, success on finishing a day) | Yes, through the same API | None |
| Switches, segmented controls, dialogs | Cupertino | Material 3 | Material 3 |

### Motion and feedback (all platforms unless noted)

- **Press feedback:** tappable rows, cards and buttons scale down slightly and spring back. This replaces the ink splash on iOS. Android keeps a ripple plus the scale.
- **Ticks:** the day-part tick animates from empty to filled with a spring and a haptic. Finishing all parts of a day plays a small celebratory moment on the hero card or the week row, kept brief and calm.
- **Hero card to reader:** opening the day from Hoy carries the hero card into the reader as a shared-element transition, so it feels like one continuous movement. *(My call: the reader gets a header in the hero-card style, showing the day title and main idea, as the transition's destination. It replaces the reader's current plain blockquote of the main idea, so no content is added or lost.)*
- **Loading:** skeletons shaped like the real content replace every bare spinner on member screens, and content fades or slides in when it arrives. Admin screens can keep spinners.
- **Lists:** items appear with a short staggered entrance on first load only, never on every rebuild.
- **Respect Reduce Motion:** when the OS asks for reduced motion, springs, staggers and the shared-element transition fall back to simple fades.

### Theme and components

- Rework `app/lib/src/app/theme.dart` into a design system: spacing scale, corner radii, elevation and shadow levels, a type scale (keeping Georgia for quotes and reading), and motion durations and curves as named tokens.
- Build a small shared component set in place of ad-hoc `Card`/`ListTile`/`InkWell` use: pressable row, hero card, section header, skeleton, adaptive app bar, adaptive tab bar, adaptive glass button.
- Use SF Symbols for iOS tab icons (through the package) and Material Symbols on Android and web.

## Screens

**Full treatment (member):**
- Hoy (`today_page.dart`)
- Estudios: church page, study page, reader
- Perfil
- Sign-in
- Welcome
- Church picker
- Join
- Create church

**Theme and components only (admin):**
- Admin home
- Church settings
- People
- Requests
- Sermon import
- Sermon page

## Testing and verification

- All existing widget tests in `app/test/` keep passing. Update a test only where a finder depends on a widget type that intentionally changed, and keep what it asserts.
- Add widget tests for the adaptive pieces: the right component is chosen per platform via `debugDefaultTargetPlatformOverride`, and Reduce Motion disables animations.
- Visually check every member screen on the iOS Simulator (light and dark) and in Chrome at narrow and wide widths. *(Decided by the owner: no Android device testing in this project. The Android look is checked in Chrome and through platform-override widget tests, and testing on a real Android device or emulator comes later.)*
- Manually check VoiceOver on iOS. The package documents that native controls over scrolling Flutter content may be hard to reach (flutter/flutter#194389). The tab bar must stay reachable and correctly labeled. If it isn't, that blocks shipping the glass bar, and the fallback is a Flutter-drawn bar with a frosted blur.
- Check performance on a physical iPhone (the owner's iPhone on iOS 26.6 is available to `flutter run` over wireless): scrolling the reader under the glass bar stays smooth (no visible jank in a profile build).

## Left to the builder

- The order screens are redone in (Hoy, the shell and the reader first is the natural start, since that's where the spike was).
- Exact spacing, radii, shadow, duration and curve values, within the direction of the brainstorm mockup (`.superpowers/brainstorm/…/direction.html`, local only).
- Which helper packages to use for skeletons or animation, if any. Prefer few dependencies.
- Exactly where the "at most a few" native glass buttons go. The mockup put a glass overflow button top-right and a floating action next to the tab bar on Hoy.
- Whether to split the work into several PRs (recommended: theme and components, then the shell and navigation, then screens).
