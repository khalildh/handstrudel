#!/usr/bin/env node
// Undoes publish.mjs: unschedules the seed posts' upcoming daily sounds and deletes the seed
// posts through the app's own `delete-video` function (row + R2 files).
//
//   SUPABASE_URL=… SUPABASE_SERVICE_ROLE_KEY=… node scripts/seed-official/delete.mjs --dry-run
//   … node scripts/seed-official/delete.mjs [--production] [--only slug,slug] [--delete-account]
//
// Only posts whose caption is in posts.json are touched; anything else the account posted stays.
// --delete-account also deletes @handstrudel itself (via `delete-account`), and refuses if the
// account has posts that are not seed posts.
import { Api, loadManifest, parseArgs, target, utcToday } from './lib.mjs';

const args = parseArgs(process.argv.slice(2));
const dryRun = Boolean(args['dry-run']);
const manifest = loadManifest();
const { username } = manifest.account;
const only = args.only ? String(args.only).split(',') : null;
const seeds = manifest.posts.filter((p) => !only || only.includes(p.slug));
const seedCaptions = new Map(seeds.map((p) => [p.caption, p.slug]));
const allCaptions = new Set(manifest.posts.map((p) => p.caption));
const say = (m = '') => console.log(m);

async function main() {
  const t = target({ allowProduction: Boolean(args.production) });
  const api = new Api(t);
  say(`${dryRun ? 'DRY RUN — nothing will be deleted.' : 'Deleting.'} Target: ${t.url}${t.production ? '  (PRODUCTION)' : ''}`);
  const [profile] = await api.select('profiles', `username=eq.${username}&select=id`);
  if (!profile) { say(`@${username} does not exist. Nothing to do.`); return; }
  const user = await api.getUser(profile.id);
  const videos = await api.select('videos', `user_id=eq.${profile.id}&select=id,caption,created_at&order=created_at`);
  const targets = videos.filter((v) => seedCaptions.has(v.caption));
  const others = videos.filter((v) => !allCaptions.has(v.caption));
  say(`@${username} (${profile.id}): ${videos.length} post(s), ${targets.length} selected seed post(s), ${others.length} non-seed.`);

  // Upcoming scheduled days first: once a post is gone its daily_sounds row keeps a copy of the sound.
  let daily = [];
  try {
    daily = await api.select('daily_sounds', `day=gte.${utcToday()}&source=eq.scheduled&select=day,video_id`);
  } catch (e) {
    if (!(e.status === 404 || ['PGRST205', '42P01'].includes(e.data?.code))) throw e;
  }
  const ids = new Set(targets.map((v) => v.id));
  for (const d of daily.filter((d) => ids.has(d.video_id))) {
    if (dryRun) { say(`  would unschedule daily sound ${d.day}`); continue; }
    try {
      await api.rpc('unschedule_daily_sound', { p_day: d.day });
      say(`  unscheduled daily sound ${d.day}`);
    } catch (e) {
      say(`  kept daily sound ${d.day}: ${e.message}`); // today with takes, or a past day
    }
  }

  const session = dryRun ? null : await api.sessionFor(user.email);
  for (const v of targets) {
    const slug = seedCaptions.get(v.caption);
    if (dryRun) { say(`  would delete ${slug.padEnd(24)} ${v.id}`); continue; }
    await api.invoke('delete-video', { videoId: v.id }, session.access_token);
    say(`  deleted ${slug.padEnd(24)} ${v.id}`);
  }

  if (args['delete-account']) {
    if (others.length) throw new Error(`@${username} has ${others.length} non-seed post(s); not deleting the account.`);
    if (dryRun) { say(`  would delete the account @${username} (${user.email})`); return; }
    await api.invoke('delete-account', {}, session.access_token);
    say(`  deleted the account @${username}`);
  }
  say(dryRun ? '\nDry run complete.' : '\nDone.');
}

main().catch((e) => { console.error(`\n✗ ${e.message}`); process.exit(1); });
