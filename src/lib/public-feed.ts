const feedBase = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://eygrtqbtbhktptphqdnn.supabase.co";
const publicKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "sb_publishable_V6B0E_NNyf0ClZ13WpHegQ_W-wXH_im";
const mediaBase = process.env.NEXT_PUBLIC_MEDIA_BASE_URL || "https://media.handstrudel.com";

export const PAGE_SIZE = 12;

export interface PublicVideo {
  id: string;
  video_key: string;
  thumb_key: string;
  username: string;
  caption: string;
  instrument: string | null;
  duration_s: number | null;
  width: number | null;
  height: number | null;
  created_at: string;
  sound_setup?: { version?: number; key?: string; scale?: string; bpm?: number } | null;
  comments_enabled?: boolean;
  comment_count?: number;
  backing_enabled?: boolean;
  source_video_id?: string | null;
  source_username?: string | null;
}

export interface PublicComment {
  id: string;
  body: string;
  username: string;
  created_at: string;
  reply_count: number;
  like_count?: number;
}

export interface PublicCreator {
  username: string;
  display_name: string | null;
}

export const COMMENT_PAGE_SIZE = 20;

export async function loadPublicComments(video: string, parent?: string, offset = 0, signal?: AbortSignal): Promise<PublicComment[]> {
  if (!isVideoID(video) || (parent && !isVideoID(parent))) throw new Error("Invalid comment thread.");
  const direction = parent ? "asc" : "desc";
  const url = new URL("/rest/v1/video_comments", feedBase);
  const fields = "id,body,username,created_at,reply_count";
  url.searchParams.set("select", `${fields},like_count`);
  url.searchParams.set("video_id", `eq.${video}`);
  url.searchParams.set("parent_id", parent ? `eq.${parent}` : "is.null");
  url.searchParams.set("order", `created_at.${direction},id.${direction}`);
  url.searchParams.set("offset", String(offset));
  url.searchParams.set("limit", String(COMMENT_PAGE_SIZE));
  const options: RequestInit = { headers: { apikey: publicKey }, signal, cache: "no-store" };
  let response = await fetch(url, options);
  if (response.status === 400 && (await response.json().catch(() => null))?.code === "42703") {
    url.searchParams.set("select", fields);
    response = await fetch(url, options);
  }
  if (!response.ok) throw new Error("Couldn't load comments.");
  return response.json();
}

export function isVideoID(id: string) {
  return /^[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}$/i.test(id);
}

export function isCreatorHandle(handle: string) {
  return /^[a-z0-9_]{3,20}$/.test(handle);
}

export function creatorHref(handle: string) {
  const normalized = handle.toLowerCase();
  return isCreatorHandle(normalized) ? `/creator?u=${encodeURIComponent(normalized)}` : null;
}

export async function loadPublicCreator(handle: string, signal?: AbortSignal): Promise<PublicCreator | null> {
  if (!isCreatorHandle(handle)) return null;
  const options: RequestInit = { headers: { apikey: publicKey }, signal, cache: "no-store" };
  const params = new URLSearchParams({ select: "username,display_name", username: `eq.${handle}`, limit: "1" });
  let response = await fetch(new URL(`/rest/v1/public_creators?${params}`, feedBase), options);
  if (response.status === 404) {
    // Older deployments expose creator names on visible feed rows.
    response = await fetch(new URL(`/rest/v1/feed_videos?${params}`, feedBase), options);
  }
  if (!response.ok) throw new Error("Couldn't load the creator.");
  const [creator]: PublicCreator[] = await response.json();
  return creator ?? null;
}

export function mediaURL(key: string) {
  // Keep media requests under the configured origin even for untrusted keys.
  const parts = key.split("/");
  if (parts.some((part) => !part || part === "." || part === "..")) return undefined;
  return `${mediaBase.replace(/\/$/, "")}/${parts.map(encodeURIComponent).join("/")}`;
}

export function postSearch(input: string) {
  const cleaned = input.replace(/\0/g, "").trim();
  const byHandle = cleaned.startsWith("@");
  const text = Array.from(byHandle ? cleaned.slice(1) : cleaned).slice(0, 80).join("").trim();
  if (Array.from(text).length < 2) return null;
  const literal = text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const quoted = literal.replace(/["\\]/g, "\\$&");
  const columns = byHandle ? ["username"] : ["caption", "instrument", "username", "display_name"];
  return { text, filter: columns.map((column) => `${column}.imatch."${quoted}"`).join(",") };
}

export async function loadPublicVideos(
  { id, after, search, creator }: { id?: string; after?: PublicVideo; search?: ReturnType<typeof postSearch>; creator?: string },
  signal?: AbortSignal,
): Promise<PublicVideo[]> {
  const url = new URL("/rest/v1/feed_videos", feedBase);
  const fields = "id,video_key,thumb_key,username,caption,instrument,duration_s,width,height,created_at";
  url.searchParams.set("order", "created_at.desc,id.desc");
  url.searchParams.set("limit", String(id ? 1 : PAGE_SIZE));
  if (id) url.searchParams.set("id", `eq.${id}`);
  if (creator !== undefined) {
    if (!isCreatorHandle(creator)) return [];
    url.searchParams.set("username", `eq.${creator}`);
  }
  const cursor = after && `created_at.lt.${after.created_at},and(created_at.eq.${after.created_at},id.lt.${after.id})`;
  if (cursor && search) url.searchParams.set("or", `(and(or(${search.filter}),or(${cursor})))`);
  else if (search || cursor) url.searchParams.set("or", `(${search?.filter ?? cursor})`);
  const options: RequestInit = { headers: { apikey: publicKey }, signal, cache: "no-store" };
  const supportedSelections = [
    ",sound_setup,comments_enabled,comment_count,backing_enabled,source_video_id,source_username",
    ",sound_setup,comments_enabled,comment_count",
    ",sound_setup",
    "",
  ];
  for (const optional of supportedSelections) {
    url.searchParams.set("select", fields + optional);
    const response = await fetch(url, options);
    if (response.ok) return response.json();
    const error = response.status === 400 ? await response.json().catch(() => null) : null;
    if (error?.code !== "42703") break;
  }
  throw new Error("The public feed couldn't be loaded.");
}
