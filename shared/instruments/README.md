# Instrument files

A HandStrudel instrument is a small JSON file that describes a playable on-screen instrument: its surface and what each zone plays. Apps draw and play it with their own built-in code. Nothing in the file is executed, so an instrument can come from the app bundle, a feed post or a generator.

**Instruments are structure, not music.** The test: if the same zone, with the same settings, would sound different, it's a music setting and doesn't belong in an instrument. Zones are defined relative to the player's current settings, never as fixed notes or counts: one note wedge per note of the selected scale (5 for pentatonic, 7 for major), one chord wedge per chord of the selected progression, labels in the selected key. The music (key, scale, progression, chord voicing, SoundFont or synth, tempo) is chosen separately, exactly as today, and every instrument adapts to it. A shared post pairs an instrument with a sound; neither contains the other.

- `schema.json` is the spec (JSON Schema, format versions 1 and 2).
- `library/` holds the instruments shipped in the iOS app (bundled as its `library` folder). `scale-wheel.json` and `split-wheel.json` are the built-in Scale and Split wheels; `wide-wheel.json` is a wheel with bigger zones. The other files are the format 2 starter library, at least one per surface type. They are also good seeds for generators.
- `fixtures/` pins the loading rules. Each file has an `input` instrument and the `expect`ed result: whether it is accepted, the issue codes in order, and optionally `zone_count` and `values` (dotted paths such as `zones.0.frame.w` into the repaired instrument, re-encoded). Every implementation must pass all of them (iOS: `InstrumentSpecTests.testSharedFixtures`).

## Loading rules

Fields a loader doesn't know are ignored, so newer files still open in older apps; generators must still follow the schema exactly. Files that are not instruments, use a newer `format_version`, have an invalid `id`, use a value outside the vocabulary (an unknown surface, role, drum, parameter, gesture or style), or exceed 16 KB are rejected. Values that are only out of range are repaired, with an issue code for each:

| Code | Repair |
|---|---|
| `name_trimmed` / `description_trimmed` | Trim whitespace, cut to 40 / 200 characters. An empty name is rejected (`name_missing`). |
| `radius_clamped` | Wheel radius into 0.7–1.0. |
| `rest_radius_clamped` | Rest hole into 0.2–0.5. |
| `octave_band_radius_clamped` | Octave rim into 0.6–0.92, and at least 0.25 outside the rest hole so the base band stays playable. |

## Format 2

Format 2 keeps the split wheel exactly as format 1 (same fields, same behaviour) and adds general surfaces. A format 2 instrument with any other surface has `zones`, and optionally `gestures` and `visuals`, instead of `chords` and `notes`.

**Surfaces.** Coordinates are fractions of the *play area*: the screen minus the studio's top bar and bottom controls (x right, y down).

| Type | Layout |
|---|---|
| `grid` | `rows` × `columns` cells (1–8 × 1–6), filled row by row from the top left. |
| `keys`, `strips` | A linear keyboard, `horizontal` (left to right) or `vertical` (bottom to top). Keys and strips play the same; they only look different. |
| `radial` | Wedges clockwise from the top around a resting centre, between `inner_radius` and `outer_radius`. |
| `arc` | Wedges fanned around the bottom centre from `start_angle` to `end_angle` (degrees clockwise from up). |
| `pads` | Each zone's `frame`; `round` or `rounded`. |
| `orbs` | Pads that `drift` or `pulse` by `amount` every `period` seconds (visual only, never tempo). |

**Zones** say *which* part of the player's music they play, never pitches:

| Role | Field | Plays |
|---|---|---|
| `note` | `degree` (+ `octave`) | A degree of the player's scale; past the scale's size it climbs octaves. |
| `chord` | `slot` (+ `octave`) | A chord of the player's progression (wrapping), voiced by the player's settings. |
| `chord_tone` | `tone` (+ `octave`) | Root, third, fifth or seventh of the held chord (the last chord played, else the progression's first). |
| `drum` | `drum` | A kit slot: kick, snare, hihat, crash, ride, tom. |
| `expression` | `parameter` (+ `axis`) | Sets filter, hipass, reverb, delay, volume, pan, drive or crush by position along the zone. |

Pitched zones `hold` (sound while touched or pinched), `latch` (tap on, tap off) or `retrigger` (a short note per hit), and can have `octave_bands` (top/outer band an octave up, bottom/inner an octave down). `hand` limits a zone to one tracked hand; touch plays every zone.

**Gestures.** `play` is `pinch` (pinch inside a zone) or `hover` (a hand's pinch point inside a zone). `expressions` map a hand input (the hand pipeline's axes: x, y, spread, pinch, fist, rotation and the five finger curls) to a parameter.

**Visuals** come from fixed named sets that read in every studio theme: `palette` (theme, aurora, ember, ocean, candy, mono), `shape` (rounded, round, square), `effect` while played (none, glow, particles, ripple) and `labels` (notes, degrees, none). A zone can replace its label with up to 12 characters.

### Playability rules

Checked against a 340×480-point reference play area (the smallest iPhone, portrait), in this order:

| Code | Rule |
|---|---|
| `zones_missing` (reject) | At least one zone. |
| `zone_invalid` (reject) | Every zone has its role's field, and pads and orbs have a `frame`. |
| `surface_clamped` | Surface values into range; radial and arc rings at least 0.3 deep; arcs at least 60° wide. |
| `zone_clamped` | `degree` 0–20, `octave` −2…2, `slot` 0–7, `tone` 0–3. |
| `label_trimmed` | Labels trimmed to 12 characters. |
| `zone_moved` | Pads and orbs moved inside the play area. |
| `zone_resized` | Pads and orbs grown around their centre to at least 44 points a side. |
| `zones_dropped` | At most 16 zones per hand (a zone for either hand counts for both), and no more than the surface fits at 44 points: grid cells, 7 keys across or 10 up, and as many wedges as fit around the ring's middle. Later zones are dropped. |
| `octave_bands_removed` | Octave bands only on pitched zones at least 88 points tall (or deep), so each band is a real target. |
| `zones_overlap` (reject) | Pads and orbs must not overlap, counting how far orbs drift or swell. |
| `gesture_dropped` | One expression per hand input, none on the play gesture (pinch when `play` is pinch), one control per parameter (a zone or a gesture), at most six. |

Rejections stop at the first failing rule; repairs are each reported once, in this order.
