// The invite reward queue in Postgres (see migration 20261121030000_invite_rewards.sql).
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { type ClaimedGrant, type GrantStore, processInviteRewards, RevenueCat } from "./invite-rewards.ts";
import { admin } from "./r2.ts";

export function supabaseGrantStore(db: SupabaseClient): GrantStore {
  return {
    async claim(forUser) {
      const { data, error } = await db.rpc("claim_invite_grants", { for_user: forUser, max_rows: 20 });
      if (error) throw new Error("Could not claim invite rewards");
      return (data ?? []) as ClaimedGrant[];
    },
    async recordEntitlement(grant, entitlement) {
      const { error } = await db.rpc("record_invite_entitlement",
        { grant_id: grant.id, claim: grant.claimed_at, entitlement });
      if (error) throw new Error("Could not record invite entitlement");
    },
    async finish(grant, outcome) {
      const { error } = await db.rpc("finish_invite_grant", outcome.ok
        ? { grant_id: grant.id, claim: grant.claimed_at, succeeded: true, reward_expires_at: outcome.expiresAt }
        : { grant_id: grant.id, claim: grant.claimed_at, succeeded: false, error: outcome.error });
      if (error) throw new Error("Could not record invite reward");
    },
  };
}

/**
 * Best effort, right after a screened post publishes: if it was an invited friend's first take,
 * grant both rewards now. Never throws; anything left is retried by `grant-invite-rewards`.
 */
export async function grantInviteRewardsFor(userId: string) {
  const key = Deno.env.get("REVENUECAT_SECRET_KEY");
  if (!key) return;
  try {
    await processInviteRewards(supabaseGrantStore(admin()), new RevenueCat(key), userId);
  } catch (error) {
    console.error("Invite rewards deferred", error instanceof Error ? error.message : "unknown error");
  }
}
