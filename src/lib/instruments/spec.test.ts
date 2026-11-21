// Run: npm run test:instruments
// Checks the web port of the instrument format against the shared fixtures
// (exactly what InstrumentSpecTests.testSharedFixtures checks on iOS) and
// against answers recorded from the real Swift code (swift-goldens.json, see
// scripts/instrument-goldens).
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import {
  chordDisplayName, chordNameSuffix, chordTones, chordToneLanes, noteLanes, STANDARD_GEOMETRY, swapHands, wheelRules,
} from "./rules.ts";
import { BYTE_LIMIT, loadInstrument, loadInstrumentValue, parseJSON, type InstrumentSpec } from "./spec.ts";
import { splitOctaveShift, zoneAt, type WheelLayout } from "./wheel.ts";

const root = join(import.meta.dirname, "../../../shared/instruments");
const readJSON = (path: string) => JSON.parse(readFileSync(path, "utf8"));
const jsonFiles = (folder: string) => readdirSync(join(root, folder)).filter((f) => f.endsWith(".json")).sort();
const library = (id: string): InstrumentSpec => {
  const file = jsonFiles("library").find((f) => readJSON(join(root, "library", f)).id === id)!;
  return loadInstrument(readFileSync(join(root, "library", file))).spec!;
};

test("every shared fixture loads exactly as on iOS", () => {
  const files = jsonFiles("fixtures");
  assert.ok(files.length >= 10);
  for (const name of files) {
    const fixture = readJSON(join(root, "fixtures", name));
    const result = loadInstrument(JSON.stringify(fixture.input));
    const expect = fixture.expect;
    assert.equal(result.accepted, expect.accepted, name);
    assert.deepEqual(result.issues, expect.issues, name);
    if (!result.spec) continue;
    if (expect.surface) {
      assert.equal(result.spec.surface.radius, expect.surface.radius, name);
      assert.equal(result.spec.surface.rest_radius, expect.surface.rest_radius, name);
      assert.equal(result.spec.surface.octave_band_radius, expect.surface.octave_band_radius, name);
    }
    if (expect.name !== undefined) assert.equal(result.spec.name, expect.name, name);
    // A repaired instrument loads cleanly the second time.
    assert.deepEqual(loadInstrument(JSON.stringify(result.spec)).issues, [], name);
  }
});

test("oversized and non-JSON files are rejected", () => {
  assert.deepEqual(loadInstrument(new Uint8Array(BYTE_LIMIT + 1).fill(32)).issues, ["too_large"]);
  assert.deepEqual(loadInstrument("not json").issues, ["malformed"]);
  assert.deepEqual(loadInstrument("[]").issues, ["malformed"]);
  assert.deepEqual(loadInstrument(new Uint8Array([0x7b, 0xff, 0x7d])).issues, ["malformed"]);
});

test("the bundled library loads cleanly", () => {
  for (const file of jsonFiles("library")) {
    assert.deepEqual(loadInstrument(readFileSync(join(root, "library", file))).issues, [], file);
  }
});

test("loads instruments that arrive as JSON values", () => {
  const spec = readJSON(join(root, "library/split-wheel.json"));
  assert.equal(loadInstrumentValue(spec).spec?.id, "builtin.split-wheel");
  assert.equal(loadInstrumentValue(JSON.stringify(spec)).spec?.id, "builtin.split-wheel");
  assert.deepEqual(loadInstrumentValue(null).issues, ["malformed"]);
  assert.deepEqual(loadInstrumentValue(undefined).issues, ["malformed"]);
  assert.deepEqual(loadInstrumentValue({ ...spec, padding: "x".repeat(BYTE_LIMIT) }).issues, ["too_large"]);
});

test("parseJSON matches JSON.parse except that the first duplicate key wins", () => {
  for (const text of ['{"a":[1,2,{"b":null}],"c":"\\u00e9\\n","d":-1.5e3,"e":true}', "[]", "0", '"x"', ' {"__proto__": 1} ']) {
    assert.deepEqual(parseJSON(text), JSON.parse(text), text);
  }
  assert.deepEqual(parseJSON('{"a":1,"a":2}'), { a: 1 });
  for (const bad of ["", "{", '{"a":}', "[1,]", "01", "tru", '"\u0001"', "1 2", "{'a':1}"]) {
    assert.throws(() => parseJSON(bad), SyntaxError, bad);
  }
});

const goldens = JSON.parse(readFileSync(join(import.meta.dirname, "swift-goldens.json"), "utf8"));

test("the loader agrees with the Swift loader on every golden case", () => {
  assert.ok(goldens.loads.length >= 60);
  for (const golden of goldens.loads) {
    const result = loadInstrument(golden.text);
    assert.equal(result.accepted, golden.accepted, golden.name);
    assert.deepEqual(result.issues, golden.issues, golden.name);
    // Swift's encoder writes the repaired spec; compare field for field.
    if (golden.spec) assert.deepEqual(JSON.parse(JSON.stringify(result.spec)), JSON.parse(golden.spec), golden.name);
  }
});

test("wheel rules agree with Swift for every key, scale and degree", () => {
  const scale = wheelRules(library("builtin.scale-wheel"));
  const split = wheelRules(library("builtin.split-wheel"));
  assert.ok(goldens.rules.length > 900);
  for (const row of goldens.rules) {
    const label = `${row.key} ${row.scale} degree ${row.degree}`;
    const key: number = row.semitone;
    const intervals: number[] = row.intervals;
    assert.deepEqual(chordTones(scale, key, intervals, row.degree), row.scaleChord, label);
    assert.deepEqual(chordTones(split, key, intervals, row.degree), row.splitChord, label);
    const lanes = noteLanes(scale, key, intervals, row.degree);
    const splitLanes = noteLanes(split, key, intervals, row.degree);
    assert.deepEqual(lanes, row.scaleLanes, label);
    assert.deepEqual(splitLanes, row.splitLanes, label);
    assert.deepEqual([...chordToneLanes(scale, key, intervals, row.degree, lanes)].sort((a, b) => a - b), row.scaleChordToneLanes, label);
    assert.deepEqual([...chordToneLanes(split, key, intervals, row.degree, splitLanes)], row.splitChordToneLanes, label);
    assert.equal(chordDisplayName(key, intervals, row.degree), row.chordName, label);
  }
  assert.equal(chordNameSuffix(scale), goldens.suffix.scale);
  assert.equal(chordNameSuffix(split), goldens.suffix.split);
  assert.deepEqual([swapHands(scale, false), swapHands(scale, true)], goldens.swapHands);
});

// InstrumentSpecTests.testBuiltInWheelFilesMatchTheOriginalWheels / testChordToneHighlightFollowsTheInstrument
test("built-in wheel files describe the original wheels", () => {
  assert.deepEqual(wheelRules(library("builtin.scale-wheel")), {
    geometry: STANDARD_GEOMETRY, chordsOnRight: false, voicing: "seventh",
    noteSource: "scale_one_octave", notesOctaveBand: true, highlightChordTones: true,
  });
  assert.deepEqual(wheelRules(library("builtin.split-wheel")), {
    geometry: STANDARD_GEOMETRY, chordsOnRight: false, voicing: "triad",
    noteSource: "chord_tones_three_octaves", notesOctaveBand: false, highlightChordTones: false,
  });
  const major = [0, 2, 4, 5, 7, 9, 11];
  const scale = wheelRules(library("builtin.scale-wheel"));
  const lanes = noteLanes(scale, 0, major, 0);
  assert.deepEqual(lanes, [60, 62, 64, 65, 67, 69, 71]);
  assert.deepEqual([...chordToneLanes(scale, 0, major, 0, lanes)], [0, 2, 4, 6]);
  assert.deepEqual([...chordToneLanes(wheelRules(library("builtin.split-wheel")), 0, major, 0, lanes)], []);
  // D pentatonic on the wide wheel: one wedge per scale note, Scale-wheel voicing.
  const wide = wheelRules(library("demo.wide-wheel"));
  assert.deepEqual(wide.geometry, { radius: 1.0, restRadius: 0.26, octaveBandRadius: 0.7 });
  assert.equal(noteLanes(wide, 2, [0, 2, 4, 7, 9], 0).length, 5);
  assert.deepEqual(chordTones(wide, 2, [0, 2, 4, 7, 9], 0), [50, 54, 59, 64]);
});

// InstrumentSpecTests.testChordSideIsMirroredBySwapHands
test("the chord side is mirrored by swap-hands", () => {
  const rules = wheelRules(library("builtin.scale-wheel"));
  assert.equal(swapHands(rules, false), false);
  assert.equal(swapHands(rules, true), true);
  rules.chordsOnRight = true;
  assert.equal(swapHands(rules, false), true);
  assert.equal(swapHands(rules, true), false);
});

// InstrumentSpecTests.testTouchUsesTheInstrumentsRestHoleAndOctaveRim, in the
// wheel's own units (a 400pt view: half the shorter side is 200).
test("touch zones use the instrument's rest hole and octave rim", () => {
  const layout: WheelLayout = {
    geometry: STANDARD_GEOMETRY, chordsOnRight: false, chordCount: 4, noteCount: 5, notesOctaveBand: true,
  };
  const point = (degrees: number, fraction: number, radius: number) => {
    const a = (degrees * Math.PI) / 180;
    return [Math.sin(a) * radius * fraction, Math.cos(a) * radius * fraction] as const;
  };
  const wedge = 180 / 5;
  assert.equal(zoneAt(layout, ...point(0.5 * wedge, 0.32, 1)), null, "0.32 is still the rest hole");
  layout.geometry = { radius: 0.94, restRadius: 0.28, octaveBandRadius: 0.74 };
  assert.deepEqual(zoneAt(layout, ...point(0.5 * wedge, 0.32, 0.94)), { kind: "note", lane: 4, octave: 0 });
  assert.deepEqual(zoneAt(layout, ...point(0.25 * wedge, 0.77, 0.94)), { kind: "note", lane: 4, octave: 1 });
  assert.deepEqual(zoneAt(layout, ...point(0.75 * wedge, 0.77, 0.94)), { kind: "note", lane: 4, octave: -1 });
  assert.equal(zoneAt(layout, ...point(0.5 * wedge, 0.25, 0.94)), null);
  // The chord half is the left semicircle; wedge 0 is at the top.
  assert.deepEqual(zoneAt(layout, ...point(-0.5 * 45, 0.5, 0.94)), { kind: "chord", wedge: 0, octave: 0 });
  assert.deepEqual(zoneAt(layout, ...point(-(180 - 10), 0.9, 0.94)), { kind: "chord", wedge: 3, octave: -1 });
  // Swapped: chords on the right.
  assert.deepEqual(zoneAt({ ...layout, chordsOnRight: true }, ...point(10, 0.5, 0.94)), { kind: "chord", wedge: 0, octave: 0 });
});

// InstrumentSpecTests.testHandTrackedOctaveRimFollowsTheInstrumentGeometry
test("the hand-tracked octave rim follows the instrument geometry", () => {
  assert.equal(splitOctaveShift(STANDARD_GEOMETRY, "right", 5, 0.85, 0, 7), 1);
  assert.equal(splitOctaveShift({ radius: 1, restRadius: 0.3, octaveBandRadius: 0.9 }, "right", 5, 0.85, 0, 7), 0);
});
