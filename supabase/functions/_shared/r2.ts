// Cloudflare R2 (S3-compatible) helpers + Supabase auth for Edge Functions.
import { AwsClient } from "npm:aws4fetch@1.0.20";
import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";

const env = (k: string) => {
  const v = Deno.env.get(k);
  if (!v) throw new Error(`missing env ${k}`);
  return v;
};

export const r2 = () =>
  new AwsClient({
    accessKeyId: env("R2_ACCESS_KEY_ID"),
    secretAccessKey: env("R2_SECRET_ACCESS_KEY"),
    service: "s3",
    region: "auto",
  });

export const bucketUrl = () =>
  `https://${env("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com/${env("R2_BUCKET")}`;

export function privateVideoBucketUrl() {
  const bucket = env("R2_VIDEO_STAGING_BUCKET");
  if (bucket === env("R2_BUCKET")) throw new Error("New video media must not use the legacy public bucket");
  return `https://${env("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com/${bucket}`;
}

export const privateVideoR2 = () =>
  new AwsClient({
    accessKeyId: env("R2_VIDEO_STAGING_ACCESS_KEY_ID"),
    secretAccessKey: env("R2_VIDEO_STAGING_SECRET_ACCESS_KEY"),
    service: "s3",
    region: "auto",
  });

function bucketClient(bucket: string) {
  if (bucket === bucketUrl()) return r2();
  if (bucket === privateVideoBucketUrl()) return privateVideoR2();
  throw new Error("Unrecognized R2 bucket");
}

export function uploadKeys(userId: string, id: string) {
  return { videoKey: `videos/${userId}/screened/${id}.mp4`, thumbKey: `thumbs/${userId}/screened/${id}.jpg` };
}

export function isPrivateVideoKey(key: string) {
  return /^(videos|thumbs)\/[^/]+\/screened\/[^/]+$/.test(key);
}

/** The URL cannot overwrite an existing object, even if the client replays it. */
export async function presignPut(key: string, contentType: string, contentLength: number, bucket: string) {
  const url = new URL(`${bucket}/${key}`);
  url.searchParams.set("X-Amz-Expires", "600");
  const signed = await bucketClient(bucket).sign(
    new Request(url, {
      method: "PUT",
      headers: { "Content-Type": contentType, "Content-Length": String(contentLength), "If-None-Match": "*" },
    }),
    { aws: { signQuery: true, allHeaders: true } },
  );
  return signed.url;
}

export async function deleteKeys(keys: string[], bucket = bucketUrl()) {
  const client = bucketClient(bucket);
  await Promise.all(
    keys.map(async (k) => {
      const res = await client.fetch(`${bucket}/${k}`, { method: "DELETE", signal: AbortSignal.timeout(15_000) });
      if (!res.ok && res.status !== 404) throw new Error(`R2 delete ${k}: ${res.status}`);
    }),
  );
}

export async function putAvatar(key: string, bytes: Uint8Array<ArrayBuffer>) {
  const response = await r2().fetch(`${bucketUrl()}/${key}`, {
    method: "PUT",
    headers: { "Content-Type": "image/jpeg", "Cache-Control": "public, max-age=3600" },
    body: bytes,
  });
  if (!response.ok) throw new Error(`R2 avatar upload: ${response.status}`);
}

/** Every key under a prefix (ListObjectsV2, paginated). */
export async function listKeys(prefix: string, bucket = bucketUrl()): Promise<string[]> {
  const client = bucketClient(bucket);
  const keys: string[] = [];
  let token: string | undefined;
  do {
    const u = new URL(bucket);
    u.searchParams.set("list-type", "2");
    u.searchParams.set("prefix", prefix);
    if (token) u.searchParams.set("continuation-token", token);
    const response = await client.fetch(u);
    if (!response.ok) throw new Error(`R2 list objects: ${response.status}`);
    const xml = await response.text();
    for (const m of xml.matchAll(/<Key>([^<]+)<\/Key>/g)) keys.push(m[1]);
    token = xml.match(/<NextContinuationToken>([^<]+)<\/NextContinuationToken>/)?.[1];
  } while (token);
  return keys;
}

export const admin = (): SupabaseClient =>
  createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false },
  });

/** The signed-in caller, from the request's Supabase JWT. */
export async function caller(req: Request): Promise<User> {
  const jwt = req.headers.get("Authorization")?.replace(/^Bearer /, "");
  if (!jwt) throw new HttpError(401, "sign in required");
  const { data, error } = await admin().auth.getUser(jwt);
  if (error || !data.user) throw new HttpError(401, "invalid session");
  return data.user;
}

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export function handler(fn: (req: Request) => Promise<unknown>) {
  return async (req: Request) => {
    if (req.method === "OPTIONS") return new Response(null, { headers: cors });
    try {
      return json(await fn(req));
    } catch (e) {
      const status = e instanceof HttpError ? e.status : 500;
      if (status === 500) console.error(e);
      return json({ error: e instanceof Error ? e.message : String(e) }, status);
    }
  };
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
