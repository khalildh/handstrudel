// Renders overlay graphics (captions, frame mask, footer, App Store end card)
// as PNGs with headless Chrome, so the look is plain HTML/CSS.
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';
import QRCode from 'qrcode';

const FONTS = `<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;800&family=Inter:wght@500;700;800;900&display=swap" rel="stylesheet">`;

const BASE_CSS = `
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{background:transparent;width:100%;height:100%;overflow:hidden}
  body{font-family:Inter,-apple-system,"SF Pro Display",system-ui,sans-serif;color:#fff;-webkit-font-smoothing:antialiased}
  .wm{font-family:"JetBrains Mono",ui-monospace,monospace;letter-spacing:.02em}
  .wm .a{font-weight:300;color:#d6d6d6}
  .wm .b{font-weight:800;background:linear-gradient(90deg,#3ddc84,#38bdf8);-webkit-background-clip:text;background-clip:text;color:transparent}
`;

async function launch() {
  const opts = [{ channel: 'chrome' }, {}];
  for (const o of opts) {
    try { return await chromium.launch(o); } catch { /* try next */ }
  }
  const cache = path.join(process.env.HOME, 'Library/Caches/ms-playwright');
  for (const dir of fs.existsSync(cache) ? fs.readdirSync(cache).sort().reverse() : []) {
    if (!dir.startsWith('chromium-')) continue;
    const exe = path.join(cache, dir, 'chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing');
    if (fs.existsSync(exe)) return chromium.launch({ executablePath: exe });
  }
  throw new Error('No Chrome found for rendering cards. Install Google Chrome.');
}

async function shot(browser, html, file, w, h, transparent = true) {
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  await page.setContent(`<!doctype html><html><head><meta charset="utf-8">${FONTS}<style>${BASE_CSS}</style></head><body>${html}</body></html>`,
    { waitUntil: 'networkidle' }).catch(() => {});
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: file, omitBackground: transparent });
  await page.close();
}

const dataUri = (file) => `data:image/${path.extname(file).slice(1).replace('svg', 'svg+xml')};base64,${fs.readFileSync(file).toString('base64')}`;

/**
 * Render every graphic a video needs into `dir`.
 * layout: { W, H, fg: {x,y,w,h,r} }
 */
export async function renderCards({ dir, layout, captions, config, brandDir }) {
  fs.mkdirSync(dir, { recursive: true });
  const { W, H, fg } = layout;
  const browser = await launch();
  try {
    // Rounded-corner mask for the app footage.
    await shot(browser, `<div style="position:absolute;inset:0;background:#fff;border-radius:${fg.r}px"></div>`,
      path.join(dir, 'mask.png'), fg.w, fg.h);

    // Soft glow/border drawn behind the footage.
    await shot(browser, `<div style="position:absolute;left:${fg.x}px;top:${fg.y}px;width:${fg.w}px;height:${fg.h}px;
        border-radius:${fg.r}px;box-shadow:0 0 0 2px rgba(255,255,255,.14),0 30px 120px rgba(56,189,248,.28),0 0 220px rgba(61,220,132,.18)"></div>`,
      path.join(dir, 'frame.png'), W, H);

    // Footer: wordmark + "on the App Store".
    const footerY = fg.y + fg.h + Math.round((H - fg.y - fg.h) / 2);
    await shot(browser, `<div style="position:absolute;left:0;right:0;top:${footerY - 24}px;text-align:center;font-size:34px;font-weight:700;opacity:.92">
        <span class="wm" style="font-size:38px"><span class="a">hand</span><span class="b">strudel</span></span>
        <span style="color:#9aa3ad;font-weight:600;font-size:28px;margin-left:14px">· on the App Store</span></div>`,
      path.join(dir, 'footer.png'), W, H);

    // Captions (top band above the footage).
    const files = [];
    for (const [i, c] of captions.entries()) {
      const f = path.join(dir, `caption_${i}.png`);
      await shot(browser, `<div style="position:absolute;left:40px;right:40px;top:${layout.capTop ?? 0}px;height:${fg.y - (layout.capTop ?? 0) - 20}px;display:flex;align-items:center;justify-content:center;text-align:center">
          <div style="font-size:${c.size ?? 64}px;line-height:1.08;font-weight:900;letter-spacing:-.02em;text-shadow:0 4px 30px rgba(0,0,0,.7)">
          ${c.text.replace(/<em>/g, '<em style="font-style:normal;background:linear-gradient(90deg,#3ddc84,#38bdf8);-webkit-background-clip:text;background-clip:text;color:transparent">')}</div></div>`,
        f, W, H);
      files.push(f);
    }

    // End card.
    const icon = dataUri(path.join(brandDir, 'app-icon.png'));
    const badgeFile = ['app-store-badge.svg', 'app-store-badge.png'].map((n) => path.join(brandDir, n)).find(fs.existsSync);
    const cta = badgeFile
      ? `<img src="${dataUri(badgeFile)}" style="height:120px">`
      : `<div style="display:inline-flex;align-items:center;gap:18px;padding:26px 46px;border-radius:999px;background:#fff;color:#000;font-size:40px;font-weight:800;box-shadow:0 20px 80px rgba(56,189,248,.35)">
           <svg width="40" height="40" viewBox="0 0 24 24"><path fill="#000" d="M12 3v12m0 0l-5-5m5 5l5-5M5 21h14" stroke="#000" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>
           ${config.ctaText}</div>`;
    let qr = '';
    if (config.appStoreUrl) {
      const svg = await QRCode.toString(config.appStoreUrl, { type: 'svg', margin: 1, color: { dark: '#000', light: '#fff' } });
      qr = `<div style="margin-top:56px;display:flex;align-items:center;justify-content:center;gap:28px">
              <div style="width:190px;height:190px;background:#fff;border-radius:22px;padding:12px">${svg}</div>
              <div style="text-align:left;font-size:30px;color:#c9d1d9;line-height:1.35;font-weight:600">Scan to<br>download</div></div>`;
    }
    const endHtml = `
      <div style="position:absolute;inset:0;background:radial-gradient(1200px 900px at 50% 38%,#0f2a2a 0%,#06090c 55%,#000 100%)"></div>
      <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 60px">
        <img src="${icon}" style="width:300px;height:300px;border-radius:68px;box-shadow:0 30px 120px rgba(61,220,132,.35),0 0 0 2px rgba(255,255,255,.08)">
        <div class="wm" style="font-size:104px;margin-top:64px"><span class="a">hand</span><span class="b">strudel</span></div>
        <div style="font-size:44px;color:#c9d1d9;margin-top:18px;font-weight:500">${config.tagline}</div>
        <div style="margin-top:84px">${cta}</div>
        <div style="margin-top:34px;font-size:32px;color:#8b949e;font-weight:600">${config.searchHint}</div>
        ${qr}
      </div>`;
    await shot(browser, endHtml, path.join(dir, 'endcard.png'), W, H, false);

    return { mask: path.join(dir, 'mask.png'), frame: path.join(dir, 'frame.png'), footer: path.join(dir, 'footer.png'),
      captions: files, endcard: path.join(dir, 'endcard.png') };
  } finally {
    await browser.close();
  }
}
