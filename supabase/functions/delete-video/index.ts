// POST { videoId } → deletes the caller's own video row and its R2 files.
import { admin, caller, deleteKeys, handler, HttpError } from "../_shared/r2.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const user = await caller(req);
  const { videoId } = await req.json();
  const db = admin();
  const { data: video } = await db.from("videos").select("user_id, video_key, thumb_key")
    .eq("id", videoId).single();
  if (!video) throw new HttpError(404, "not found");
  if (video.user_id !== user.id) throw new HttpError(403, "not your video");
  await deleteKeys([video.video_key, video.thumb_key]);
  await db.from("videos").delete().eq("id", videoId);
  return { deleted: videoId };
}));
