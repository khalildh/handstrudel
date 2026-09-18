/**
 * Jev client — TypeSafe's "System One" decision model.
 *
 * Jev generates no text. You post application state plus typed questions whose
 * answers are drawn from a closed option list, and it replies in one forward
 * pass (70–500ms) with a choice, a probability distribution over the options,
 * and a confidence. There is nothing to parse and no way to get a value back
 * that wasn't in the list you sent.
 *
 * Nothing here runs on the 60fps hot path. Every call is fire-and-forget with a
 * hard timeout, and every failure raises a JevError the director swallows, so a
 * bad key or a dead network only ever means "fall back to what the app did
 * before" — never a stall and never an exception into the render tree.
 *
 * WIRE FORMAT: the request/response shape here follows Jev's public
 * description (`POST /v1/systemone` with `model`, `state` and typed
 * `questions`; answers carrying a choice, a distribution and a confidence) and
 * has NOT been run against the live API. Parsing is therefore deliberately
 * tolerant and confined to parseAnswer/parseAnswers below — if the real
 * response differs, that is the only place to change. Check docs.typesafe.ai
 * before trusting it in anger.
 *
 * KEY HANDLING: with `proxyUrl` set, the request goes to that server and no key
 * leaves this file. Without one, the key is read from localStorage and sent
 * straight to Jev from the browser — fine for a personal build, not for a
 * deployment other people use.
 */

/** Public Jev endpoint. Used when no proxy is configured. */
export const JEV_ENDPOINT = "https://api.typesafe.ai/v1/systemone";

/** Floating model pointer. Pin a version (e.g. "jev-1.13.0") to freeze behaviour. */
export const JEV_MODEL = "jev-latest";

/* ── Config (persisted in localStorage) ──────────────── */

export interface JevConfig {
  enabled: boolean;
  /** Sent as a bearer token when `proxyUrl` is empty. */
  apiKey: string;
  /** A server that holds the key and forwards to Jev. Takes precedence. */
  proxyUrl: string;
}

export const DEFAULT_JEV_CONFIG: JevConfig = {
  enabled: false,
  apiKey: "",
  proxyUrl: "",
};

const STORAGE_KEY = "handstrudel.jev";

export function loadJevConfig(): JevConfig {
  if (typeof window === "undefined") return { ...DEFAULT_JEV_CONFIG };
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT_JEV_CONFIG };
    const p = JSON.parse(raw) as Partial<JevConfig>;
    return {
      enabled: p.enabled === true,
      apiKey: typeof p.apiKey === "string" ? p.apiKey : "",
      proxyUrl: typeof p.proxyUrl === "string" ? p.proxyUrl : "",
    };
  } catch {
    return { ...DEFAULT_JEV_CONFIG };
  }
}

export function saveJevConfig(cfg: JevConfig): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
  } catch {
    /* private mode / quota — config just won't persist */
  }
}

/** Enabled and pointed at something that can answer. */
export function jevReady(cfg: JevConfig): boolean {
  return cfg.enabled && (cfg.proxyUrl.trim() !== "" || cfg.apiKey.trim() !== "");
}

/* ── Questions & answers ─────────────────────────────── */

export interface JevChoice {
  /** Correlates the answer back to the question. */
  id: string;
  question: string;
  /** Closed option list — the answer is always one of these. */
  options: string[];
}

export interface JevAnswer {
  id: string;
  choice: string;
  /** 0–1. */
  confidence: number;
  /** option → probability, for every option the response scored. */
  probabilities: Record<string, number>;
}

export interface JevResult {
  answers: Record<string, JevAnswer>;
  latencyMs: number;
  model: string;
}

function num(v: unknown, fallback = 0): number {
  return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}

function asRecord(v: unknown): Record<string, unknown> | null {
  return typeof v === "object" && v !== null && !Array.isArray(v)
    ? (v as Record<string, unknown>)
    : null;
}

/**
 * Normalise one answer object into a JevAnswer.
 *
 * Deliberately tolerant about field naming (`choice`/`value`/`answer`,
 * probabilities as a map or as an array aligned to `options`) so a wire-format
 * difference degrades to a fallback rather than a crash. The choice is always
 * validated against the option list we sent.
 */
function parseAnswer(raw: unknown, q: JevChoice): JevAnswer | null {
  const o = asRecord(raw);
  if (!o) return null;

  let choice: string | null = null;
  const candidate = o.choice ?? o.value ?? o.answer ?? o.selected;
  if (typeof candidate === "string" && q.options.includes(candidate)) {
    choice = candidate;
  } else if (typeof candidate === "number" && q.options[candidate] !== undefined) {
    choice = q.options[candidate];
  }

  const probabilities: Record<string, number> = {};
  const probs = o.probabilities ?? o.probs ?? o.distribution;
  if (Array.isArray(probs)) {
    probs.forEach((p, i) => {
      const opt = q.options[i];
      if (opt !== undefined) probabilities[opt] = num(p);
    });
  } else {
    const map = asRecord(probs);
    if (map) {
      for (const [k, v] of Object.entries(map)) {
        if (q.options.includes(k)) probabilities[k] = num(v);
      }
    }
  }

  // No usable choice field, but a distribution: take the argmax.
  if (choice === null) {
    let best: string | null = null;
    let bestP = -Infinity;
    for (const [k, v] of Object.entries(probabilities)) {
      if (v > bestP) {
        bestP = v;
        best = k;
      }
    }
    choice = best;
  }
  if (choice === null) return null;

  return {
    id: q.id,
    choice,
    confidence: num(o.confidence, probabilities[choice] ?? 0),
    probabilities,
  };
}

function parseAnswers(raw: unknown, questions: JevChoice[]): Record<string, JevAnswer> {
  const body = asRecord(raw);
  const out: Record<string, JevAnswer> = {};
  if (!body) return out;

  const answers = body.answers ?? body.results ?? body.decisions;
  const byId = new Map<string, unknown>();

  if (Array.isArray(answers)) {
    answers.forEach((a, i) => {
      const o = asRecord(a);
      const id = o && typeof o.id === "string" ? o.id : questions[i]?.id;
      if (id) byId.set(id, a);
    });
  } else {
    const map = asRecord(answers);
    if (map) for (const [k, v] of Object.entries(map)) byId.set(k, v);
  }

  for (const q of questions) {
    const parsed = parseAnswer(byId.get(q.id), q);
    if (parsed) out[q.id] = parsed;
  }
  return out;
}

export class JevError extends Error {}

/**
 * Ask Jev a batch of choice questions.
 *
 * Questions in one request are answered in parallel and cannot see each other,
 * so only fan out questions that are genuinely independent; anything that has
 * to be consistent with a prior decision belongs in `state`.
 *
 * Throws JevError on transport/HTTP failure so callers can surface the reason.
 */
export async function askJev(
  cfg: JevConfig,
  state: Record<string, unknown>,
  questions: JevChoice[],
  timeoutMs = 2500,
): Promise<JevResult> {
  const proxy = cfg.proxyUrl.trim();
  const url = proxy || JEV_ENDPOINT;

  const headers: Record<string, string> = { "content-type": "application/json" };
  if (!proxy) headers.authorization = `Bearer ${cfg.apiKey.trim()}`;

  const body = JSON.stringify({
    model: JEV_MODEL,
    state,
    questions: questions.map((q) => ({
      id: q.id,
      type: "choice",
      question: q.question,
      options: q.options,
    })),
  });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const started = performance.now();

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers,
      body,
      credentials: "omit",
      signal: controller.signal,
    });
  } catch (e: unknown) {
    clearTimeout(timer);
    if (e instanceof DOMException && e.name === "AbortError") {
      throw new JevError(`timed out after ${timeoutMs}ms`);
    }
    // A browser CORS rejection also lands here, indistinguishable from offline.
    throw new JevError(proxy ? "proxy unreachable" : "unreachable (offline or CORS — try a proxy)");
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) {
    if (res.status === 401 || res.status === 403) throw new JevError("key rejected");
    if (res.status === 429) throw new JevError("rate limited");
    throw new JevError(`http ${res.status}`);
  }

  let json: unknown;
  try {
    json = await res.json();
  } catch {
    throw new JevError("malformed response");
  }

  const answers = parseAnswers(json, questions);
  if (Object.keys(answers).length === 0) throw new JevError("no usable answers");

  const model = asRecord(json)?.model;
  return {
    answers,
    latencyMs: Math.round(performance.now() - started),
    model: typeof model === "string" ? model : JEV_MODEL,
  };
}

/* ── Sampling ────────────────────────────────────────── */

export interface SampleOptions {
  /** Keep the top options covering this much probability mass. */
  nucleus?: number;
  /** Options to down-weight — keeps repeated questions from stagnating. */
  avoid?: string[];
  /** Multiplier applied to avoided options. */
  noveltyWeight?: number;
  rng?: () => number;
}

/**
 * Sample from an answer's distribution instead of always taking the argmax.
 *
 * Jev hands back the whole distribution, which is the useful part here: the
 * argmax every 8 seconds would make the music predictable, so we sample the
 * nucleus and down-weight whatever just played.
 */
export function sampleChoice(answer: JevAnswer, opts: SampleOptions = {}): string {
  const {
    nucleus = 0.9,
    avoid = [],
    noveltyWeight = 0.2,
    rng = Math.random,
  } = opts;

  const entries = Object.entries(answer.probabilities)
    .filter(([, p]) => p > 0)
    .sort((a, b) => b[1] - a[1]);
  if (entries.length === 0) return answer.choice;

  const total = entries.reduce((s, [, p]) => s + p, 0);
  if (total <= 0) return answer.choice;

  // Nucleus: smallest prefix whose mass reaches the threshold.
  const kept: [string, number][] = [];
  let mass = 0;
  for (const [opt, p] of entries) {
    kept.push([opt, p]);
    mass += p / total;
    if (mass >= nucleus) break;
  }

  const weighted = kept.map(([opt, p]): [string, number] => [
    opt,
    avoid.includes(opt) ? p * noveltyWeight : p,
  ]);
  const weightTotal = weighted.reduce((s, [, p]) => s + p, 0);
  if (weightTotal <= 0) return kept[0][0];

  let r = rng() * weightTotal;
  for (const [opt, p] of weighted) {
    r -= p;
    if (r <= 0) return opt;
  }
  return weighted[weighted.length - 1][0];
}
