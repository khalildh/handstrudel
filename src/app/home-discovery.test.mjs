import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { after, before, test } from "node:test";

// Start Next on port 43246 with NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_MEDIA_BASE_URL
// pointed at a local placeholder. With Playwright installed or on NODE_PATH:
// node --test src/app/home-discovery.test.mjs
const playwright = createRequire(import.meta.url)("playwright");
const browserType = process.env.HANDSTRUDEL_TEST_BROWSER === "webkit" ? playwright.webkit : playwright.chromium;
const base = new URL(process.env.HOME_TEST_BASE_URL || "http://127.0.0.1:43246");
const watchPath = `${base.pathname.replace(/\/$/, "")}/watch`;
const video = {
  id: "30000000-0000-0000-0000-000000000301",
  username: "fixture_artist", caption: "Local community performance",
  instrument: "Kalimba", video_key: "fixture/clip.mp4", thumb_key: "fixture/clip.jpg", comments_enabled: false,
};

let browser;
before(async () => { browser = await browserType.launch(); });
after(async () => { await browser?.close(); });

for (const viewport of [
  { name: "desktop", width: 1280, height: 900, mobile: false },
  { name: "narrow mobile", width: 320, height: 640, mobile: true },
  { name: "mobile landscape", width: 667, height: 375, mobile: true },
]) {
  test(`the homepage offers a visible path to performances without camera access on ${viewport.name}`, async () => {
    const { width, height, mobile } = viewport;
    const context = await browser.newContext({ viewport: { width, height }, isMobile: mobile, hasTouch: mobile });
    let feedRequests = 0;
    await context.route("**/*", (route) => {
      const url = new URL(route.request().url());
      if (url.pathname === "/rest/v1/feed_videos") {
        feedRequests += 1;
        return route.fulfill({
          json: [video], headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" },
        });
      }
      return url.origin === base.origin ? route.continue() : route.abort();
    });
    await context.addInitScript(() => {
      window.cameraRequests = 0;
      if (navigator.mediaDevices) Object.defineProperty(navigator.mediaDevices, "getUserMedia", {
        value: async () => {
          window.cameraRequests += 1;
          throw new DOMException("Test camera blocked", "NotAllowedError");
        },
      });
    });
    try {
      const page = await context.newPage();
      page.setDefaultTimeout(15_000);
      await page.goto(new URL(`${base.pathname.replace(/\/$/, "")}/`, base).href);
      const overlay = page.locator("#start");
      const link = overlay.getByRole("link", { name: "Watch performances No camera needed" });
      await link.waitFor();
      await page.evaluate(() => document.fonts.ready);
      const box = await link.boundingBox();
      assert.ok(box.width >= 44 && box.height >= 44, "The link is large enough for touch");
      assert.ok(box.x >= 0 && box.x + box.width <= width && box.y >= 0 && box.y + box.height <= height,
        "The link is visible without scrolling");
      assert.equal(await overlay.evaluate((element) => element.scrollTop), 0);
      assert.ok(await overlay.evaluate((element) => element.scrollWidth <= element.clientWidth));
      assert.equal(await link.getAttribute("href"), watchPath);

      const start = overlay.getByRole("button", { name: "START" });
      const startBox = await start.boundingBox();
      if (height >= 640) assert.ok(startBox.y + startBox.height <= height, "Start remains above the fold");
      assert.ok(box.y < startBox.y, "Discovery is available before the setup flow");
      assert.equal(feedRequests, 0, "Home does not fetch clip data");
      assert.equal(await page.evaluate(() => window.cameraRequests), 0);

      if (mobile) await link.tap();
      else await link.press("Enter");
      await page.waitForURL(url => url.pathname === watchPath);
      await page.getByRole("region", { name: "Video player" }).getByRole("heading", { name: video.caption }).waitFor();
      assert.ok(feedRequests > 0, "The existing Watch route handles clip data");
      assert.equal(await page.evaluate(() => window.cameraRequests), 0);
    } finally {
      await context.close();
    }
  });
}
