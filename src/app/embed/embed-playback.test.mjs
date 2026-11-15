import assert from "node:assert/strict";
import { createServer } from "node:http";
import { createRequire } from "node:module";
import { after, before, test } from "node:test";

// Start Next locally with NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_MEDIA_BASE_URL
// set to http://127.0.0.1:43227 (also set NEXT_PUBLIC_SUPABASE_ANON_KEY=local-fixture).
// With Playwright installed or on NODE_PATH: node --test src/app/embed/embed-playback.test.mjs
const { chromium } = createRequire(import.meta.url)("playwright");
const app = new URL(process.env.EMBED_TEST_BASE_URL || "http://127.0.0.1:43226");
const fixture = new URL("http://127.0.0.1:43227");
const brokenId = "30000000-0000-0000-0000-000000000101";
const workingId = "30000000-0000-0000-0000-000000000102";
const caption = "Local fixture performance";
const watchHref = `https://handstrudel.com/watch?v=${brokenId}`;
// Two seconds of solid blue VP8 video, generated with FFmpeg, to exercise the real media pipeline.
const sample = Buffer.from(
  "GkXfo59ChoEBQveBAULygQRC84EIQoKEd2VibUKHgQJChYECGFOAZwH/////////EU2bdKtNu4tTq4QVSalmU6yBoU27i1OrhBZUrmtTrIHNTbuMU6uEElTDZ1OsggEa7AEAAAAAAABoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVSalmpyrXsYMPQkBNgI1MYXZmNjIuMTIuMTAwV0GNTGF2ZjYyLjEyLjEwMBZUrmvIrgEAAAAAAAA/14EBc8WI30ln74hJ7zmcgQAitZyDdW5kiIEAhoVWX1ZQOIOBASPjg4QdzWUA4JCwgSC6gTCagQJVsIRVuYEBElTDZ9hzc6BjwIBnyJpFo4dFTkNPREVSRIeNTGF2ZjYyLjEyLjEwMHNzsmPAi2PFiN9JZ++ISe85Z8ihRaOHRU5DT0RFUkSHlExhdmM2Mi4yOC4xMDAgbGlidnB4H0O2dfHngQCjvoEAAIDwAgCdASogADAAAEcIhYWIhYSIAgICdaoD+AIHkaudCgD+/00S//xYV/FhX8WFf/FhX/z8zu3F/OYAo5WBAfQAsQEABRCsABgAGFgv9AAIiACjlYED6ACxAQAFEKwAGAAYWC/0AAiIAB9DtnWb54IF3KOVgQAAALEBAAUQrAAYABhYL/QACIgA",
  "base64",
);

const server = createServer((req, res) => {
  const url = new URL(req.url, fixture);
  const cors = { "access-control-allow-origin": app.origin, "access-control-allow-headers": "apikey" };
  if (req.method === "OPTIONS") return res.writeHead(204, cors).end();
  if (url.pathname === "/host") {
    const height = Number(url.searchParams.get("height"));
    const id = url.searchParams.get("working") ? workingId : brokenId;
    const src = new URL(`${app.pathname.replace(/\/$/, "")}/embed?v=${id}`, app);
    return res.writeHead(200, { "content-type": "text/html" }).end(
      `<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1">
      <iframe src="${src}" title="HandStrudel performance" width="520" height="${height}" style="max-width:100%;border:0" allowfullscreen></iframe>`,
    );
  }
  if (url.pathname === "/rest/v1/feed_videos") {
    const id = url.searchParams.get("id")?.slice(3);
    const videos = [brokenId, workingId].includes(id) ? [{
      id, caption, username: "fixture_artist", thumb_key: "clips/missing.jpg",
      video_key: id === workingId ? "clips/working.webm" : "clips/missing.webm",
    }] : [];
    return res.writeHead(200, { ...cors, "content-type": "application/json" }).end(JSON.stringify(videos));
  }
  if (url.pathname === "/clips/working.webm") {
    return res.writeHead(200, { "content-type": "video/webm", "content-length": sample.length }).end(sample);
  }
  return res.writeHead(404).end();
});

let browser;
before(async () => {
  await new Promise((resolve, reject) => server.once("error", reject).listen(fixture.port, fixture.hostname, resolve));
  browser = await chromium.launch();
});
after(async () => {
  await browser?.close();
  await new Promise((resolve) => server.close(resolve));
});

async function withEmbed({ width, height, frameHeight, working = false }, run) {
  const context = await browser.newContext({ viewport: { width, height }, isMobile: true, hasTouch: true });
  await context.route("**/*", (route) => {
    const url = new URL(route.request().url());
    if (url.href === watchHref) return route.fulfill({ contentType: "text/html", body: "Local Watch stand-in" });
    return [app.origin, fixture.origin].includes(url.origin) ? route.continue() : route.abort();
  });
  try {
    const page = await context.newPage();
    page.setDefaultTimeout(10_000);
    await page.goto(`${fixture.origin}/host?height=${frameHeight}${working ? "&working=1" : ""}`);
    const iframe = page.getByTitle("HandStrudel performance");
    await run(page, iframe.contentFrame(), iframe);
  } finally {
    await context.close();
  }
}

for (const viewport of [
  { name: "narrow portrait", width: 320, height: 740, frameHeight: 140 },
  { name: "short landscape", width: 667, height: 375, frameHeight: 120 },
]) {
  test(`unplayable media offers a reachable recovery link in a ${viewport.name} iframe`, async () => {
    await withEmbed(viewport, async (page, frame, iframe) => {
      const video = frame.locator("video");
      const failedRequest = page.waitForResponse((response) => response.url() === `${fixture.origin}/clips/missing.webm`);
      await video.evaluate((node) => {
        node.focus();
        node.muted = true;
        void node.play().catch(() => {});
      });
      assert.equal((await failedRequest).status(), 404);

      const status = frame.getByRole("status");
      const recovery = frame.getByRole("link", { name: "Open on HandStrudel" });
      await recovery.and(frame.locator(":focus")).waitFor();
      assert.equal(await video.count(), 0);
      assert.equal(await status.innerText(), "This performance can't play here.");
      assert.equal(await recovery.getAttribute("href"), watchHref);
      assert.equal(await recovery.getAttribute("target"), "_blank");
      assert.equal(await recovery.getAttribute("rel"), "noopener noreferrer");
      const bounds = await iframe.boundingBox();
      for (const locator of [status, recovery]) {
        const box = await locator.boundingBox();
        assert.ok(box.x >= bounds.x && box.x + box.width <= bounds.x + bounds.width);
        assert.ok(box.y >= bounds.y && box.y + box.height <= bounds.y + bounds.height);
      }
      if (viewport.width === 320) {
        const popup = page.waitForEvent("popup");
        await recovery.press("Enter");
        await (await popup).getByText("Local Watch stand-in").waitFor();
      }
    });
  });
}

test("a playable clip keeps its native controls and caption even if the poster fails", async () => {
  await withEmbed({ width: 320, height: 740, frameHeight: 280, working: true }, async (_page, frame) => {
    const video = frame.locator("video");
    const playback = await video.evaluate(async (node) => {
      node.muted = true;
      await node.play();
      return { controls: node.controls, playing: !node.paused, width: node.videoWidth, playsInline: node.playsInline };
    });
    assert.deepEqual(playback, { controls: true, playing: true, width: 32, playsInline: true });
    assert.equal(await video.getAttribute("aria-label"), caption);
    assert.equal(await frame.getByRole("link", { name: /Local fixture performance/ }).count(), 1);
    assert.equal(await frame.getByRole("link", { name: "Open on HandStrudel" }).count(), 0);
  });
});
