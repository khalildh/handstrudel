// POST { videoBytes, thumbBytes } → presigned R2 PUT URLs for a new post.
// The app uploads both files to their permanent private keys, then calls publish-upload.
import { admin, caller, handler, HttpError, presignPut, privateVideoBucketUrl, uploadKeys } from "../_shared/r2.ts";
import { videoUploadsEnabledFor } from "../_shared/video-rollout.ts";
import { bannedMessage } from "../_shared/moderation.ts";

const MAX_VIDEO = 15 * 1024 * 1024;
const MAX_THUMB = 1 * 1024 * 1024;

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await caller(req);
  const { videoBytes, thumbBytes, moderationVersion } = await req.json();
  if (moderationVersion !== 2) throw new HttpError(409, "Update HandStrudel to post videos.");
  if (!videoUploadsEnabledFor(user.id)) throw new HttpError(503, "Posting is temporarily unavailable.");
  if (!Number.isInteger(videoBytes) || videoBytes <= 0 || videoBytes > MAX_VIDEO) {
    throw new HttpError(413, "video must be 1 byte – 15 MB");
  }
  if (!Number.isInteger(thumbBytes) || thumbBytes <= 0 || thumbBytes > MAX_THUMB) {
    throw new HttpError(413, "thumbnail must be 1 byte – 1 MB");
  }

  const db = admin();
  const { data: profile } = await db.from("profiles").select("username").eq("id", user.id).single();
  if (!profile?.username) throw new HttpError(403, "choose a username first");
  const bucket = privateVideoBucketUrl();
  const { data: id, error } = await db.rpc("reserve_video_upload", {
    uploader: user.id, video_size: videoBytes, thumb_size: thumbBytes,
  });
  if (error?.message === "UPLOAD_LIMIT") throw new HttpError(429, "Limit of 20 uploads per day.");
  if (error?.message === "ACCOUNT_BANNED") throw new HttpError(403, bannedMessage);
  if (error || typeof id !== "string") throw new Error("Could not reserve video upload");
  const { videoKey, thumbKey } = uploadKeys(user.id, id);
  return {
    id,
    videoUploadUrl: await presignPut(videoKey, "video/mp4", videoBytes, bucket),
    thumbUploadUrl: await presignPut(thumbKey, "image/jpeg", thumbBytes, bucket),
  };
}));
