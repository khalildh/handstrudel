import { admin, caller, deleteKeys, handler, HttpError, privateVideoBucketUrl, uploadKeys } from "../_shared/r2.ts";
import { screenUpload } from "../_shared/sightengine.ts";
import { readPrivateVideo } from "../_shared/private-video.ts";
import { videoUploadsEnabledFor } from "../_shared/video-rollout.ts";
import { noteTrack } from "../_shared/note-track.ts";
import { grantInviteRewardsFor } from "../_shared/invite-grant-store.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const fields = "id, user_id, video_bytes, thumb_bytes, status, attempt, post_fields";
const maxAttempts = 3;

type Reservation = {
  id: string; user_id: string; video_bytes: number; thumb_bytes: number;
  attempt: number; post_fields: ReturnType<typeof postFields>;
};

function postFields(input: unknown) {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new HttpError(400, "Invalid post details.");
  const p = input as Record<string, unknown>;
  const dimension = (v: unknown) => typeof v === "number" && Number.isInteger(v) && v >= 1 && v <= 8192;
  if (typeof p.duration_s !== "number" || !Number.isFinite(p.duration_s) || p.duration_s <= 0 || p.duration_s > 60 ||
      !dimension(p.width) || !dimension(p.height) ||
      (p.source_video_id != null && (typeof p.source_video_id !== "string" || !uuid.test(p.source_video_id)))) {
    throw new HttpError(400, "Invalid video details.");
  }
  return {
    caption: typeof p.caption === "string" ? Array.from(p.caption).slice(0, 150).join("") : "",
    instrument: typeof p.instrument === "string" ? p.instrument.slice(0, 150) : null,
    mode: typeof p.mode === "string" ? p.mode.slice(0, 150) : null,
    duration_s: p.duration_s, width: p.width, height: p.height,
    sound_setup: p.sound_setup ?? null, note_track: p.sound_setup ? noteTrack(p.note_track) : null,
    comments_enabled: p.comments_enabled !== false,
    backing_enabled: p.backing_enabled === true, source_video_id: p.source_video_id ?? null,
  };
}

async function checkAndPublish(post: Reservation, privateBucket: string) {
  const db = admin();
  const { videoKey, thumbKey } = uploadKeys(post.user_id, post.id);
  const updateAttempt = (values: Record<string, unknown>) =>
    db.from("pending_video_uploads").update(values)
      .eq("id", post.id).eq("status", "checking").eq("attempt", post.attempt);
  try {
    const [video, thumb] = await Promise.all([
      readPrivateVideo(privateBucket, videoKey, post.video_bytes, "video/mp4"),
      readPrivateVideo(privateBucket, thumbKey, post.thumb_bytes, "image/jpeg"),
    ]);
    if (await screenUpload(video, thumb) === "held") {
      const { error } = await updateAttempt({ status: "held", post_fields: null, retry_at: null });
      if (error) throw new Error("Could not mark upload held");
      return;
    }
    if (!videoUploadsEnabledFor(post.user_id)) throw new Error("Publication is paused");

    const { error } = await db.rpc("publish_screened_video", {
      upload_id: post.id, fields: post.post_fields, checked_attempt: post.attempt,
    });
    if (error) throw new Error("Could not publish screened post");
    await grantInviteRewardsFor(post.user_id);
  } catch (error) {
    console.error("Video check failed", post.id, error instanceof Error ? error.message : "unknown error");
    // A past or ambiguous attempt cannot change an already published or newly claimed post.
    const { error: retryError } = await updateAttempt(post.attempt < maxAttempts
      ? { retry_at: new Date(Date.now() + 30_000 * post.attempt).toISOString() }
      : { status: "failed", post_fields: null, retry_at: null });
    if (retryError) console.error("Could not update video check status", post.id);
  }
}

async function maintain(privateBucket: string) {
  const db = admin();
  const cutoff = new Date(Date.now() - 24 * 60 * 60_000).toISOString();
  const stale = new Date(Date.now() - 10 * 60_000).toISOString();
  const now = new Date().toISOString();
  const publicEnabled = Deno.env.get("VIDEO_UPLOADS_ENABLED") === "true";
  const smokeUser = Deno.env.get("VIDEO_UPLOADS_SMOKE_USER_ID");
  if (publicEnabled || smokeUser) {
    const due = `retry_at.lte.${now},and(retry_at.is.null,check_started_at.lt.${stale})`;
    const jobs = db.from("pending_video_uploads")
      .select("id, attempt").eq("status", "checking").gt("created_at", cutoff)
      .or(due).order("created_at").limit(2);
    const { data, error } = await (publicEnabled ? jobs : jobs.eq("user_id", smokeUser));
    if (error) throw new Error("Could not load scheduled video checks");
    // Check one at a time to bound memory, including when each clip is at the size limit.
    for (const job of data) {
      const { data: claimed, error } = await db.from("pending_video_uploads").update(job.attempt >= maxAttempts
        ? { status: "failed", post_fields: null, retry_at: null }
        : { attempt: job.attempt + 1, check_started_at: now, retry_at: null })
        .eq("id", job.id).eq("status", "checking").eq("attempt", job.attempt)
        .or(due).select(fields).maybeSingle();
      if (error) throw new Error("Could not claim scheduled video check");
      if (claimed?.status === "checking") await checkAndPublish(claimed as Reservation, privateBucket);
    }
  }

  // Expire reservations only after the signed URLs and any screening lease have expired.
  const { data: expired, error } = await db.rpc("expired_video_uploads");
  if (error) throw new Error("Could not load expired video uploads");
  for (const item of expired) {
    try {
      // Claim before touching R2. A late successful publication must never lose its bytes.
      if (item.status === "checking") {
        const { data, error } = await db.from("pending_video_uploads")
          .update({ status: "failed", post_fields: null, retry_at: null })
          .eq("id", item.id).eq("status", "checking").lt("check_started_at", stale).select("id").maybeSingle();
        if (error) throw error;
        if (!data) continue;
      }
      const { data: video, error } = await db.from("videos").select("id").eq("id", item.id).maybeSingle();
      if (error) throw error;
      if (!video) {
        const { videoKey, thumbKey } = uploadKeys(item.user_id, item.id);
        await deleteKeys([videoKey, thumbKey], privateBucket);
      }
      const { error: removeError } = await db.from("pending_video_uploads").delete().eq("id", item.id);
      if (removeError) throw removeError;
    } catch {
      console.error("Could not expire video upload", item.id);
    }
  }
}

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "POST only");
  const maintenanceToken = req.headers.get("X-Video-Maintenance-Token");
  if (maintenanceToken !== null) {
    const expected = Deno.env.get("VIDEO_MAINTENANCE_TOKEN");
    if (!expected || maintenanceToken !== expected) throw new HttpError(403, "Invalid maintenance token.");
    const bucket = privateVideoBucketUrl();
    EdgeRuntime.waitUntil(maintain(bucket).catch((error) => console.error("Video maintenance failed", error)));
    return { scheduled: true };
  }
  const user = await caller(req);
  const body = await req.json();
  if (typeof body?.id !== "string" || !uuid.test(body.id)) throw new HttpError(400, "Invalid upload.");
  const db = admin();
  const query = () => db.from("pending_video_uploads").select(fields).eq("id", body.id).eq("user_id", user.id).maybeSingle();
  const { data: upload, error } = await query();
  if (error) throw new Error("Could not read upload status");
  if (!upload) throw new HttpError(404, "Upload not found.");
  if (body.action === "status") return { status: upload.status };
  if (body.action !== "submit") throw new HttpError(400, "Invalid upload action.");
  if (upload.status !== "reserved") return { status: upload.status };
  if (!videoUploadsEnabledFor(user.id)) throw new HttpError(503, "Posting is temporarily unavailable.");
  const metadata = postFields(body.fields);
  const privateBucket = privateVideoBucketUrl();
  const { data: claimed, error: claimError } = await db.from("pending_video_uploads")
    .update({ status: "checking", check_started_at: new Date().toISOString(), attempt: 1, post_fields: metadata })
    .eq("id", upload.id).eq("user_id", user.id).eq("status", "reserved")
    .gt("created_at", new Date(Date.now() - 30 * 60_000).toISOString()).select(fields).maybeSingle();
  if (claimError) throw new Error("Could not start screening");
  if (!claimed) {
    const { data: latest } = await query();
    if (latest && latest.status !== "reserved") return { status: latest.status };
    throw new HttpError(409, "This upload expired. Try again from Private drafts.");
  }
  EdgeRuntime.waitUntil(checkAndPublish(claimed as Reservation, privateBucket));
  return { status: "checking" };
}));
