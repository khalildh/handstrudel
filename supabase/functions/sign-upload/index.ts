// POST { videoBytes, thumbBytes } → presigned R2 PUT URLs for a new post.
// The app uploads both files, then inserts the `videos` row with the returned keys.
import { admin, caller, handler, HttpError, presignPut } from "../_shared/r2.ts";

const MAX_VIDEO = 15 * 1024 * 1024;
const MAX_THUMB = 1 * 1024 * 1024;
const DAILY_LIMIT = 20;

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await caller(req);
  const { videoBytes, thumbBytes } = await req.json();
  if (!Number.isInteger(videoBytes) || videoBytes <= 0 || videoBytes > MAX_VIDEO) {
    throw new HttpError(413, "video must be 1 byte – 15 MB");
  }
  if (!Number.isInteger(thumbBytes) || thumbBytes <= 0 || thumbBytes > MAX_THUMB) {
    throw new HttpError(413, "thumbnail must be 1 byte – 1 MB");
  }

  const db = admin();
  const { data: profile } = await db.from("profiles").select("username").eq("id", user.id).single();
  if (!profile?.username) throw new HttpError(403, "choose a username first");
  const { data: count } = await db.rpc("uploads_today", { uid: user.id });
  if ((count ?? 0) >= DAILY_LIMIT) throw new HttpError(429, `limit of ${DAILY_LIMIT} posts per day`);

  const id = crypto.randomUUID();
  const videoKey = `videos/${user.id}/${id}.mp4`;
  const thumbKey = `thumbs/${user.id}/${id}.jpg`;
  return {
    id,
    videoKey,
    thumbKey,
    videoUploadUrl: await presignPut(videoKey, "video/mp4", videoBytes),
    thumbUploadUrl: await presignPut(thumbKey, "image/jpeg", thumbBytes),
  };
}));
