import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { after, before, test } from "node:test";

// Run against `next dev` with NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_MEDIA_BASE_URL pointing at a
// local placeholder. Browser routes supply all data; no backend is required.
// With Playwright on NODE_PATH or installed: node --test src/app/watch/challenge-banner.test.mjs
const playwright = createRequire(import.meta.url)("playwright");
const browserType = process.env.HANDSTRUDEL_TEST_BROWSER === "webkit" ? playwright.webkit : playwright.chromium;
const base = new URL(process.env.WATCH_TEST_BASE_URL || "http://127.0.0.1:43236");
const id = "30000000-0000-0000-0000-000000000301";
const clip = {
  id, username: "challenger", caption: "Answer this", instrument: "Grand Piano",
  video_key: "fixture/clip.mp4", thumb_key: "fixture/clip.jpg", duration_s: 12, comments_enabled: false,
  sound_setup: { version: 1, key: "C", scale: "Major", mode: "scalechordmelody" },
};
let browser;
before(async () => { browser = await browserType.launch(); });
after(async () => { await browser?.close(); });

async function openWatch(query) {
  const context = await browser.newContext({ viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true });
  await context.route("**/*", route => new URL(route.request().url()).origin === base.origin ? route.continue() : route.abort());
  const page = await context.newPage();
  page.setDefaultTimeout(10_000);
  await page.route("**/rest/v1/feed_videos?**", route => route.fulfill({
    json: [clip],
    headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" },
  }));
  await page.goto(new URL(`${base.pathname.replace(/\/$/, "")}/watch?${query}`, base).href);
  await page.getByRole("region", { name: "Video player" }).getByRole("heading", { name: clip.caption }).waitFor();
  return { page, context };
}

test("a challenge link shows the banner with the App Store and in-app reply links", async () => {
  const { page, context } = await openWatch(`v=${id}&reply=1`);
  try {
    const banner = page.getByRole("complementary", { name: "Challenge" });
    await banner.getByRole("heading", { name: "You've been challenged" }).waitFor();
    assert.ok((await banner.innerText()).includes("@challenger"));
    assert.equal(await banner.getByRole("link", { name: /Reply in the app/ }).getAttribute("href"), `handstrudel://reply/${id}`);
    assert.equal(await banner.getByRole("link", { name: /App Store/ }).getAttribute("href"), "https://apps.apple.com/app/id6764415289");
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
  } finally {
    await context.close();
  }
});

test("a normal watch link has no challenge banner", async () => {
  const { page, context } = await openWatch(`v=${id}`);
  try {
    assert.equal(await page.getByRole("complementary", { name: "Challenge" }).count(), 0);
  } finally {
    await context.close();
  }
});
