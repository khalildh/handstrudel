#!/usr/bin/env node
// Social profile assets: circle-safe avatar + YouTube banner, in brand style.
//   node profile-kit.mjs  → out/profile-kit/
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(here, 'out', 'profile-kit');
fs.mkdirSync(out, { recursive: true });
const icon = `data:image/png;base64,${fs.readFileSync(path.join(here, 'brand', 'app-icon.png')).toString('base64')}`;
const config = JSON.parse(fs.readFileSync(path.join(here, 'config.json'), 'utf8'));

const HEAD = `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;800&family=Inter:wght@500;600;700&display=swap" rel="stylesheet">
<style>
  html,body{margin:0;background:#000;color:#fff;font-family:Inter,system-ui,sans-serif;-webkit-font-smoothing:antialiased}
  .wm{font-family:"JetBrains Mono",monospace;letter-spacing:.02em}
  .wm .a{font-weight:300;color:#d6d6d6}
  .wm .b{font-weight:800;background:linear-gradient(90deg,#3ddc84,#38bdf8);-webkit-background-clip:text;background-clip:text;color:transparent}
</style></head><body>`;

// Avatar: icon shrunk so its whole drawing survives a circular crop.
const avatar = `${HEAD}<div style="width:1080px;height:1080px;display:grid;place-items:center;
  background:radial-gradient(circle at 50% 50%,#04140c 0%,#000 70%)">
  <img src="${icon}" style="width:930px;height:930px;border-radius:50%"></div></body></html>`;

// YouTube banner 2560×1440; everything important inside the 1546×423 safe area.
const banner = `${HEAD}<div style="position:relative;width:2560px;height:1440px;overflow:hidden;
  background:radial-gradient(1400px 700px at 50% 50%,#0f2a2a 0%,#06090c 55%,#000 100%)">
  <svg width="2560" height="1440" style="position:absolute;inset:0;opacity:.35">
    ${[0, 1, 2, 3].map((i) => `<path d="M0 ${980 + i * 34} ${Array.from({ length: 33 }, (_, k) => `L${k * 80} ${980 + i * 34 + Math.sin(k * 0.6 + i) * (26 - i * 4)}`).join(' ')}" stroke="${i % 2 ? '#38bdf8' : '#3ddc84'}" stroke-width="3" fill="none"/>`).join('')}
  </svg>
  <div style="position:absolute;left:507px;top:508px;width:1546px;height:423px;display:flex;align-items:center;gap:56px;justify-content:center">
    <img src="${icon}" style="width:330px;height:330px;border-radius:72px;box-shadow:0 0 90px #3ddc8455">
    <div>
      <div class="wm" style="font-size:150px;line-height:1"><span class="a">hand</span><span class="b">strudel</span></div>
      <div style="font-size:54px;color:#c9d1d9;margin-top:22px;font-weight:500">${config.tagline}</div>
      <div style="font-size:40px;color:#8b949e;margin-top:20px;font-weight:600">Free on the App Store · new videos daily</div>
    </div>
  </div></div></body></html>`;

// X header 1500×500. The avatar overlaps the lower-left corner and phones
// crop the top/bottom, so keep content in the right-centre band.
const xHeader = `${HEAD}<div style="position:relative;width:1500px;height:500px;overflow:hidden;
  background:radial-gradient(900px 420px at 60% 50%,#0f2a2a 0%,#06090c 60%,#000 100%)">
  <svg width="1500" height="500" style="position:absolute;inset:0;opacity:.35">
    ${[0, 1, 2, 3].map((i) => `<path d="M0 ${400 + i * 18} ${Array.from({ length: 21 }, (_, k) => `L${k * 75} ${400 + i * 18 + Math.sin(k * 0.6 + i) * (14 - i * 2)}`).join(' ')}" stroke="${i % 2 ? '#38bdf8' : '#3ddc84'}" stroke-width="2" fill="none"/>`).join('')}
  </svg>
  <div style="position:absolute;left:430px;right:60px;top:110px;height:260px;display:flex;align-items:center;gap:36px">
    <img src="${icon}" style="width:190px;height:190px;border-radius:42px;box-shadow:0 0 60px #3ddc8455">
    <div>
      <div class="wm" style="font-size:96px;line-height:1"><span class="a">hand</span><span class="b">strudel</span></div>
      <div style="font-size:36px;color:#c9d1d9;margin-top:14px;font-weight:500">${config.tagline}</div>
      <div style="font-size:26px;color:#8b949e;margin-top:12px;font-weight:600">Free on the App Store</div>
    </div>
  </div></div></body></html>`;

let browser;
for (const o of [{ channel: 'chrome' }, {}]) { try { browser = await chromium.launch(o); break; } catch { /* next */ } }
const page = await browser.newPage();
const shot = async (html, w, h, file) => {
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: path.join(out, file), clip: { x: 0, y: 0, width: w, height: h } });
};
await shot(avatar, 1080, 1080, 'avatar-1080.png');
await shot(banner, 2560, 1440, 'youtube-banner-2560x1440.png');
await shot(xHeader, 1500, 500, 'x-header-1500x500.png');
await browser.close();
console.log(`wrote ${path.relative(process.cwd(), out)}/`);
