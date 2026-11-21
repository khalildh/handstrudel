#!/usr/bin/env node
// Renders the official account's seed posts with the real app in the iOS Simulator.
//
//   node scripts/seed-official/render.mjs                 # every post in posts.json
//   node scripts/seed-official/render.mjs sunday-piano    # one post (by slug)
//   node scripts/seed-official/render.mjs --skip-build    # reuse the last Debug build
//   node scripts/seed-official/render.mjs --edit-only     # re-cut from the last recordings
//   node scripts/seed-official/render.mjs --device "Seed iPhone 16e"
//
// Uses the promo pipeline (promo/lib): the DEBUG DemoDirector plays the song with scripted
// hands, the SoundFont engine renders the audio offline, and the app exports the take's
// SoundSetup, Learn-to-play note track and draft labels. Each post gets:
//
//   <media>/<slug>/video.mp4   720x1280 H.264 + AAC, the clean app recording (no captions/voice)
//   <media>/<slug>/thumb.jpg   720x1280 JPEG
//   <media>/<slug>/post.json   sound_setup, note_track, instrument, mode, duration, size
//
// <media> defaults to /Volumes/PRO-G40/handstrudel-seed/media (SEED_MEDIA_DIR overrides it).
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { composeScript } from '../../promo/lib/choreo.mjs';
import { buildApp, resolveDevice, bootDevice, installApp, screenInfo, recordRun } from '../../promo/lib/sim.mjs';
import { renderPost, thumbnail } from '../../promo/lib/edit.mjs';
import { loadManifest, mediaRoot, readPostMedia } from './lib.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../..');
const promo = path.join(repoRoot, 'promo');
const config = JSON.parse(fs.readFileSync(path.join(promo, 'config.json'), 'utf8'));

const args = process.argv.slice(2);
const flag = (f) => args.includes(f);
const opt = (f) => { const i = args.indexOf(f); return i >= 0 ? args[i + 1] : undefined; };
const wanted = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--device');
const log = (m) => console.log(`▸ ${m}`);

const media = mediaRoot();
const work = path.join(media, '.work');
const manifest = loadManifest();
const posts = wanted.length ? manifest.posts.filter((p) => wanted.includes(p.slug)) : manifest.posts;
if (wanted.length && posts.length !== wanted.length) throw new Error(`unknown slug in: ${wanted.join(' ')}`);

fs.mkdirSync(work, { recursive: true });
let dev, screen;
if (!flag('--edit-only')) {
  dev = resolveDevice(opt('--device') ?? config.device);
  bootDevice(dev, log);
  if (!flag('--skip-build')) {
    // DerivedData stays on the media volume, not the startup disk.
    installApp(dev, buildApp({ repoRoot, derivedData: path.join(work, 'dd'), deviceId: dev.udid, log }), log);
  }
  screen = screenInfo(dev, work);
  log(`device ${dev.name} ${screen.width}x${screen.height}`);
}

const failed = [];
for (const post of posts) {
  try {
    const song = JSON.parse(fs.readFileSync(path.join(promo, 'songs', `${post.song}.json`), 'utf8'));
    const runDir = path.join(work, 'runs', post.slug);
    const outDir = path.join(media, post.slug);
    fs.mkdirSync(outDir, { recursive: true });
    console.log(`\n■ ${post.slug}  (${song.name}, ${song.instrument}, ${song.key} ${song.scale}, ${song.bpm} BPM)`);
    let run;
    if (flag('--edit-only')) {
      run = JSON.parse(fs.readFileSync(path.join(runDir, 'run.json'), 'utf8'));
    } else {
      const script = composeScript(song, { screenAspect: screen.aspect });
      fs.mkdirSync(runDir, { recursive: true });
      fs.writeFileSync(path.join(runDir, 'demo.json'), JSON.stringify(script, null, 1));
      run = await recordRun({ dev, bundleId: config.bundleId, script, outDir: runDir, log });
    }
    if (!run.soundSetup || !run.postLabels) {
      throw new Error('the app did not export sound_setup.json / post_labels.json (rebuild without --skip-build)');
    }
    const video = path.join(outDir, 'video.mp4');
    const { duration } = renderPost({ run, out: video });
    const thumb = thumbnail(video, Math.min(6, duration / 2), path.join(outDir, 'thumb.jpg'));
    const soundSetup = JSON.parse(fs.readFileSync(run.soundSetup, 'utf8'));
    const labels = JSON.parse(fs.readFileSync(run.postLabels, 'utf8'));
    const noteTrack = run.noteTrack ? JSON.parse(fs.readFileSync(run.noteTrack, 'utf8')) : null;
    if (soundSetup.instrument !== song.instrument || soundSetup.key !== song.key || soundSetup.scale !== song.scale) {
      throw new Error(`exported setup ${soundSetup.instrument} ${soundSetup.key} ${soundSetup.scale} does not match the song`);
    }
    const probe = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration:stream=width,height',
      '-of', 'json', video], { encoding: 'utf8' });
    const info = JSON.parse(probe);
    const v = info.streams.find((s) => s.width);
    fs.writeFileSync(path.join(outDir, 'post.json'), JSON.stringify({
      slug: post.slug,
      song: post.song,
      duration_s: Math.round(Number(info.format.duration) * 1000) / 1000,
      width: v.width,
      height: v.height,
      instrument: labels.instrument,
      mode: labels.mode,
      sound_setup: soundSetup,
      note_track: noteTrack,
    }, null, 2) + '\n');
    const m = readPostMedia(post.slug);
    console.log(`  ✓ ${video} (${(m.videoBytes / 1e6).toFixed(1)} MB, ${m.meta.duration_s}s, ` +
      `${noteTrack?.notes.length ?? 0} notes) + ${path.basename(thumb)}`);
  } catch (e) {
    console.error(`  ✗ ${post.slug}: ${e.message.split('\n')[0]}`);
    failed.push(post.slug);
  }
}
if (failed.length) { console.error(`\n✗ ${failed.length} failed: ${failed.join(' ')}`); process.exitCode = 1; }
