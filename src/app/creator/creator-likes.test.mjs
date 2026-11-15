import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { test } from "node:test";

const playwright = createRequire(import.meta.url)("playwright");
const browserType = process.env.HANDSTRUDEL_TEST_BROWSER === "webkit" ? playwright.webkit : playwright.chromium;
const app = new URL(process.env.PROFILE_LIKES_TEST_BASE_URL || "http://127.0.0.1:3825");
const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "apikey" };

test("creator profile uses the server total and distinguishes zero from missing", async () => {
  const browser = await browserType.launch();
  try {
    for (const count of [1243, 0, undefined]) {
      const page = await browser.newPage({ locale: "en-US", viewport: { width: 390, height: 844 } });
      await page.route("**/*", (route) => {
        const url = new URL(route.request().url());
        if (route.request().method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
        if (url.pathname === "/rest/v1/public_creators") {
          return route.fulfill({ headers: cors, json: [{ username: "loopmaker", display_name: "Loop Maker", likes_received: count }] });
        }
        if (url.pathname === "/rest/v1/feed_videos") {
          return route.fulfill({ headers: cors, json: [{
            id: "72000000-0000-4000-8000-000000000001", username: "loopmaker", caption: "Recent clip",
            video_key: "clips/fixture.mp4", thumb_key: "", like_count: 3, created_at: "2026-01-01T00:00:00Z",
          }] });
        }
        return url.origin === app.origin ? route.continue() : route.abort();
      });
      const path = `${app.pathname.replace(/\/$/, "")}/creator?u=loopmaker`;
      await page.goto(new URL(path, app).href);
      await page.getByRole("heading", { name: "Loop Maker" }).waitFor();
      const total = page.locator(".creator-likes");
      if (count === undefined) assert.equal(await total.count(), 0);
      else assert.equal(await total.textContent(), `${count.toLocaleString("en-US")} likes received`);
      await page.close();
    }
  } finally {
    await browser.close();
  }
});
