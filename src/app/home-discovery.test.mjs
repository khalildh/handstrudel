import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { after, before, test } from "node:test";

// Start Next on port 43246 with NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_MEDIA_BASE_URL
// pointed at a local placeholder. With Playwright installed or on NODE_PATH:
// node --test src/app/home-discovery.test.mjs
const playwright = createRequire(import.meta.url)("playwright");
const browserType = process.env.HANDSTRUDEL_TEST_BROWSER === "webkit" ? playwright.webkit : playwright.chromium;
const base = new URL(process.env.HOME_TEST_BASE_URL || "http://127.0.0.1:43246");
const prefix = base.pathname.replace(/\/$/, "");
const watchPath = `${prefix}/watch`;
const playPath = `${prefix}/play`;
const homeUrl = new URL(`${prefix}/`, base).href;
const appStore = "https://apps.apple.com/app/apple-store/id6764415289?pt=127873492&ct=website&mt=8";
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
  test(`the iPhone download leads, without requesting a camera on ${viewport.name}`, async () => {
    const { width, height, mobile } = viewport;
    const context = await browser.newContext({ viewport: { width, height }, isMobile: mobile, hasTouch: mobile, reducedMotion: "reduce" });
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
      await page.goto(homeUrl);
      const home = page.locator(".home-page");
      const hero = page.locator(".home-hero");
      const download = hero.getByRole("link", { name: "Download for iPhone" });
      const headerDownload = page.getByRole("link", { name: "Get the app" });
      const watch = page.getByRole("link", { name: "Watch", exact: true });
      await download.waitFor();
      await page.evaluate(() => document.fonts.ready);
      const box = await (height >= 640 ? download : headerDownload).boundingBox();
      assert.ok(box.width >= 44 && box.height >= 44, "The iPhone link is large enough for touch");
      assert.ok(box.x >= 0 && box.x + box.width <= width && box.y >= 0 && box.y + box.height <= height,
        "An iPhone download link is visible without scrolling");
      assert.equal(await home.evaluate((element) => element.scrollTop), 0);
      assert.ok(await home.evaluate((element) => element.scrollWidth <= element.clientWidth));
      assert.equal(await download.getAttribute("href"), appStore);
      assert.equal(await headerDownload.getAttribute("href"), appStore);
      assert.equal(await hero.getByRole("link", { name: "Try in browser" }).getAttribute("href"), playPath);
      assert.equal(await watch.getAttribute("href"), watchPath);
      assert.equal(await hero.locator("video").evaluate((element) => element.paused), true);
      assert.equal(feedRequests, 0, "Home does not fetch clip data");
      assert.equal(await page.evaluate(() => window.cameraRequests), 0);

      if (mobile) await watch.tap();
      else await watch.press("Enter");
      await page.waitForURL(url => url.pathname === watchPath);
      await page.getByRole("region", { name: "Video player" }).getByRole("heading", { name: video.caption }).waitFor();
      assert.ok(feedRequests > 0, "The existing Watch route handles clip data");
      assert.equal(await page.evaluate(() => window.cameraRequests), 0);
    } finally {
      await context.close();
    }
  });
}

test("the browser studio is reachable without requesting the camera on arrival", async () => {
  const page = await browser.newPage();
  await page.addInitScript(() => {
    window.cameraRequests = 0;
    if (navigator.mediaDevices) Object.defineProperty(navigator.mediaDevices, "getUserMedia", {
      value: async () => { window.cameraRequests += 1; throw new DOMException("Blocked", "NotAllowedError"); },
    });
  });
  try {
    await page.goto(homeUrl);
    await page.getByRole("link", { name: "Try in browser" }).click();
    await page.waitForURL(url => url.pathname === playPath);
    await page.locator("#start").getByRole("button", { name: "Start camera" }).waitFor();
    assert.equal(await page.evaluate(() => window.cameraRequests), 0);
  } finally {
    await page.close();
  }
});

test("a failed local demo links to the full performance", async () => {
  const page = await browser.newPage();
  await page.route("**/home/dreamy-piano.mp4", (route) => route.abort());
  try {
    await page.goto(homeUrl);
    await page.getByRole("button", { name: "Play demo", exact: true }).click();
    const fallback = page.getByRole("link", { name: "Watch demo" });
    await fallback.waitFor();
    assert.equal(await fallback.getAttribute("href"), `${watchPath}?v=41ba66c5-6f0a-4697-99e8-5261f7cb6240`);
  } finally {
    await page.close();
  }
});
