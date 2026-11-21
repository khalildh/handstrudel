#!/usr/bin/env node
// One image with a mid-take frame of every rendered seed post, labelled with slug, sound and length.
//
//   node scripts/seed-official/contact-sheet.mjs [--out /path/contact-sheet.png]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { loadManifest, mediaRoot, parseArgs, readPostMedia } from './lib.mjs';

const args = parseArgs(process.argv.slice(2));
const out = args.out ?? path.join(mediaRoot(), '..', 'contact-sheet.png');
const tmp = path.join(mediaRoot(), '.work', 'sheet');
fs.rmSync(tmp, { recursive: true, force: true });
fs.mkdirSync(tmp, { recursive: true });
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const html = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

const posts = loadManifest().posts;
const cells = posts.map((p, i) => {
  const m = readPostMedia(p.slug);
  const s = m.meta.sound_setup;
  const free = ['grand_piano', 'electric_piano_1', 'nylon_guitar', 'clean_guitar', 'acoustic_bass', 'violin', 'strings', 'choir']
    .includes(s.instrument) && ['Major', 'Minor', 'Dorian', 'Pentatonic', 'Blues'].includes(s.scale);
  const frame = path.join(tmp, `${String(i).padStart(2, '0')}.jpg`);
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-ss', String(m.meta.duration_s * 0.55), '-i', m.video,
    '-frames:v', '1', '-vf', 'scale=240:427', '-q:v', '3', frame]);
  return `<figure><img src="${path.basename(frame)}"><figcaption><b>${i + 1}. ${html(p.slug)}</b><br>` +
    `${html(m.meta.instrument)} · ${s.key} ${s.scale} · ${s.bpm} BPM<br>` +
    `<span class="${free ? 'free' : 'pro'}">${free ? 'free' : 'PRO'}</span> · ${m.meta.duration_s.toFixed(1)}s · ` +
    `${m.meta.note_track?.notes.length ?? 0} notes · ${p.daily ? `daily day ${p.daily.day}` : 'not daily'}</figcaption></figure>`;
});
const cols = 5;
const width = cols * 252 + 24;
const height = Math.ceil(posts.length / cols) * 512 + 70;
fs.writeFileSync(path.join(tmp, 'sheet.html'), `<!doctype html><meta charset="utf-8"><style>
body{margin:0;padding:12px;background:#151515;color:#eee;font:12px/1.35 -apple-system,Helvetica,sans-serif}
h1{font-size:18px;margin:4px 0 10px} main{display:grid;grid-template-columns:repeat(${cols},240px);gap:12px}
figure{margin:0} img{display:block;width:240px;height:427px;border-radius:6px} figcaption{padding:4px 2px}
.free{color:#7ee787;font-weight:700} .pro{color:#f0b429;font-weight:700}</style>
<h1>@handstrudel seed posts (${posts.length})</h1><main>${cells.join('')}</main>`);
execFileSync(chrome, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--window-size=${width},${height}`,
  `--screenshot=${out}`, `file://${path.join(tmp, 'sheet.html')}`], { stdio: 'ignore' });
console.log(`wrote ${out}`);
