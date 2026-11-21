import { CHORD_PROGRESSIONS, IOS_KEY_SEMITONES, IOS_NOTE_NAMES, IOS_SCALE_INTERVALS } from "./music-data.generated";
import { publicSupabaseUrl as feedBase, publicSupabaseKey as publicKey } from "./public-supabase";

const mediaBase = process.env.NEXT_PUBLIC_MEDIA_BASE_URL || "https://media.handstrudel.com";
const clipMediaBase = process.env.NEXT_PUBLIC_CLIP_MEDIA_BASE_URL || "https://clips.handstrudel.com";

export const PAGE_SIZE = 12;

export interface PublicVideo {
  id: string;
  video_key: string;
  thumb_key: string;
  username: string;
  caption: string;
  instrument: string | null;
  duration_s: number | null;
  view_count?: number;
  width: number | null;
  height: number | null;
  created_at: string;
  sound_setup?: PublicSoundSetup | null;
  comments_enabled?: boolean;
  comment_count?: number;
  backing_enabled?: boolean;
  source_video_id?: string | null;
  source_username?: string | null;
  /** The post carries an instrument file (read separately from videos.instrument_spec). */
  has_instrument?: boolean;
  instrument_spec_name?: string | null;
}

interface PublicSoundSetup {
  version?: number;
  key?: string;
  scale?: string | { id: string; name: string; intervals: number[] };
  bpm?: number;
  progression?: string;
  customDegrees?: number[];
  mode?: string;
}

const triadModes = new Set(["chordmelody", "radialchordmelody", "splitchordmelody"]);
const chordQualities = new Map([
  ["4,7", "maj"], ["3,7", "min"], ["3,6", "dim"], ["4,8", "aug"],
  ["4,7,11", "maj7"], ["4,7,10", "7"], ["3,7,10", "min7"], ["3,7,11", "min(maj7)"],
  ["3,6,10", "min7b5"], ["3,6,9", "dim7"], ["4,8,11", "maj7#5"],
]);

export function describeClipScale(scale: PublicSoundSetup["scale"]) {
  if (typeof scale === "string") {
    const intervals = IOS_SCALE_INTERVALS.get(scale);
    if (!intervals) return null;
    const name = scale === "Pentatonic" ? "Major Pentatonic" : scale === "Blues" ? "Minor Blues" : scale;
    return { name, intervals };
  }
  if (!scale || typeof scale.name !== "string" || !scale.name || scale.name.trim() !== scale.name ||
      Array.from(scale.name).length > 40 || /[\u0000-\u001f\u007f-\u009f]/.test(scale.name)) return null;
  const { intervals } = scale;
  if (!Array.isArray(intervals) || intervals.length < 3 || intervals.length > 12 || intervals[0] !== 0 ||
      !intervals.every((n, i) => Number.isInteger(n) && n < 12 && (i === 0 || n > intervals[i - 1]))) return null;
  return { name: scale.name, intervals };
}

function savedChordNames(setup: PublicSoundSetup, degrees: readonly number[]): string[] | null {
  const seventh = setup.mode === "scalechordmelody";
  if (!degrees.length || (!seventh && !triadModes.has(setup.mode ?? ""))) return null;
  const tonic = IOS_KEY_SEMITONES.get(setup.key ?? "");
  const scale = describeClipScale(setup.scale)?.intervals;
  // Shorter iOS scales wrap degrees back onto earlier roots. Keep those layouts numeric.
  if (tonic === undefined || scale?.length !== 7) return null;
  const names: string[] = [];
  for (const degree of degrees) {
    const root = scale[degree];
    // MusicTheory.swift stacks notes 2, 4, and (in Scale mode) 6 scale steps above the root.
    const intervals = (seventh ? [2, 4, 6] : [2, 4]).map(step => (scale[(degree + step) % scale.length] - root + 12) % 12);
    const quality = chordQualities.get(intervals.join(","));
    if (!quality) return null;
    names.push(IOS_NOTE_NAMES[(tonic + root) % 12] + quality);
  }
  return names;
}

export function describeClipChords(setup: PublicVideo["sound_setup"]) {
  if (setup?.version !== 1 || typeof setup.progression !== "string") return null;
  if (setup.progression === "free") return {
    label: "Chord layout", name: "Free layout", degrees: null,
    names: savedChordNames(setup, CHORD_PROGRESSIONS.get("free")?.degrees ?? []),
  };
  if (setup.progression === "custom") {
    const degrees = setup.customDegrees;
    if (!Array.isArray(degrees) || !degrees.length || degrees.length > 64 ||
        !degrees.every(d => Number.isInteger(d) && d >= 0 && d <= 6)) return null;
    return { label: "Chord progression", name: "Custom", degrees: degrees.map(d => d + 1), names: savedChordNames(setup, degrees) };
  }
  const preset = CHORD_PROGRESSIONS.get(setup.progression);
  return preset ? {
    label: "Chord progression", name: preset.name, degrees: preset.degrees.map(d => d + 1),
    names: savedChordNames(setup, preset.degrees),
  } : null;
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
  avatar_key?: string | null;
  likes_received?: number | null;
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

export function formatVideoViews(count?: number) {
  if (typeof count !== "number" || !Number.isSafeInteger(count) || count < 0) return null;
  return `${count.toLocaleString()} ${count === 1 ? "view" : "views"}`;
}

export async function recordPublicVideoView(id: string, receipt: string): Promise<number | null> {
  if (!isVideoID(id) || !isVideoID(receipt)) return null;
  const response = await fetch(new URL("/rest/v1/rpc/record_video_view", feedBase), {
    method: "POST",
    headers: { apikey: publicKey, "Content-Type": "application/json" },
    body: JSON.stringify({ target_video: id, watch_receipt: receipt }),
    keepalive: true,
  });
  if (!response.ok) return null;
  const count: unknown = await response.json();
  return typeof count === "number" && Number.isSafeInteger(count) && count >= 0 ? count : null;
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
  const params = new URLSearchParams({ username: `eq.${handle}`, limit: "1" });
  let response = await fetch(new URL(`/rest/v1/public_creators?${params}`, feedBase), options);
  if (response.status === 404) {
    // Older deployments expose creator names on visible feed rows.
    params.set("select", "username,display_name,avatar_key");
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
  const screened = parts.length === 4 && (parts[0] === "videos" || parts[0] === "thumbs") && parts[2] === "screened";
  return `${(screened ? clipMediaBase : mediaBase).replace(/\/$/, "")}/${parts.map(encodeURIComponent).join("/")}`;
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
    ",sound_setup,comments_enabled,comment_count,backing_enabled,source_video_id,source_username,view_count,has_instrument,instrument_spec_name",
    ",sound_setup,comments_enabled,comment_count,backing_enabled,source_video_id,source_username,view_count",
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
