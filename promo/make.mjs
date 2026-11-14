#!/usr/bin/env node
// HandStrudel promo-video factory.
//
//   node make.mjs                       # every video in videos/
//   node make.mjs pocket-orchestra      # just one (by file name)
//   node make.mjs --skip-build          # reuse the last Debug build
//   node make.mjs --edit-only           # re-edit from the last recording (tweak captions/end card)
//   node make.mjs --no-voice            # skip the Kokoro voice-over
//   node make.mjs --device "iPhone 17 Pro"
//
// Output: out/<video>/{<video>-social.mp4, <video>-appstore-preview.mp4, <video>-cover.jpg}
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { composeScript } from './lib/choreo.mjs';
import { buildApp, resolveDevice, bootDevice, installApp, screenInfo, recordRun } from './lib/sim.mjs';
import { renderCards } from './lib/cards.mjs';
import { socialLayout, renderSocial, renderAppPreview, renderHype, thumbnail, rel } from './lib/edit.mjs';
import { renderHypeLayers, loudnessEnvelope } from './lib/hype.mjs';
import { buildVoiceMix } from './lib/voice.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const work = path.join(here, '.work');
const outRoot = path.join(here, 'out');
const config = JSON.parse(fs.readFileSync(path.join(here, 'config.json'), 'utf8'));

const args = process.argv.slice(2);
const flag = (f) => args.includes(f);
const opt = (f) => { const i = args.indexOf(f); return i >= 0 ? args[i + 1] : undefined; };
const deviceName = opt('--device') ?? config.device;
// Which cuts to make: clean (social + App Store preview), hype (flashy social).
const styles = (opt('--styles') ?? (config.styles ?? ['clean', 'hype']).join(',')).split(',');
const wanted = args.filter((a, i) => !a.startsWith('--') && !['--device', '--styles'].includes(args[i - 1]));
const log = (m) => console.log(`▸ ${m}`);

const videoIds = (wanted.length ? wanted : fs.readdirSync(path.join(here, 'videos')).filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5)));

async function main() {
  fs.mkdirSync(work, { recursive: true });
  const editOnly = flag('--edit-only');
  let dev, screen;

  if (!editOnly) {
    dev = resolveDevice(deviceName);
    bootDevice(dev, log);
    if (!flag('--skip-build')) {
      const app = buildApp({ repoRoot, derivedData: path.join(work, 'dd'), deviceId: dev.udid, log });
      installApp(dev, app, log);
    }
    screen = screenInfo(dev, work);
    fs.writeFileSync(path.join(work, 'screen.json'), JSON.stringify(screen));
    log(`device ${dev.name} ${screen.width}x${screen.height}`);
  } else {
    screen = JSON.parse(fs.readFileSync(path.join(work, 'screen.json'), 'utf8'));
  }

  const failed = [];
  for (const id of videoIds) {
   try {
    const spec = JSON.parse(fs.readFileSync(path.join(here, 'videos', `${id}.json`), 'utf8'));
    const song = JSON.parse(fs.readFileSync(path.join(here, 'songs', `${spec.song}.json`), 'utf8'));
    const runDir = path.join(work, 'runs', id);
    const outDir = path.join(outRoot, id);
    fs.mkdirSync(outDir, { recursive: true });
    console.log(`\n■ ${id}  (${song.name}, ${song.instrument}, ${song.key} ${song.scale})`);

    let run;
    if (editOnly) {
      run = JSON.parse(fs.readFileSync(path.join(runDir, 'run.json'), 'utf8'));
    } else {
      const script = composeScript(song, { screenAspect: screen.aspect });
      fs.mkdirSync(runDir, { recursive: true });
      fs.writeFileSync(path.join(runDir, 'demo.json'), JSON.stringify(script, null, 1));
      run = await recordRun({ dev, bundleId: config.bundleId, script, outDir: runDir, log });
    }

    log('rendering captions + App Store end card…');
    const layout = socialLayout(screen.aspect);
    const cards = await renderCards({ dir: path.join(runDir, 'cards'), layout, captions: spec.captions ?? [], config, brandDir: path.join(here, 'brand') });

    // Kokoro voice-over, ducking the app's music (social + hype cuts only).
    let voiced = run;
    if (config.voiceover !== false && !flag('--no-voice')) {
      log('voicing lines with Kokoro…');
      const mix = await buildVoiceMix({ spec, config, music: run.audio, duration: run.duration,
        endCardStart: run.duration - 0.5, total: run.duration + config.endCardSeconds, dir: path.join(runDir, 'voice'), log });
      if (mix) voiced = { ...run, audio: mix };
    }

    const made = [];
    if (styles.includes('clean')) {
      log('editing social cut (1080x1920)…');
      const social = renderSocial({ run: voiced, cards, captions: spec.captions ?? [], layout, endSeconds: config.endCardSeconds, out: path.join(outDir, `${id}-social.mp4`) });
      log('editing App Store preview (886x1920)…');
      made.push(social, renderAppPreview({ run, out: path.join(outDir, `${id}-appstore-preview.mp4`) }));
      thumbnail(social, 6, path.join(outDir, `${id}-cover.jpg`));
    }
    if (styles.includes('hype')) {
      log('rendering hype visuals (music-synced)…');
      const script = composeScript(song, { screenAspect: screen.aspect });
      const frames = Math.ceil(run.duration * 30);
      const layers = await renderHypeLayers({
        dir: path.join(runDir, 'hype'), layout, duration: run.duration, events: script.events, bpm: song.bpm,
        captions: (spec.captions ?? []).map(({ say, ...c }) => c), env: loudnessEnvelope(run.audio, frames), log,
      });
      log('editing hype cut (1080x1920)…');
      const hype = renderHype({ run: voiced, cards, layers, events: script.events, layout, endSeconds: config.endCardSeconds, out: path.join(outDir, `${id}-hype.mp4`) });
      thumbnail(hype, 6, path.join(outDir, `${id}-hype-cover.jpg`));
      made.push(hype);
    }
    if (styles.includes('short')) {
      log('cutting short hype (~12s)…');
      const short = await renderShort({ id, spec, song, run, cards, layout, runDir, outDir, screen });
      thumbnail(short, 1.5, path.join(outDir, `${id}-short-cover.jpg`));
      made.push(short);
    }
    for (const f of made) console.log(`  ✓ ${rel(f)}`);
   } catch (e) {
      // Keep going: one bad take shouldn't sink a long batch.
      console.error(`  ✗ ${id}: ${e.message.split('\n')[0]}`);
      failed.push(id);
    }
  }
  if (failed.length) { console.error(`\n✗ ${failed.length} failed: ${failed.join(' ')}`); process.exitCode = 1; }
}

/**
 * Short hype cut (~12s): the busiest stretch of the take, opening on a chord
 * hit with the video's hook caption + its voice line, then a quick end card.
 * TikTok's ad guidance favours 9–15s and the first 1–3s decide retention.
 */
async function renderShort({ id, spec, song, run, cards, layout, runDir, outDir, screen }) {
  const L = Math.min(config.shortSeconds ?? 9, run.duration - 0.5);
  const E = config.shortEndSeconds ?? 3;
  const { events } = composeScript(song, { screenAspect: screen.aspect });
  const busy = (s) => [...events.chords, ...events.notes].filter((e) => e.t >= s && e.t < s + L).length
    + 2 * events.chords.filter((c) => c.t >= s && c.t < s + L).length;
  // Candidate starts: chord onsets that leave a full window.
  const starts = events.chords.map((c) => c.t).filter((t) => t + L <= run.duration);
  const s = starts.length ? starts.reduce((a, b) => (busy(b) > busy(a) ? b : a)) : 0;

  const dir = path.join(runDir, 'short');
  fs.mkdirSync(dir, { recursive: true });
  const music = path.join(dir, 'music.wav');
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-ss', s.toFixed(3), '-t', (L + E).toFixed(3),
    '-i', run.audio, '-af', 'afade=t=in:d=0.05', '-c:a', 'pcm_f32le', music]);
  const shift = (list) => list.filter((e) => e.t >= s - 0.01 && e.t < s + L).map((e) => ({ ...e, t: e.t - s }));
  const ev = { chords: shift(events.chords), notes: shift(events.notes) };
  const hook = { ...(spec.shortCaption ?? spec.captions?.[0] ?? {}), start: 0, end: L - 0.35 };
  const sRun = { ...run, offset: run.offset + s, duration: L, audio: music };

  let voiced = sRun;
  if (config.voiceover !== false && !flag('--no-voice') && hook.say) {
    const mix = await buildVoiceMix({ spec: { ...spec, captions: [hook] }, config, music, duration: L,
      endCardStart: L - 0.4, total: L + E, dir: path.join(dir, 'voice'), log });
    if (mix) voiced = { ...sRun, audio: mix };
  }
  const frames = Math.ceil(L * 30);
  const env = loudnessEnvelope(run.audio, Math.ceil(run.duration * 30)).slice(Math.round(s * 30), Math.round(s * 30) + frames);
  while (env.length < frames) env.push(0);
  const { say, ...hookVis } = hook;
  const layers = await renderHypeLayers({ dir: path.join(dir, 'hype'), layout, duration: L, events: ev, bpm: song.bpm,
    captions: hook.text ? [hookVis] : [], env, log });
  log(`  short window ${s.toFixed(1)}–${(s + L).toFixed(1)}s`);
  return renderHype({ run: voiced, cards, layers, events: ev, layout, endSeconds: E, out: path.join(outDir, `${id}-short.mp4`) });
}

main().catch((e) => { console.error(`\n✗ ${e.message}`); process.exit(1); });
