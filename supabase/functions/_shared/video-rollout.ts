export function videoUploadsEnabledFor(userId: string) {
  return Deno.env.get("VIDEO_UPLOADS_ENABLED") === "true" ||
    userId === Deno.env.get("VIDEO_UPLOADS_SMOKE_USER_ID");
}
