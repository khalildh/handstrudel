// Runs under Deno (`deno test`) or Node: node --test supabase/functions/_shared/instrument-spec_test.ts
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { instrumentByteLimit, instrumentIssue, instrumentIsAIGenerated, postedInstrument } from "./instrument-spec.ts";

const test: (name: string, fn: () => void) => void =
  (globalThis as { Deno?: { test: typeof test } }).Deno?.test ?? (await import("node:test")).test;

const fixtures = new URL("../../../shared/instruments/fixtures/", import.meta.url);
const library = new URL("../../../shared/instruments/library/", import.meta.url);
const read = (dir: URL, file: string) => JSON.parse(readFileSync(new URL(file, dir), "utf8"));
const wide = () => read(library, "wide-wheel.json");

test("matches the loader on every shared fixture", () => {
  const files = readdirSync(fixtures).filter((f) => f.endsWith(".json"));
  assert.ok(files.length >= 10);
  for (const file of files) {
    const { input, expect } = read(fixtures, file);
    if (expect.issues[0] === "unsupported_version") {
      // A newer version is stored for newer apps; older loaders decline to open it.
      assert.equal(instrumentIssue(input), null, file);
      continue;
    }
    assert.equal(instrumentIssue(input), expect.accepted ? null : expect.issues[0], file);
  }
});

test("accepts every bundled instrument", () => {
  for (const file of readdirSync(library)) assert.equal(instrumentIssue(read(library, file)), null, file);
});

test("rejects files the loader rejects", () => {
  assert.equal(instrumentIssue(null), "malformed");
  assert.equal(instrumentIssue([wide()]), "malformed");
  assert.equal(instrumentIssue({ ...wide(), format_version: 1.5 }), "unsupported_version");
  assert.equal(instrumentIssue({ ...wide(), format_version: "1" }), "malformed");
  assert.equal(instrumentIssue({ ...wide(), name: 7 }), "malformed");
  assert.equal(instrumentIssue({ ...wide(), description: { text: "x" } }), "malformed");
  assert.equal(instrumentIssue({ ...wide(), chords: { side: "up" } }), "malformed");
  assert.equal(instrumentIssue({ ...wide(), notes: { source: "scale_one_octave" } }), "malformed");
  assert.equal(instrumentIssue({ ...wide(), surface: { ...wide().surface, radius: "big" } }), "malformed");
});

test("caps the file at 16 KB of compact JSON", () => {
  const base = JSON.stringify(wide()).length;
  const fits = { ...wide(), padding: "x".repeat(instrumentByteLimit - base - 13) };
  assert.equal(JSON.stringify(fits).length, instrumentByteLimit);
  assert.equal(instrumentIssue(fits), null);
  assert.equal(instrumentIssue({ ...fits, padding: fits.padding + "x" }), "too_large");
  // Multibyte names count in bytes, as the loader counts them.
  assert.equal(instrumentIssue({ ...fits, padding: fits.padding.slice(1) + "é" }), "too_large");
});

test("only checks the header of newer format versions", () => {
  const v2 = { format: "handstrudel.instrument", format_version: 2, id: "future.pads", name: "Pads", surface: { type: "pad_grid" } };
  assert.equal(instrumentIssue(v2), null);
  assert.equal(instrumentIssue({ ...v2, id: "Bad Id" }), "id_invalid");
  assert.equal(instrumentIssue({ ...v2, name: " " }), "name_missing");
  assert.equal(instrumentIssue({ ...v2, format_version: 100 }), "unsupported_version");
});

test("reads the AI marker from the file", () => {
  assert.equal(instrumentIsAIGenerated(wide()), false);
  assert.equal(instrumentIsAIGenerated({ ...wide(), ai_generated: true }), true);
  assert.equal(instrumentIsAIGenerated({ ...wide(), ai_generated: "yes" }), false);
  assert.equal(instrumentIsAIGenerated({ ...wide(), generator: { kind: "ai", model: "x" } }), true);
});

test("builds the post's instrument fields", () => {
  const source = "A0000000-0000-0000-0000-000000000001";
  assert.deepEqual(postedInstrument({ instrument_spec: wide(), instrument_source_id: source }), {
    instrument_spec: wide(), instrument_source_id: source.toLowerCase(),
    instrument_remixes_allowed: true, instrument_ai_generated: false,
  });
  const closed = postedInstrument({ instrument_spec: { ...wide(), ai_generated: true }, instrument_remixes_allowed: false });
  assert.equal(closed.instrument_remixes_allowed, false);
  assert.equal(closed.instrument_ai_generated, true);
  assert.equal(postedInstrument({ instrument_spec: wide(), instrument_ai_generated: true }).instrument_ai_generated, true);
  assert.equal(postedInstrument({ instrument_spec: wide(), instrument_source_id: "not-a-post" }).instrument_source_id, null);
});

test("drops an invalid instrument and its credit so the take still posts", () => {
  const none = { instrument_spec: null, instrument_source_id: null, instrument_remixes_allowed: true, instrument_ai_generated: false };
  assert.deepEqual(postedInstrument({}), none);
  assert.deepEqual(postedInstrument({ instrument_spec: { ...wide(), id: "Has Spaces!" },
    instrument_source_id: "a0000000-0000-0000-0000-000000000001", instrument_remixes_allowed: false }), none);
  assert.deepEqual(postedInstrument({ instrument_spec: { ...wide(), padding: "x".repeat(instrumentByteLimit) } }), none);
});
