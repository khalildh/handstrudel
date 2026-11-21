// Which quota tier a user is on. Purchases live in RevenueCat, whose app user
// id is the Supabase user id in upper case (see invite rewards). Without a
// REVENUECAT_SECRET_KEY, or if the lookup fails, everyone is "free": a failed
// lookup costs a Pro player some quota, never the server money.
import type { Tier } from "./generate.ts";

type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

function active(entitlement: { expires_date?: string | null } | undefined, now: number) {
  if (!entitlement) return false;
  if (entitlement.expires_date == null) return true; // lifetime (the one-time Pro purchase)
  const expires = Date.parse(entitlement.expires_date);
  return Number.isFinite(expires) && expires > now;
}

export async function tierFromRevenueCat(userId: string, secretKey: string | undefined, fetchFn: Fetch,
                                         baseURL?: string, now = Date.now()): Promise<Tier> {
  if (!secretKey) return "free";
  if (!/^[0-9a-f-]{36}$/i.test(userId)) return "free";
  const base = (baseURL || "https://api.revenuecat.com/v1").replace(/\/$/, "");
  try {
    const response = await fetchFn(`${base}/subscribers/${encodeURIComponent(userId.toUpperCase())}`, {
      headers: { Authorization: `Bearer ${secretKey}` },
      signal: AbortSignal.timeout(3_000),
    });
    if (!response.ok) return "free";
    const body = await response.json();
    const entitlements = body?.subscriber?.entitlements ?? {};
    if (active(entitlements.plus_features, now)) return "plus";
    if (active(entitlements.pro, now)) return "pro";
    return "free";
  } catch {
    return "free";
  }
}
