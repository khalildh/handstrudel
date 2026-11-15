import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { after, before, test } from "node:test";

// Point NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_MEDIA_BASE_URL at a local
// placeholder in Next. Browser routes supply all data; no backend is required.
// With Playwright on NODE_PATH or installed: node --test src/app/watch/saved-chords.test.mjs
const { chromium } = createRequire(import.meta.url)("playwright");
const base = new URL(process.env.WATCH_TEST_BASE_URL || "http://127.0.0.1:43236");
const id = "30000000-0000-0000-0000-000000000201";
const clip = {
  id, username: "fixture_artist", caption: "Fixture performance", instrument: "Grand Piano",
  video_key: "fixture/clip.mp4", thumb_key: "fixture/clip.jpg", duration_s: 20, comments_enabled: false,
};
const pop = { version: 1, key: "C", scale: "Major", progression: "pop", mode: "splitchordmelody" };
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function showChords(page, setup, expected, names) {
  const intercept = (route) => route.fulfill({
    json: [{ ...clip, sound_setup: setup }],
    headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" },
  });
  await page.route("**/rest/v1/feed_videos?**", intercept);
  try {
    await page.goto(new URL(`${base.pathname.replace(/\/$/, "")}/watch?v=${id}`, base).href);
    const stage = page.getByRole("region", { name: "Video player" });
    await stage.getByRole("heading", { name: clip.caption }).waitFor();
    const badge = stage.locator(".watch-preset-chords");
    if (expected) {
      assert.ok((await badge.innerText()).includes(expected));
    } else {
      assert.equal(await badge.count(), 0);
    }
    if (names) {
      assert.equal(await badge.locator(".watch-preset-chord-names").textContent(), `Chords in this setup: ${names}`);
      assert.ok(await badge.evaluate(node => node.scrollWidth <= node.clientWidth));
    } else {
      assert.equal(await stage.getByText("Chords in this setup:", { exact: true }).count(), 0);
    }
  } finally {
    await page.unroute("**/rest/v1/feed_videos?**", intercept);
  }
}

async function withWatch(run) {
  const context = await browser.newContext({ viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true });
  await context.route("**/*", route => new URL(route.request().url()).origin === base.origin ? route.continue() : route.abort());
  try {
    const page = await context.newPage();
    page.setDefaultTimeout(10_000);
    await run(page);
  } finally {
    await context.close();
  }
}

test("the same saved Pop degrees name triads or sevenths according to mode", async () => {
  await withWatch(async (page) => {
    for (const mode of ["splitchordmelody", "radialchordmelody", "chordmelody"]) {
      await showChords(page, { ...pop, mode }, "Pop (1–5–6–4)", "Cmaj · Gmaj · Amin · Fmaj");
    }
    await showChords(page, { ...pop, mode: "scalechordmelody" }, "Pop (1–5–6–4)", "Cmaj7 · G7 · Amin7 · Fmaj7");
  });
});

test("Free and custom layouts respect Swift's scales, flat spellings, and degree order", async () => {
  await withWatch(async (page) => {
    await showChords(page, { ...pop, key: "Eb", scale: "Dorian", progression: "free" },
      "Free layout", "Ebmin · Fmin · Gbmaj · Abmaj · Bbmin · Cdim · Dbmaj");
    await showChords(page, { ...pop, key: "A", scale: "Harmonic Minor", mode: "scalechordmelody",
      progression: "custom", customDegrees: [0, 1, 4, 6, 0] },
    "Custom (1–2–5–7–1)", "Amin(maj7) · Bmin7b5 · E7 · Abdim7 · Amin(maj7)");
    await showChords(page, { ...pop, scale: "Harmonic Minor", mode: "scalechordmelody",
      progression: "custom", customDegrees: [2] }, "Custom (3)", "Ebmaj7#5");
  });
});

test("uncertain or invalid metadata does not invent chord names", async () => {
  await withWatch(async (page) => {
    for (const unknown of [
      { mode: undefined }, { mode: "soundfont" }, { mode: "futuremode" }, { key: "H" },
      { scale: undefined }, { scale: "future scale" }, { scale: "Pentatonic" },
    ]) {
      await showChords(page, { ...pop, ...unknown }, "Pop (1–5–6–4)");
    }
    await showChords(page, { ...pop, scale: "Hungarian Minor", progression: "custom", customDegrees: [0, 1] }, "Custom (1–2)");
    await showChords(page, { ...pop, progression: "custom", customDegrees: [7] });
    await showChords(page, { ...pop, version: 2 });
    await showChords(page, { ...pop, progression: "unknown" });
  });
});
