#!/usr/bin/env node
// Test-only: reads the seed posts back the way the app does (anon key, public views and RPCs)
// and checks them against posts.json and the rendered media. Local stack only.
//
//   eval "$(scripts/seed-official/test/stack.sh env)"; node scripts/seed-official/test/verify.mjs [--expect N]
import fs from 'node:fs';
import crypto from 'node:crypto';
import { loadManifest, parseArgs, readPostMedia } from '../lib.mjs';

const args = parseArgs(process.argv.slice(2));
const url = process.env.SUPABASE_URL;
const anon = process.env.SUPABASE_ANON_KEY;
const mock = `http://127.0.0.1:${process.env.MOCK_PORT || 59490}`;
if (!url?.startsWith('http://127.0.0.1') || !anon) throw new Error('local stack only: eval "$(stack.sh env)" first');
const manifest = loadManifest();
const byCaption = new Map(manifest.posts.map((p) => [p.caption, p]));
let failures = 0;
const check = (ok, msg) => { console.log(`${ok ? '  ✓' : '  ✗'} ${msg}`); if (!ok) failures++; };
const anonGet = async (path, init = {}) => {
  const res = await fetch(`${url}${path}`, { ...init, headers: { apikey: anon, Authorization: `Bearer ${anon}`, 'Content-Type': 'application/json', ...init.headers } });
  const body = await res.json();
  if (!res.ok) throw new Error(`${path} → ${res.status} ${JSON.stringify(body)}`);
  return body;
};
const sha = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
const canonical = (v) => JSON.stringify(v, Object.keys(v).sort());

const [creator] = await anonGet(`/rest/v1/public_creators?username=eq.${manifest.account.username}&select=*`);
check(creator?.display_name === manifest.account.displayName, `public_creators shows @${manifest.account.username} "${creator?.display_name}"`);

// The same query FeedService runs for a creator's posts, newest first.
const feed = await anonGet(`/rest/v1/feed_videos?username=eq.${manifest.account.username}&hidden=eq.false&order=created_at.desc&select=*`);
console.log(`feed_videos: ${feed.length} post(s) by @${manifest.account.username}`);
if (args.expect !== undefined) check(feed.length === Number(args.expect), `expected ${args.expect} posts`);
for (const v of feed) {
  const post = byCaption.get(v.caption);
  if (!post) { check(false, `unexpected post ${v.id}: ${v.caption}`); continue; }
  const m = readPostMedia(post.slug);
  const problems = [];
  if (canonical(v.sound_setup) !== canonical(m.meta.sound_setup)) problems.push('sound_setup differs');
  if (v.instrument !== m.meta.instrument || v.mode !== m.meta.mode) problems.push(`labels ${v.instrument}/${v.mode}`);
  if (v.has_note_track !== Boolean(m.meta.note_track)) problems.push('has_note_track');
  if (v.backing_enabled !== true) problems.push('play-along off');
  if (Math.abs(v.duration_s - m.meta.duration_s) > 0.01 || v.width !== m.meta.width || v.height !== m.meta.height) problems.push('size/duration');
  const [{ note_track }] = await anonGet(`/rest/v1/videos?id=eq.${v.id}&select=note_track`);
  if ((note_track?.notes.length ?? 0) !== (m.meta.note_track?.notes.length ?? 0)) problems.push('note_track');
  for (const [key, file] of [[v.video_key, m.video], [v.thumb_key, m.thumb]]) {
    const playable = await anonGet('/rest/v1/rpc/can_play_screened_media', { method: 'POST', body: JSON.stringify({ post_id: v.id, media_key: key }) });
    if (playable !== true) problems.push(`not playable: ${key}`);
    const res = await fetch(`${mock}/clips/${key}`);
    if (!res.ok || sha(Buffer.from(await res.arrayBuffer())) !== sha(fs.readFileSync(file))) problems.push(`media bytes ${key}`);
  }
  check(!problems.length, `${post.slug.padEnd(24)} ${v.sound_setup.instrument} ${v.sound_setup.key} ${v.sound_setup.scale}` +
    `${problems.length ? ' — ' + problems.join(', ') : ''}`);
}

try {
  const today = await anonGet('/rest/v1/rpc/daily_sound_today', { method: 'POST', body: '{}' });
  console.log(`daily_sound_today: ${today?.day} "${today?.title ?? ''}" video ${today?.video_id ?? today?.video?.id ?? '-'}`);
} catch (e) {
  console.log(`daily_sound_today unavailable (${e.message.slice(0, 80)})`);
}
if (failures) { console.error(`\n✗ ${failures} check(s) failed`); process.exit(1); }
console.log('\nAll checks passed.');
