import { admin, caller, deleteKeys, handler, HttpError, putAvatar } from "../_shared/r2.ts";
import { cleanAvatar, MAX_BYTES } from "./image.ts";

async function readPhoto(req: Request) {
  if (req.headers.get("Content-Type") !== "image/jpeg") throw new HttpError(415, "JPEG required");
  const reader = req.body?.getReader();
  if (!reader) throw new HttpError(400, "Photo required");
  const bytes = new Uint8Array(MAX_BYTES);
  let length = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    if (length + value.length > MAX_BYTES) {
      await reader.cancel();
      throw new HttpError(413, "Photo is too large");
    }
    bytes.set(value, length);
    length += value.length;
  }
  return bytes.subarray(0, length);
}

function ownsAvatar(key: string | null, prefix: string): key is string {
  return !!key && key.startsWith(prefix) && /^[a-f0-9-]{36}\.jpg$/.test(key.slice(prefix.length));
}

Deno.serve(handler(async (req) => {
  if (req.method !== "POST" && req.method !== "DELETE") throw new HttpError(405, "POST or DELETE only");
  const user = await caller(req);
  const db = admin();
  const prefix = `avatars/${user.id}/`;
  const { data: profile, error: profileError } = await db.from("profiles")
    .select("username,avatar_key").eq("id", user.id).maybeSingle();
  if (profileError) throw new Error("Couldn't load profile");
  if (!profile?.username) throw new HttpError(403, "Choose a username first");

  let avatarKey: string | null = null;
  if (req.method === "POST") {
    const { data: allowed, error } = await db.rpc("claim_avatar_upload", { uid: user.id });
    if (error) throw new Error("Couldn't check upload limit");
    if (!allowed) throw new HttpError(429, "Wait a few seconds before uploading another photo");
    const photo = await readPhoto(req);
    let jpeg: Uint8Array<ArrayBuffer>;
    try { jpeg = cleanAvatar(photo); }
    catch { throw new HttpError(422, "Couldn't read this profile photo"); }
    avatarKey = `${prefix}${crypto.randomUUID()}.jpg`;
    await putAvatar(avatarKey, jpeg);
  }

  const update = db.from("profiles").update({ avatar_key: avatarKey }).eq("id", user.id);
  const previous: string | null = profile.avatar_key;
  const { data: saved, error } = await (previous == null
    ? update.is("avatar_key", null)
    : update.eq("avatar_key", previous)).select("id").maybeSingle();
  // On an ambiguous database error, leave the new object in place so an
  // update that actually committed never points at a deleted photo.
  if (error) throw new Error("Couldn't update profile photo");
  if (!saved) {
    if (avatarKey) await deleteKeys([avatarKey]).catch(console.error);
    throw new HttpError(409, "Profile photo changed. Refresh and try again.");
  }
  if (ownsAvatar(previous, prefix)) await deleteKeys([previous]).catch(console.error);
  return { avatarKey };
}));
