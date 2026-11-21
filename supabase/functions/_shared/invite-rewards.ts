// Grants queued invite rewards (7 days of HandStrudel+) through RevenueCat's promotional
// entitlement API. Pure logic with injected I/O so it can be tested with RevenueCat mocked.

/** HandStrudel+ features, plus Pro content so 1.0.1 clients (which only check `pro`) unlock too. */
export const REWARD_ENTITLEMENTS = ["plus_features", "pro"] as const;
const API = "https://api.revenuecat.com/v1";

export type ClaimedGrant = {
  id: string;
  recipient_id: string;
  role: "inviter" | "invitee";
  attempts: number;
  claimed_at: string;
  /** When the previous attempt claimed this row; null on the first attempt. */
  previous_claim: string | null;
  verify_first: boolean;
  /** Entitlements a previous attempt already granted and recorded. */
  granted_entitlements: string[];
};

export type GrantStore = {
  claim(forUser: string | null): Promise<ClaimedGrant[]>;
  /** Records that one entitlement reached RevenueCat, before moving to the next. */
  recordEntitlement(grant: ClaimedGrant, entitlement: string): Promise<void>;
  finish(grant: ClaimedGrant, outcome: { ok: true; expiresAt: string | null } | { ok: false; error: string }): Promise<void>;
};

type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

/**
 * The app calls `Purchases.logIn(session.user.id.uuidString)`, and Swift's `uuidString`
 * is uppercase. RevenueCat app user IDs are case-sensitive, so match it exactly.
 */
export function revenueCatUserId(supabaseUserId: string) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(supabaseUserId)) {
    throw new Error("Invalid user id");
  }
  return supabaseUserId.toUpperCase();
}

export class RevenueCat {
  private secretKey: string;
  private fetchImpl: Fetch;

  constructor(secretKey: string, fetchImpl: Fetch = fetch) {
    if (!secretKey) throw new Error("missing env REVENUECAT_SECRET_KEY");
    this.secretKey = secretKey;
    this.fetchImpl = fetchImpl;
  }

  private request(path: string, init: RequestInit = {}) {
    return this.fetchImpl(`${API}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${this.secretKey}`,
        "Content-Type": "application/json",
        "X-Platform": "ios",
        ...(init.headers ?? {}),
      },
      signal: AbortSignal.timeout(15_000),
    });
  }

  /** Grants one week of `entitlement`. Returns its expiry from RevenueCat, if reported. */
  async grantWeek(appUserId: string, entitlement: string): Promise<string | null> {
    const path = `/subscribers/${encodeURIComponent(appUserId)}/entitlements/${encodeURIComponent(entitlement)}/promotional`;
    const response = await this.request(path, { method: "POST", body: JSON.stringify({ duration: "weekly" }) });
    if (!response.ok) throw new Error(`RevenueCat grant ${entitlement}: HTTP ${response.status}`);
    const body = await response.json().catch(() => null);
    return expiryOf(body, entitlement);
  }

  /**
   * Whether a promotional `entitlement` was already granted at or after `since`.
   * Used before re-granting on a retry, so an attempt that reached RevenueCat but
   * didn't get recorded doesn't grant a second week.
   */
  async promotionalSince(appUserId: string, entitlement: string, since: Date): Promise<{ found: boolean; expiresAt: string | null }> {
    const response = await this.request(`/subscribers/${encodeURIComponent(appUserId)}`);
    if (!response.ok) throw new Error(`RevenueCat lookup: HTTP ${response.status}`);
    const body = await response.json();
    const ent = body?.subscriber?.entitlements?.[entitlement];
    const product = typeof ent?.product_identifier === "string" ? ent.product_identifier : "";
    const purchased = Date.parse(ent?.purchase_date ?? "");
    // RevenueCat names promotional products `rc_promo_<entitlement>_<duration>`.
    const found = product.startsWith("rc_promo") && Number.isFinite(purchased) && purchased >= since.getTime() - 60_000;
    return { found, expiresAt: found ? ent?.expires_date ?? null : null };
  }
}

function expiryOf(body: unknown, entitlement: string): string | null {
  const value = (body as { subscriber?: { entitlements?: Record<string, { expires_date?: unknown }> } } | null)
    ?.subscriber?.entitlements?.[entitlement]?.expires_date;
  return typeof value === "string" ? value : null;
}

/**
 * Grants every entitlement for one claimed row. Entitlements recorded by an earlier attempt are
 * skipped; for the one an interrupted attempt may have sent without recording, RevenueCat is
 * checked for a promotional grant made since that attempt began.
 */
export async function grantReward(rc: RevenueCat, store: GrantStore, grant: ClaimedGrant): Promise<string | null> {
  const appUserId = revenueCatUserId(grant.recipient_id);
  let expiry: string | null = null;
  for (const entitlement of REWARD_ENTITLEMENTS) {
    if (grant.granted_entitlements?.includes(entitlement)) continue;
    let granted: string | null = null;
    let done = false;
    if (grant.verify_first && grant.previous_claim) {
      const existing = await rc.promotionalSince(appUserId, entitlement, new Date(grant.previous_claim));
      if (existing.found) { granted = existing.expiresAt; done = true; }
    }
    if (!done) granted = await rc.grantWeek(appUserId, entitlement);
    await store.recordEntitlement(grant, entitlement);
    expiry ??= granted;
  }
  return expiry;
}

/** Claims due grants (optionally only those involving `forUser`) and grants them. */
export async function processInviteRewards(store: GrantStore, rc: RevenueCat, forUser: string | null = null) {
  const grants = await store.claim(forUser);
  let granted = 0, failed = 0;
  for (const grant of grants) {
    try {
      const expiresAt = await grantReward(rc, store, grant);
      await store.finish(grant, { ok: true, expiresAt });
      granted++;
    } catch (error) {
      failed++;
      const message = error instanceof Error ? error.message : "unknown error";
      console.error("Invite reward grant failed", grant.id, message);
      // If recording the failure also fails, the claim goes stale and is retried with verify_first.
      await store.finish(grant, { ok: false, error: message }).catch(() => {});
    }
  }
  return { claimed: grants.length, granted, failed };
}
