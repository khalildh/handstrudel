import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

/** Shown in the app when a banned account tries to post (comments map ACCOUNT_BANNED in the app). */
export const bannedMessage =
  "Your account can't post because it broke the HandStrudel community guidelines. Contact support if you think this is a mistake.";

export async function isAccountBanned(db: SupabaseClient, userId: string) {
  const { data, error } = await db.rpc("account_is_banned", { uid: userId });
  if (error) throw new Error("Could not check account standing");
  return data === true;
}
