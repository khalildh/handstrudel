// POST { prompt, current?, original_prompt? } → a generated instrument file.
// Signed-in users only. See supabase/functions/_shared/instrument-ai/generate.ts
// for the flow and docs/ai-instruments.md for setup (ANTHROPIC_API_KEY).
import Anthropic from "npm:@anthropic-ai/sdk@1.12.0";
import { admin, caller, HttpError } from "../_shared/r2.ts";
import {
  type CallModel, DEFAULT_MODEL, generateInstrument, GenerateError, type QuotaStore, type Tier,
} from "../_shared/instrument-ai/generate.ts";
import { tierFromRevenueCat } from "../_shared/instrument-ai/tier.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function anthropicModel(): CallModel {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) throw new Error("missing env ANTHROPIC_API_KEY");
  // One SDK retry for 429/5xx; the generator adds its own repair retry for bad answers.
  const client = new Anthropic({ apiKey, timeout: 15_000, maxRetries: 1 });
  return async (request) => {
    const response = await client.messages.create({
      model: request.model,
      max_tokens: request.maxTokens,
      system: [{ type: "text", text: request.system, cache_control: { type: "ephemeral" } }],
      messages: request.messages,
      // Small structured edits: no thinking and low effort keep a generation under ~3 s.
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

function supabaseQuota(): QuotaStore {
  const db = admin();
  return {
    async claim({ userId, tier, kind, prompt, seedId }) {
      const { data, error } = await db.rpc("claim_instrument_generation", {
        p_user_id: userId, p_tier: tier, p_kind: kind, p_prompt: prompt, p_seed_id: seedId,
      }).single<{ allowed: boolean; used: number; daily_limit: number; generation_id: string | null }>();
      if (error || !data) throw new Error(`quota claim failed: ${error?.message}`);
      return { allowed: data.allowed, used: data.used, limit: data.daily_limit, generationId: data.generation_id };
    },
    async finish(generationId, record) {
      const { error } = await db.rpc("finish_instrument_generation", {
        p_generation_id: generationId,
        p_status: record.status,
        p_attempts: record.attempts,
        p_latency_ms: record.latencyMs,
        p_model: record.model,
        p_result: record.result,
        p_suggestion: record.suggestion,
        p_issues: record.issues,
        p_input_tokens: record.inputTokens,
        p_output_tokens: record.outputTokens,
        p_cost_usd: record.costUsd,
        p_error: record.error ?? null,
      });
      if (error) console.error("finish_instrument_generation", error.message);
    },
    async logBlocked({ userId, kind, prompt, reason }) {
      const { error } = await db.rpc("log_blocked_instrument_prompt", {
        p_user_id: userId, p_kind: kind, p_prompt: prompt, p_reason: reason,
      });
      if (error) console.error("log_blocked_instrument_prompt", error.message);
    },
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    if (req.method !== "POST") throw new HttpError(405, "POST only");
    const user = await caller(req);
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") throw new HttpError(400, "JSON body required");
    const tier: Tier = await tierFromRevenueCat(user.id, Deno.env.get("REVENUECAT_SECRET_KEY"), fetch,
      Deno.env.get("REVENUECAT_API_URL"));
    const result = await generateInstrument({
      userId: user.id,
      tier,
      prompt: body.prompt,
      current: body.current,
      originalPrompt: typeof body.original_prompt === "string" ? body.original_prompt.slice(0, 300) : undefined,
    }, {
      callModel: anthropicModel(),
      quota: supabaseQuota(),
      model: Deno.env.get("ANTHROPIC_INSTRUMENT_MODEL") || DEFAULT_MODEL,
      log: (message, detail) => console.error(message, detail),
    });
    return json(result);
  } catch (e) {
    if (e instanceof GenerateError) return json({ error: e.message, code: e.code, ...e.detail }, e.status);
    const status = e instanceof HttpError ? e.status : 500;
    if (status === 500) console.error(e);
    return json({ error: status === 500 ? "Something went wrong" : (e as Error).message }, status);
  }
});
