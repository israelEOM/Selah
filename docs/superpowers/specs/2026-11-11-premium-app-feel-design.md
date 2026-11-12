# Premium app feel: motion, colour, illustration

Date: 2026-11-11 · Status: draft for review

## Why

Selah's iOS app works, but it feels plain "everywhere" next to apps like Structured, Waterllama and Gentler Streak. Those apps share four things Selah lacks:

1. **A reward moment** when you finish the core action.
2. **A personality layer**, meaning illustration in one consistent style.
3. **Progress you can watch move.**
4. **Screens that arrive and carry over** instead of just appearing.

Selah already has the mechanics: a spring press scale, haptics, a ticks spring-in, skeletons and Reduce Motion support (`app/lib/src/app/design/`). What it lacks is the *moments*.

The emotional target, in the owner's words, is **"peaceful and quietly proud, not pressured."** Gentler Streak is the closest model: it guides without rushing and uses words over numbers.

## Goals

- Finishing a day feels like a small, calm reward.
- You can see, and act on, any day of the current week, including catching up on yesterday.
- The three parts of a day (Bible reading, Reflection, Prayer) each have a colour and a small cartoon icon, and ticking them feels alive.
- In the reader, the three ticks are always reachable while scrolling.
- Illustrations from one shared library appear across the app, picked automatically for each study.
- Every screen gets considered motion. The screens are listed below.

## Non-goals

- Android-specific polish. The Flutter code is shared and Android must not break, but nothing is tuned for it here.
- Per-study custom image generation. It may come later, on top of the library.
- Syncing progress across devices. Progress stays on the device in `SharedPreferences`, as today.
- Redesigning the website layout (the desktop "site" layout). It inherits shared widgets but gets no new layout work.

## Anti-goals (a failure even if it works)

- Streak counts, confetti, sounds, badges, or anything that makes a missed day feel like a loss. A missed day is just unfilled. Copy for a past, unfinished day is gentle ("Not too late. You can still finish this day.").
- Celebrations that block you or need dismissing.
- Motion that ignores Reduce Motion. With it on, everything becomes a plain fade or an instant change, following the existing `reduceMotion(context)` rule.
- Images that look like different illustrators made them.

## Decisions

### 1. The finishing moment ("moment A: the light settles")

When the last part of a day is ticked:
1. A soft light rises inside the green hero card: a radial highlight from the bottom, fading in over about 1.8s.
2. That day's ring in the week row fills to a solid green circle with a check.
3. A serif line fades up, about 8px of rise over 1s, starting about 0.7s in. Today: "That's today." with "Go in peace." underneath. A past day: "Day complete." with "Nothing lost." underneath.
4. One `SelahHaptics.success()`.

It then rests in that state. Nothing pops up and nothing needs dismissing.

### 2. Week row: rings you can walk through

**Study days stay self-paced (owner's decision).** Today keeps showing the first unfinished day of the newest study, as `todayFor` does now. A study day is not tied to a calendar date. What the week row shows is *when you did things*.

- **Every tick records its date.** Add a per-part date to `DayProgress`, for example `partsOn: {reading: "2026-11-10", ...}`, next to the existing `parts` and `doneOn`. Older saved progress has no part dates. In that case, treat its parts as ticked on `doneOn` if the day is done, and leave them undated otherwise. The format must stay backward compatible.
- **A date's ring** shows the parts ticked on that date, in their colours, from whichever study day they belong to. It becomes a filled green circle with a check when a study day was completed on that date. Dates with nothing ticked show an empty, neutral ring.
- **Tapping a past date** shows the study day you worked on that date. If you worked on more than one, it shows the last one. If you did nothing that date, it shows the day Today currently shows (the first unfinished one). This lets you record something you did but forgot to tick.
- **Ticks made while viewing a past date are recorded on that date (my call).** So if you read yesterday but forgot to tick, ticking it from yesterday fills yesterday's ring. Finishing a day this way sets `doneOn` to that past date and plays moment A with "Day complete. Nothing lost."
- **Reading ahead** is unchanged. The "Read the next one" link stays after a day is finished, as a quiet text link, and ticks on that next day count on the date you make them.
- **`doneDatesProvider`/`weekCircles`** get replaced by a per-date lookup of the parts ticked on each date.

- **Rings, not dots.** Each of the seven days (Monday to Sunday) is a ring split into three arcs, one per part, each in its part's colour. Unticked arcs are a pale neutral. A fully finished day becomes a filled green circle with a check. The date number sits inside the ring, and today's number is terracotta.
- **Tap a past day** (today or earlier) to show that day's content on Today. The content slides left or right in the direction of travel (about 24px plus a fade, 250ms), with a `selection` haptic. The title changes to "Yesterday" or the weekday name.
- **You can tick from a past day,** and those ticks are recorded on that date (see above).
- **Future days** are dimmed and can't be tapped.
- **Arcs fill with a spring** as ticks happen.

### 3. Part colours and icons

| Part | Colour | Tint (row) | Soft (icon tile) | Icon |
|---|---|---|---|---|
| Bible reading | `#2F5D4A` (Selah green) | `#E6EEE8` | `#D3E2D8` | open book |
| Reflection | `#B8732E` (amber) | `#F5EBDD` | `#EEDCC2` | lightbulb |
| Prayer | `#5E6A9C` (dusk blue) | `#E8E9F2` | `#D7DAEA` | praying hands |

- These are light-mode values. Dark-mode equivalents are left to the builder, but they must pass the existing contrast tests (`test/contrast_test.dart`).
- This **changes the design system rule** that green is the only strong colour. Update `DESIGN.md` and `theme.dart` (`SelahTones`) to add the three part colours as a new rule: *part colours mark the three parts of a day, and only those.* Terracotta keeps its role.
- The icons are cartoon illustrations from the library (see 7), shown on a rounded square tile in the part's soft colour.

### 4. Ticking a part

On Today's part rows and in the reader bar:
1. The icon does a small hop (scale to 1.25, a slight rotate, then back, with a spring, about 600ms).
2. The check springs in.
3. A ring ripples out from the tick, about 600ms.
4. `SelahHaptics.tick()`.

Unticking reverses quietly. Today's rows use the part's tint as the row background, with the icon tile on the left, the title and subtitle in the middle, and the round tick on the right in the part's colour.

### 5. Reader: the always-visible tick bar

- **A floating glass bar** holds the three parts. It is pill-shaped and translucent with a blur, and sits at the bottom of the reader in place of the tab bar (the reader already sits above the tabs). It replaces the per-section `PartTick`s that sit inside the sections today.
- **It follows your reading.** The part whose section is currently in view widens to show its icon, name and "Tap to tick". The other two shrink to just their icons, and every one stays tappable. Width changes use a spring.
- **Ticked parts** show a small check badge on the icon's corner.
- **When all parts are ticked,** the bar turns into a green "Day complete · back to Today ›" pill. It does **not** go back automatically, so the reader can keep reading. Tapping it goes to Today, which plays moment A for that day.
- **The reader header** shows "Day N of M" and a small ring for the day's progress.
- **Sections** get a left rule in their part's colour, with the eyebrow label in that colour.

### 6. Motion across the app

The constants for durations and springs live in `Motion` in `tokens.dart`. Add any new ones there.

- **Screens arrive.** On the first build of a page, content rises a few pixels and fades in, staggered about 40ms per block, about 300ms each. The website's motion already works this way. This is a smaller app version of it.
- **Shared transitions:**
  - The Today hero card into the reader header (this exists; keep it).
  - A study card in Studies into the study page header.
  - The art on a church row into the church art on the next screen.
- **Skeleton to content** crossfades instead of popping.
- **Progress bars** (the featured study, the admin monthly usage) fill when they first appear.
- **Haptic vocabulary:**
  - `selection` for switching days or segments
  - `tick` for ticking a part
  - `success` for finishing a day, joining a church, or publishing a study

Per-screen notes are in the screen list (9).

### 7. Illustration library

- **Making it:** about 30–40 scenes made once in ChatGPT, all in one style: soft, painterly, warm paper tones, harmonious with paper `#FAF7F2` and Selah green. The set should cover:
  - Landscapes: hillside at dawn, quiet lake, desert path, wheat field, and similar.
  - Bible imagery: vine and grapes, bread and cup, lamp, sheep, boat, open door, and similar.
  - Images that are safe as defaults: no depictions of Jesus' face, no text in the images.
- **Fixed art made in the same pass:**
  - The three part icons.
  - Welcome, sign-in and invitation scenes.
  - Empty-state scenes: "no studies yet", "no events" and choosing a church.
- **Storage (owner-agreed approach, builder's call on details):** bundle the library as app assets (`app/assets/art/`), with a manifest (`manifest.json`) listing each image's key, theme tags and alt text in all three languages. The worker reads the same manifest from the repo.
- **Picking images:** when the worker generates a study, Gemini also chooses one image key for the study and one per day from the manifest's tags. This is a new field in the analysis or devotional output and is stored with the study. An admin can swap the study's or a day's image on the sermon page in the Manage area. Studies published before this change, or with no valid key, fall back to a deterministic pick from the study's id.
- **Producing the images** is owner work, outside the code plan. The plan should ship with placeholder art and a tag list, and the real images drop in later without code changes.

### 8. Tab bar

A floating, translucent pill with a blur, holding Today, Studies, Events and Profile. The active tab gets a soft green-tinted pill behind it.

The app already uses `cupertino_native_better` for the tab bar. If it gives the native iOS 26 Liquid Glass bar, keep it and only adjust the colours. A hand-drawn imitation is not wanted on iOS.

### 9. Screens

Light mode is shown. Dark mode follows the existing tokens.

| Screen | Changes |
|---|---|
| Welcome | A large scene at the top, then the title, then two choice rows each with an icon tile. The art settles in first (a 600ms fade and rise), then the choices stagger in. |
| Sign in | A scene at the top, the "Selah" wordmark and the italic tagline, Google, then email. The art drifts very slowly (a 20s parallax loop, off with Reduce Motion). A wrong password gives a gentle shake and a warning haptic. |
| Choose your church | A search field, then rows with round church art and Follow chips. Follow springs into "✓ Following", and the church art carries through to Today. |
| Invitation (join) | Round church art, the eyebrow "You're invited", the title "Join {church} as {role}", and the primary button. |
| Today, in progress | The eyebrow (date · church), the "Today" title, the week rings, the hero card (with round art in the bottom-right corner), the three part rows, and the Sermon summary button. |
| Today, day finished | Moment A. |
| Today, past day | The title becomes "Yesterday" or the weekday name, plus the gentle line if the day isn't finished. |
| Today, study finished | The existing AllDone state, with the quote setting in word by word (a 40ms stagger). |
| Reader | See section 5. A scene sits under the header. |
| Studies | The featured "Devotional of the week" card with large art, a progress line, and Continue. Recent studies are rows with square art thumbnails. |
| Study page | The header art collapses into the title bar on scroll. The devotional path lists each day with its ring. |
| Events | Grouped by day with sticky headings, and date tiles with a terracotta month. Tapping opens details in a sheet. |
| Profile | Avatar, name, your church row, segmented Language and Theme controls (the pill slides, with a selection haptic), Manage the church, and Sign out. |
| Manage: sermons (Spanish) | The monthly usage bar fills, the import button, and sermon rows with art and status chips. "Generando" shimmers slowly. |
| Manage: sermon (Spanish) | The progress steps' dots fill as each step finishes, and the active one breathes slowly. The study art appears with a "Cambiar imagen" (change image) control. Publishing plays the success haptic. |
| Empty states | Each gets its library scene above the existing copy. |

The mockups used in the conversation are in `.superpowers/brainstorm/` (git-ignored):
- `finish-moment.html`: the three finish options. Option A was chosen.
- `today-v5.html`: the interactive Today with the week rings.
- `all-pages-v2.html`: every screen.
- `reader-dock-v2.html`: the reader tick bar.

### 10. Calls made while writing this up (check these)

- **Church art:** churches get no upload. Their art is a deterministic pick from the library based on the church id. There is no new column and no admin UI.
- **Moment A plays once,** live, at the moment the day is finished. When you open Today later on a finished day, it shows the settled state (light in the card, the filled ring, the quiet line) without animating.
- **"Day complete · back to Today" from any reader day** goes to Today on today's date and plays moment A there. If the reader was opened from a past date, it goes back to that date instead.
- **Tab bar:** it already uses native Liquid Glass through `cupertino_native_better` (`adaptive_tab_bar.dart`), so it only needs colour changes.

## Constraints

- Flutter app, Riverpod, go_router (existing). No new animation packages unless a clear need appears. Flutter's own animation APIs and the existing `Pressable` and `SpringIn` should cover it. Rive or Lottie are out of scope.
- Three languages (en, es, pt) for all new copy, through the ARB files. The admin screens stay Spanish-only, as today.
- Reduce Motion is honoured everywhere. There are existing tests for it (`design_test.dart`), and new motion should be testable the same way.
- Progress format in `SharedPreferences` (`progress:<studyId>`) must stay backward compatible.
- `DESIGN.md` and the code must agree. Update both.

## Left to the builder

- Exact curves, spring constants and durations within the ranges above.
- Dark-mode values for the part colours, subject to the contrast tests.
- Whether the illustration pick is stored on the study row or in its JSON, and the shape of the migration.
- How the reader detects the section in view.
- How the light in moment A is painted.
