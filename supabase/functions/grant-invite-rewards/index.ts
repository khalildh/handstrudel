// POST → grants any queued invite rewards that involve the signed-in caller.
// With `X-Invite-Worker-Token: $INVITE_WORKER_TOKEN`, processes the whole queue (for a cron retry).
// Safe to call repeatedly: rows are claimed atomically and retries check RevenueCat first.
import { admin, caller, handler, HttpError } from "../_shared/r2.ts";
import { processInviteRewards, RevenueCat } from "../_shared/invite-rewards.ts";
import { supabaseGrantStore } from "../_shared/invite-grant-store.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const workerToken = req.headers.get("X-Invite-Worker-Token");
  let forUser: string | null;
  if (workerToken !== null) {
    const expected = Deno.env.get("INVITE_WORKER_TOKEN");
    if (!expected || workerToken !== expected) throw new HttpError(403, "Invalid worker token.");
    forUser = null;
  } else {
    forUser = (await caller(req)).id;
  }
  const key = Deno.env.get("REVENUECAT_SECRET_KEY");
  // Leave grants queued until the key is configured; they are granted on a later call.
  if (!key) return { claimed: 0, granted: 0, failed: 0, configured: false };
  return await processInviteRewards(supabaseGrantStore(admin()), new RevenueCat(key), forUser);
}));
