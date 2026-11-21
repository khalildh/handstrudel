# Instrument files

A HandStrudel instrument is a small JSON file that describes a playable on-screen instrument: its surface, what the chord and note zones play, and optionally its sound. Apps draw and play it with their own built-in code. Nothing in the file is executed, so an instrument can come from the app bundle, a feed post or a generator.

- `schema.json` is the spec (JSON Schema, format version 1).
- `library/` holds the instruments shipped in the iOS app (bundled as its `library` folder). `scale-wheel.json` and `split-wheel.json` are the built-in Scale and Split wheels. `moon-pentatonic.json` is a demo.
- `fixtures/` pins the loading rules. Each file has an `input` instrument and the `expect`ed result: whether it is accepted, the issue codes in order, and the repaired values. Every implementation must pass all of them (iOS: `InstrumentSpecTests.testSharedFixtures`).

## Loading rules

Files that are not instruments, use a newer `format_version`, have an invalid `id`, use a value outside the vocabulary, or exceed 16 KB are rejected. Values that are only out of range are repaired, with an issue code for each:

| Code | Repair |
|---|---|
| `name_trimmed` / `description_trimmed` | Trim whitespace, cut to 40 / 200 characters. An empty name is rejected (`name_missing`). |
| `radius_clamped` | Wheel radius into 0.7–1.0. |
| `rest_radius_clamped` | Rest hole into 0.2–0.5. |
| `octave_band_radius_clamped` | Octave rim into 0.6–0.92, and at least 0.25 outside the rest hole so the base band stays playable. |
| `sound_dropped` | A sound this app can't play is removed; the instrument plays with the player's own sound. |

## Version 1

One surface type, `split_wheel`: a circle cut into a chord half and a note half around a rest hole, with an outer octave rim. The chord side, chord voicing (triad or seventh), note source (one octave of the scale, or the held chord's tones over three octaves), whether notes have an octave rim, and chord-tone highlighting are all set by the file. New surface types and fields come with a new `format_version` or as optional fields that older apps ignore.
