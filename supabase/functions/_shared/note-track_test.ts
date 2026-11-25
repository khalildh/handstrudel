import assert from "node:assert/strict";
import { noteTrack } from "./note-track.ts";

Deno.test("keeps a well-formed track and drops unknown fields", () => {
  const input = { v: 1, notes: [{ t: 0, d: 0.5, m: 60, extra: "x" }, { t: 0.5, d: 1, m: 64, c: true }], other: 1 };
  assert.deepEqual(noteTrack(input), { v: 1, notes: [{ t: 0, d: 0.5, m: 60 }, { t: 0.5, d: 1, m: 64, c: true }] });
});

Deno.test("rejects malformed tracks", () => {
  assert.deepEqual(noteTrack(null), null);
  assert.deepEqual(noteTrack([]), null);
  assert.deepEqual(noteTrack({ v: 2, notes: [{ t: 0, d: 1, m: 60 }] }), null);
  assert.deepEqual(noteTrack({ v: 1, notes: [] }), null);
  assert.deepEqual(noteTrack({ v: 1, notes: [{ t: -1, d: 1, m: 60 }] }), null);
  assert.deepEqual(noteTrack({ v: 1, notes: [{ t: 0, d: 0, m: 60 }] }), null);
  assert.deepEqual(noteTrack({ v: 1, notes: [{ t: 0, d: 1, m: 128 }] }), null);
  assert.deepEqual(noteTrack({ v: 1, notes: [{ t: 0, d: 1, m: 60.5 }] }), null);
  assert.deepEqual(noteTrack({ v: 1, notes: [{ t: 0, d: 1, m: 60, c: "yes" }] }), null);
});

Deno.test("caps the number of notes", () => {
  const notes = Array.from({ length: 601 }, (_, i) => ({ t: i / 20, d: 0.05, m: 60 }));
  assert.deepEqual(noteTrack({ v: 1, notes }), null);
  assert.deepEqual(noteTrack({ v: 1, notes: notes.slice(0, 600) })?.notes.length, 600);
});
