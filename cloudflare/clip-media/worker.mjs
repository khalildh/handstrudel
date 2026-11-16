const uuid = "[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}";
const pathPattern = new RegExp(`^/(videos|thumbs)/${uuid}/screened/(${uuid})\\.(mp4|jpg)$`);

function reply(status, body = null, inputHeaders = {}) {
  const headers = new Headers(inputHeaders);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Expose-Headers", "Accept-Ranges, Content-Length, Content-Range");
  headers.set("Cache-Control", "no-store");
  headers.set("X-Content-Type-Options", "nosniff");
  return new Response(body, { status, headers });
}

function parseRange(value) {
  const match = value?.match(/^bytes=(\d*)-(\d*)$/i);
  if (!match || !(match[1] || match[2])) return;
  const [start, end] = match.slice(1).map((part) => part ? Number(part) : null);
  if (start === null) return { suffix: end };
  return end === null ? { offset: start } : { offset: start, length: end - start + 1 };
}

function resolveRange(range, size) {
  const start = range.suffix == null ? range.offset : Math.max(0, size - range.suffix);
  const end = Math.min(size, start + (range.length ?? size));
  return start < end ? { start, end } : null;
}

function unsatisfiable(size) {
  return reply(416, null, { "Content-Range": `bytes */${size}`, "Accept-Ranges": "bytes" });
}

async function canPlay(env, postId, key, fetcher) {
  const result = await fetcher(new URL("/rest/v1/rpc/can_play_screened_media", env.SUPABASE_URL), {
    method: "POST",
    headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ post_id: postId, media_key: key }),
    signal: AbortSignal.timeout(3500),
  });
  if (!result.ok) throw new Error(`Playback lookup failed: ${result.status}`);
  const visible = await result.json();
  if (typeof visible !== "boolean") throw new Error("Invalid playback lookup result");
  return visible;
}

export async function serveMedia(request, env, ctx, { fetcher = fetch, cache = globalThis.caches?.default } = {}) {
  const url = new URL(request.url);
  const match = url.pathname.match(pathPattern);
  if (!match || (match[1] === "videos") !== (match[3] === "mp4")) return reply(404);
  if (request.method === "OPTIONS") {
    return reply(204, null, { "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS", "Access-Control-Allow-Headers": "Range" });
  }
  if (!["GET", "HEAD"].includes(request.method)) return reply(405, null, { Allow: "GET, HEAD, OPTIONS" });
  const key = url.pathname.slice(1);
  try {
    // Never cache approval. An unavailable status lookup must not unlock cached bytes.
    if (!await canPlay(env, match[2], key, fetcher)) return reply(404);
    const head = request.method === "HEAD";
    // If-Range may be ignored by sending the complete representation.
    const rangeValue = head || request.headers.has("If-Range") ? null : request.headers.get("Range");
    const range = parseRange(rangeValue);
    const cacheKey = new URL(`/_media-cache/v1/${key}`, url).href;
    const ttl = Number(env.MEDIA_CACHE_TTL_SECONDS);
    if (!head && cache && ttl > 0 && (!range || Object.values(range).every(Number.isSafeInteger))) {
      try {
        const hit = await cache.match(new Request(cacheKey, { headers: range ? { Range: rangeValue } : {} }));
        if (hit?.status === 206 || (hit?.status === 200 && !range)) return reply(hit.status, hit.body, hit.headers);
        await hit?.body?.cancel();
      } catch {
        // Cache availability does not affect the visibility check or playback.
      }
    }

    const full = !range || (range.offset === 0 && range.length == null);
    const bucket = env.PRIVATE_VIDEOS;
    let object;
    if (head) {
      object = await bucket.head(key);
    } else if (full) {
      object = await bucket.get(key);
    } else if (Object.values(range).every(Number.isSafeInteger) && range.suffix !== 0 && !(range.length <= 0)) {
      try {
        object = await bucket.get(key, { range });
      } catch (error) {
        const meta = await bucket.head(key);
        if (!meta) return reply(404);
        if (!resolveRange(range, meta.size)) return unsatisfiable(meta.size);
        throw error;
      }
    } else {
      const meta = await bucket.head(key);
      return meta ? unsatisfiable(meta.size) : reply(404);
    }
    if (!object) return reply(404);

    const resolved = range && resolveRange(range, object.size);
    if (range && !resolved) {
      await object.body?.cancel();
      return unsatisfiable(object.size);
    }
    const headers = new Headers({
      "Accept-Ranges": "bytes",
      "Content-Type": match[3] === "mp4" ? "video/mp4" : "image/jpeg",
      "Content-Length": String(object.size),
      ETag: object.httpEtag,
    });
    let body = head ? null : object.body;
    const isComplete = !resolved || (resolved.start === 0 && resolved.end === object.size);
    if (body && isComplete && cache && ttl > 0) {
      const cachedHeaders = new Headers(headers);
      cachedHeaders.set("Cache-Control", `public, max-age=${ttl}`);
      const [playback, cached] = body.tee();
      body = playback;
      ctx.waitUntil(cache.put(cacheKey, new Response(cached, { headers: cachedHeaders })).catch(() => {}));
    }
    if (resolved) {
      headers.set("Content-Length", String(resolved.end - resolved.start));
      headers.set("Content-Range", `bytes ${resolved.start}-${resolved.end - 1}/${object.size}`);
      return reply(206, body, headers);
    }
    return reply(200, body, headers);
  } catch (error) {
    console.error("Clip playback unavailable", error instanceof Error ? error.message : "unknown error");
    return reply(503, null, { "Retry-After": "5" });
  }
}

export default {
  fetch: (request, env, ctx) => serveMedia(request, env, ctx),
  async scheduled(_event, env) {
    // Playback can deploy before the production upload functions and their shared token.
    if (!env.VIDEO_MAINTENANCE_TOKEN) return;
    const result = await fetch(new URL("/functions/v1/publish-upload", env.SUPABASE_URL), {
      method: "POST",
      headers: { "X-Video-Maintenance-Token": env.VIDEO_MAINTENANCE_TOKEN },
      signal: AbortSignal.timeout(10_000),
    });
    await result.body?.cancel();
    if (!result.ok) throw new Error(`Video maintenance request failed: ${result.status}`);
  },
};
