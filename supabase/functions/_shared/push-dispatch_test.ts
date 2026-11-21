import assert from "node:assert/strict";
import { ApnsTokenCache, type ClaimedPush, importApnsKey } from "./apns.ts";
import { dispatch, type DispatchDb } from "./push-dispatch.ts";

const fromBase64url = (value: string) =>
  Uint8Array.from(atob(value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - value.length % 4) % 4)),
    (c) => c.charCodeAt(0));

async function keyPair() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  return { pem: `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----`,
           publicKey: pair.publicKey };
}

const GOOD = "aa".repeat(32);
const GONE = "bb".repeat(32);
const BAD = "cc".repeat(32);
const VIDEO = "11111111-1111-1111-1111-111111111111";

/** A fake database: one batch of claimed rows, then nothing. Records what the sender writes back. */
function fakeDb(batch: ClaimedPush[]) {
  const finished = new Map<string, unknown>();
  const removed: string[][] = [];
  const claims: unknown[][] = [];
  let served = false;
  const db: DispatchDb = {
    async claim(batchSize, env) {
      claims.push([batchSize, env]);
      if (served) return [];
      served = true;
      return batch;
    },
    async finish(id, result) { finished.set(id, result); },
    async removeTokens(tokens) { removed.push(tokens); },
  };
  return { db, finished, removed, claims };
}

type Recorded = { url: string; headers: Record<string, string>; body: Record<string, unknown> };

/** Mock APNs: answers per device token, the way api.push.apple.com does. */
function mockApns(answers: Record<string, Array<[number, string?]>>) {
  const requests: Recorded[] = [];
  const fetch = async (request: Request) => {
    const headers: Record<string, string> = {};
    request.headers.forEach((value, key) => { headers[key] = value; });
    requests.push({ url: request.url, headers, body: JSON.parse(await request.text()) });
    const device = new URL(request.url).pathname.split("/").pop()!;
    const [status, reason] = answers[device].shift() ?? [500, "Unexpected"];
    return new Response(reason ? JSON.stringify({ reason }) : null, { status });
  };
  return { fetch, requests };
}

Deno.test("sends each claimed push to APNs with a signed request and records the outcome", async () => {
  const { pem, publicKey } = await keyPair();
  const like: ClaimedPush = {
    id: "like-1", kind: "like", actor_username: "maya", actor_count: 5, video_id: VIDEO,
    comment_body: null, video_caption: null, challenge_title: null, tokens: [GOOD, GONE],
  };
  const comment: ClaimedPush = {
    id: "comment-1", kind: "comment", actor_username: "leo", actor_count: 1, video_id: VIDEO,
    comment_body: "love the bassline", video_caption: null, challenge_title: null, tokens: [BAD],
  };
  const { db, finished, removed, claims } = fakeDb([like, comment]);
  const apns = mockApns({ [GOOD]: [[200]], [GONE]: [[410, "Unregistered"]], [BAD]: [[400, "BadDeviceToken"]] });

  const totals = await dispatch({
    db, env: "production", bundleId: "com.handstrudel.app", fetch: apns.fetch, deadline: Date.now() + 5_000,
    auth: new ApnsTokenCache(() => importApnsKey(pem), "KEY1234567", "TVAG3T3Y65"),
  });

  assert.deepEqual(claims[0], [100, "production"]);
  assert.equal(apns.requests.length, 3);
  const toGood = apns.requests.find((r) => r.url.endsWith(GOOD))!;
  assert.equal(toGood.url, `https://api.push.apple.com/3/device/${GOOD}`);
  assert.equal(toGood.headers["apns-topic"], "com.handstrudel.app");
  assert.equal(toGood.headers["apns-push-type"], "alert");
  assert.equal(toGood.headers["apns-priority"], "10");
  assert.equal(toGood.headers["apns-collapse-id"], `like-${VIDEO}`);
  assert.deepEqual(toGood.body, {
    aps: { alert: { title: "HandStrudel", body: "@maya and 4 others liked your post." }, sound: "default", "thread-id": "like" },
    link: `handstrudel://watch/${VIDEO}`, kind: "like",
  });

  // The bearer token is an ES256 JWT for this team and key that verifies with the key's public half.
  const jwt = toGood.headers.authorization.replace(/^bearer /, "");
  const [header, claimsPart, signature] = jwt.split(".");
  assert.deepEqual(JSON.parse(new TextDecoder().decode(fromBase64url(header))), { alg: "ES256", kid: "KEY1234567" });
  assert.equal(JSON.parse(new TextDecoder().decode(fromBase64url(claimsPart))).iss, "TVAG3T3Y65");
  assert.ok(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, publicKey, fromBase64url(signature),
    new TextEncoder().encode(`${header}.${claimsPart}`)));

  const toBad = apns.requests.find((r) => r.url.endsWith(BAD))!;
  assert.equal(toBad.body.link, `handstrudel://comments/${VIDEO}`);
  assert.equal(toBad.headers["apns-collapse-id"], undefined);

  // Delivered to one of two devices counts as sent; the dead tokens are removed.
  assert.deepEqual(finished.get("like-1"), { delivered: true });
  assert.deepEqual(finished.get("comment-1"), { delivered: false, error: "no devices" });
  assert.deepEqual(removed.map((batch) => [...batch].sort()), [[GONE, BAD]]);
  assert.deepEqual(totals, { sent: 1, failed: 1, removedTokens: 2 });
});

Deno.test("refreshes an expired provider token once and retries", async () => {
  const { pem } = await keyPair();
  const push: ClaimedPush = {
    id: "remix-1", kind: "remix", actor_username: "maya", actor_count: 1, video_id: VIDEO,
    comment_body: null, video_caption: null, challenge_title: null, tokens: [GOOD],
  };
  const { db, finished } = fakeDb([push]);
  const apns = mockApns({ [GOOD]: [[403, "ExpiredProviderToken"], [200]] });
  await dispatch({
    db, env: "sandbox", bundleId: "com.handstrudel.app", fetch: apns.fetch, deadline: Date.now() + 5_000,
    auth: new ApnsTokenCache(() => importApnsKey(pem), "KEY", "TEAM"),
  });
  assert.equal(apns.requests.length, 2);
  assert.equal(apns.requests[0].url, `https://api.sandbox.push.apple.com/3/device/${GOOD}`);
  assert.notEqual(apns.requests[0].headers.authorization, apns.requests[1].headers.authorization, "a new JWT is signed");
  assert.deepEqual(finished.get("remix-1"), { delivered: true });
});

Deno.test("keeps the failure reason when APNs is unavailable", async () => {
  const { pem } = await keyPair();
  const push: ClaimedPush = {
    id: "post-1", kind: "following_post", actor_username: "maya", actor_count: 1, video_id: VIDEO,
    comment_body: null, video_caption: "night drive", challenge_title: null, tokens: [GOOD],
  };
  const { db, finished, removed } = fakeDb([push]);
  const apns = mockApns({ [GOOD]: [[503, "ServiceUnavailable"]] });
  const totals = await dispatch({
    db, env: "production", bundleId: "b", fetch: apns.fetch, deadline: Date.now() + 5_000,
    auth: new ApnsTokenCache(() => importApnsKey(pem), "KEY", "TEAM"),
  });
  assert.equal((apns.requests[0].body.aps as { alert: { body: string } }).alert.body, "@maya posted: night drive");
  assert.deepEqual(finished.get("post-1"), { delivered: false, error: "APNs 503 ServiceUnavailable" });
  assert.deepEqual(removed, [], "a transient failure keeps the token");
  assert.deepEqual(totals, { sent: 0, failed: 1, removedTokens: 0 });
});

Deno.test("stops when nothing is due or the deadline passed", async () => {
  const { db, claims } = fakeDb([]);
  const apns = mockApns({});
  const auth = new ApnsTokenCache(async () => { throw new Error("no key needed"); }, "KEY", "TEAM");
  assert.deepEqual(await dispatch({ db, env: "production", bundleId: "b", fetch: apns.fetch, auth,
                                    deadline: Date.now() + 5_000 }), { sent: 0, failed: 0, removedTokens: 0 });
  assert.equal(claims.length, 1);
  await dispatch({ db, env: "production", bundleId: "b", fetch: apns.fetch, auth, deadline: Date.now() - 1 });
  assert.equal(claims.length, 1, "no claim after the deadline");
  assert.equal(apns.requests.length, 0);
});
