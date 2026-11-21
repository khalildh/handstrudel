// Shared helpers for the official account's seed content: manifest, rendered media,
// and a small dependency-free client for Supabase Auth, REST and Edge Functions.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
export const PRODUCTION_REF = 'eygrtqbtbhktptphqdnn';
export const MAX_VIDEO = 15 * 1024 * 1024; // sign-upload limits
export const MAX_THUMB = 1 * 1024 * 1024;

export function loadManifest() {
  const manifest = JSON.parse(fs.readFileSync(path.join(here, 'posts.json'), 'utf8'));
  const captions = new Set();
  for (const p of manifest.posts) {
    if (!/^[a-z0-9-]+$/.test(p.slug)) throw new Error(`bad slug ${p.slug}`);
    // The caption is how a re-run recognises a published post, so it must be unique.
    if (captions.has(p.caption)) throw new Error(`duplicate caption: ${p.slug}`);
    if ([...p.caption].length > 150) throw new Error(`caption over 150 characters: ${p.slug}`);
    captions.add(p.caption);
  }
  return manifest;
}

export const mediaRoot = () => process.env.SEED_MEDIA_DIR || '/Volumes/PRO-G40/handstrudel-seed/media';

/** The rendered files for one post, checked against the upload limits. */
export function readPostMedia(slug) {
  const dir = path.join(mediaRoot(), slug);
  const files = { video: path.join(dir, 'video.mp4'), thumb: path.join(dir, 'thumb.jpg'), meta: path.join(dir, 'post.json') };
  for (const f of Object.values(files)) if (!fs.existsSync(f)) throw new Error(`${slug}: missing ${f} (run render.mjs)`);
  const meta = JSON.parse(fs.readFileSync(files.meta, 'utf8'));
  const videoBytes = fs.statSync(files.video).size;
  const thumbBytes = fs.statSync(files.thumb).size;
  if (videoBytes > MAX_VIDEO) throw new Error(`${slug}: video is ${videoBytes} bytes, over 15 MB`);
  if (thumbBytes > MAX_THUMB) throw new Error(`${slug}: thumbnail is ${thumbBytes} bytes, over 1 MB`);
  if (!(meta.duration_s > 0 && meta.duration_s <= 60)) throw new Error(`${slug}: bad duration ${meta.duration_s}`);
  return { ...files, meta, videoBytes, thumbBytes };
}

/** The `fields` a real post sends to publish-upload (see VideoUploader.swift / VideoPostFields). */
export function postFields(post, media) {
  const m = media.meta;
  return {
    caption: post.caption,
    instrument: m.instrument,
    mode: m.mode,
    duration_s: m.duration_s,
    width: m.width,
    height: m.height,
    sound_setup: m.sound_setup,
    note_track: m.note_track ?? undefined,
    // Official seed posts are open to play-along takes (they are what challenges and replies build on).
    backing_enabled: post.backingEnabled !== false ? true : undefined,
  };
}

export function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { out._.push(a); continue; }
    const [k, v] = a.slice(2).split('=');
    if (v !== undefined) out[k] = v;
    else if (argv[i + 1] && !argv[i + 1].startsWith('--')) out[k] = argv[++i];
    else out[k] = true;
  }
  return out;
}

/** Reads the target from the environment and refuses to touch production unless told so explicitly. */
export function target({ allowProduction }) {
  const url = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) throw new Error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (see scripts/seed-official/README.md).');
  const production = url.includes(PRODUCTION_REF);
  if (production && !allowProduction) {
    throw new Error(`SUPABASE_URL is the production project (${PRODUCTION_REF}). Re-run with --production to confirm.`);
  }
  return { url, serviceKey, production };
}

export class Api {
  constructor({ url, serviceKey }) {
    this.url = url;
    this.serviceKey = serviceKey;
  }

  async request(method, pathname, { body, token, headers = {}, ok = [200, 201, 204] } = {}) {
    const res = await fetch(`${this.url}${pathname}`, {
      method,
      headers: {
        apikey: this.serviceKey,
        Authorization: `Bearer ${token ?? this.serviceKey}`,
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...headers,
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(60_000),
    });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = text; }
    if (!ok.includes(res.status)) {
      const detail = typeof data === 'object' && data ? (data.error ?? data.message ?? data.msg ?? JSON.stringify(data)) : text;
      const err = new Error(`${method} ${pathname.split('?')[0]} → ${res.status}: ${detail}`);
      err.status = res.status;
      err.data = data;
      throw err;
    }
    return data;
  }

  // ---- REST (service role)
  select(table, query) { return this.request('GET', `/rest/v1/${table}?${query}`); }
  update(table, query, values) {
    return this.request('PATCH', `/rest/v1/${table}?${query}`, { body: values, headers: { Prefer: 'return=representation' } });
  }
  rpc(fn, args, opts) { return this.request('POST', `/rest/v1/rpc/${fn}`, { body: args, ...opts }); }

  // ---- Auth admin
  getUser(id) { return this.request('GET', `/auth/v1/admin/users/${id}`); }
  async findUserByEmail(email) {
    const want = email.toLowerCase();
    for (let page = 1; page < 500; page++) {
      const data = await this.request('GET', `/auth/v1/admin/users?page=${page}&per_page=200`);
      const users = data.users ?? [];
      const hit = users.find((u) => (u.email ?? '').toLowerCase() === want);
      if (hit) return hit;
      if (users.length < 200) return null;
    }
    return null;
  }
  createUser(email) {
    return this.request('POST', '/auth/v1/admin/users', { body: { email, email_confirm: true } });
  }
  /** A session for an account, without sending any email: admin magic link → verify. */
  async sessionFor(email) {
    const link = await this.request('POST', '/auth/v1/admin/generate_link', { body: { type: 'magiclink', email } });
    const tokenHash = link.hashed_token ?? link.properties?.hashed_token;
    if (!tokenHash) throw new Error('generate_link returned no token');
    const session = await this.request('POST', '/auth/v1/verify', { body: { type: 'magiclink', token_hash: tokenHash } });
    if (!session?.access_token) throw new Error('verify returned no session');
    return session;
  }

  // ---- Edge Functions, as the signed-in account (the same calls the app makes)
  invoke(name, body, token) { return this.request('POST', `/functions/v1/${name}`, { body, token }); }
}

/** PUT a file to a presigned R2 URL with the headers sign-upload signed. */
export async function putPresigned(url, file, contentType) {
  const bytes = fs.readFileSync(file);
  const res = await fetch(url, {
    method: 'PUT',
    headers: { 'Content-Type': contentType, 'Content-Length': String(bytes.length), 'If-None-Match': '*' },
    body: bytes,
    signal: AbortSignal.timeout(120_000),
  });
  if (!res.ok) throw new Error(`upload ${path.basename(file)} → ${res.status} ${await res.text().catch(() => '')}`.trim());
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export const utcToday = () => new Date().toISOString().slice(0, 10);
export function addDays(day, n) {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
export const sqlString = (s) => (s == null ? 'null' : `'${String(s).replace(/'/g, "''")}'`);
