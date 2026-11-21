import assert from "node:assert/strict";
import {
  ApnsTokenCache, apnsEnvironment, apnsJwt, apnsRequest, type ClaimedPush, deliveryOutcome, importApnsKey, likeText,
  pushMessage, sameSecret,
} from "./apns.ts";

const fromBase64url = (value: string) =>
  Uint8Array.from(atob(value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - value.length % 4) % 4)),
    (c) => c.charCodeAt(0));
const decodeJson = (value: string) => JSON.parse(new TextDecoder().decode(fromBase64url(value)));

async function testKey() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const base64 = btoa(String.fromCharCode(...der));
  const pem = `-----BEGIN PRIVATE KEY-----\n${base64.match(/.{1,64}/g)!.join("\n")}\n-----END PRIVATE KEY-----`;
  return { pem, publicKey: pair.publicKey };
}

const row = (overrides: Partial<ClaimedPush>): ClaimedPush => ({
  id: "n1", kind: "like", actor_username: "maya", actor_count: 1, video_id: "11111111-1111-1111-1111-111111111111",
  comment_body: null, video_caption: null, challenge_title: null, tokens: ["ab"], ...overrides,
});

Deno.test("signs an ES256 provider token that verifies with the key's public half", async () => {
  const { pem, publicKey } = await testKey();
  const jwt = await apnsJwt(await importApnsKey(pem), "KEY1234567", "TVAG3T3Y65", 1_800_000_000);
  const [header, claims, signature] = jwt.split(".");
  assert.deepEqual(decodeJson(header), { alg: "ES256", kid: "KEY1234567" });
  assert.deepEqual(decodeJson(claims), { iss: "TVAG3T3Y65", iat: 1_800_000_000 });
  const raw = fromBase64url(signature);
  assert.equal(raw.length, 64, "JWS ES256 signatures are raw r||s, not DER");
  const valid = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, publicKey, raw,
    new TextEncoder().encode(`${header}.${claims}`));
  assert.ok(valid);
});

Deno.test("accepts a .p8 key pasted with escaped newlines", async () => {
  const { pem } = await testKey();
  await importApnsKey(pem.replace(/\n/g, "\\n"));
});

Deno.test("reuses a provider token for 50 minutes", async () => {
  const { pem } = await testKey();
  let now = 1_800_000_000;
  const cache = new ApnsTokenCache(() => importApnsKey(pem), "KEY", "TEAM", () => now);
  const first = await cache.get();
  now += 49 * 60;
  assert.equal(await cache.get(), first);
  now += 2 * 60;
  assert.notEqual(await cache.get(), first);
  const second = await cache.get();
  cache.invalidate();
  now += 1;
  assert.notEqual(await cache.get(), second);
});

Deno.test("batches like text", () => {
  assert.equal(likeText("maya", 1), "@maya liked your post.");
  assert.equal(likeText("maya", 2), "@maya and 1 other liked your post.");
  assert.equal(likeText("maya", 5), "@maya and 4 others liked your post.");
});

Deno.test("routes each kind to an existing in-app link", () => {
  const video = "11111111-1111-1111-1111-111111111111";
  const like = pushMessage(row({ actor_count: 3 }));
  assert.equal(like.payload.link, `handstrudel://watch/${video}`);
  assert.equal(like.collapseId, `like-${video}`);
  assert.deepEqual(like.payload.aps.alert, { title: "HandStrudel", body: "@maya and 2 others liked your post." });

  const comment = pushMessage(row({ kind: "comment", comment_body: "  so   good\n" }));
  assert.equal(comment.payload.link, `handstrudel://comments/${video}`);
  assert.equal((comment.payload.aps.alert as { body: string }).body, "@maya commented: so good");
  assert.equal(comment.collapseId, undefined);

  assert.equal((pushMessage(row({ kind: "remix" })).payload.aps.alert as { body: string }).body,
    "@maya played along with your post.");
  assert.equal((pushMessage(row({ kind: "take_reply" })).payload.aps.alert as { body: string }).body,
    "@maya replied to your post with a take.");
  assert.equal((pushMessage(row({ kind: "following_post" })).payload.aps.alert as { body: string }).body,
    "@maya posted a new performance.");
  const challenge = pushMessage(row({ kind: "challenge", challenge_title: "Lo-fi week" }));
  assert.equal(challenge.payload.link, `handstrudel://watch/${video}`);
  assert.deepEqual(challenge.payload.aps.alert, { title: "New weekly challenge", body: "Lo-fi week is live. Play along now." });
});

Deno.test("keeps long text short", () => {
  const message = pushMessage(row({ kind: "comment", comment_body: "🎹".repeat(400) }));
  const body = (message.payload.aps.alert as { body: string }).body;
  assert.ok(Array.from(body).length < 140);
  assert.ok(body.endsWith("…"));
  assert.ok(new TextEncoder().encode(JSON.stringify(message.payload)).length < 4096);
});

Deno.test("removes only dead tokens", () => {
  assert.equal(deliveryOutcome(200, undefined), "sent");
  assert.equal(deliveryOutcome(410, "Unregistered"), "remove-token");
  assert.equal(deliveryOutcome(400, "BadDeviceToken"), "remove-token");
  assert.equal(deliveryOutcome(403, "ExpiredProviderToken"), "refresh-auth");
  assert.equal(deliveryOutcome(400, "PayloadTooLarge"), "failed");
  assert.equal(deliveryOutcome(429, "TooManyRequests"), "failed");
  assert.equal(deliveryOutcome(503, "ServiceUnavailable"), "failed");
});

Deno.test("builds the APNs request", async () => {
  const request = apnsRequest("sandbox", "abcd", "com.handstrudel.app", "jwt", pushMessage(row({})));
  assert.equal(request.url, "https://api.sandbox.push.apple.com/3/device/abcd");
  assert.equal(request.headers.get("authorization"), "bearer jwt");
  assert.equal(request.headers.get("apns-topic"), "com.handstrudel.app");
  assert.equal(request.headers.get("apns-push-type"), "alert");
  assert.equal(request.headers.get("apns-collapse-id"), "like-11111111-1111-1111-1111-111111111111");
  assert.equal(JSON.parse(await request.text()).kind, "like");
  assert.equal(apnsRequest("production", "abcd", "b", "j", pushMessage(row({}))).url,
    "https://api.push.apple.com/3/device/abcd");
});

Deno.test("validates settings and the dispatch secret", () => {
  assert.equal(apnsEnvironment("production"), "production");
  assert.throws(() => apnsEnvironment("prod"));
  assert.ok(sameSecret("s3cret", "s3cret"));
  assert.ok(!sameSecret("s3cre", "s3cret"));
  assert.ok(!sameSecret("", ""));
});
