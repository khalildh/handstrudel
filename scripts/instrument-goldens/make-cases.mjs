// Builds the loader inputs the Swift golden generator runs: every shared
// fixture plus edge cases the fixtures don't pin (types, Unicode, rounding).
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("../../shared/instruments/", import.meta.url).pathname;
const base = JSON.parse(readFileSync(join(root, "library/scale-wheel.json"), "utf8"));
const cases = [];
for (const file of readdirSync(join(root, "fixtures")).filter((f) => f.endsWith(".json")).sort()) {
  cases.push({ name: `fixture:${file}`, text: JSON.stringify(JSON.parse(readFileSync(join(root, "fixtures", file), "utf8")).input) });
}
const edit = (name, change) => {
  const spec = structuredClone(base);
  change(spec);
  cases.push({ name, text: JSON.stringify(spec) });
};
const raw = (name, text) => cases.push({ name, text });

raw("not json", "not json");
raw("array", "[]");
raw("null", "null");
raw("too large", " ".repeat(16 * 1024 + 1));
raw("exactly 16 KB of padding", JSON.stringify(base) + " ".repeat(16 * 1024 - JSON.stringify(base).length));
raw("format_version 1.0", JSON.stringify(base).replace('"format_version":1', '"format_version":1.0'));
raw("format_version 1e0", JSON.stringify(base).replace('"format_version":1', '"format_version":1e0'));
raw("radius 1e400", JSON.stringify(base).replace('"radius":1', '"radius":1e400'));
raw("duplicate name keys", JSON.stringify(base).replace('"name":"Scale Wheel"', '"name":"First","name":"Second"'));
edit("format is a number", (s) => { s.format = 1; });
edit("format missing", (s) => { delete s.format; });
edit("format null", (s) => { s.format = null; });
edit("format_version string", (s) => { s.format_version = "1"; });
edit("format_version 1.5", (s) => { s.format_version = 1.5; });
edit("format_version missing", (s) => { delete s.format_version; });
edit("future version with a broken body", (s) => { s.format_version = 2; s.surface = 7; });
edit("id with trailing newline", (s) => { s.id = "builtin.scale-wheel\n"; });
edit("id with leading dot", (s) => { s.id = ".wheel"; });
edit("id 80 characters", (s) => { s.id = "a".repeat(80); });
edit("id 81 characters", (s) => { s.id = "a".repeat(81); });
edit("id uppercase", (s) => { s.id = "Wheel"; });
edit("id number", (s) => { s.id = 5; });
edit("name NBSP and NEL", (s) => { s.name = " Wheel\u0085"; });
edit("name BOM", (s) => { s.name = "﻿Wheel"; });
edit("name ideographic space", (s) => { s.name = "　Wheel "; });
edit("name zero-width space only", (s) => { s.name = "\u200b"; });
edit("name zero-width spaces around", (s) => { s.name = "\u200bWheel\u200b"; });
edit("name word joiner and BOM", (s) => { s.name = "\u2060Wheel\ufeff"; });
edit("name tabs and newlines only", (s) => { s.name = "\t\n\r "; });
edit("name 45 flags", (s) => { s.name = "🇯🇵".repeat(45); });
edit("name 41 decomposed e-acute", (s) => { s.name = "é".repeat(41); });
edit("name 40 then spaces then more", (s) => { s.name = "x".repeat(39) + "   tail"; });
edit("name family emoji", (s) => { s.name = "👨‍👩‍👧‍👦".repeat(41); });
edit("description whitespace", (s) => { s.description = "   "; });
edit("description null", (s) => { s.description = null; });
edit("description missing", (s) => { delete s.description; });
edit("description 201", (s) => { s.description = "d".repeat(201); });
edit("description number", (s) => { s.description = 3; });
edit("highlight null", (s) => { s.notes.highlight_chord_tones = null; });
edit("highlight missing", (s) => { delete s.notes.highlight_chord_tones; });
edit("highlight 1", (s) => { s.notes.highlight_chord_tones = 1; });
edit("octave_band 1", (s) => { s.notes.octave_band = 1; });
edit("octave_band missing", (s) => { delete s.notes.octave_band; });
edit("radius string", (s) => { s.surface.radius = "1"; });
edit("radius integer", (s) => { s.surface.radius = 1; });
edit("radius null", (s) => { s.surface.radius = null; });
edit("side middle", (s) => { s.chords.side = "middle"; });
edit("side right", (s) => { s.chords.side = "right"; });
edit("source unknown", (s) => { s.notes.source = "scale_two_octaves"; });
edit("surface missing", (s) => { delete s.surface; });
edit("surface array", (s) => { s.surface = []; });
edit("chords extra field", (s) => { s.chords.colors = ["red"]; });
edit("rest 0.45 band 0.69", (s) => { s.surface.rest_radius = 0.45; s.surface.octave_band_radius = 0.69; });
edit("rest 0.3333333 band 0.5", (s) => { s.surface.rest_radius = 0.3333333; s.surface.octave_band_radius = 0.5; });
edit("rest 0.4 band 0.6", (s) => { s.surface.rest_radius = 0.4; s.surface.octave_band_radius = 0.6; });
edit("negative radii", (s) => { s.surface.radius = -1; s.surface.rest_radius = -1; s.surface.octave_band_radius = -1; });
edit("split wheel", (s) => { s.notes.source = "chord_tones_three_octaves"; s.notes.octave_band = false; });

writeFileSync(process.argv[2], JSON.stringify(cases, null, 1));
console.log(`${cases.length} cases`);
