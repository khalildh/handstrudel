// Which instrument a shared post plays on the web: the post's own instrument
// file when it has one and it loads, otherwise the built-in wheel for the mode
// it was recorded in. Everything from a post goes through `loadInstrumentValue`.

import scaleWheelFile from "../../../shared/instruments/library/scale-wheel.json";
import splitWheelFile from "../../../shared/instruments/library/split-wheel.json";
import { publicSupabaseKey, publicSupabaseUrl } from "../public-supabase";
import { loadInstrumentValue, type InstrumentIssue, type InstrumentSpec } from "./spec.ts";

export const SCALE_WHEEL = loadInstrumentValue(scaleWheelFile).spec!;
export const SPLIT_WHEEL = loadInstrumentValue(splitWheelFile).spec!;

export interface PostInstrument {
  spec: InstrumentSpec;
  /** "post": the post's own file; "builtin": the fallback wheel. */
  source: "post" | "builtin";
  /** Why the post's own file wasn't used, when it had one. */
  rejected?: InstrumentIssue[];
}

/** The built-in wheel for an iOS mode: Split for `splitchordmelody`, otherwise Scale. */
export function builtInWheelFor(mode: unknown): InstrumentSpec {
  return mode === "splitchordmelody" ? SPLIT_WHEEL : SCALE_WHEEL;
}

export function choosePostInstrument(spec: unknown, mode: unknown): PostInstrument {
  if (spec !== undefined && spec !== null) {
    const result = loadInstrumentValue(spec);
    if (result.spec) return { spec: result.spec, source: "post" };
    return { spec: builtInWheelFor(mode), source: "builtin", rejected: result.issues };
  }
  return { spec: builtInWheelFor(mode), source: "builtin" };
}

/**
 * Read a post's instrument file. Feeds only say whether a post has one
 * (`has_instrument`); the file lives in `videos.instrument_spec`. Any failure
 * (older database, network) returns null so the caller falls back.
 */
export async function fetchPostInstrumentSpec(id: string, signal?: AbortSignal): Promise<unknown> {
  try {
    const url = new URL("/rest/v1/videos", publicSupabaseUrl);
    url.searchParams.set("select", "instrument_spec");
    url.searchParams.set("id", `eq.${id}`);
    url.searchParams.set("limit", "1");
    const response = await fetch(url, { headers: { apikey: publicSupabaseKey }, signal, cache: "no-store" });
    if (!response.ok) return null;
    const rows: unknown = await response.json();
    return Array.isArray(rows) && rows[0] && typeof rows[0] === "object" ? (rows[0] as { instrument_spec?: unknown }).instrument_spec ?? null : null;
  } catch {
    return null;
  }
}
