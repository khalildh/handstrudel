// Offline checks for the eval runner (no key needed):
//   npm run test:instrument-ai
import assert from "node:assert/strict";
import { test } from "node:test";
import { SEED_INSTRUMENTS } from "../../supabase/functions/_shared/instrument-ai/assets.generated.ts";
import { judge, loadCases, mockModel, inProcessRunner, passes, runEvals, summarize } from "./run.ts";

test("the prompt set has about 100 cases across the five categories", () => {
  const cases = loadCases();
  assert.equal(cases.length, 100);
  assert.equal(new Set(cases.map((c) => c.id)).size, 100);
  for (const category of ["simple", "genre", "abstract", "adversarial", "music_only"]) {
    assert.equal(cases.filter((c) => c.category === category).length, 20, category);
  }
});

test("the full pipeline passes the release gate with the mock model", async () => {
  const results = await runEvals(loadCases(), inProcessRunner(mockModel()));
  const summary = summarize(results);
  assert.ok(passes(summary), JSON.stringify(summary));
  assert.equal(summary.musicLeaks, 0);
  assert.equal(summary.errors, 0);
  assert.equal(summary.expectationsMetPct, 100);
  assert.deepEqual(results.filter((r) => r.outcome === "blocked").map((r) => r.id).sort(),
    ["adversarial-11", "adversarial-12", "adversarial-20"]);
  assert.ok(summary.repairRatePct > 0, "the mock's out-of-range first answers exercise repairs");
  assert.ok(summary.costUsd!.perGeneration < 0.001, "under a tenth of a cent per generation at Haiku 5.5 prices");
  const adversarial = results.filter((r) => r.category === "adversarial" && r.outcome !== "blocked");
  for (const r of adversarial) assert.ok(r.checks.valid && r.checks.clean, `${r.id}: ${r.issues}`);
  assert.ok(!results.some((r) => /roland|yamaha|nintendo|mario/i.test(r.name ?? "")), "brand names never survive");
});

test("the judge catches invalid, leaking and unexpected outputs", () => {
  const seed = SEED_INSTRUMENTS[0];
  const base = { costUsd: 0, latencyMs: 10 };
  const response = (instrument: Record<string, unknown>, extra: Record<string, unknown> = {}) => ({
    ...base,
    response: { instrument, suggested_music: null, status: "ok" as const, ai_generated: true, seed_id: "builtin.scale-wheel",
      attempts: 1, latency_ms: 10, quota: { used: 1, limit: 5, remaining: 4 }, ...extra },
  });
  const testCase = { id: "t", category: "music_only", prompt: "x", expect: { suggestion: true } };

  const leaking = judge(testCase, response({ ...seed, name: "Sad Wheel in D Minor", tempo: 70 }));
  assert.equal(leaking.checks.noMusicLeak, false);
  assert.equal(leaking.checks.valid, false, "unknown fields are schema errors");
  assert.equal(leaking.checks.expectation, false, "music-only prompts need a suggestion");

  const broken = judge({ ...testCase, expect: {} }, response({ ...seed, surface: { type: "split_wheel", radius: 2, rest_radius: 0.5, octave_band_radius: 0.6 } }));
  assert.equal(broken.checks.valid, false);

  const branded = judge({ ...testCase, expect: {} }, response({ ...seed, name: "Yamaha Wheel" }));
  assert.equal(branded.checks.clean, false);

  const blockedWhenExpected = judge({ id: "a", category: "adversarial", prompt: "x", expect: { blocked: true } }, { ...base, blocked: true });
  assert.equal(blockedWhenExpected.checks.expectation, true);
  const notBlocked = judge({ id: "a", category: "adversarial", prompt: "x", expect: { blocked: true } }, response(seed));
  assert.equal(notBlocked.checks.expectation, false);

  const summary = summarize([leaking, broken]);
  assert.equal(passes(summary), false);
  assert.equal(summary.musicLeaks, 1);
});
