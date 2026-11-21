# Instrument files

A HandStrudel instrument is a small JSON file that describes a playable on-screen instrument: its surface and what each zone plays. Apps draw and play it with their own built-in code. Nothing in the file is executed, so an instrument can come from the app bundle, a feed post or a generator.

**Instruments are structure, not music.** The test: if the same zone, with the same settings, would sound different, it's a music setting and doesn't belong in an instrument. Zones are defined relative to the player's current settings, never as fixed notes or counts: one note wedge per note of the selected scale (5 for pentatonic, 7 for major), one chord wedge per chord of the selected progression, labels in the selected key. The music (key, scale, progression, chord voicing, SoundFont or synth, tempo) is chosen separately, exactly as today, and every instrument adapts to it. A shared post pairs an instrument with a sound; neither contains the other.

- `schema.json` is the spec (JSON Schema, format version 1).
- `library/` holds the instruments shipped in the iOS app (bundled as its `library` folder). `scale-wheel.json` and `split-wheel.json` are the built-in Scale and Split wheels. `wide-wheel.json` is a demo with bigger zones.
- `fixtures/` pins the loading rules. Each file has an `input` instrument and the `expect`ed result: whether it is accepted, the issue codes in order, and the repaired values. Every implementation must pass all of them (iOS: `InstrumentSpecTests.testSharedFixtures`).

## Loading rules

Fields a loader doesn't know are ignored, so newer files still open in older apps; generators must still follow the schema exactly. Files that are not instruments, use a newer `format_version`, have an invalid `id`, use a value outside the vocabulary, or exceed 16 KB are rejected. Values that are only out of range are repaired, with an issue code for each:

| Code | Repair |
|---|---|
| `name_trimmed` / `description_trimmed` | Trim whitespace, cut to 40 / 200 characters. An empty name is rejected (`name_missing`). |
| `radius_clamped` | Wheel radius into 0.7–1.0. |
| `rest_radius_clamped` | Rest hole into 0.2–0.5. |
| `octave_band_radius_clamped` | Octave rim into 0.6–0.92, and at least 0.25 outside the rest hole so the base band stays playable. |

## Version 1

One surface type, `split_wheel`: a circle cut into a chord half and a note half around a rest hole, with an outer octave rim. The file sets the geometry, the chord side, the note source (one octave of the player's scale, or the held chord's tones over three octaves), whether notes have an octave rim, and chord-tone highlighting. Future surfaces (grids, keys, pads, orbs) follow the same rule: zones say *which* scale degree, chord or drum they play, and the player's settings decide the actual pitches and sounds. New surface types and fields come with a new `format_version` or as optional fields that older apps ignore.
