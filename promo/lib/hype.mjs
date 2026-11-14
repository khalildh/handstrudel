// "Hype" style: music-synced motion graphics rendered frame-by-frame in a
// headless Chrome canvas. Produces two layers for ffmpeg:
//   bg.mp4  — opaque background (neon blobs, rays, synthwave grid, rings)
//   fx.mov  — transparent foreground (note bursts on the footage, flashes,
//             kinetic captions, emoji, progress bar)
// Every frame is a pure function of time + the song's chord/note events +
// the audio loudness envelope, so renders are reproducible.
import { spawn, execFileSync } from 'node:child_process';
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const FPS = 30;

/** Per-frame loudness (0..1) from the app's audio capture. */
export function loudnessEnvelope(audioFile, frames) {
  const out = execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-i', audioFile, '-af',
    `aresample=48000,asetnsamples=${48000 / FPS}:p=0,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-`,
    '-f', 'null', '-'], { encoding: 'utf8', maxBuffer: 64 << 20 });
  const db = [...out.matchAll(/RMS_level=(-?[\d.]+|-inf)/g)].map((m) => (m[1] === '-inf' ? -90 : Number(m[1])));
  const env = db.map((d) => Math.max(0, Math.min(1, (d + 50) / 42)));
  while (env.length < frames) env.push(0);
  // light smoothing
  return env.map((v, i) => (v * 2 + (env[i - 1] ?? v) + (env[i + 1] ?? v)) / 4).slice(0, frames);
}

async function launch() {
  for (const o of [{ channel: 'chrome' }, {}]) {
    try { return await chromium.launch(o); } catch { /* next */ }
  }
  throw new Error('No Chrome found for rendering hype layers.');
}

function encoder(args) {
  const p = spawn('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((res, rej) => p.on('exit', (c) => (c === 0 ? res() : rej(new Error(`ffmpeg exited ${c}`)))));
  return { stdin: p.stdin, done };
}
const write = (stream, buf) => new Promise((r) => (stream.write(buf) ? r() : stream.once('drain', r)));

/**
 * Render bg.mp4 + fx.mov for one video.
 * opts: { dir, layout, duration, events, bpm, captions, screenAspect, env, log }
 */
export async function renderHypeLayers(opts) {
  const { dir, layout, duration, log } = opts;
  fs.mkdirSync(dir, { recursive: true });
  const frames = Math.ceil(duration * FPS);
  const bgOut = path.join(dir, 'bg.mp4');
  const fxOut = path.join(dir, 'fx.mov');
  // Skip re-rendering when nothing that affects the visuals changed.
  const key = crypto.createHash('sha1').update(JSON.stringify({ ...opts, log: 0, dir: 0 }) + PAGE).digest('hex');
  const keyFile = path.join(dir, 'key.txt');
  if (fs.existsSync(bgOut) && fs.existsSync(fxOut) && fs.existsSync(keyFile) && fs.readFileSync(keyFile, 'utf8') === key) {
    log?.('  hype layers unchanged — reusing');
    return { bg: bgOut, fx: fxOut };
  }

  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: layout.W, height: layout.H } });
  await page.setContent(PAGE, { waitUntil: 'networkidle' }).catch(() => {});
  await page.evaluate(async (data) => {
    await document.fonts.load('900 64px Inter');
    await document.fonts.load('800 64px Inter');
    window.setup(data);
  }, { ...opts, log: undefined, dir: undefined, fps: FPS, frames });

  const bg = encoder(['-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p', bgOut]);
  const fx = encoder(['-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'png', '-i', '-',
    '-c:v', 'png', '-pix_fmt', 'rgba', fxOut]);

  const t0 = Date.now();
  for (let f = 0; f < frames; f++) {
    const { b, x } = await page.evaluate((fr) => window.frame(fr), f);
    await write(bg.stdin, Buffer.from(b, 'base64'));
    await write(fx.stdin, Buffer.from(x, 'base64'));
    if (f % 150 === 0 && f) log?.(`  hype frames ${f}/${frames} (${((Date.now() - t0) / f).toFixed(0)}ms/frame)`);
  }
  bg.stdin.end(); fx.stdin.end();
  await Promise.all([bg.done, fx.done]);
  await browser.close();
  fs.writeFileSync(keyFile, key);
  return { bg: bgOut, fx: fxOut };
}

// ---------------------------------------------------------------------------
// The scene. Runs inside Chrome.
const PAGE = `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@800;900&display=swap" rel="stylesheet">
<style>html,body{margin:0;background:transparent}canvas{display:block}</style></head>
<body><canvas id="bg"></canvas><canvas id="fx"></canvas>
<script>
let D, bgc, fxc, B, X;
const TAU = Math.PI * 2;
function rng(seed){ let s = seed >>> 0 || 1; return () => (s = (s * 1664525 + 1013904223) >>> 0) / 4294967296; }
const ease = (u) => 1 - Math.pow(1 - u, 3);
const backOut = (u) => { const c = 1.6; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); };
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));

window.setup = (data) => {
  D = data;
  bgc = document.getElementById('bg'); fxc = document.getElementById('fx');
  bgc.width = fxc.width = D.layout.W; bgc.height = fxc.height = D.layout.H;
  B = bgc.getContext('2d'); X = fxc.getContext('2d');
  // Each chord gets a hue; neighbouring degrees far apart on the wheel.
  D.hueFor = (zone) => [168, 285, 205, 330, 45, 250, 10][zone % 7];
  D.chords = D.events.chords; D.notes = D.events.notes;
  D.spb = 60 / D.bpm;
  // Footage rect (where the app screen sits) → map app screen coords.
  D.toFrame = (sx, sy) => ({ x: D.layout.fg.x + sx * D.layout.fg.w, y: D.layout.fg.y + sy * D.layout.fg.h });
};

function chordAt(t) { let c = null; for (const k of D.chords) if (k.t <= t) c = k; return c; }
function pulse(list, t, k) { let p = 0; for (const e of list) { const d = t - e.t; if (d >= 0 && d < 2) p += Math.exp(-k * d); } return Math.min(1.5, p); }

function hueAt(t) {
  const c = chordAt(t); if (!c) return 190 + t * 10;
  const i = D.chords.indexOf(c); const prev = D.chords[i - 1];
  const target = D.hueFor(c.zone), from = prev ? D.hueFor(prev.zone) : target;
  let dh = ((target - from + 540) % 360) - 180;
  return from + dh * ease(clamp((t - c.t) / 0.5)) + Math.sin(t * 0.7) * 12;
}

function drawBG(t, f) {
  const { W, H, fg } = D.layout; const env = D.env[f] || 0;
  const hue = hueAt(t); const cp = pulse(D.chords, t, 3.5); const np = pulse(D.notes, t, 9);
  B.globalCompositeOperation = 'source-over';
  B.fillStyle = '#05030b'; B.fillRect(0, 0, W, H);
  B.globalCompositeOperation = 'lighter';
  // Drifting neon blobs
  const blobs = [[0.2, 0.25, 0], [0.85, 0.55, 70], [0.3, 0.85, 150], [0.75, 0.12, 220]];
  blobs.forEach(([bx, by, ho], i) => {
    const x = (bx + 0.12 * Math.sin(t * (0.35 + i * 0.07) + i * 2)) * W;
    const y = (by + 0.08 * Math.cos(t * (0.3 + i * 0.05) + i)) * H;
    const r = 620 + 160 * Math.sin(t * 0.5 + i) + 260 * cp;
    const g = B.createRadialGradient(x, y, 0, x, y, r);
    const a = 0.32 + 0.35 * env + 0.25 * cp;
    g.addColorStop(0, 'hsla(' + (hue + ho) + ',100%,60%,' + a + ')');
    g.addColorStop(1, 'hsla(' + (hue + ho) + ',100%,50%,0)');
    B.fillStyle = g; B.fillRect(0, 0, W, H);
  });
  // Light rays behind the phone
  const cx = W / 2, cy = fg.y + fg.h * 0.42;
  B.save(); B.translate(cx, cy); B.rotate(t * 0.25 + cp * 0.15);
  for (let i = 0; i < 14; i++) {
    B.rotate(TAU / 14);
    const g = B.createLinearGradient(0, 0, 0, -1500);
    g.addColorStop(0, 'hsla(' + (hue + i * 8) + ',100%,70%,' + (0.10 + 0.22 * env + 0.18 * cp) + ')');
    g.addColorStop(1, 'hsla(' + hue + ',100%,60%,0)');
    B.fillStyle = g; B.beginPath(); B.moveTo(0, 0); B.lineTo(-70, -1500); B.lineTo(70, -1500); B.closePath(); B.fill();
  }
  B.restore();
  // Synthwave grid (bottom)
  const horizon = H * 0.66, gh = H - horizon;
  const scroll = (t / D.spb) % 1;
  B.lineWidth = 3;
  B.strokeStyle = 'hsla(' + (hue + 180) + ',100%,65%,' + (0.35 + 0.4 * env) + ')';
  B.shadowColor = 'hsla(' + (hue + 180) + ',100%,60%,1)'; B.shadowBlur = 18;
  for (let i = 0; i < 12; i++) {
    const z = (i + scroll) / 12; const y = horizon + gh * z * z;
    B.globalAlpha = z; B.beginPath(); B.moveTo(0, y); B.lineTo(W, y); B.stroke();
  }
  B.globalAlpha = 1;
  for (let i = -10; i <= 10; i++) {
    B.beginPath(); B.moveTo(W / 2 + i * 30, horizon); B.lineTo(W / 2 + i * 260, H); B.stroke();
  }
  B.shadowBlur = 0;
  // Shockwave rings on chord hits
  for (const c of D.chords) {
    const d = t - c.t; if (d < 0 || d > 1.2) continue;
    const u = d / 1.2;
    B.strokeStyle = 'hsla(' + D.hueFor(c.zone) + ',100%,70%,' + (1 - u) + ')';
    B.lineWidth = 40 * (1 - u) + 2;
    B.beginPath(); B.arc(cx, cy, 200 + 1100 * ease(u), 0, TAU); B.stroke();
  }
  // Pulsing glow around the phone
  B.globalCompositeOperation = 'source-over';
  B.shadowColor = 'hsla(' + hue + ',100%,60%,' + (0.6 + 0.4 * cp) + ')'; B.shadowBlur = 90 + 120 * env + 80 * cp;
  B.fillStyle = '#000'; roundRect(B, fg.x, fg.y, fg.w, fg.h, fg.r); B.fill();
  B.shadowBlur = 0;
  // Floating sparkles
  const r = rng(7);
  for (let i = 0; i < 70; i++) {
    const sx = r() * W, speed = 30 + r() * 90, ph = r() * 1000;
    const y = H - ((t * speed + ph) % (H + 100));
    const tw = 0.4 + 0.6 * Math.abs(Math.sin(t * (1 + r() * 3) + ph));
    B.fillStyle = 'hsla(' + (hue + r() * 120) + ',100%,80%,' + (tw * (0.3 + 0.5 * np)) + ')';
    B.beginPath(); B.arc(sx + Math.sin(t + ph) * 20, y, 1.5 + r() * 3.5, 0, TAU); B.fill();
  }
}

function roundRect(c, x, y, w, h, r) { c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r); c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath(); }

function burst(c, ox, oy, hue, d, seed, n, power) {
  const r = rng(seed);
  for (let i = 0; i < n; i++) {
    const a = r() * TAU, sp = (220 + r() * 520) * power;
    const life = 0.55 + r() * 0.4; if (d > life) continue;
    const u = d / life;
    const x = ox + Math.cos(a) * sp * ease(u), y = oy + Math.sin(a) * sp * ease(u) + 140 * u * u;
    c.fillStyle = 'hsla(' + (hue + r() * 60 - 30) + ',100%,' + (65 + r() * 25) + '%,' + (1 - u) + ')';
    const s = (3 + r() * 7) * (1 - u * 0.6);
    if (i % 3 === 0) { c.save(); c.translate(x, y); c.rotate(a + u * 6); c.fillRect(-s, -s / 3, s * 2, s * 0.66); c.restore(); }
    else { c.beginPath(); c.arc(x, y, s, 0, TAU); c.fill(); }
  }
}

function drawFX(t, f) {
  const { W, H, fg } = D.layout;
  X.clearRect(0, 0, W, H);
  X.globalCompositeOperation = 'lighter';
  // Note bursts exactly where the right hand pinches
  D.notes.forEach((n, i) => {
    const d = t - n.t; if (d < 0 || d > 1.0) return;
    const p = D.toFrame(n.x, n.y); const hue = 300 + n.lane * 22 + n.octave * 30;
    const g = X.createRadialGradient(p.x, p.y, 0, p.x, p.y, 140);
    g.addColorStop(0, 'hsla(' + hue + ',100%,75%,' + (0.9 * (1 - d)) + ')'); g.addColorStop(1, 'hsla(' + hue + ',100%,60%,0)');
    X.fillStyle = g; X.beginPath(); X.arc(p.x, p.y, 140, 0, TAU); X.fill();
    X.strokeStyle = 'hsla(' + hue + ',100%,80%,' + (1 - d) + ')'; X.lineWidth = 6 * (1 - d);
    X.beginPath(); X.arc(p.x, p.y, 20 + 160 * ease(d), 0, TAU); X.stroke();
    burst(X, p.x, p.y, hue, d, 100 + i, 22, 0.7);
  });
  // Chord bursts where the left hand pinches
  D.chords.forEach((c, i) => {
    const d = t - c.t; if (d < 0 || d > 1.2) return;
    const p = D.toFrame(c.x, c.y);
    burst(X, p.x, p.y, D.hueFor(c.zone), d, 900 + i, 46, 1.25);
  });
  X.globalCompositeOperation = 'source-over';
  // Colour flash on chord hits
  const c = chordAt(t);
  if (c) { const d = t - c.t; if (d < 0.25) { X.fillStyle = 'hsla(' + D.hueFor(c.zone) + ',100%,85%,' + (0.16 * (1 - d / 0.25)) + ')'; X.fillRect(0, 0, W, H); } }
  drawCaptions(t);
  // Progress bar
  const prog = clamp(t / D.duration);
  X.fillStyle = 'rgba(255,255,255,.15)'; roundRect(X, 80, H - 70, W - 160, 12, 6); X.fill();
  const g = X.createLinearGradient(80, 0, W - 80, 0); g.addColorStop(0, '#3ddc84'); g.addColorStop(0.5, '#38bdf8'); g.addColorStop(1, '#e879f9');
  X.fillStyle = g; roundRect(X, 80, H - 70, Math.max(12, (W - 160) * prog), 12, 6); X.fill();
}

function drawCaptions(t) {
  const { W, fg } = D.layout; const top = D.layout.capTop, bottom = fg.y - 20;
  const cp = pulse(D.chords, t, 6);
  for (const cap of D.captions) {
    if (t < cap.start - 0.05 || t > cap.end + 0.3) continue;
    const lines = cap.text.split(/<br\\s*\\/?>/i).map((l) => {
      const words = []; let em = false;
      l.replace(/<\\/?em>|[^<\\s]+/g, (m) => { if (m === '<em>') em = true; else if (m === '</em>') em = false; else words.push({ w: m.replace(/&amp;/g, '&'), em }); return m; });
      return words;
    });
    const n = lines.reduce((a, l) => a + l.length, 0);
    let size = cap.size ?? 76; X.font = '900 ' + size + 'px Inter';
    const lineW = (l) => l.reduce((a, w) => a + X.measureText(w.w).width, 0) + (l.length - 1) * size * 0.28;
    while ((Math.max(...lines.map(lineW)) > W - 120 || size * 1.12 * lines.length > bottom - top - 10) && size > 40) { size -= 2; X.font = '900 ' + size + 'px Inter'; }
    const lh = size * 1.12; const blockH = lh * lines.length; let y0 = (top + bottom) / 2 - blockH / 2 + size * 0.85;
    const exitU = clamp((t - cap.end) / 0.3);
    let k = 0;
    lines.forEach((l, li) => {
      let x = W / 2 - lineW(l) / 2;
      l.forEach((w) => {
        const ww = X.measureText(w.w).width;
        const u = clamp((t - cap.start - k * 0.07) / 0.32);
        if (u > 0) {
          const s = backOut(u) * (1 - exitU * 0.4) * (1 + 0.06 * cp);
          const cx = x + ww / 2, cy = y0 + li * lh - size * 0.35;
          X.save(); X.translate(cx, cy); X.rotate((1 - u) * (k % 2 ? 0.25 : -0.25) + Math.sin(t * 3 + k) * 0.02); X.scale(s, s);
          X.globalAlpha = clamp(u * 2) * (1 - exitU);
          X.lineJoin = 'round'; X.lineWidth = size * 0.16; X.strokeStyle = 'rgba(0,0,0,.85)';
          X.strokeText(w.w, -ww / 2, size * 0.35);
          if (w.em) {
            const g = X.createLinearGradient(-ww / 2, 0, ww / 2, 0);
            const h = hueAt(t); g.addColorStop(0, 'hsl(' + h + ',100%,65%)'); g.addColorStop(1, 'hsl(' + (h + 70) + ',100%,70%)');
            X.fillStyle = g; X.shadowColor = 'hsl(' + h + ',100%,60%)'; X.shadowBlur = 30;
          } else { X.fillStyle = '#fff'; X.shadowColor = 'rgba(255,255,255,.5)'; X.shadowBlur = 12; }
          X.fillText(w.w, -ww / 2, size * 0.35);
          X.restore();
        }
        x += ww + size * 0.28; k++;
      });
    });
    // Emoji sticker
    if (cap.emoji) {
      const u = clamp((t - cap.start - n * 0.07) / 0.35);
      if (u > 0) {
        X.save(); X.translate(W - 120, top + 30); X.rotate(0.3 * Math.sin(t * 4) - (1 - u) * 1.5);
        const s = backOut(u) * (1 + 0.15 * cp) * (1 - exitU); X.scale(s, s); X.globalAlpha = 1 - exitU;
        X.font = '110px "Apple Color Emoji"'; X.textAlign = 'center'; X.fillText(cap.emoji, 0, 40); X.textAlign = 'start';
        X.restore();
      }
    }
  }
}

window.frame = (f) => {
  const t = f / D.fps;
  drawBG(t, f); drawFX(t, f);
  return { b: bgc.toDataURL('image/jpeg', 0.9).split(',')[1], x: fxc.toDataURL('image/png').split(',')[1] };
};
</script></body></html>`;
