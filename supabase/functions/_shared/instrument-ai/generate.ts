// "Make your own instrument": prompt → instrument file. Pure logic with every
// side effect injected (model, quota store, clock, ids) so Node tests and the
// eval runner exercise exactly what the Edge Function runs.
//
// Flow: moderate the prompt → claim a quota slot → pick the closest seed →
// ask the model to modify it (structured JSON output) → validate → on failure
// retry once with the errors → on failure again, fall back to the seed.
// Players never see an error screen for a bad model answer.
import { INSTRUMENT_SCHEMA, SEED_INSTRUMENTS } from "./assets.generated.ts";
import type { Schema } from "./json-schema.ts";
import { moderatePrompt } from "./moderation.ts";
import {
  createMessage, outputSchema, refineMessage, repairMessage, SUGGESTION_BPM, SUGGESTION_KEYS, SUGGESTION_SCALES,
  systemPrompt, withoutServerFields,
} from "./prompt.ts";
import { type Issue, validateInstrument } from "./validate.ts";

export const DEFAULT_MODEL = "claude-haiku-5-5";
export const PROMPT_LIMIT = 300;

export type Tier = "free" | "pro" | "plus";
export type ChatMessage = { role: "user" | "assistant"; content: string };

export type ModelRequest = {
  model: string;
  system: string;
  messages: ChatMessage[];
  outputSchema: Schema;
  maxTokens: number;
};

export type ModelReply = {
  /** The JSON text, or null when the model returned none (refusal, cut off). */
  text: string | null;
  stopReason: string;
  usage: { inputTokens: number; outputTokens: number; cacheReadTokens?: number; cacheWriteTokens?: number };
};

export type CallModel = (request: ModelRequest) => Promise<ModelReply>;

export type QuotaClaim = { allowed: boolean; used: number; limit: number; generationId: string | null };

export type GenerationRecord = {
  status: "ok" | "repaired" | "fallback" | "blocked";
  attempts: number;
  latencyMs: number;
  model: string;
  result: Record<string, unknown> | null;
  suggestion: Suggestion | null;
  issues: string[];
  inputTokens: number;
  outputTokens: number;
  costUsd: number | null;
  error?: string;
};

export interface QuotaStore {
  /** Atomically checks today's count against the tier's limit and, when
   *  allowed, records a pending generation. */
  claim(input: { userId: string; tier: Tier; kind: "create" | "refine"; prompt: string; seedId: string | null }): Promise<QuotaClaim>;
  finish(generationId: string, record: GenerationRecord): Promise<void>;
  /** Logs a prompt the filter blocked (not counted against the quota). */
  logBlocked(input: { userId: string; kind: "create" | "refine"; prompt: string; reason: string }): Promise<void>;
}

export type Deps = {
  callModel: CallModel;
  quota: QuotaStore;
  model?: string;
  schema?: Schema;
  seeds?: Record<string, unknown>[];
  now?: () => number;
  newId?: () => string;
  log?: (message: string, detail?: unknown) => void;
};

export type GenerateRequest = {
  userId: string;
  tier: Tier;
  prompt: string;
  /** Refine: the player's current instrument plus the change they asked for (in `prompt`). */
  current?: unknown;
  originalPrompt?: string;
};

export type Suggestion = { key: string | null; scale: string | null; bpm: number | null };

export type GenerateResponse = {
  instrument: Record<string, unknown>;
  suggested_music: Suggestion | null;
  /** ok: first answer valid. repaired: valid after one retry. fallback: the seed (or, for refine, the unchanged current instrument). */
  status: "ok" | "repaired" | "fallback";
  ai_generated: boolean;
  seed_id: string | null;
  attempts: number;
  latency_ms: number;
  quota: { used: number; limit: number; remaining: number };
};

export class GenerateError extends Error {
  status: number;
  code: string;
  detail?: Record<string, unknown>;
  constructor(status: number, code: string, message: string, detail?: Record<string, unknown>) {
    super(message);
    this.status = status;
    this.code = code;
    this.detail = detail;
  }
}

/** $ per million tokens: input, output, cache read, cache write (5 min). */
const PRICES: Record<string, [number, number, number, number]> = {
  "claude-haiku-5-5": [0.10, 0.50, 0.01, 0.125],
  "claude-sonnet-5-5": [2, 10, 0.10, 2.5],
  "claude-opus-5-5": [4, 20, 0.20, 5],
};

export function costUsd(model: string, usage: ModelReply["usage"]): number | null {
  const price = PRICES[model];
  if (!price) return null;
  return (usage.inputTokens * price[0] + usage.outputTokens * price[1]
    + (usage.cacheReadTokens ?? 0) * price[2] + (usage.cacheWriteTokens ?? 0) * price[3]) / 1e6;
}

// MARK: Seeds

/** Words that point at a seed whose id contains the value. */
const SEED_HINTS: [RegExp, string][] = [
  [/\b(wide|big|bigger|huge|large|giant|easy|easier|simple|kids?|child|beginner|accessib\w*|chunky|fat)\b/i, "wide"],
  [/\b(arp\w*|chord tones?|harp|strum\w*|split)\b/i, "split"],
];

function words(text: string): Set<string> {
  return new Set(text.toLowerCase().split(/[^a-z]+/).filter((w) => w.length >= 4));
}

/** The library instrument that best matches a prompt: hint words first, then
 *  shared words with its name and description, then the first built-in. */
export function nearestSeed(prompt: string, seeds: Record<string, unknown>[]): Record<string, unknown> {
  for (const [pattern, idPart] of SEED_HINTS) {
    if (!pattern.test(prompt)) continue;
    const hit = seeds.find((seed) => String(seed.id).includes(idPart));
    if (hit) return hit;
  }
  const promptWords = words(prompt);
  let best = seeds.find((seed) => seed.id === "builtin.scale-wheel") ?? seeds[0];
  let bestScore = 0;
  for (const seed of seeds) {
    const seedWords = words(`${seed.name} ${seed.description ?? ""}`);
    const score = [...promptWords].filter((w) => seedWords.has(w)).length;
    if (score > bestScore) { best = seed; bestScore = score; }
  }
  return best;
}

// MARK: Results

function parseReply(reply: ModelReply): { instrument?: Record<string, unknown>; suggestion?: unknown; error?: string } {
  if (reply.stopReason === "refusal") return { error: "the model declined this request" };
  if (reply.stopReason === "max_tokens") return { error: "the answer was cut off" };
  if (!reply.text) return { error: "the model returned no JSON" };
  try {
    const body = JSON.parse(reply.text);
    if (!body || typeof body !== "object" || !body.instrument || typeof body.instrument !== "object" || Array.isArray(body.instrument)) {
      return { error: "the answer has no instrument object" };
    }
    return { instrument: body.instrument, suggestion: body.suggested_music };
  } catch {
    return { error: "the answer is not valid JSON" };
  }
}

/** Adds the server-owned fields in a stable order. */
export function finalize(instrument: Record<string, unknown>, schema: Schema, id: string): Record<string, unknown> {
  const properties = (schema.properties ?? {}) as Record<string, { const?: unknown }>;
  const { name, description, ...rest } = withoutServerFields(instrument);
  return {
    format: properties.format?.const ?? "handstrudel.instrument",
    format_version: properties.format_version?.const ?? 1,
    id,
    name,
    ...(description !== undefined ? { description } : {}),
    ai_generated: true,
    ...rest,
  };
}

export function sanitizeSuggestion(value: unknown): Suggestion | null {
  if (!value || typeof value !== "object") return null;
  const v = value as Record<string, unknown>;
  const key = typeof v.key === "string" && SUGGESTION_KEYS.includes(v.key) ? v.key : null;
  const scale = typeof v.scale === "string" && SUGGESTION_SCALES.includes(v.scale) ? v.scale : null;
  const bpm = typeof v.bpm === "number" && Number.isFinite(v.bpm)
    ? Math.round(Math.min(SUGGESTION_BPM.max, Math.max(SUGGESTION_BPM.min, v.bpm))) : null;
  return key || scale || bpm ? { key, scale, bpm } : null;
}

function randomId() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return `ai.${[...bytes].map((b) => b.toString(16).padStart(2, "0")).join("")}`;
}

// MARK: Generate

export async function generateInstrument(request: GenerateRequest, deps: Deps): Promise<GenerateResponse> {
  const schema = deps.schema ?? INSTRUMENT_SCHEMA;
  const seeds = deps.seeds ?? SEED_INSTRUMENTS;
  const model = deps.model ?? DEFAULT_MODEL;
  const now = deps.now ?? (() => Date.now());
  const newId = deps.newId ?? randomId;
  const started = now();

  const prompt = typeof request.prompt === "string" ? request.prompt.trim() : "";
  if (!prompt) throw new GenerateError(400, "prompt_missing", "Describe the instrument you want.");
  if ([...prompt].length > PROMPT_LIMIT) throw new GenerateError(400, "prompt_too_long", `Keep it under ${PROMPT_LIMIT} characters.`);
  const kind = request.current === undefined ? "create" : "refine";

  // The current instrument (refine) must itself be a valid instrument.
  let current: Record<string, unknown> | null = null;
  if (kind === "refine") {
    const issues = validateInstrument(request.current, schema).filter((i) => i.kind !== "moderation");
    if (issues.length) throw new GenerateError(400, "current_invalid", "That instrument can't be refined.", { issues: issues.map((i) => i.message) });
    current = request.current as Record<string, unknown>;
  }

  const verdict = moderatePrompt(`${prompt} ${request.originalPrompt ?? ""}`);
  if (!verdict.ok) {
    await deps.quota.logBlocked({ userId: request.userId, kind, prompt, reason: `${verdict.reason}:${verdict.term}` });
    throw new GenerateError(422, "prompt_blocked", "That prompt can't be used. Try describing the layout or look you want.");
  }

  const seed = current ?? nearestSeed(prompt, seeds);
  const seedId = typeof seed.id === "string" ? seed.id : null;
  const claim = await deps.quota.claim({ userId: request.userId, tier: request.tier, kind, prompt, seedId });
  const quota = { used: claim.used, limit: claim.limit, remaining: Math.max(0, claim.limit - claim.used) };
  if (!claim.allowed || !claim.generationId) {
    throw new GenerateError(429, "quota_exceeded", `You've made ${claim.limit} instruments today. Try again tomorrow.`, { quota });
  }

  const system = systemPrompt(schema, seeds);
  const messages: ChatMessage[] = [{
    role: "user",
    content: kind === "refine" ? refineMessage(prompt, current!, request.originalPrompt) : createMessage(prompt, seed),
  }];
  const usage = { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0 };
  const allIssues: string[] = [];
  const id = kind === "refine" && typeof current!.id === "string" && current!.id.startsWith("ai.") ? current!.id as string : newId();
  let attempts = 0;
  let result: { instrument: Record<string, unknown>; suggestion: Suggestion | null } | null = null;
  let modelError: string | undefined;

  for (attempts = 1; attempts <= 2; attempts++) {
    let reply: ModelReply;
    try {
      reply = await deps.callModel({ model, system, messages, outputSchema: outputSchema(schema), maxTokens: 2048 });
    } catch (error) {
      modelError = error instanceof Error ? error.message : String(error);
      deps.log?.("model call failed", modelError);
      break; // Network or API failure: retrying the same call won't repair anything; fall back.
    }
    usage.inputTokens += reply.usage.inputTokens;
    usage.outputTokens += reply.usage.outputTokens;
    usage.cacheReadTokens += reply.usage.cacheReadTokens ?? 0;
    usage.cacheWriteTokens += reply.usage.cacheWriteTokens ?? 0;

    const parsed = parseReply(reply);
    let issues: Issue[];
    let candidate: Record<string, unknown> | null = null;
    if (parsed.error) {
      issues = [{ kind: "schema", message: parsed.error }];
    } else {
      candidate = finalize(parsed.instrument!, schema, id);
      issues = validateInstrument(candidate, schema);
    }
    if (!issues.length && candidate) {
      result = { instrument: candidate, suggestion: sanitizeSuggestion(parsed.suggestion) };
      break;
    }
    allIssues.push(...issues.map((i) => `attempt ${attempts} ${i.kind}: ${i.message}`));
    if (reply.stopReason === "refusal") break; // A refusal won't be repaired by a retry.
    messages.push({ role: "assistant", content: reply.text ?? "{}" });
    messages.push({ role: "user", content: repairMessage(issues.map((i) => i.message)) });
  }
  attempts = Math.min(attempts, 2);

  const status: GenerateResponse["status"] = result ? (attempts === 1 ? "ok" : "repaired") : "fallback";
  const instrument = result?.instrument ?? seed;
  const suggestion = result?.suggestion ?? null;
  const latencyMs = Math.round(now() - started);
  const cost = costUsd(model, usage);

  await deps.quota.finish(claim.generationId, {
    status, attempts, latencyMs, model, result: instrument, suggestion, issues: allIssues,
    inputTokens: usage.inputTokens + usage.cacheReadTokens + usage.cacheWriteTokens, outputTokens: usage.outputTokens,
    costUsd: cost, error: modelError,
  });

  return {
    instrument,
    suggested_music: suggestion,
    status,
    ai_generated: status !== "fallback",
    seed_id: seedId,
    attempts,
    latency_ms: latencyMs,
    quota,
  };
}
