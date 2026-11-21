// Offline tests for "Make your own instrument" with a mocked model.
//   npm run test:instrument-ai
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { INSTRUMENT_SCHEMA, SEED_INSTRUMENTS } from "./assets.generated.ts";
import { checkSchema, toStructuredOutputSchema } from "./json-schema.ts";
import { brandIn, moderatePrompt } from "./moderation.ts";
import { costUsd, generateInstrument, GenerateError, nearestSeed, sanitizeSuggestion } from "./generate.ts";
import { outputSchema, systemPrompt } from "./prompt.ts";
import { tierFromRevenueCat } from "./tier.ts";
import { musicLeaks, validateInstrument } from "./validate.ts";
import { MemoryQuota, scriptedModel, wheelAnswer } from "./mocks.ts";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..", "..");
const USER = "6f1c2a8e-1d2b-4c3d-9e8f-0a1b2c3d4e5f";
let clock = 0;
const deps = (model: ReturnType<typeof scriptedModel>, quota = new MemoryQuota()) => ({
  callModel: model, quota, now: () => (clock += 400), newId: () => "ai.0123456789ab",
});

test("a valid answer becomes an AI-made instrument the loader rules accept", async () => {
  const quota = new MemoryQuota();
  const model = scriptedModel([wheelAnswer()]);
  const result = await generateInstrument({ userId: USER, tier: "free", prompt: "a big glowing wheel" }, deps(model, quota));
  assert.equal(result.status, "ok");
  assert.equal(result.attempts, 1);
  assert.equal(result.ai_generated, true);
  assert.deepEqual(Object.keys(result.instrument).slice(0, 6), ["format", "format_version", "id", "name", "description", "ai_generated"]);
  assert.equal(result.instrument.id, "ai.0123456789ab");
  assert.equal(result.instrument.ai_generated, true);
  assert.deepEqual(validateInstrument(result.instrument, INSTRUMENT_SCHEMA), []);
  assert.equal(result.seed_id, "demo.wide-wheel", "'big' starts from the wide wheel");
  assert.deepEqual(result.quota, { used: 1, limit: 5, remaining: 4 });
  assert.equal(model.requests.length, 1);
  assert.equal(model.requests[0].model, "claude-haiku-5-5");
  assert.match(model.requests[0].messages[0].content, /"start_from":\{"name":"Wide Wheel"/);
  const record = quota.finished.get("gen-1")!;
  assert.equal(record.status, "ok");
  assert.equal(record.latencyMs, 400);
  assert.equal(record.result!.id, "ai.0123456789ab");
  assert.ok(record.costUsd! > 0 && record.costUsd! < 0.001, `cost ${record.costUsd} is under a tenth of a cent`);
});

test("an invalid answer is repaired by one retry that sees the errors", async () => {
  const quota = new MemoryQuota();
  const model = scriptedModel([
    wheelAnswer({ surface: { type: "split_wheel", radius: 1.3, rest_radius: 0.45, octave_band_radius: 0.6 } }),
    wheelAnswer({ surface: { type: "split_wheel", radius: 1.0, rest_radius: 0.45, octave_band_radius: 0.75 } }),
  ]);
  const result = await generateInstrument({ userId: USER, tier: "free", prompt: "chunky rim" }, deps(model, quota));
  assert.equal(result.status, "repaired");
  assert.equal(result.attempts, 2);
  assert.equal((result.instrument.surface as Record<string, number>).octave_band_radius, 0.75);
  const retry = model.requests[1].messages;
  assert.equal(retry.length, 3);
  assert.equal(retry[1].role, "assistant");
  assert.match(retry[2].content, /surface\.radius: must be <= 1/);
  assert.equal(quota.finished.get("gen-1")!.issues.length > 0, true);
  assert.equal(quota.claims.length, 1, "a repair doesn't cost the player a second generation");
});

test("a second invalid answer falls back to the nearest seed, never an error", async () => {
  const model = scriptedModel([
    wheelAnswer({ surface: { type: "spiral" } }),
    "not json at all",
  ]);
  const quota = new MemoryQuota();
  const result = await generateInstrument({ userId: USER, tier: "free", prompt: "arpeggio harp thing" }, deps(model, quota));
  assert.equal(result.status, "fallback");
  assert.equal(result.ai_generated, false);
  assert.equal(result.instrument.id, "builtin.split-wheel", "falls back to the seed the prompt matched");
  assert.deepEqual(result.instrument, SEED_INSTRUMENTS.find((s) => s.id === "builtin.split-wheel"));
  assert.equal(quota.finished.get("gen-1")!.status, "fallback");
});

test("model outages and refusals fall back without a retry storm", async () => {
  const outage = scriptedModel([new Error("529 overloaded")]);
  const down = await generateInstrument({ userId: USER, tier: "free", prompt: "anything" }, deps(outage));
  assert.equal(down.status, "fallback");
  assert.equal(outage.requests.length, 1);

  const refusing = scriptedModel([{ text: null, stopReason: "refusal", usage: { inputTokens: 10, outputTokens: 0 } }]);
  const refused = await generateInstrument({ userId: USER, tier: "free", prompt: "anything" }, deps(refusing));
  assert.equal(refused.status, "fallback");
  assert.equal(refusing.requests.length, 1);
});

test("quota exceeded stops before the model is called", async () => {
  const quota = new MemoryQuota({ free: 1 });
  const model = scriptedModel([wheelAnswer(), wheelAnswer()]);
  await generateInstrument({ userId: USER, tier: "free", prompt: "one" }, deps(model, quota));
  await assert.rejects(
    generateInstrument({ userId: USER, tier: "free", prompt: "two" }, deps(model, quota)),
    (e: unknown) => e instanceof GenerateError && e.status === 429 && e.code === "quota_exceeded"
      && (e.detail!.quota as { remaining: number }).remaining === 0,
  );
  assert.equal(model.requests.length, 1);
  const pro = await generateInstrument({ userId: USER, tier: "pro", prompt: "two" }, deps(model, quota));
  assert.equal(pro.quota.limit, 25, "Pro has its own, higher limit");
});

test("moderation blocks slurs and harassment before quota or model", async () => {
  for (const prompt of ["a wheel for f4gg0ts", "make kill yourself wheel", "n i g g e r drums"]) {
    const quota = new MemoryQuota();
    const model = scriptedModel([wheelAnswer()]);
    await assert.rejects(
      generateInstrument({ userId: USER, tier: "free", prompt }, deps(model, quota)),
      (e: unknown) => e instanceof GenerateError && e.status === 422 && e.code === "prompt_blocked",
      prompt,
    );
    assert.equal(model.requests.length, 0);
    assert.equal(quota.claims.length, 0, "blocked prompts don't use quota");
    assert.equal(quota.blocked.length, 1, "but are logged for review");
  }
  assert.equal(moderatePrompt("glassy arpeggio wheel with big rims").ok, true);
  assert.equal(moderatePrompt("a scunthorpe-proof grape drape").ok, true, "whole words only for short terms");
});

test("brand names and slurs in a generated name are repaired", async () => {
  const model = scriptedModel([
    wheelAnswer({ name: "Roland Wheel" }),
    wheelAnswer({ name: "Retro Box Wheel" }),
  ]);
  const result = await generateInstrument({ userId: USER, tier: "free", prompt: "like my roland drum machine" }, deps(model));
  assert.equal(result.status, "repaired");
  assert.equal(result.instrument.name, "Retro Box Wheel");
  assert.match(model.requests[1].messages[2].content, /brand or trademark "roland"/);
  assert.equal(brandIn("Stratocaster Strum"), "stratocaster");
  assert.equal(brandIn("Sunset Strum"), null);
});

test("music never leaks into the instrument: extra fields and key/scale/tempo names are rejected", async () => {
  const model = scriptedModel([
    wheelAnswer({ name: "D Minor Wheel", key: "D", scale: "minor", tempo: 70, sound: "piano" }),
    wheelAnswer({ name: "Rainy Wheel", description: "Soft wide wedges for slow playing." }, { key: "D", scale: "Minor", bpm: 70 }),
  ]);
  const result = await generateInstrument({ userId: USER, tier: "free", prompt: "a sad piano in D minor at 70 bpm" }, deps(model));
  assert.equal(result.status, "repaired");
  const repair = model.requests[1].messages[2].content;
  for (const field of ["key", "scale", "tempo", "sound"]) assert.match(repair, new RegExp(`\\$\\.${field}: unknown field`));
  assert.match(repair, /name: names a key or scale/);
  const allowed = Object.keys((INSTRUMENT_SCHEMA as { properties: object }).properties);
  for (const field of Object.keys(result.instrument)) assert.ok(allowed.includes(field), `${field} is a schema field`);
  assert.deepEqual(result.suggested_music, { key: "D", scale: "Minor", bpm: 70 }, "music goes to the suggestion");
  assert.deepEqual(musicLeaks({ name: "Glow", surface: { bpm: 90 } }, INSTRUMENT_SCHEMA).length, 1);
  assert.deepEqual(musicLeaks({ name: "Slow 80 BPM pads" }, INSTRUMENT_SCHEMA).length, 1);
  assert.deepEqual(musicLeaks({ name: "A minimal wheel" }, INSTRUMENT_SCHEMA), []);
});

test("suggestions keep only known keys and scales and a sane tempo", () => {
  assert.equal(sanitizeSuggestion(null), null);
  assert.equal(sanitizeSuggestion({ key: "H", scale: "Klingon", bpm: null }), null);
  assert.deepEqual(sanitizeSuggestion({ key: "Eb", scale: "Lydian", bpm: 999 }), { key: "Eb", scale: "Lydian", bpm: 200 });
  assert.deepEqual(sanitizeSuggestion({ key: null, scale: null, bpm: 12.4 }), { key: null, scale: null, bpm: 50 });
});

test("refine sends the current instrument and keeps its id", async () => {
  const first = await generateInstrument({ userId: USER, tier: "free", prompt: "glow wheel" }, deps(scriptedModel([wheelAnswer()])));
  const model = scriptedModel([wheelAnswer({ surface: { type: "split_wheel", radius: 1.0, rest_radius: 0.25, octave_band_radius: 0.85 } })]);
  const refined = await generateInstrument(
    { userId: USER, tier: "free", prompt: "bigger zones", current: first.instrument, originalPrompt: "glow wheel" },
    { ...deps(model), newId: () => "ai.ffffffffffff" },
  );
  assert.equal(refined.status, "ok");
  assert.equal(refined.instrument.id, first.instrument.id);
  const sent = JSON.parse(model.requests[0].messages[0].content);
  assert.equal(sent.request, "bigger zones");
  assert.equal(sent.original_request, "glow wheel");
  assert.equal(sent.start_from.name, "Glow Wheel");
  assert.equal(sent.start_from.id, undefined, "server fields aren't sent to the model");

  const failing = scriptedModel(["{}", "{}"]);
  const kept = await generateInstrument({ userId: USER, tier: "free", prompt: "more glow", current: first.instrument }, deps(failing));
  assert.equal(kept.status, "fallback");
  assert.deepEqual(kept.instrument, first.instrument, "a failed refine keeps the current instrument");

  await assert.rejects(generateInstrument({ userId: USER, tier: "free", prompt: "x", current: { name: "junk" } }, deps(scriptedModel([]))),
    (e: unknown) => e instanceof GenerateError && e.code === "current_invalid");
});

test("prompts are required and bounded", async () => {
  for (const prompt of ["", "   ", "x".repeat(301)]) {
    await assert.rejects(generateInstrument({ userId: USER, tier: "free", prompt }, deps(scriptedModel([]))),
      (e: unknown) => e instanceof GenerateError && e.status === 400);
  }
});

test("seeds: hint words and shared words pick the closest library instrument", () => {
  assert.equal(nearestSeed("huge zones for kids", SEED_INSTRUMENTS).id, "demo.wide-wheel");
  assert.equal(nearestSeed("arpeggiate the chord tones", SEED_INSTRUMENTS).id, "builtin.split-wheel");
  assert.equal(nearestSeed("something weird", SEED_INSTRUMENTS).id, "builtin.scale-wheel");
});

test("the validator agrees with the shared loader fixtures", () => {
  const dir = join(root, "shared", "instruments", "fixtures");
  for (const name of readdirSync(dir).filter((f) => f.endsWith(".json"))) {
    const fixture = JSON.parse(readFileSync(join(dir, name), "utf8"));
    const clean = fixture.expect.accepted && fixture.expect.issues.length === 0;
    const issues = validateInstrument(fixture.input, INSTRUMENT_SCHEMA).filter((i) => i.kind === "schema" || i.kind === "playability" || i.kind === "size");
    // Loaders ignore unknown fields for forward compatibility; generators must not write them.
    if (name === "ignores-unknown-fields.json") { assert.ok(issues.length > 0, name); continue; }
    assert.equal(issues.length === 0, clean, `${name}: ${issues.map((i) => i.message).join("; ")}`);
  }
  for (const seed of SEED_INSTRUMENTS) assert.deepEqual(validateInstrument(seed, INSTRUMENT_SCHEMA), [], String(seed.id));
});

test("the generator's copy of the schema and seeds matches shared/instruments", async () => {
  const { render } = await import(join(root, "scripts", "instrument-ai", "sync-assets.mjs"));
  assert.equal(readFileSync(join(root, "supabase", "functions", "_shared", "instrument-ai", "assets.generated.ts"), "utf8"), render(),
    "run node scripts/instrument-ai/sync-assets.mjs");
});

test("the structured-output schema only uses supported keywords, closes every object and accepts valid answers", () => {
  const schema = outputSchema(INSTRUMENT_SCHEMA);
  const text = JSON.stringify(schema);
  for (const keyword of ["minimum", "maximum", "minLength", "maxLength", "pattern", "oneOf", "\"default\""]) {
    assert.ok(!text.includes(`"${keyword.replace(/"/g, "")}"`), `${keyword} removed`);
  }
  const walk = (node: unknown) => {
    if (Array.isArray(node)) return node.forEach(walk);
    if (!node || typeof node !== "object") return;
    const n = node as Record<string, unknown>;
    if (n.type === "object") assert.equal(n.additionalProperties, false);
    Object.values(n).forEach(walk);
  };
  walk(schema);
  assert.deepEqual(checkSchema(wheelAnswer(), schema), []);
  assert.deepEqual(checkSchema(wheelAnswer({}, { key: "D", scale: "Minor", bpm: 80 }), schema), []);
  assert.ok(checkSchema(wheelAnswer({ id: "x" }), schema).length > 0, "server fields are not part of the answer");
  assert.ok(!JSON.stringify(toStructuredOutputSchema(INSTRUMENT_SCHEMA)).includes("\"maximum\""));
});

test("the system prompt is stable and built from the schema and every seed", () => {
  const a = systemPrompt(INSTRUMENT_SCHEMA, SEED_INSTRUMENTS);
  assert.equal(a, systemPrompt(INSTRUMENT_SCHEMA, SEED_INSTRUMENTS));
  for (const seed of SEED_INSTRUMENTS) assert.ok(a.includes(String(seed.name)));
  assert.ok(a.includes("octave_band_radius"));
  assert.ok(!a.includes("builtin."), "ids are server-owned");
});

test("cost estimate uses Haiku 5.5 prices", () => {
  assert.equal(costUsd("claude-haiku-5-5", { inputTokens: 1_000_000, outputTokens: 0 }), 0.10);
  assert.equal(costUsd("claude-haiku-5-5", { inputTokens: 0, outputTokens: 1_000_000 }), 0.50);
  assert.equal(costUsd("some-other-model", { inputTokens: 1, outputTokens: 1 }), null);
});

test("tiers come from RevenueCat entitlements, defaulting to free", async () => {
  const later = new Date(Date.now() + 86_400_000).toISOString();
  const reply = (entitlements: unknown, ok = true) => async (url: string, init?: RequestInit) => {
    assert.match(url, /\/subscribers\/6F1C2A8E-1D2B-4C3D-9E8F-0A1B2C3D4E5F$/);
    assert.equal((init!.headers as Record<string, string>).Authorization, "Bearer sk");
    return new Response(JSON.stringify({ subscriber: { entitlements } }), { status: ok ? 200 : 500 });
  };
  assert.equal(await tierFromRevenueCat(USER, undefined, reply({})), "free");
  assert.equal(await tierFromRevenueCat(USER, "sk", reply({ pro: { expires_date: null } })), "pro");
  assert.equal(await tierFromRevenueCat(USER, "sk", reply({ pro: { expires_date: null }, plus_features: { expires_date: later } })), "plus");
  assert.equal(await tierFromRevenueCat(USER, "sk", reply({ plus_features: { expires_date: "2020-01-01T00:00:00Z" } })), "free");
  assert.equal(await tierFromRevenueCat(USER, "sk", reply({}, false)), "free");
  assert.equal(await tierFromRevenueCat(USER, "sk", () => Promise.reject(new Error("down"))), "free");
});
