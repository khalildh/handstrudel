// POST { videoId } → deletes the caller's own video row and its R2 files.
import { admin, caller, deleteKeys, handler, HttpError, isPrivateVideoKey, privateVideoBucketUrl } from "../_shared/r2.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await caller(req);
  const { videoId } = await req.json();
  const db = admin();
  const { data: video, error: readError } = await db.from("videos").select("user_id, video_key, thumb_key")
    .eq("id", videoId).single();
  if (readError && readError.code !== "PGRST116") throw new Error("Could not load video");
  if (!video) throw new HttpError(404, "not found");
  if (video.user_id !== user.id) throw new HttpError(403, "not your video");
  const { error: hideError } = await db.from("videos").update({ hidden: true }).eq("id", videoId);
  if (hideError) throw new Error("Could not hide video");
  const keys: string[] = [video.video_key, video.thumb_key];
  await deleteKeys(keys.filter((key) => !isPrivateVideoKey(key)));
  const privateKeys = keys.filter(isPrivateVideoKey);
  if (privateKeys.length) await deleteKeys(privateKeys, privateVideoBucketUrl());
  const { error: deleteError } = await db.from("videos").delete().eq("id", videoId);
  if (deleteError) throw new Error("Could not delete video");
  return { deleted: videoId };
}));
