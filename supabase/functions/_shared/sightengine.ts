const threshold = 0.5;

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid screening response");
  return value as Record<string, unknown>;
}

function explicit(nudity: unknown): boolean {
  const fields = object(nudity);
  const scores = [fields.sexual_activity, fields.sexual_display].map((score) => {
    if (typeof score !== "number" || !Number.isFinite(score) || score < 0 || score > 1) {
      throw new Error("Invalid explicit-content score");
    }
    return score;
  });
  return scores.some((score) => score >= threshold);
}

export function shouldHold(payload: unknown, kind: "video" | "image"): boolean {
  const response = object(payload);
  if (response.status !== "success") throw new Error("Screening did not complete");
  if (kind === "image") return explicit(response.nudity);
  const frames = object(response.data).frames;
  if (!Array.isArray(frames) || frames.length === 0) throw new Error("No frames were screened");
  return frames.map((frame) => explicit(object(frame).nudity)).some(Boolean);
}

export async function screenMedia(bytes: ArrayBuffer, kind: "video" | "image", request = fetch): Promise<boolean> {
  const user = Deno.env.get("SIGHTENGINE_API_USER");
  const secret = Deno.env.get("SIGHTENGINE_API_SECRET");
  if (!user || !secret) throw new Error("Screening is not configured");
  const isVideo = kind === "video";
  const form = new FormData();
  form.set("api_user", user);
  form.set("api_secret", secret);
  form.set("models", "nudity-2.1");
  if (isVideo) form.set("interval", "0.5");
  form.set("media", new Blob([bytes], { type: isVideo ? "video/mp4" : "image/jpeg" }), isVideo ? "clip.mp4" : "thumbnail.jpg");
  const response = await request(`https://api.sightengine.com/1.0/${isVideo ? "video/check-sync.json" : "check.json"}`, {
    method: "POST", body: form, signal: AbortSignal.timeout(45_000), redirect: "error",
  });
  if (!response.ok) {
    const payload = await response.json().catch(() => null);
    const errorType = typeof payload?.error?.type === "string" && /^[a-z_]{1,40}$/.test(payload.error.type) ? payload.error.type : "unknown_error";
    const code = Number.isInteger(payload?.error?.code) ? payload.error.code : 0;
    throw new Error(`Screening ${kind} HTTP ${response.status} (${errorType}:${code})`);
  }
  return shouldHold(await response.json(), kind);
}

export async function screenUpload(video: ArrayBuffer, thumbnail: ArrayBuffer, check = screenMedia) {
  const results = await Promise.all([check(video, "video"), check(thumbnail, "image")]);
  return results.some(Boolean) ? "held" : "clear";
}
