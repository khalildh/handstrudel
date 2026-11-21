#!/usr/bin/env node
// One image with a mid-take frame of every rendered seed post, labelled with slug, sound and length.
//
//   node scripts/seed-official/contact-sheet.mjs [--out /path/contact-sheet.jpg]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { loadManifest, mediaRoot, parseArgs, readPostMedia } from './lib.mjs';

const args = parseArgs(process.argv.slice(2));
const out = args.out ?? path.join(mediaRoot(), '..', 'contact-sheet.jpg');
const tmp = path.join(mediaRoot(), '.work', 'sheet');
fs.rmSync(tmp, { recursive: true, force: true });
fs.mkdirSync(tmp, { recursive: true });
const font = ['/System/Library/Fonts/Supplemental/Arial.ttf', '/System/Library/Fonts/Helvetica.ttc'].find((f) => fs.existsSync(f));
const esc = (s) => s.replace(/\\/g, '\\\\').replace(/:/g, '\\:').replace(/'/g, '\u2019').replace(/%/g, '\\%');

const posts = loadManifest().posts;
posts.forEach((p, i) => {
  const m = readPostMedia(p.slug);
  const s = m.meta.sound_setup;
  const free = ['grand_piano', 'electric_piano_1', 'nylon_guitar', 'clean_guitar', 'acoustic_bass', 'violin', 'strings', 'choir']
    .includes(s.instrument) && ['Major', 'Minor', 'Dorian', 'Pentatonic', 'Blues'].includes(s.scale);
  const lines = [`${i + 1}. ${p.slug}`, `${m.meta.instrument} · ${s.key} ${s.scale}`,
    `${free ? 'free' : 'PRO'} · ${m.meta.duration_s.toFixed(1)}s · ${p.daily ? `day ${p.daily.day}` : 'no daily'}`];
  const text = lines.map((l, k) => `drawtext=fontfile=${font}:text='${esc(l)}':x=12:y=${300 + k * 26}:fontsize=${k ? 17 : 20}:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=4`).join(',');
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-ss', String(m.meta.duration_s * 0.55), '-i', m.video,
    '-frames:v', '1', '-vf', `scale=240:427,${text}`, path.join(tmp, `${String(i).padStart(2, '0')}.png`)]);
});
const cols = 5;
const rows = Math.ceil(posts.length / cols);
execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-framerate', '1', '-i', path.join(tmp, '%02d.png'),
  '-vf', `tile=${cols}x${rows}:padding=6:color=0x222222`, '-frames:v', '1', '-q:v', '3', out]);
console.log(`wrote ${out}`);
