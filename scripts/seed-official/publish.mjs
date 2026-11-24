#!/usr/bin/env node
// Publishes the official @handstrudel account's seed posts and daily-sound schedule.
//
//   SUPABASE_URL=… SUPABASE_SERVICE_ROLE_KEY=… [SEED_OFFICIAL_EMAIL=…] \
//     node scripts/seed-official/publish.mjs --dry-run [--start-date YYYY-MM-DD]
//   … node scripts/seed-official/publish.mjs [--production] [--start-date YYYY-MM-DD]
//
// Posts go through the same path the app uses: sign-upload → PUT to R2 → publish-upload,
// so the server screens them and counts, feeds, sound pages and triggers behave normally.
// Re-running skips posts already published (matched by caption on the official account).
// See README.md in this folder.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  Api, addDays, loadManifest, mediaRoot, parseArgs, postFields, putPresigned, readPostMedia, sleep, target, utcToday,
} from './lib.mjs';
import { scheduleSql } from './schedule-sql.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = parseArgs(process.argv.slice(2));
const dryRun = Boolean(args['dry-run']);
const manifest = loadManifest();
const { username, displayName } = manifest.account;
const say = (m = '') => console.log(m);

if (args['start-date'] !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(String(args['start-date']))) {
  throw new Error('--start-date must be YYYY-MM-DD (a UTC date)');
}
const startDate = args['start-date'] ? String(args['start-date']) : null;
const only = args.only ? String(args.only).split(',') : null;
const posts = only ? manifest.posts.filter((p) => only.includes(p.slug)) : manifest.posts;

async function main() {
  const t = target({ allowProduction: Boolean(args.production) });
  const api = new Api(t);
  say(`${dryRun ? 'DRY RUN — nothing will be written.' : 'Publishing.'} Target: ${t.url}${t.production ? '  (PRODUCTION)' : ''}`);
  say(`Media: ${mediaRoot()}`);

  // ---- media, checked before anything is written
  const media = new Map();
  const missing = [];
  for (const p of posts) {
    try { media.set(p.slug, readPostMedia(p.slug)); } catch (e) { missing.push(e.message); }
  }
  if (missing.length) {
    for (const m of missing) say(`  ✗ ${m}`);
    throw new Error(`${missing.length} post(s) have no valid rendered media. Run render.mjs first.`);
  }

  // ---- account
  const account = await resolveAccount(api);
  if (!account.id) {
    say(`\nAccount: would create @${username} ("${displayName}") with email ${account.email}.`);
  } else {
    say(`\nAccount: @${username} (${account.id})${account.created ? ' — created' : ' — existing'}`);
  }

  // ---- what exists already
  const published = new Map(); // caption → video row
  const screening = new Map(); // caption → pending upload
  let usedToday = 0;
  if (account.id) {
    for (const v of await api.select('videos', `user_id=eq.${account.id}&select=id,caption,hidden,created_at,sound_setup`)) {
      published.set(v.caption, v);
    }
    const since = new Date(Date.now() - 24 * 3600_000).toISOString();
    const pending = await api.select('pending_video_uploads',
      `user_id=eq.${account.id}&select=id,status,post_fields,created_at&order=created_at.desc`);
    for (const u of pending) {
      if (u.status === 'checking' && u.post_fields?.caption) screening.set(u.post_fields.caption, u);
      if (u.created_at > since) usedToday++;
    }
  }

  const todo = [];
  say(`\nPosts (${posts.length}):`);
  for (const [i, p] of posts.entries()) {
    const m = media.get(p.slug);
    const tier = isFree(m.meta.sound_setup) ? 'free' : 'Pro ';
    const label = `${String(i + 1).padStart(2)}. ${p.slug.padEnd(24)} ${tier} ${m.meta.sound_setup.key} ${m.meta.sound_setup.scale}`.padEnd(62);
    const existing = published.get(p.caption);
    if (existing) {
      say(`${label} skip — already published (${existing.id}${existing.hidden ? ', HIDDEN' : ''})`);
    } else if (screening.has(p.caption)) {
      say(`${label} skip — still screening (${screening.get(p.caption).id})`);
    } else {
      say(`${label} ${dryRun ? 'would publish' : 'publish'} — ${m.meta.duration_s}s, ${(m.videoBytes / 1e6).toFixed(1)} MB, ` +
        `${m.meta.note_track?.notes.length ?? 0} notes`);
      if (dryRun) say(`      caption: ${p.caption}`);
      todo.push(p);
    }
  }
  const quota = Math.max(0, 20 - usedToday);
  if (todo.length > quota) {
    say(`\nThe server allows 20 uploads per account per 24 hours (${usedToday} used). This run publishes the first ${quota};`);
    say(`run the same command again after the window frees up to publish the remaining ${todo.length - quota}.`);
  }

  // ---- publish
  let made = 0;
  if (!dryRun) {
    const session = await api.sessionFor(account.email);
    for (const p of todo.slice(0, quota)) {
      const status = await publishOne(api, session.access_token, p, media.get(p.slug));
      if (status === 'limit') { say('  Upload limit reached; re-run later to continue.'); break; }
      if (status === 'published') made++;
    }
    for (const v of await api.select('videos', `user_id=eq.${account.id}&select=id,caption,hidden,created_at,sound_setup`)) {
      published.set(v.caption, v);
    }
  }
  say(`\n${dryRun ? `Would publish ${Math.min(todo.length, quota)} post(s).` : `Published ${made} post(s).`}`);

  await schedule(api, published);
}

/** Finds @handstrudel, or (with SEED_OFFICIAL_EMAIL) creates it. Never takes over another account. */
async function resolveAccount(api) {
  const [profile] = await api.select('profiles', `username=eq.${username}&select=id,username,display_name,accepted_terms_at`);
  if (profile) {
    const user = await api.getUser(profile.id);
    if (!user.email) throw new Error(`@${username} has no email address, so the script cannot sign in as it.`);
    if (!dryRun && profile.display_name !== displayName) {
      await api.update('profiles', `id=eq.${profile.id}`, { display_name: displayName });
    }
    return { id: profile.id, email: user.email, created: false };
  }
  const email = process.env.SEED_OFFICIAL_EMAIL;
  if (!email) throw new Error(`@${username} does not exist yet. Set SEED_OFFICIAL_EMAIL to the address it should sign in with.`);
  let user = await api.findUserByEmail(email);
  if (user) {
    const [p] = await api.select('profiles', `id=eq.${user.id}&select=username`);
    if (p?.username) throw new Error(`${email} already belongs to @${p.username}; refusing to rename it to @${username}.`);
  }
  if (dryRun) return { id: user?.id ?? null, email, created: false, wouldCreate: !user };
  if (!user) user = await api.createUser(email);
  // The owner sets up this account and accepts the terms for it, as the app asks every poster to.
  await api.update('profiles', `id=eq.${user.id}`,
    { username, display_name: displayName, accepted_terms_at: new Date().toISOString() });
  return { id: user.id, email, created: true };
}

async function publishOne(api, token, post, m) {
  process.stdout.write(`  ${post.slug}: `);
  let signed;
  try {
    signed = await api.invoke('sign-upload', { videoBytes: m.videoBytes, thumbBytes: m.thumbBytes, moderationVersion: 2 }, token);
  } catch (e) {
    if (e.status === 429) { say('upload limit'); return 'limit'; }
    throw e;
  }
  await putPresigned(signed.videoUploadUrl, m.video, 'video/mp4');
  await putPresigned(signed.thumbUploadUrl, m.thumb, 'image/jpeg');
  let { status } = await api.invoke('publish-upload', { action: 'submit', id: signed.id, fields: postFields(post, m) }, token);
  process.stdout.write(`uploaded ${signed.id}, ${status}`);
  const deadline = Date.now() + 180_000;
  while (status === 'checking' && Date.now() < deadline) {
    await sleep(2000);
    ({ status } = await api.invoke('publish-upload', { action: 'status', id: signed.id }, token));
  }
  say(` → ${status}`);
  if (status === 'held') say('    Screening held this clip. Check it in the dashboard (pending_video_uploads) before retrying.');
  if (status === 'checking') say('    Still screening; the next run will pick it up.');
  return status;
}

async function schedule(api, published) {
  const daily = manifest.posts.filter((p) => p.daily).sort((a, b) => a.daily.day - b.daily.day);
  if (!startDate) {
    say(`\nDaily sounds: not scheduled (pass --start-date YYYY-MM-DD to schedule ${daily.length} days).`);
    return;
  }
  const today = utcToday();
  const lastDay = addDays(startDate, daily.at(-1).daily.day - 1);
  say(`\nDaily sounds ${startDate} → ${lastDay} (UTC):`);
  let rpcMissing = false;
  try {
    // A read-only probe for the daily-sound tables (PR #112).
    await api.select('daily_sounds', 'select=day&limit=1');
  } catch (e) {
    if (e.status === 404 || ['PGRST205', '42P01'].includes(e.data?.code)) rpcMissing = true; else throw e;
  }
  if (rpcMissing) {
    const file = path.join(mediaRoot(), '..', `daily-schedule-${startDate}.sql`);
    if (!dryRun) fs.writeFileSync(file, scheduleSql({ manifest, startDate }));
    say(`  The daily-sound migration (PR #112) is not on this server yet.`);
    say(`  ${dryRun ? 'Would write' : 'Wrote'} ${file}: run it in the SQL editor after the migration is deployed.`);
    return;
  }
  const scheduled = new Map(
    (await api.select('daily_sounds', `day=gte.${startDate}&day=lte.${lastDay}&select=day,video_id,source`))
      .map((r) => [r.day, r]));
  for (const p of daily) {
    const day = addDays(startDate, p.daily.day - 1);
    const video = published.get(p.caption);
    const line = `  ${day}  ${p.daily.title.padEnd(24)}`;
    const current = scheduled.get(day);
    if (day < today) { say(`${line} skip — in the past`); continue; }
    if (!video) { say(`${line} ${dryRun ? 'would schedule once published' : 'skip — post not published yet (re-run later)'}`); continue; }
    if (current?.video_id === video.id && current.source === 'scheduled') { say(`${line} skip — already scheduled`); continue; }
    if (current?.source === 'scheduled' && !args['replace-schedule']) {
      say(`${line} skip — another sound is scheduled that day (--replace-schedule to overwrite)`); continue;
    }
    if (dryRun) { say(`${line} would schedule ${video.id}`); continue; }
    await api.rpc('schedule_daily_sound', { p_day: day, p_video_id: video.id, p_title: p.daily.title, p_note: p.daily.note });
    say(`${line} scheduled ${video.id}`);
  }
}

// Mirrors SoundSetup.requiredPacks / daily-sound's free list: free soundfonts and scales.
const FREE_SOUNDFONTS = new Set(['grand_piano', 'electric_piano_1', 'nylon_guitar', 'clean_guitar', 'acoustic_bass', 'violin', 'strings', 'choir']);
const FREE_SCALES = new Set(['Major', 'Minor', 'Dorian', 'Pentatonic', 'Blues']);
export function isFree(setup) {
  return setup.useSoundFont && FREE_SOUNDFONTS.has(setup.instrument) && FREE_SCALES.has(setup.scale) && setup.progression === 'free';
}

main().catch((e) => { console.error(`\n✗ ${e.message}`); process.exit(1); });
