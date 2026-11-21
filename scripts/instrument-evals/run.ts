#!/usr/bin/env node
// Evals for "Make your own instrument" (generate-instrument).
//
//   node scripts/instrument-evals/run.ts --mock                 # offline, deterministic mock model (CI)
//   ANTHROPIC_API_KEY=… node scripts/instrument-evals/run.ts    # real model, generator run in-process
//   HANDSTRUDEL_EVAL_JWT=… node scripts/instrument-evals/run.ts --function-url https://<ref>.supabase.co/functions/v1/generate-instrument
//
// Options: --only <category|id>  --limit N  --out report.json  --model <id>  --concurrency N
//
// Every output is re-checked here with the same validator the function uses,
// so a bug in the function's own checks still shows up as invalid. Reports:
// schema validity, playability, music leaks (hard and soft), moderation,
// repair and fallback rates, latency (p50/p95) and cost.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { INSTRUMENT_SCHEMA } from "../../supabase/functions/_shared/instrument-ai/assets.generated.ts";
import {
  type CallModel, DEFAULT_MODEL, generateInstrument, GenerateError, type GenerateResponse, type ModelRequest,
} from "../../supabase/functions/_shared/instrument-ai/generate.ts";
import { MemoryQuota } from "../../supabase/functions/_shared/instrument-ai/mocks.ts";
import { soundWordsIn, validateInstrument } from "../../supabase/functions/_shared/instrument-ai/validate.ts";

export type EvalCase = {
  id: string;
  category: string;
  prompt: string;
  expect?: { blocked?: boolean; suggestion?: boolean; seed?: string };
};

export type CaseResult = {
  id: string;
  category: string;
  prompt: string;
  outcome: "ok" | "repaired" | "fallback" | "blocked" | "error";
  latencyMs: number;
  costUsd: number | null;
  name?: string;
  issues: string[];
  softMusic: string[];
  suggestion: unknown;
  checks: { valid: boolean; playable: boolean; noMusicLeak: boolean; clean: boolean; expectation: boolean };
  error?: string;
};

const here = dirname(fileURLToPath(import.meta.url));

export function loadCases(): EvalCase[] {
  return JSON.parse(readFileSync(join(here, "prompts.json"), "utf8")).cases;
}

// MARK: Models

/** An offline stand-in for the model: edits the seed from keywords, sometimes
 *  wrongly on the first try so the repair path is exercised, and fixes what a
 *  repair message lists. Deterministic. */
export function mockModel(): CallModel {
  return (request: ModelRequest) => {
    const first = JSON.parse(request.messages[0].content) as { request: string; start_from: Record<string, any> };
    const repairing = request.messages.length > 1;
    const prompt = first.request.toLowerCase();
    const instrument = structuredClone(first.start_from);
    instrument.surface = { ...instrument.surface };
    instrument.notes = { ...instrument.notes };
    instrument.chords = { ...instrument.chords };
    if (/\b(big|bigger|huge|wide|widest|easy|kids|fills|without looking|thick)\b/.test(prompt)) {
      Object.assign(instrument.surface, { radius: 1.0, rest_radius: 0.25, octave_band_radius: 0.85 });
    }
    if (/\b(small|compact|thin|minimal)\b/.test(prompt)) Object.assign(instrument.surface, { radius: 0.8, octave_band_radius: 0.86 });
    if (/smaller rest|rest hole smaller/.test(prompt)) instrument.surface.rest_radius = 0.22;
    if (/huge rest|big rest/.test(prompt)) Object.assign(instrument.surface, { rest_radius: 0.5, octave_band_radius: 0.8 });
    if (/chords on the right|left-handed|other side/.test(prompt)) instrument.chords.side = "right";
    if (/chords on the left/.test(prompt)) instrument.chords.side = "left";
    if (/arpeggi|chord tones|harp|three octaves/.test(prompt)) {
      Object.assign(instrument.notes, { source: "chord_tones_three_octaves", octave_band: false });
    }
    if (/one octave|just the scale/.test(prompt)) instrument.notes.source = "scale_one_octave";
    if (/no octave rim/.test(prompt)) instrument.notes.octave_band = false;
    if (/highlight|glow/.test(prompt)) instrument.notes.highlight_chord_tones = true;

    const words = first.request.replace(/[^A-Za-z ]/g, " ").split(/\s+/).filter((w) => w.length > 3).slice(0, 2);
    const title = words.map((w) => w[0].toUpperCase() + w.slice(1).toLowerCase()).join(" ");
    instrument.name = repairing ? `${words[0] ? "Custom" : "My"} Wheel` : `${title || "My"} Wheel`;
    instrument.description = "A wheel shaped by your words. It plays your key, scale and chords.";
    // Out-of-range values on the first try, as a model might write them.
    if (!repairing && /radius to 5|huge zones|widest/.test(prompt)) instrument.surface.radius = 1.2;
    if (!repairing && /midi_notes/.test(prompt)) instrument.midi_notes = [60, 64, 67];

    const key = first.request.match(/\b([A-G])(?:\s?(flat|sharp|b|#))?\b(?=\s+(?:major|minor|lydian|dorian|mixolydian|phrygian|blues|harmonic|pentatonic)|$)/i)
      ?? first.request.match(/key of ([A-G])/i) ?? first.request.match(/\bin ([A-G])(?:\s(flat|sharp))?\b/);
    const accidental = key?.[2] && /flat|b/i.test(key[2]) ? "b" : key?.[2] ? "#" : "";
    const sharps: Record<string, string> = { "C#": "Db", "D#": "Eb", "F#": "Gb", "G#": "Ab", "A#": "Bb" };
    const keyName = key ? (sharps[key[1].toUpperCase() + accidental] ?? key[1].toUpperCase() + accidental) : null;
    const scales: [RegExp, string][] = [[/phrygian dominant/i, "Phrygian Dominant"], [/harmonic minor/i, "Harmonic Minor"],
      [/whole tone/i, "Whole Tone"], [/hirajoshi/i, "Hirajoshi"], [/pentatonic/i, "Pentatonic"], [/blues/i, "Blues"],
      [/dorian/i, "Dorian"], [/lydian/i, "Lydian"], [/mixolydian/i, "Mixolydian"], [/minor|sad|melancholy/i, "Minor"],
      [/major|happy/i, "Major"]];
    const scale = scales.find(([pattern]) => pattern.test(first.request))?.[1] ?? null;
    const bpm = Number(first.request.match(/(\d{2,3})\s?bpm/i)?.[1] ?? first.request.match(/at (\d{2,3})\b/)?.[1] ?? NaN);
    const suggestion = keyName || scale || Number.isFinite(bpm)
      ? { key: keyName, scale, bpm: Number.isFinite(bpm) ? bpm : null } : null;
    const text = JSON.stringify({ instrument, suggested_music: suggestion });
    return Promise.resolve({
      text,
      stopReason: "end_turn",
      usage: {
        inputTokens: Math.round((request.system.length + JSON.stringify(request.messages).length) / 4),
        outputTokens: Math.round(text.length / 4),
      },
    });
  };
}

/** The real model, through the Anthropic SDK (same request as the function). */
export async function anthropicModel(): Promise<CallModel> {
  const { default: Anthropic } = await import("@anthropic-ai/sdk");
  const client = new Anthropic({ timeout: 15_000, maxRetries: 1 });
  return async (request) => {
    const response = await client.messages.create({
      model: request.model,
      max_tokens: request.maxTokens,
      system: [{ type: "text", text: request.system, cache_control: { type: "ephemeral" } }],
      messages: request.messages,
      thinking: { type: "disabled" },
      output_config: { effort: "low", format: { type: "json_schema", schema: request.outputSchema } },
    });
    const text = response.content.find((block) => block.type === "text");
    return {
      text: text && text.type === "text" ? text.text : null,
      stopReason: response.stop_reason ?? "end_turn",
      usage: {
        inputTokens: response.usage.input_tokens,
        outputTokens: response.usage.output_tokens,
        cacheReadTokens: response.usage.cache_read_input_tokens ?? 0,
        cacheWriteTokens: response.usage.cache_creation_input_tokens ?? 0,
      },
    };
  };
}

// MARK: Running

type Runner = (testCase: EvalCase) => Promise<{ response?: GenerateResponse; blocked?: boolean; error?: string; costUsd: number | null; latencyMs: number }>;

/** Runs the generator in-process with an in-memory quota. */
export function inProcessRunner(callModel: CallModel, model = DEFAULT_MODEL): Runner {
  return async (testCase) => {
    const quota = new MemoryQuota({ free: 1_000_000 });
    const started = performance.now();
    try {
      const response = await generateInstrument({ userId: "eval", tier: "free", prompt: testCase.prompt }, { callModel, quota, model });
      const record = [...quota.finished.values()][0];
      return { response, costUsd: record?.costUsd ?? null, latencyMs: Math.round(performance.now() - started) };
    } catch (e) {
      const latencyMs = Math.round(performance.now() - started);
      if (e instanceof GenerateError && e.code === "prompt_blocked") return { blocked: true, costUsd: 0, latencyMs };
      return { error: e instanceof Error ? e.message : String(e), costUsd: null, latencyMs };
    }
  };
}

/** Calls a deployed generate-instrument function (uses that account's quota). */
export function functionRunner(url: string, jwt: string, anonKey?: string): Runner {
  return async (testCase) => {
    const started = performance.now();
    const response = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json", ...(anonKey ? { apikey: anonKey } : {}) },
      body: JSON.stringify({ prompt: testCase.prompt }),
    });
    const latencyMs = Math.round(performance.now() - started);
    const body = await response.json().catch(() => ({}));
    if (response.status === 422) return { blocked: true, costUsd: 0, latencyMs };
    if (!response.ok) return { error: `HTTP ${response.status}: ${body.error ?? ""}`, costUsd: null, latencyMs };
    return { response: body as GenerateResponse, costUsd: null, latencyMs };
  };
}

export function judge(testCase: EvalCase, run: Awaited<ReturnType<Runner>>): CaseResult {
  const base = { id: testCase.id, category: testCase.category, prompt: testCase.prompt, latencyMs: run.latencyMs, costUsd: run.costUsd };
  if (run.blocked) {
    const expectation = testCase.expect?.blocked === true || testCase.category === "adversarial";
    return { ...base, outcome: "blocked", issues: [], softMusic: [], suggestion: null,
      checks: { valid: true, playable: true, noMusicLeak: true, clean: true, expectation } };
  }
  if (!run.response) {
    return { ...base, outcome: "error", issues: [run.error ?? "no response"], softMusic: [], suggestion: null, error: run.error,
      checks: { valid: false, playable: false, noMusicLeak: false, clean: false, expectation: false } };
  }
  const { response } = run;
  const issues = validateInstrument(response.instrument, INSTRUMENT_SCHEMA);
  const valid = !issues.some((i) => i.kind === "schema" || i.kind === "size");
  const playable = valid && !issues.some((i) => i.kind === "playability");
  const noMusicLeak = !issues.some((i) => i.kind === "music");
  const clean = !issues.some((i) => i.kind === "moderation");
  let expectation = true;
  if (testCase.expect?.blocked) expectation = false;
  if (testCase.expect?.suggestion && !response.suggested_music) expectation = false;
  if (testCase.expect?.seed && response.seed_id !== testCase.expect.seed) expectation = false;
  return {
    ...base,
    outcome: response.status,
    name: String(response.instrument.name ?? ""),
    issues: issues.map((i) => `${i.kind}: ${i.message}`),
    softMusic: response.ai_generated ? soundWordsIn(response.instrument) : [],
    suggestion: response.suggested_music,
    checks: { valid, playable, noMusicLeak, clean, expectation },
  };
}

export async function runEvals(cases: EvalCase[], runner: Runner, concurrency = 4): Promise<CaseResult[]> {
  const results: CaseResult[] = new Array(cases.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(concurrency, cases.length) }, async () => {
    while (next < cases.length) {
      const index = next++;
      results[index] = judge(cases[index], await runner(cases[index]));
    }
  }));
  return results;
}

const percentile = (values: number[], p: number) => {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)];
};
const rate = (n: number, d: number) => (d ? Math.round((n / d) * 1000) / 10 : 100);

export function summarize(results: CaseResult[]) {
  const answered = results.filter((r) => r.outcome !== "blocked" && r.outcome !== "error");
  const generated = answered.filter((r) => r.outcome !== "fallback");
  const costs = results.map((r) => r.costUsd).filter((c): c is number => typeof c === "number");
  const byCategory: Record<string, { cases: number; ok: number; repaired: number; fallback: number; blocked: number; error: number; expectationsMet: number }> = {};
  for (const r of results) {
    const c = byCategory[r.category] ??= { cases: 0, ok: 0, repaired: 0, fallback: 0, blocked: 0, error: 0, expectationsMet: 0 };
    c.cases++;
    c[r.outcome]++;
    if (r.checks.expectation) c.expectationsMet++;
  }
  return {
    cases: results.length,
    schemaValidPct: rate(answered.filter((r) => r.checks.valid).length, answered.length),
    playablePct: rate(answered.filter((r) => r.checks.playable).length, answered.length),
    musicLeaks: answered.filter((r) => !r.checks.noMusicLeak).length,
    softMusicMentions: answered.filter((r) => r.softMusic.length).length,
    moderationMisses: answered.filter((r) => !r.checks.clean).length,
    firstTryPct: rate(answered.filter((r) => r.outcome === "ok").length, answered.length),
    repairRatePct: rate(answered.filter((r) => r.outcome === "repaired").length, answered.length),
    fallbackRatePct: rate(answered.filter((r) => r.outcome === "fallback").length, answered.length),
    blocked: results.filter((r) => r.outcome === "blocked").length,
    errors: results.filter((r) => r.outcome === "error").length,
    expectationsMetPct: rate(results.filter((r) => r.checks.expectation).length, results.length),
    suggestionsOnMusicOnlyPct: rate(results.filter((r) => r.category === "music_only" && r.suggestion).length,
      results.filter((r) => r.category === "music_only").length),
    aiGenerated: generated.length,
    latencyMs: { p50: percentile(results.map((r) => r.latencyMs), 50), p95: percentile(results.map((r) => r.latencyMs), 95) },
    costUsd: costs.length ? {
      total: Math.round(costs.reduce((a, b) => a + b, 0) * 1e6) / 1e6,
      perGeneration: Math.round((costs.reduce((a, b) => a + b, 0) / Math.max(1, costs.length)) * 1e8) / 1e8,
    } : null,
    byCategory,
  };
}

/** Release gate: every answer valid and playable, no hard music leaks, no
 *  moderation misses, no errors. */
export function passes(summary: ReturnType<typeof summarize>) {
  return summary.schemaValidPct === 100 && summary.playablePct === 100 && summary.musicLeaks === 0
    && summary.moderationMisses === 0 && summary.errors === 0;
}

async function main() {
  const args = process.argv.slice(2);
  const option = (name: string) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
  let cases = loadCases();
  const only = option("--only");
  if (only) cases = cases.filter((c) => c.category === only || c.id === only);
  const limit = Number(option("--limit") ?? NaN);
  if (Number.isFinite(limit)) cases = cases.slice(0, limit);
  const model = option("--model") ?? process.env.ANTHROPIC_INSTRUMENT_MODEL ?? DEFAULT_MODEL;

  let runner: Runner;
  let mode: string;
  if (args.includes("--mock")) {
    runner = inProcessRunner(mockModel(), model);
    mode = "mock model (offline)";
  } else if (option("--function-url")) {
    const jwt = process.env.HANDSTRUDEL_EVAL_JWT;
    if (!jwt) throw new Error("Set HANDSTRUDEL_EVAL_JWT to a test account's access token.");
    runner = functionRunner(option("--function-url")!, jwt, process.env.SUPABASE_ANON_KEY);
    mode = `deployed function ${option("--function-url")}`;
  } else {
    if (!process.env.ANTHROPIC_API_KEY) {
      console.error("No ANTHROPIC_API_KEY: run with --mock for the offline check, or set a key to evaluate the real model.");
      process.exit(2);
    }
    runner = inProcessRunner(await anthropicModel(), model);
    mode = `${model} via the Anthropic API`;
  }

  const results = await runEvals(cases, runner, Number(option("--concurrency") ?? 4));
  const summary = summarize(results);
  console.log(`Instrument evals: ${cases.length} prompts, ${mode}\n`);
  console.log(JSON.stringify({ ...summary, byCategory: undefined }, null, 2));
  console.table(summary.byCategory);
  for (const r of results.filter((r) => !r.checks.valid || !r.checks.playable || !r.checks.noMusicLeak || !r.checks.clean || !r.checks.expectation)) {
    console.log(`✗ ${r.id} [${r.outcome}] ${r.prompt}\n    ${[...r.issues, r.error].filter(Boolean).join("\n    ") || "expectation not met"}`);
  }
  const out = option("--out");
  if (out) writeFileSync(out, JSON.stringify({ mode, summary, results }, null, 2));
  process.exit(passes(summary) ? 0 : 1);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => { console.error(e); process.exit(1); });
}
