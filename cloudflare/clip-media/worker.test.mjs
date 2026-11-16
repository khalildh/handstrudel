import assert from "node:assert/strict";
import { test } from "node:test";
import { serveMedia } from "./worker.mjs";

const owner = "00000000-0000-0000-0000-00000000000a";
const id = "11111111-1111-1111-1111-111111111111";
const key = `videos/${owner}/screened/${id}.mp4`;
const base = "https://clips.handstrudel.com/";
const clip = "0123456789";

function fixture() {
  const state = { visible: true, reads: 0, checks: 0, cacheReads: 0, jobs: [], offline: false };
  const meta = { size: clip.length, httpEtag: '"fixture"' };
  const stored = new Map();
  const env = {
    SUPABASE_URL: "https://db.example",
    SUPABASE_PUBLISHABLE_KEY: "test-key",
    MEDIA_CACHE_TTL_SECONDS: "120",
    PRIVATE_VIDEOS: {
      head: async () => meta,
      async get(_, opts) {
        state.reads++;
        const r = opts?.range;
        const start = r?.offset ?? (r?.suffix ? Math.max(0, clip.length - r.suffix) : 0);
        if (start >= clip.length) throw new Error("range unavailable");
        const bytes = clip.slice(start, r?.length ? start + r.length : undefined);
        return { ...meta, body: new Response(bytes).body };
      },
    },
  };
  const cache = {
    async match(request) {
      state.cacheReads++;
      const value = stored.get(request.url);
      if (!value) return;
      const { body, headers } = value;
      const match = request.headers.get("Range")?.match(/^bytes=(\d+)-(\d+)$/);
      if (!match) return new Response(body, { headers });
      const [, start, end] = match.map(Number);
      const partial = body.slice(start, end + 1);
      return new Response(partial, { status: 206, headers: {
        ...headers, "content-length": String(partial.length), "content-range": `bytes ${start}-${end}/${body.length}`,
      } });
    },
    async put(url, response) {
      stored.set(url, { body: await response.text(), headers: Object.fromEntries(response.headers) });
    },
  };
  const fetcher = async (url, options) => {
    state.checks++;
    assert.equal(url.href, "https://db.example/rest/v1/rpc/can_play_screened_media");
    assert.equal(options.headers.apikey, "test-key");
    assert.equal(JSON.parse(options.body).post_id, id);
    if (state.offline) return new Response(null, { status: 503 });
    return Response.json(state.visible);
  };
  return {
    state,
    request: (init, path = key) => serveMedia(
      new Request(base + path, init), env, { waitUntil: (job) => state.jobs.push(job) }, { fetcher, cache },
    ),
  };
}

test("approved playback warms the internal cache; later range requests avoid R2", async () => {
  const { state, request } = fixture();
  const first = await request({ headers: { Range: "bytes=0-" } });
  assert.equal(first.status, 206);
  assert.equal(first.headers.get("Content-Range"), "bytes 0-9/10");
  assert.equal(first.headers.get("Content-Type"), "video/mp4");
  assert.equal(first.headers.get("Cache-Control"), "no-store");
  assert.equal(await first.text(), clip);
  await Promise.all(state.jobs);
  const seek = await request({ headers: { Range: "bytes=3-6" } });
  assert.equal(seek.status, 206);
  assert.equal(await seek.text(), "3456");
  assert.equal(state.reads, 1);
  assert.equal(state.checks, 2);
});

test("takedowns and Supabase failures block warm-cache playback", async () => {
  const { state, request } = fixture();
  assert.equal(await (await request()).text(), clip);
  await Promise.all(state.jobs);
  state.visible = false;
  assert.equal((await request()).status, 404);
  assert.equal((await request({ method: "HEAD" })).status, 404);
  state.offline = true;
  assert.equal((await request()).status, 503);
  assert.equal(state.cacheReads, 1);
  assert.equal(state.reads, 1);
});

test("cold ranges, suffixes, HEAD and unsatisfiable ranges work without warming partial bodies", async () => {
  const { state, request } = fixture();
  const seek = await request({ headers: { Range: "bytes=3-6" } });
  assert.equal(seek.status, 206);
  assert.equal(seek.headers.get("Content-Length"), "4");
  assert.equal(await seek.text(), "3456");
  assert.equal(await (await request({ headers: { Range: "bytes=-2" } })).text(), "89");
  const head = await request({ method: "HEAD" });
  assert.equal(head.status, 200);
  assert.equal(head.headers.get("Content-Length"), "10");
  assert.equal(await head.text(), "");
  for (const range of ["bytes=999-", "bytes=5-3", "bytes=-0"]) {
    const invalid = await request({ headers: { Range: range } });
    assert.equal(invalid.status, 416);
    assert.equal(invalid.headers.get("Content-Range"), "bytes */10");
  }
  assert.equal(state.jobs.length, 0);
});

test("a pending post is denied, and the cache key and write methods cannot bypass playback", async () => {
  const { state, request } = fixture();
  state.visible = false;
  assert.equal((await request()).status, 404);
  assert.equal((await request(undefined, `_media-cache/v1/${key}`)).status, 404);
  assert.equal((await request({ method: "PUT" })).status, 405);
  assert.equal(state.checks, 1);
  assert.equal(state.cacheReads, 0);
  assert.equal(state.reads, 0);
});
