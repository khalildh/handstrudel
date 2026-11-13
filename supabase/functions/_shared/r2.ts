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

/** Presigned PUT valid for 10 minutes; Content-Type and Content-Length are signed. */
export async function presignPut(key: string, contentType: string, contentLength: number) {
  const url = new URL(`${bucketUrl()}/${key}`);
  url.searchParams.set("X-Amz-Expires", "600");
  const signed = await r2().sign(
    new Request(url, {
      method: "PUT",
      headers: { "Content-Type": contentType, "Content-Length": String(contentLength) },
    }),
    { aws: { signQuery: true, allHeaders: true } },
  );
  return signed.url;
}

export async function deleteKeys(keys: string[]) {
  const client = r2();
  await Promise.all(
    keys.map(async (k) => {
      const res = await client.fetch(`${bucketUrl()}/${k}`, { method: "DELETE" });
      if (!res.ok && res.status !== 404) throw new Error(`R2 delete ${k}: ${res.status}`);
    }),
  );
}

/** Every key under a prefix (ListObjectsV2, paginated). */
export async function listKeys(prefix: string): Promise<string[]> {
  const client = r2();
  const keys: string[] = [];
  let token: string | undefined;
  do {
    const u = new URL(bucketUrl());
    u.searchParams.set("list-type", "2");
    u.searchParams.set("prefix", prefix);
    if (token) u.searchParams.set("continuation-token", token);
    const xml = await (await client.fetch(u)).text();
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
