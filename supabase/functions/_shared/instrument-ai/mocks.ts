// Mocks for the generator's injected I/O, shared by the Node tests and the
// eval runner's offline self-test.
import type { CallModel, GenerationRecord, ModelReply, ModelRequest, QuotaStore, Tier } from "./generate.ts";

export class MemoryQuota implements QuotaStore {
  limits: Record<Tier, number>;
  claims: { userId: string; tier: Tier; kind: string; prompt: string; seedId: string | null; id: string }[] = [];
  finished = new Map<string, GenerationRecord>();
  blocked: { userId: string; prompt: string; reason: string }[] = [];

  constructor(limits: Partial<Record<Tier, number>> = {}) {
    this.limits = { free: 5, pro: 25, plus: 50, ...limits };
  }

  claim(input: { userId: string; tier: Tier; kind: "create" | "refine"; prompt: string; seedId: string | null }) {
    const used = this.claims.filter((c) => c.userId === input.userId).length;
    const limit = this.limits[input.tier];
    if (used >= limit) return Promise.resolve({ allowed: false, used, limit, generationId: null });
    const id = `gen-${this.claims.length + 1}`;
    this.claims.push({ ...input, id });
    return Promise.resolve({ allowed: true, used: used + 1, limit, generationId: id });
  }

  finish(generationId: string, record: GenerationRecord) {
    this.finished.set(generationId, record);
    return Promise.resolve();
  }

  logBlocked(input: { userId: string; kind: "create" | "refine"; prompt: string; reason: string }) {
    this.blocked.push(input);
    return Promise.resolve();
  }
}

export type ScriptedReply = Record<string, unknown> | string | Error | ModelReply;

/** A model that answers with the scripted replies in order and records every request. */
export function scriptedModel(replies: ScriptedReply[]): CallModel & { requests: ModelRequest[] } {
  const requests: ModelRequest[] = [];
  const call = (request: ModelRequest): Promise<ModelReply> => {
    requests.push(structuredClone(request));
    const next = replies.shift();
    if (next === undefined) return Promise.reject(new Error("no scripted reply left"));
    if (next instanceof Error) return Promise.reject(next);
    if (typeof next === "object" && "stopReason" in next && "usage" in next) return Promise.resolve(next as ModelReply);
    const text = typeof next === "string" ? next : JSON.stringify(next);
    return Promise.resolve({ text, stopReason: "end_turn", usage: { inputTokens: 3000, outputTokens: 180 } });
  };
  return Object.assign(call, { requests });
}

/** A valid model answer (without server fields) for the v1 split wheel. */
export function wheelAnswer(overrides: Record<string, unknown> = {}, suggestion: unknown = null) {
  return {
    instrument: {
      name: "Glow Wheel",
      description: "Big chord wedges on the left and every scale note on the right.",
      surface: { type: "split_wheel", radius: 1.0, rest_radius: 0.3, octave_band_radius: 0.82 },
      chords: { side: "left" },
      notes: { source: "scale_one_octave", octave_band: true, highlight_chord_tones: true },
      ...overrides,
    },
    suggested_music: suggestion,
  };
}
