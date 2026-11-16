// POST → permanently deletes the caller: public R2 media, then the auth user
// (profile, videos, likes, follows, reports and blocks cascade).
// Required by App Store Guideline 5.1.1(v).
import { admin, caller, deleteKeys, handler, HttpError, listKeys, privateVideoBucketUrl } from "../_shared/r2.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await caller(req);
  const db = admin();
  const keys = [
    ...(await listKeys(`videos/${user.id}/`)),
    ...(await listKeys(`thumbs/${user.id}/`)),
    ...(await listKeys(`avatars/${user.id}/`)),
  ];
  await deleteKeys(keys);
  let privateKeys: string[] = [];
  let privateBucket: string | undefined;
  if (Deno.env.get("R2_VIDEO_STAGING_BUCKET")) {
    privateBucket = privateVideoBucketUrl();
    privateKeys = (await Promise.all([
      listKeys(`videos/${user.id}/screened/`, privateBucket), listKeys(`thumbs/${user.id}/screened/`, privateBucket),
    ])).flat();
  }
  const { error } = await db.auth.admin.deleteUser(user.id);
  if (error) throw new HttpError(500, error.message);
  // Only remove write-once media after publication is no longer possible for this account.
  let privateDeleted = 0;
  if (privateBucket && privateKeys.length) {
    try {
      await deleteKeys(privateKeys, privateBucket);
      privateDeleted = privateKeys.length;
    } catch {
      console.error("Private account media will be retried by scheduled cleanup");
    }
  }
  return { deleted: user.id, files: keys.length + privateDeleted };
}));
