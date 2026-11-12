# Selah illustration library

The app bundles one illustration per key listed in `manifest.json`. The worker reads the same manifest to pick an image for each study and day, and an admin can swap it later. **Until a file exists the app shows a calm generated placeholder**, except behind the green day cards on Today and in the reader, which stay plain green, so images can be dropped in one at a time with no code change.

## Style (use for every image)

Soft painterly illustration in gouache and watercolour, with gentle brush texture and a calm, quiet mood. Warm paper tones that sit harmoniously with the app's paper colour #FAF7F2 and Selah green #2F5D4A: cream, sage, sand, soft ochre and a touch of terracotta. Low contrast, plenty of open space, no hard outlines. No text, letters or numbers anywhere in the image, and no faces of Jesus (no human faces at all where possible; figures are seen from behind or in silhouette).

Add this paragraph to every prompt, then the scene line below. Keep every image in the same hand so the set feels like one book.

## Files

| What | Path | Size and format |
|---|---|---|
| Scenes (pickable and fixed) | `assets/art/<key>.webp` | 1200 x 900 px, WebP, about 150 KB or less |
| Part icons | `assets/art/parts/reading.png`, `reflection.png`, `prayer.png` | 256 x 256 px, PNG with a transparent background |

Keep the main subject in the centre: the same scene is cropped wide behind the right of Today's card (the app fades its left edge into the green, so no transparency is needed), square (study thumbnails) and wide (headers). Keep detail soft and low in contrast so white text stays readable over it.

## Part icons

Same style, one simple object each, centred, transparent background, sage / ochre / dusk blue tints matching the part colours (reading `#2F5D4A`, reflection `#B8732E`, prayer `#5E6A9C`).

- `reading.png`: an open book
- `reflection.png`: a lightbulb
- `prayer.png`: praying hands (no faces)

## Pickable scenes (`pickable: true`)

The worker may choose these for a study or a day, by matching the `tags` in the manifest. When adding a scene, add its entry to `manifest.json` with tags and alt text in en, es and pt (a short plain description, no "image of").

| Key | Scene prompt |
|---|---|
| `hillside-dawn` | Rolling green hills under a pale gold sunrise |
| `quiet-lake` | A perfectly still lake with soft reflections and distant hills |
| `desert-path` | A narrow path winding through warm sand dunes toward the horizon |
| `wheat-field` | A wide field of golden wheat moving in a light breeze |
| `olive-grove` | Old silvery olive trees on a terraced hillside |
| `mountain-mist` | Layered blue-green mountain ridges fading into morning mist |
| `river-bend` | A gentle river curving through soft green banks |
| `night-stars` | A deep blue night sky full of soft stars over quiet hills |
| `garden-gate` | A weathered wooden gate standing open onto a green garden |
| `seashore` | A quiet shoreline with small waves and pale morning light |
| `forest-light` | Soft rays of sunlight falling through tall trees onto a mossy path |
| `snowy-field` | A wide snowy field under a pale rose-grey winter sky |
| `vine-grapes` | A grapevine climbing a wooden trellis with ripe purple grapes |
| `bread-cup` | A loaf of bread and a simple clay cup on a plain wooden table |
| `oil-lamp` | A small clay oil lamp with a warm steady flame in a dim room |
| `sheep-field` | A small flock of sheep resting on a soft green pasture |
| `fishing-boat` | A wooden fishing boat floating on calm water at dawn |
| `open-door` | An old wooden door standing open with warm light spilling out |
| `well-water` | A round stone well with a rope and a clay jar beside it |
| `fig-tree` | A broad fig tree in full leaf with small figs, in soft shade |
| `mustard-seed` | A tiny seed in an open palm beside a sprouting young plant |
| `lost-coin` | A single small coin catching light on an old stone floor |
| `shepherd-staff` | A wooden shepherd's staff leaning in long grass at sunset |
| `cross-hill` | A plain wooden cross on a quiet hill under a soft grey-rose sky |
| `empty-tomb` | A rock tomb with the stone rolled away and morning light inside |
| `dove` | A white dove flying upward against a pale glowing sky |
| `ark-rainbow` | A wooden ark on calm water beneath a soft pastel rainbow |
| `tent-desert` | A simple woven tent on desert sand at twilight |
| `city-wall` | An ancient stone city wall glowing in the last light of day |
| `harvest-baskets` | Woven baskets full of fruit and grain on a wooden table |
| `salt-light` | A small bowl of salt beside a lit candle on a plain table |
| `stone-jar` | A row of tall stone water jars in warm indoor light |
| `loaves-fish` | A basket of small round loaves and two fish on green grass |
| `pruning-shears` | Garden shears resting on a trimmed vine branch |
| `scroll-table` | An open parchment scroll with no legible writing on a wooden table |
| `table-feast` | A long wooden table set with bread, fruit and cups, with empty chairs |

## Fixed scenes (`pickable: false`)

Used by specific screens only; never chosen for a study.

| Key | Scene prompt |
|---|---|
| `scene-welcome` | A wide sunrise over a quiet green path leading into hills, the Welcome screen header |
| `scene-signin` | A calm evening landscape with a small house and one lit window, for the sign-in screen (drifts slowly, so keep the edges soft and extend the sky) |
| `scene-invite` | An open wooden door in a stone garden wall with warm light beyond, for the invitation screen |
| `scene-churches` | A small simple village church among trees, for choosing a church |
| `scene-empty-studies` | A quiet table with an open empty notebook and a lamp, for 'no studies yet' |
| `scene-empty-events` | A quiet meadow with a single bench and nothing scheduled, for 'no events' |

## Rules

- No text, letters or numbers inside any image.
- No faces of Jesus. Avoid faces altogether where you can.
- Nothing that dates the image or ties it to one church.
- Check the key spelling: the file name must match the manifest key exactly.
