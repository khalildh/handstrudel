import assert from "node:assert/strict";
import { type ClaimedGrant, type GrantStore, processInviteRewards, RevenueCat, revenueCatUserId } from "./invite-rewards.ts";

const USER = "0f8fad5b-d9cb-469f-a165-70867728950e";
const RC_USER = USER.toUpperCase();

type Call = { method: string; url: string; body?: string; auth?: string };

/** A RevenueCat stand-in that records calls and can fail chosen requests. */
function mockRevenueCat(options: {
  failGrant?: (entitlement: string, n: number) => number | null;
  existing?: Record<string, { product_identifier: string; purchase_date: string; expires_date: string }>;
} = {}) {
  const calls: Call[] = [];
  const grants: Record<string, number> = {};
  const fetchImpl = async (url: string, init: RequestInit = {}) => {
    const method = init.method ?? "GET";
    const headers = init.headers as Record<string, string>;
    calls.push({ method, url, body: init.body as string | undefined, auth: headers.Authorization });
    if (method === "GET") {
      return Response.json({ subscriber: { entitlements: options.existing ?? {} } });
    }
    const entitlement = decodeURIComponent(url.split("/entitlements/")[1].split("/")[0]);
    grants[entitlement] = (grants[entitlement] ?? 0) + 1;
    const status = options.failGrant?.(entitlement, grants[entitlement]);
    if (status) return new Response("{}", { status });
    return Response.json({
      subscriber: { entitlements: { [entitlement]: { expires_date: "2026-11-28T03:00:00Z", product_identifier: `rc_promo_${entitlement}_weekly` } } },
    }, { status: 201 });
  };
  return { rc: new RevenueCat("sk_test", fetchImpl as typeof fetch), calls, grants };
}

/** An in-memory queue with the same claim/record/finish contract as the SQL functions. */
function memoryStore(rows: Partial<ClaimedGrant>[]) {
  const grants = rows.map((row, i) => ({
    id: `g${i}`, recipient_id: USER, role: "invitee" as const, attempts: 0, claimed_at: "",
    previous_claim: null as string | null, verify_first: false, granted_entitlements: [] as string[],
    status: "pending", expiresAt: null as string | null, error: null as string | null, ...row,
  }));
  let clock = Date.parse("2026-11-21T03:00:00Z");
  const store: GrantStore = {
    async claim() {
      return grants.filter((g) => g.status === "pending").map((g) => {
        const previous = g.claimed_at || null;
        g.status = "granting"; g.attempts++; g.claimed_at = new Date(clock += 1000).toISOString();
        return { ...g, previous_claim: previous, verify_first: previous !== null, granted_entitlements: [...g.granted_entitlements] };
      });
    },
    async recordEntitlement(grant, entitlement) {
      const row = grants.find((g) => g.id === grant.id)!;
      if (row.claimed_at === grant.claimed_at && !row.granted_entitlements.includes(entitlement)) row.granted_entitlements.push(entitlement);
    },
    async finish(grant, outcome) {
      const row = grants.find((g) => g.id === grant.id)!;
      if (row.claimed_at !== grant.claimed_at) return;
      if (outcome.ok) { row.status = "granted"; row.expiresAt = outcome.expiresAt; }
      else { row.status = "pending"; row.error = outcome.error; }
    },
  };
  return { store, grants };
}

Deno.test("matches the app's RevenueCat user id, which is Swift's uppercase uuidString", () => {
  assert.equal(revenueCatUserId(USER), RC_USER);
  assert.throws(() => revenueCatUserId("$RCAnonymousID:abc"));
  assert.throws(() => revenueCatUserId(""));
});

Deno.test("grants one week of HandStrudel+ and Pro through the promotional endpoint", async () => {
  const { rc, calls } = mockRevenueCat();
  const { store, grants } = memoryStore([{}]);
  assert.deepEqual(await processInviteRewards(store, rc), { claimed: 1, granted: 1, failed: 0 });
  assert.deepEqual(calls.map((c) => `${c.method} ${c.url}`), [
    `POST https://api.revenuecat.com/v1/subscribers/${RC_USER}/entitlements/plus_features/promotional`,
    `POST https://api.revenuecat.com/v1/subscribers/${RC_USER}/entitlements/pro/promotional`,
  ]);
  assert.ok(calls.every((c) => c.body === JSON.stringify({ duration: "weekly" }) && c.auth === "Bearer sk_test"));
  assert.equal(grants[0].status, "granted");
  assert.equal(grants[0].expiresAt, "2026-11-28T03:00:00Z");
});

Deno.test("a failed grant is released for retry, and the retry doesn't repeat what already succeeded", async () => {
  const { rc, grants: sent } = mockRevenueCat({ failGrant: (ent, n) => ent === "pro" && n === 1 ? 503 : null });
  const { store, grants } = memoryStore([{}]);
  assert.deepEqual(await processInviteRewards(store, rc), { claimed: 1, granted: 0, failed: 1 });
  assert.equal(grants[0].status, "pending");
  assert.match(grants[0].error!, /HTTP 503/);
  assert.deepEqual(grants[0].granted_entitlements, ["plus_features"]);

  assert.deepEqual(await processInviteRewards(store, rc), { claimed: 1, granted: 1, failed: 0 });
  assert.deepEqual(sent, { plus_features: 1, pro: 2 }, "HandStrudel+ was granted exactly once");
  assert.equal(grants[0].status, "granted");
});

Deno.test("an interrupted attempt that reached RevenueCat is not granted twice", async () => {
  // The previous attempt (claimed at 03:00) granted plus_features but crashed before recording it.
  const { rc, calls, grants: sent } = mockRevenueCat({
    existing: { plus_features: { product_identifier: "rc_promo_plus_features_weekly", purchase_date: "2026-11-21T03:00:05Z", expires_date: "2026-11-28T03:00:05Z" } },
  });
  const { store, grants } = memoryStore([{ claimed_at: "2026-11-21T03:00:00.000Z" }]);
  assert.deepEqual(await processInviteRewards(store, rc), { claimed: 1, granted: 1, failed: 0 });
  assert.deepEqual(sent, { pro: 1 }, "only the missing entitlement is granted");
  assert.equal(calls.filter((c) => c.method === "GET").length, 2);
  assert.equal(grants[0].expiresAt, "2026-11-28T03:00:05Z");
});

Deno.test("an older promotional or a purchase doesn't count as this reward", async () => {
  const { rc, grants: sent } = mockRevenueCat({
    existing: {
      plus_features: { product_identifier: "rc_promo_plus_features_weekly", purchase_date: "2026-11-01T00:00:00Z", expires_date: "2026-11-08T00:00:00Z" },
      pro: { product_identifier: "com.handstrudel.pro", purchase_date: "2026-11-21T03:30:00Z", expires_date: "" },
    },
  });
  const { store } = memoryStore([{ claimed_at: "2026-11-21T03:00:00.000Z" }]);
  await processInviteRewards(store, rc);
  assert.deepEqual(sent, { plus_features: 1, pro: 1 });
});

Deno.test("one bad grant doesn't stop the rest of the batch", async () => {
  const other = "11111111-2222-4333-8444-555555555555";
  const { rc } = mockRevenueCat({ failGrant: () => null });
  const { store, grants } = memoryStore([{ recipient_id: "not-a-uuid" }, { recipient_id: other, role: "inviter" }]);
  assert.deepEqual(await processInviteRewards(store, rc), { claimed: 2, granted: 1, failed: 1 });
  assert.deepEqual(grants.map((g) => g.status), ["pending", "granted"]);
});

Deno.test("a stale claim can't overwrite the newer attempt's result", async () => {
  const { rc } = mockRevenueCat();
  const { store, grants } = memoryStore([{}]);
  const [claimed] = await store.claim(null);
  grants[0].claimed_at = "2026-11-21T04:00:00.000Z"; // reclaimed by another worker
  await store.finish(claimed, { ok: false, error: "late" });
  assert.equal(grants[0].status, "granting");
  assert.equal(grants[0].error, null);
  void rc;
});

Deno.test("refuses to run without the RevenueCat secret key", () => {
  assert.throws(() => new RevenueCat(""), /REVENUECAT_SECRET_KEY/);
});
