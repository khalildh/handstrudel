#!/usr/bin/env node
// Posting calendar for every rendered cut: 4 posts/day, cross-posted to
// TikTok + Instagram Reels + YouTube Shorts + X.
//
//   node calendar.mjs [--start 2026-11-13]   → out/posting-calendar.csv
//
// Phase 1 = hype vs short, Phase 2 = clean vs app-only. Each video's two cuts
// in a phase land exactly GAP_DAYS apart (an A/B pair), alternating which goes
// first so posting order doesn't bias the comparison.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const startArg = args.includes('--start') ? args[args.indexOf('--start') + 1] : '2026-11-13';
const start = new Date(`${startArg}T12:00:00`);
const TIMES = ['08:30', '12:30', '16:30', '20:00']; // posts per day = TIMES.length
const GAP_DAYS = 3; // days between the two cuts of an A/B pair

// Pair order: [video, phase]. Phase 1 = hype vs short, phase 2 = clean vs
// app-only. Laid out in blocks of (TIMES.length × GAP_DAYS) pairs — at 4/day
// that's 12 pairs per 6-day block. Strongest hooks first; holiday videos land
// in December; a video's two phases are kept weeks apart.
const P1 = (id) => [id, 1], P2 = (id) => [id, 2];
const PAIRS = [
  // Nov 13–18
  ...['hands-are-the-instrument', 'pocket-orchestra', 'lofi-with-your-hands', 'villain-organ', 'slap-bass', 'pop-hook',
    'main-character-trumpet', 'sad-violin', 'campfire-guitar', 'jazz-one-hand', 'paris-accordion', 'funk-clavinet'].map(P1),
  // Nov 19–24
  ...['choir-in-your-pocket', 'kalimba-study', 'cartoon-xylophone', 'blues-harmonica', 'fairy-harp', 'eighties-ballad',
    'ambient-2am', 'saloon-piano', 'deep-cello', 'island-steel-drums', 'marimba-hands', 'sci-fi-pad'].map(P1),
  // Nov 25–30
  ...['lullaby-zero-lessons', 'sitar-reset', 'afternoon-reset-pad', 'spooky-bells'].map(P1),
  ...['pocket-orchestra', 'lofi-with-your-hands', 'villain-organ', 'slap-bass', 'pop-hook', 'jazz-one-hand', 'sad-violin', 'choir-in-your-pocket'].map(P2),
  // Dec 1–6
  ...['holiday-glockenspiel', 'snow-day-celesta'].map(P1),
  ...['main-character-trumpet', 'campfire-guitar', 'paris-accordion', 'funk-clavinet', 'kalimba-study', 'ambient-2am',
    'cartoon-xylophone', 'blues-harmonica', 'fairy-harp', 'eighties-ballad'].map(P2),
  // Dec 7–12
  ...['holiday-glockenspiel', 'snow-day-celesta', 'hands-are-the-instrument', 'lullaby-zero-lessons', 'saloon-piano', 'deep-cello',
    'island-steel-drums', 'marimba-hands', 'sci-fi-pad', 'sitar-reset', 'afternoon-reset-pad', 'spooky-bells'].map(P2),
];
const PHASES = { 1: ['1: Hype vs Short', 'hype', 'short'], 2: ['2: Clean vs App-only', 'clean', 'app'] };

const TAGS = {
  'afternoon-reset-pad': ['#ambientmusic', '#relaxingmusic'], 'ambient-2am': ['#ambientmusic', '#latenight'],
  'blues-harmonica': ['#blues', '#harmonica'], 'campfire-guitar': ['#guitar', '#acoustic'],
  'cartoon-xylophone': ['#xylophone', '#cartoon'], 'choir-in-your-pocket': ['#choir', '#vocals'],
  'deep-cello': ['#cello', '#classicalmusic'], 'eighties-ballad': ['#80s', '#synth'],
  'fairy-harp': ['#fairycore', '#harp'], 'funk-clavinet': ['#funk', '#keys'],
  'hands-are-the-instrument': ['#piano', '#nolessons'], 'holiday-glockenspiel': ['#christmasmusic', '#holiday'],
  'island-steel-drums': ['#steeldrums', '#beachvibes'], 'jazz-one-hand': ['#jazz', '#musictheory'],
  'kalimba-study': ['#studywithme', '#kalimba'], 'lofi-with-your-hands': ['#lofi', '#lofibeats'],
  'lullaby-zero-lessons': ['#lullaby', '#musicbox'], 'main-character-trumpet': ['#maincharacter', '#trumpet'],
  'marimba-hands': ['#marimba', '#asmr'], 'paris-accordion': ['#paris', '#accordion'],
  'pocket-orchestra': ['#orchestra', '#strings'], 'pop-hook': ['#songwriting', '#popmusic'],
  'sad-violin': ['#violin', '#sadmusic'], 'saloon-piano': ['#western', '#honkytonk'],
  'sci-fi-pad': ['#scifi', '#synthwave'], 'sitar-reset': ['#sitar', '#meditation'],
  'slap-bass': ['#slapbass', '#bassist'], 'snow-day-celesta': ['#winter', '#christmasvibes'],
  'spooky-bells': ['#spooky', '#halloween'], 'villain-organ': ['#villainarc', '#organ'],
};
const config = JSON.parse(fs.readFileSync(path.join(here, 'config.json'), 'utf8'));
const BASE_TAGS = ['#handstrudel', '#musicapp', '#iphoneapp'];

const CUTS = {
  hype: { file: (id) => `${id}/${id}-hype.mp4`, label: 'Hype (long)' },
  short: { file: (id) => `${id}/${id}-short.mp4`, label: 'Short (~12s)' },
  clean: { file: (id) => `${id}/${id}-social.mp4`, label: 'Clean' },
  app: { file: (id) => `${id}/${id}-appstore-preview.mp4`, label: 'App only (no captions)' },
};

const plain = (html) => html.replace(/<br\s*\/?>/gi, ' ').replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();

function copy(id, cut) {
  const spec = JSON.parse(fs.readFileSync(path.join(here, 'videos', `${id}.json`), 'utf8'));
  const song = JSON.parse(fs.readFileSync(path.join(here, 'songs', `${spec.song}.json`), 'utf8'));
  const caps = (spec.captions ?? []).map((c) => ({ text: plain(c.text), emoji: c.emoji ?? '' }));
  const hook = caps[0]?.text ?? 'Music with your hands';
  const tags = [...BASE_TAGS, ...(TAGS[id] ?? [])].join(' ');
  const cta = 'Free on the App Store: search “HandStrudel” (link in bio)';
  const instrument = song.instrument.replace(/_\d+$/, '').replace(/_/g, ' ');
  let caption;
  if (cut === 'app') {
    caption = `No captions, just the app. ${instrument[0].toUpperCase() + instrument.slice(1)} played by moving my hands in front of the camera ${caps[0]?.emoji ?? ''}\n\n${cta}`;
  } else if (cut === 'short') {
    caption = `${hook} ${caps[0]?.emoji ?? ''}\n\n${cta}`;
  } else {
    const sentence = (t) => (/[.!?…]$/.test(t) ? t : `${t}.`);
    caption = `${hook} ${caps[0]?.emoji ?? ''}\n${caps.slice(1).map((c) => sentence(c.text)).join(' ')}\n\n${cta}`;
  }
  const ytTitle = (cut === 'app' ? `${instrument[0].toUpperCase() + instrument.slice(1)}, played with hand tracking` : hook).slice(0, 90) + ' #shorts';
  // X: 280 chars (a link counts as 23). Hook + app link + two tags.
  const xBody = cut === 'app' ? `No captions, just the app. ${instrument} played by hand tracking ${caps[0]?.emoji ?? ''}` : `${hook} ${caps[0]?.emoji ?? ''}`;
  // Per-platform App Store campaign links (App Store Connect → Analytics → Campaigns).
  const link = (p) => config.campaignLinks?.[p] ?? config.appStoreUrl;
  const xPost = `${xBody.trim()}\n\nFree on iPhone: ${link('x')}\n\n#handstrudel ${(TAGS[id] ?? [])[0] ?? '#musicapp'}`;
  const xLen = [...new Intl.Segmenter().segment(xPost.replace(link('x'), 'x'.repeat(23)))].length;
  if (xLen > 280) throw new Error(`X post too long for ${id}/${cut}: ${xLen}`);
  const full = `${caption.replace(/ +\n/g, '\n').trim()}\n\n${tags}`;
  // YouTube descriptions can carry the link itself instead of "link in bio".
  const ytDesc = full.replace('search “HandStrudel” (link in bio)', link('youtube'));
  return { caption: full, ytTitle, ytDesc, xPost };
}

function notesFor(id, date) {
  const m = date.getMonth(), d = date.getDate();
  if (id === 'spooky-bells') return 'Off-season (Halloween hook): consider holding until October';
  if (id === 'holiday-glockenspiel' && (m === 0 || (m === 11 && d > 25))) return 'Holiday hook after Christmas: consider skipping';
  return '';
}

// Blocks of G = perDay × GAP_DAYS pairs: the block's first G slots take each
// pair's first cut, the next G slots the second cut → every pair is exactly
// GAP_DAYS apart. Alternate which cut goes first to balance order effects.
const perDay = TIMES.length, G = perDay * GAP_DAYS;
const posts = [];
PAIRS.forEach(([id, ph], k) => {
  const [name, a, b] = PHASES[ph];
  const [first, second] = k % 2 ? [b, a] : [a, b];
  const slot = Math.floor(k / G) * 2 * G + (k % G);
  const pair = `${id} (${CUTS[first].label} vs ${CUTS[second].label})`;
  posts.push({ slot, id, cut: first, phase: name, pair }, { slot: slot + G, id, cut: second, phase: name, pair });
});
posts.sort((x, y) => x.slot - y.slot);
const dupes = PAIRS.map(([id, ph]) => `${id}/${ph}`).filter((v, i, a) => a.indexOf(v) !== i);
if (dupes.length) throw new Error(`duplicate pairs: ${dupes.join(', ')}`);

const csvCell = (v) => `"${String(v).replace(/"/g, '""')}"`;
const rows = [['#', 'Date', 'Day', 'Time', 'Phase', 'Video', 'Cut', 'A/B pair', 'File (promo/out/…)', 'Post to', 'Caption (TikTok + Instagram)', 'YouTube Shorts title', 'YouTube description', 'X post', 'Notes', 'Posted?']];
const missing = [];
posts.forEach((p, n) => {
  const date = new Date(start); date.setDate(start.getDate() + Math.floor(p.slot / perDay));
  const file = CUTS[p.cut].file(p.id);
  if (!fs.existsSync(path.join(here, 'out', file))) missing.push(file);
  const { caption, ytTitle, ytDesc, xPost } = copy(p.id, p.cut);
  const notes = [notesFor(p.id, date), p.cut === 'app' ? '886×1920: platforms add thin side bars' : ''].filter(Boolean).join('; ');
  rows.push([n + 1, date.toISOString().slice(0, 10), date.toLocaleDateString('en-US', { weekday: 'short' }), TIMES[p.slot % perDay],
    p.phase, p.id, CUTS[p.cut].label, p.pair, file, 'TikTok, Instagram Reels, YouTube Shorts, X', caption, ytTitle, ytDesc, xPost, notes, '']);
});

const out = path.join(here, 'out', 'posting-calendar.csv');
fs.writeFileSync(out, '﻿' + rows.map((r) => r.map(csvCell).join(',')).join('\r\n') + '\r\n');
console.log(`${posts.length} posts, ${rows[1][1]} → ${rows.at(-1)[1]}  →  ${path.relative(process.cwd(), out)}`);
if (missing.length) console.log(`⚠ ${missing.length} files missing:\n  ${missing.join('\n  ')}`);
