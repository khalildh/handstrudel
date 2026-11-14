// ffmpeg editing: social 9:16 cut with captions + App Store end card, and a
// clean App Store "app preview" cut (footage + app audio only).
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const ff = (args) => execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' });

export const SOCIAL = { W: 1080, H: 1920 };

/** Footage placement inside the 1080x1920 social frame. */
export function socialLayout(screenAspect) {
  const { W, H } = SOCIAL;
  // Keep text out of the top ~220px, where the iPhone status bar / Dynamic
  // Island and Reels/TikTok/Shorts UI cover the frame.
  const capTop = 230;
  const h = 1260;
  const w = Math.round((h * screenAspect) / 2) * 2;
  return { W, H, capTop, fg: { x: Math.round((W - w) / 2), y: 500, w, h, r: 52 } };
}

export function renderSocial({ run, cards, captions, layout, endSeconds, out }) {
  const { W, H, fg } = layout;
  const D = run.duration;
  const E = endSeconds;
  const X = 0.5; // crossfade into end card
  const total = D + E - X;

  const inputs = [
    '-ss', Math.max(0, run.offset).toFixed(3), '-t', (D + 0.5).toFixed(3), '-i', run.rawVideo,
    '-i', run.audio,
    '-loop', '1', '-framerate', '30', '-t', D.toFixed(3), '-i', cards.mask,
    '-loop', '1', '-framerate', '30', '-t', D.toFixed(3), '-i', cards.frame,
    '-loop', '1', '-framerate', '30', '-t', D.toFixed(3), '-i', cards.footer,
  ];
  for (const c of cards.captions) inputs.push('-loop', '1', '-framerate', '30', '-t', D.toFixed(3), '-i', c);
  inputs.push('-loop', '1', '-framerate', '30', '-t', E.toFixed(3), '-i', cards.endcard);
  const endIdx = 5 + cards.captions.length;

  const g = [];
  g.push(`[0:v]fps=30,setpts=PTS-STARTPTS,trim=duration=${D.toFixed(3)},split=2[va][vb]`);
  g.push(`[va]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},boxblur=60:3,eq=brightness=-0.08:saturation=1.6[bg]`);
  g.push(`[vb]scale=${fg.w}:${fg.h},format=rgba[fgv]`);
  g.push(`[2:v]format=rgba,alphaextract[mask]`);
  g.push(`[fgv][mask]alphamerge[fgr]`);
  g.push(`[bg][3:v]overlay=0:0[l0]`);
  g.push(`[l0][fgr]overlay=${fg.x}:${fg.y}[l1]`);
  g.push(`[l1][4:v]overlay=0:0[l2]`);
  let last = 'l2';
  captions.forEach((c, i) => {
    const s = c.start, e = Math.min(c.end, D);
    g.push(`[${5 + i}:v]format=rgba,fade=t=in:st=${s}:d=0.25:alpha=1,fade=t=out:st=${(e - 0.25).toFixed(3)}:d=0.25:alpha=1[cap${i}]`);
    g.push(`[${last}][cap${i}]overlay=0:0:enable='between(t,${s},${e})'[k${i}]`);
    last = `k${i}`;
  });
  g.push(`[${last}]format=yuv420p,settb=AVTB,fps=30[main]`);
  g.push(`[${endIdx}:v]scale=${W}:${H},format=yuv420p,settb=AVTB,fps=30[end]`);
  g.push(`[main][end]xfade=transition=fade:duration=${X}:offset=${(D - X).toFixed(3)}[vout]`);
  g.push(`[1:a]aresample=48000,apad,atrim=0:${total.toFixed(3)},afade=t=out:st=${(total - 1.6).toFixed(3)}:d=1.6,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[aout]`);

  ff([...inputs, '-filter_complex', g.join(';'), '-map', '[vout]', '-map', '[aout]',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-profile:v', 'high',
    '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-movflags', '+faststart', '-t', total.toFixed(3), out]);
  return out;
}

/** App Store app preview: 886x1920 (6.5"/6.9" iPhone), ≤30s, footage only. */
export function renderAppPreview({ run, out }) {
  const D = Math.min(run.duration, 29.5);
  const g = [
    `[0:v]fps=30,setpts=PTS-STARTPTS,trim=duration=${D.toFixed(3)},scale=886:1920:force_original_aspect_ratio=decrease,pad=886:1920:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p[v]`,
    `[1:a]aresample=48000,apad,atrim=0:${D.toFixed(3)},afade=t=out:st=${(D - 1.2).toFixed(3)}:d=1.2,loudnorm=I=-16:TP=-1.5,aresample=48000[a]`,
  ];
  ff(['-ss', Math.max(0, run.offset).toFixed(3), '-t', (D + 0.5).toFixed(3), '-i', run.rawVideo, '-i', run.audio,
    '-filter_complex', g.join(';'), '-map', '[v]', '-map', '[a]',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-r', '30', '-profile:v', 'high', '-level', '4.0',
    '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-ac', '2', '-movflags', '+faststart', '-t', D.toFixed(3), out]);
  return out;
}

export function thumbnail(video, at, out) {
  ff(['-ss', String(at), '-i', video, '-frames:v', '1', '-q:v', '2', out]);
  return out;
}

export const rel = (p) => path.relative(process.cwd(), p);

/** Sum of decaying pulses at event times, as an ffmpeg expression in `v`. */
function pulseExpr(times, k, v = 't') {
  if (!times.length) return '0';
  return times.map((T) => `gte(${v},${T.toFixed(3)})*exp(-${k}*(${v}-${T.toFixed(3)}))`).join('+');
}

/**
 * Hype cut: music-synced background + footage that punches/shakes on chords
 * + transparent FX layer (bursts, flashes, kinetic captions) + zooming end card.
 */
export function renderHype({ run, cards, layers, events, layout, endSeconds, out }) {
  const { W, H, fg } = layout;
  const D = run.duration;
  const E = endSeconds;
  const X = 0.4;
  const total = D + E - X;
  const m = Math.round(fg.h * 0.06 / 2) * 2; // zoom headroom
  const bw = fg.w + 2 * m, bh = fg.h + 2 * m;
  const chordT = events.chords.map((c) => c.t);
  const noteT = events.notes.map((n) => n.t);
  const zoom = `1+0.055*(${pulseExpr(chordT, 7, 'it')})+0.012*(${pulseExpr(noteT, 14, 'it')})`;
  const shake = pulseExpr(chordT, 14);

  const inputs = [
    '-i', layers.bg,
    '-ss', Math.max(0, run.offset).toFixed(3), '-t', (D + 0.5).toFixed(3), '-i', run.rawVideo,
    '-loop', '1', '-framerate', '30', '-t', D.toFixed(3), '-i', cards.mask,
    '-i', layers.fx,
    '-i', run.audio,
    '-loop', '1', '-framerate', '30', '-t', E.toFixed(3), '-i', cards.endcard,
  ];
  const g = [
    `[0:v]fps=30,format=yuv420p,trim=duration=${D.toFixed(3)}[bg]`,
    `[1:v]fps=30,setpts=PTS-STARTPTS,trim=duration=${D.toFixed(3)},scale=${fg.w}:${fg.h},format=rgba[fgv]`,
    `[2:v]format=rgba,alphaextract[mask]`,
    `[fgv][mask]alphamerge,pad=${bw}:${bh}:${m}:${m}:color=black@0,format=rgba,` +
      `zoompan=z='${zoom}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${bw}x${bh}:fps=30[fgz]`,
    `[bg][fgz]overlay=x='${fg.x - m}+14*sin(t*83)*(${shake})':y='${fg.y - m}+10*cos(t*71)*(${shake})':format=auto[l1]`,
    `[3:v]fps=30,format=rgba,trim=duration=${D.toFixed(3)}[fx]`,
    `[l1][fx]overlay=0:0:format=auto,format=yuv420p,setsar=1,fps=30,settb=AVTB[main]`,
    `[5:v]scale=${W * 2}:${H * 2},zoompan=z='1+0.06*on/${Math.round(E * 30)}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${W}x${H}:fps=30,format=yuv420p,setsar=1,settb=AVTB[end]`,
    `[main][end]xfade=transition=circleopen:duration=${X}:offset=${(D - X).toFixed(3)}[vout]`,
    `[4:a]aresample=48000,apad,atrim=0:${total.toFixed(3)},afade=t=out:st=${(total - 1.6).toFixed(3)}:d=1.6,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[aout]`,
  ];
  ff([...inputs, '-filter_complex', g.join(';'), '-map', '[vout]', '-map', '[aout]',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-profile:v', 'high',
    '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-movflags', '+faststart', '-t', total.toFixed(3), out]);
  return out;
}
