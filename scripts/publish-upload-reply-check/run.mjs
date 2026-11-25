// Runs the real publish-upload handler under Node 23+ with its R2/screening imports stubbed and
// checks reply_to_id handling. node --no-warnings scripts/publish-upload-reply-check/run.mjs
import { register } from "node:module";
import assert from "node:assert/strict";
register("./hooks.mjs", import.meta.url);
let served;
globalThis.Deno = { serve: (h) => { served = h; }, env: { get: () => undefined } };
globalThis.EdgeRuntime = { waitUntil: () => {} };
const updates = [];
// Minimal chainable PostgREST stand-in that records the update payloads.
globalThis.fakeDb = {
  from() {
    const q = { _update: null,
      select() { return q; }, eq() { return q; }, gt() { return q; }, or() { return q; }, order() { return q; }, limit() { return q; },
      update(v) { q._update = v; updates.push(v); return q; },
      async maybeSingle() { return q._update ? { data: { id: "u", user_id: "x", status: "checking", attempt: 1, post_fields: q._update.post_fields }, error: null }
        : { data: { id: "11111111-1111-1111-1111-111111111111", user_id: "x", status: "reserved", attempt: 0 }, error: null }; },
    };
    return q;
  },
  rpc: async () => ({ error: null }),
};
await import(process.argv[2] ?? new URL("../../supabase/functions/publish-upload/index.ts", import.meta.url).href);
const call = (fields) => served({ method: "POST", headers: new Headers(), json: async () => ({ action: "submit", id: "11111111-1111-1111-1111-111111111111", fields }) });
const base = { duration_s: 3, width: 720, height: 1280 };
const target = "22222222-2222-2222-2222-222222222222";
assert.deepEqual(await call({ ...base, reply_to_id: target }), { status: "checking" });
assert.equal(updates.at(-1).post_fields.reply_to_id, target, "reply target reaches publish_screened_video's fields");
await call(base);
assert.equal(updates.at(-1).post_fields.reply_to_id, null, "ordinary posts send no target");
for (const bad of ["not-a-uuid", 7, { id: target }]) {
  await assert.rejects(call({ ...base, reply_to_id: bad }), (e) => e.status === 400, `rejects ${JSON.stringify(bad)}`);
}
console.log("publish-upload: reply_to_id accepted, passed through, and malformed values rejected");
