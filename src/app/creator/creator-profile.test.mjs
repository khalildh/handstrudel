import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { test } from "node:test";

// With npm run dev running: node --test src/app/creator/creator-profile.test.mjs
// Install playwright locally (npm install --no-save --package-lock=false playwright) or provide it via NODE_PATH.
// Set CREATOR_TEST_BASE_URL to target a non-default port or a static export.
const { chromium } = createRequire(import.meta.url)("playwright");
const baseURL = new URL(process.env.CREATOR_TEST_BASE_URL || "http://127.0.0.1:3000");
const basePath = baseURL.pathname.replace(/\/$/, "");
const profileURL = new URL(`${basePath}/creator`, baseURL).href;
const clipPath = (id) => `${basePath}/watch?v=${id}`;
const creator = { username: "loopmaker", display_name: "Loop Maker" };
const videos = Array.from({ length: 27 }, (_, i) => ({
  id: `30000000-0000-0000-0000-${String(100 - i).padStart(12, "0")}`,
  username: creator.username,
  display_name: creator.display_name,
  caption: `Evening study ${i + 1}`,
  instrument: i < 12 ? "Violin" : "Kalimba",
  video_key: "fixture/clip.mp4",
  thumb_key: "fixture/thumb.jpg",
  duration_s: 32,
  width: 720,
  height: 1280,
  // Identical timestamps exercise the ID tie-breaker at every page boundary.
  created_at: "2026-11-01T20:00:00+00:00",
}));

async function mockFeed(page, { failFirstSearchPage = false, libraryUnavailable = () => false } = {}) {
  const requests = [];
  await page.route("**/*", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const json = (value, status = 200) => route.fulfill({
      status, json: value, headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" },
    });
    if (!url.pathname.startsWith("/rest/v1/")) {
      return url.origin === baseURL.origin ? route.continue() : route.abort();
    }
    if (request.method() === "OPTIONS") return json(null);
    assert.equal(request.method(), "GET");
    const handle = url.searchParams.get("username");
    if (url.pathname.endsWith("/public_creators")) {
      return json(handle === "eq.empty_artist" ? [{ username: "empty_artist" }]
        : handle === `eq.${creator.username}` ? [creator] : []);
    }
    assert.equal(url.pathname, "/rest/v1/feed_videos");
    assert.equal(url.searchParams.get("order"), "created_at.desc,id.desc");
    assert.equal(url.searchParams.get("limit"), "12");
    const filter = url.searchParams.get("or") ?? "";
    const query = filter.match(/caption\.imatch\."([^"]+)"/)?.[1]?.toLowerCase();
    const cursor = filter.match(/id\.lt\.([\da-f-]+)/)?.[1];
    requests.push({ handle, query, cursor });
    if (!query && !cursor && libraryUnavailable()) return json({}, 503);
    if (query && cursor && failFirstSearchPage) {
      failFirstSearchPage = false;
      return json({}, 503);
    }
    return json(videos.filter((video) => handle === `eq.${video.username}`
      && (!cursor || video.id < cursor)
      && (!query || [video.caption, video.instrument].some((field) => field.toLowerCase().includes(query)))).slice(0, 12));
  });
  return requests;
}

async function withPage(options, run) {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage(options);
    page.setDefaultTimeout(10_000);
    await run(page);
  } finally {
    await browser.close();
  }
}

test("creator library searches beyond the first page and keeps its scope while paging", async () => {
  await withPage({}, async (page) => {
    const requests = await mockFeed(page, { failFirstSearchPage: true });
    await page.goto(`${profileURL}?u=loopmaker`);
    await page.getByText("Showing 12 performances").waitFor();
    const library = page.getByRole("region", { name: "Public performances" });
    const clips = library.getByRole("listitem");
    assert.equal(await clips.count(), 12);
    assert.equal(await clips.first().locator("time").getAttribute("datetime"), videos[0].created_at);
    assert.equal(await library.getByText("Kalimba", { exact: true }).count(), 0);

    const search = library.getByRole("searchbox");
    await search.fill("Kalimba");
    await search.press("Enter");
    await library.getByText("Showing 12 matching performances").waitFor();
    assert.match(await clips.first().innerText(), /Evening study 13/);
    await library.getByRole("button", { name: "Load more" }).click();
    await library.getByText("Couldn't load more performances.").waitFor();
    assert.equal(await clips.count(), 12);
    await library.getByRole("button", { name: "Try again" }).press("Enter");
    await library.getByText("Showing 15 matching performances").waitFor();
    await library.getByRole("link", { name: /^Evening study 25/ }).and(page.locator(":focus")).waitFor();
    assert.equal(await clips.count(), 15);
    assert.equal(await clips.last().getByRole("link").getAttribute("href"), clipPath(videos.at(-1).id));
    assert.equal(await library.getByRole("button", { name: "Load more" }).count(), 0);
    const searchRequests = requests.filter((request) => request.query === "kalimba");
    assert.ok(searchRequests.some((request) => !request.cursor));
    assert.deepEqual(searchRequests.flatMap((request) => request.cursor ?? []), [videos[23].id, videos[23].id]);
    assert.ok(requests.every((request) => request.handle === "eq.loopmaker"));

    await search.fill("1");
    await search.press("Enter");
    await library.getByRole("alert").waitFor();
    assert.equal(await library.getByRole("alert").innerText(), "Enter at least two characters to search.");
    await search.fill("nothing here");
    await search.press("Enter");
    await library.getByText(/No performances match/).waitFor();
    assert.equal(await clips.count(), 0);
    await library.getByRole("button", { name: "Clear search" }).click();
    await library.getByText("Showing 12 performances").waitFor();
    assert.equal(await search.inputValue(), "");
    assert.equal(await search.evaluate((input) => input === document.activeElement), true);
  });
});

test("creator and clip sharing stay usable on mobile and when browser capabilities are restricted", async () => {
  await withPage({ viewport: { width: 375, height: 760 }, isMobile: true }, async (page) => {
    let libraryUnavailable = true;
    await mockFeed(page, { libraryUnavailable: () => libraryUnavailable });
    await page.addInitScript(() => {
      window.shareCalls = [];
      window.clipboardCalls = [];
      window.shareBehavior = "reject";
      Object.defineProperty(navigator, "share", { value: async (data) => {
        window.shareCalls.push(data);
        if (window.shareBehavior === "cancel") throw new DOMException("Canceled", "AbortError");
        if (window.shareBehavior === "reject") throw new Error("Share unavailable");
      } });
      Object.defineProperty(navigator, "clipboard", { value: { writeText: async (url) => {
        if (window.rejectClipboard) throw new Error("Clipboard unavailable");
        window.clipboardCalls.push(url);
      } } });
    });
    await page.goto(`${profileURL}?u=LOOPMAKER&from=feed#old`);
    await page.getByText("Couldn't load performances.", { exact: true }).waitFor();
    await page.getByRole("heading", { name: "Loop Maker" }).waitFor();
    const shareProfile = page.getByRole("button", { name: "Share profile" });
    await shareProfile.click();
    await page.getByText("Profile link copied.").waitFor();
    const canonicalProfile = `${profileURL}?u=loopmaker`;
    assert.deepEqual(await page.evaluate(() => window.clipboardCalls), [canonicalProfile]);
    assert.deepEqual(await page.evaluate(() => window.shareCalls), [{ title: "Loop Maker", url: canonicalProfile }]);

    libraryUnavailable = false;
    await page.getByRole("button", { name: "Try again" }).click();
    await page.getByText("Showing 12 performances").waitFor();
    const clip = page.getByRole("listitem").first();
    const clipURL = new URL(clipPath(videos[0].id), baseURL).href;
    const shareClip = clip.getByRole("button", { name: "Share Evening study 1", exact: true });
    await page.evaluate(() => { window.shareBehavior = "accept"; });
    await shareClip.click();
    assert.deepEqual(await page.evaluate(() => window.shareCalls.at(-1)), { title: "Evening study 1", url: clipURL });
    assert.deepEqual(await page.evaluate(() => window.clipboardCalls), [canonicalProfile]);
    await page.evaluate(() => { window.shareBehavior = "cancel"; });
    await shareClip.click();
    assert.equal(await clip.getByRole("textbox").count(), 0);
    assert.deepEqual(await page.evaluate(() => window.clipboardCalls), [canonicalProfile]);
    await page.evaluate(() => {
      window.shareBehavior = "reject";
      window.rejectClipboard = true;
    });
    await shareClip.click();
    await clip.getByText("Copy the link below to share.").waitFor();
    const manualLink = clip.getByRole("textbox", { name: "Link to Evening study 1" });
    assert.equal(await manualLink.inputValue(), clipURL);
    await manualLink.focus();
    assert.equal(await manualLink.evaluate((input) => input.selectionEnd - input.selectionStart), clipURL.length);
    assert.ok(await page.locator("main").evaluate((main) => main.scrollWidth <= main.clientWidth));
  });
});

test("an empty creator is distinct from an unavailable profile", async () => {
  await withPage({}, async (page) => {
    const requests = await mockFeed(page);
    await page.goto(`${profileURL}?u=empty_artist`);
    await page.getByRole("heading", { name: "@empty_artist" }).waitFor();
    await page.getByText("This creator hasn't posted any public performances yet.").waitFor();
    await page.goto(`${profileURL}?u=missing_artist`);
    await page.getByRole("heading", { name: "Creator unavailable" }).waitFor();
    assert.deepEqual([...new Set(requests.map((request) => request.handle))], ["eq.empty_artist"]);
  });
});
