// POST → permanently deletes the caller: R2 media, then the auth user
// (profile, videos, likes, follows, reports and blocks cascade).
// Required by App Store Guideline 5.1.1(v).
import { admin, caller, deleteKeys, handler, HttpError, listKeys } from "../_shared/r2.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await caller(req);
  const keys = [
    ...(await listKeys(`videos/${user.id}/`)),
    ...(await listKeys(`thumbs/${user.id}/`)),
    ...(await listKeys(`avatars/${user.id}/`)),
  ];
  await deleteKeys(keys);
  const { error } = await admin().auth.admin.deleteUser(user.id);
  if (error) throw new HttpError(500, error.message);
  return { deleted: user.id, files: keys.length };
}));
