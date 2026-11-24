// POST { videoIds: uuid[] } → short-lived playback URLs for posts an admin is reviewing,
// including hidden ones the public clip-media worker refuses.
// The admin check runs in the database (moderation_video_media) with the caller's own JWT.
import { createClient } from "npm:@supabase/supabase-js@2";
import { bucketUrl, handler, HttpError, isPrivateVideoKey, presignGet, privateVideoBucketUrl } from "../_shared/r2.ts";

const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const authorization = req.headers.get("Authorization");
  if (!authorization) throw new HttpError(401, "sign in required");
  const { videoIds } = await req.json();
  if (!Array.isArray(videoIds) || videoIds.length < 1 || videoIds.length > 50 ||
      !videoIds.every((id) => typeof id === "string" && uuid.test(id))) {
    throw new HttpError(400, "Invalid videos.");
  }
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const media: Record<string, { video: string; thumb: string }> = {};
  for (const id of new Set(videoIds as string[])) {
    const { data, error } = await db.rpc("moderation_video_media", { target_video: id });
    if (error?.code === "42501") throw new HttpError(403, "Moderators only.");
    if (error) throw new Error("Could not load moderation media");
    const row = data?.[0];
    if (!row) continue;
    const sign = (key: string) => presignGet(key, isPrivateVideoKey(key) ? privateVideoBucketUrl() : bucketUrl());
    media[id] = { video: await sign(row.video_key), thumb: await sign(row.thumb_key) };
  }
  return { media };
}));
