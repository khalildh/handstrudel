import { expect, test, type Page } from "@playwright/test";
import { join } from "node:path";

const clips = ["Glass kalimba", "Late night strings", "Pocket piano"].map((caption, index) => ({
  id: `52000000-0000-0000-0000-00000000000${index + 1}`,
  caption, video_key: `clips/${index}.mp4`, thumb_key: "", username: "loopmaker",
  duration_s: 1, instrument: "Keys", created_at: "2026-01-01T00:00:00Z",
}));
const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "apikey" };

async function mockClips(page: Page, isBroken = () => false, videos = clips) {
  await page.route("https://feed.handstrudel.test/rest/v1/feed_videos**", (route) => {
    if (route.request().method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
    const id = new URL(route.request().url()).searchParams.get("id")?.slice(3);
    return route.fulfill({ headers: cors, json: id ? videos.filter((clip) => clip.id === id) : videos });
  });
  await page.route("https://media.handstrudel.test/clips/**", (route) => {
    if (isBroken()) return route.fulfill({ status: 503 });
    return route.fulfill({ path: join(process.cwd(), "tests/web/fixture.mp4"), contentType: "video/mp4" });
  });
}

test("shared custom scales and legacy pentatonic IDs have readable names", async ({ page }) => {
  const custom = { id: "51000000-0000-0000-0000-000000000001", name: "Soft Glow", intervals: [0, 4, 7] };
  const videos = clips.map((clip, index) => ({
    ...clip,
    sound_setup: { version: 1, key: "C", scale: index === 0 ? custom : "Pentatonic", bpm: 110 },
  }));
  await mockClips(page, () => false, videos);
  await page.goto(`/watch?v=${clips[0].id}`);
  await expect(page.locator(".watch-preset")).toContainText("C Soft Glow · 110 BPM");
  await page.getByRole("button", { name: "Next performance" }).click();
  await expect(page.locator(".watch-preset")).toContainText("C Major Pentatonic · 110 BPM");
});

test("previous and next work from the player on mobile without replacing the video element", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await mockClips(page);
  await page.goto(`/watch?v=${clips[0].id}`);
  const previous = page.getByRole("button", { name: "Previous performance" });
  const next = page.getByRole("button", { name: "Next performance" });
  await expect(previous).toBeDisabled();
  await expect(page.getByRole("region", { name: "Playback queue" })).toContainText("Late night strings");
  await page.locator("video").evaluate((element) => { element.dataset.kept = "yes"; });
  await next.click();
  await expect(page.getByRole("heading", { name: "Late night strings", exact: true })).toBeVisible();
  await expect(page.locator("video")).toHaveAttribute("data-kept", "yes");
  await previous.click();
  await expect(page).toHaveURL(new RegExp(`${clips[0].id}$`));
  await expect(page.getByRole("heading", { name: "Glass kalimba", exact: true })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(390);
});

test("autoplay is off by default, then advances on the real ended event when enabled", async ({ page }) => {
  await mockClips(page);
  await page.goto(`/watch?v=${clips[0].id}`);
  const autoplay = page.getByRole("checkbox", { name: "Autoplay next" });
  const video = page.locator("video");
  await expect(autoplay).not.toBeChecked();
  await video.evaluate(async (node) => {
    const element = node as HTMLVideoElement;
    element.muted = true;
    await element.play();
    if (!element.ended) await new Promise((resolve) => element.addEventListener("ended", resolve, { once: true }));
  });
  await expect(page).toHaveURL(new RegExp(`${clips[0].id}$`));
  await autoplay.check();
  await video.evaluate((node) => {
    const element = node as HTMLVideoElement;
    element.currentTime = 0;
    return element.play();
  });
  await expect(page).toHaveURL(new RegExp(`${clips[2].id}$`));
  await expect(page.getByRole("button", { name: "Next performance" })).toBeDisabled();
  await expect(page.getByText("End of queue")).toBeVisible();
});

test("a failed media request shows Retry and recovers without losing the selected clip", async ({ page }) => {
  let broken = true;
  await mockClips(page, () => broken);
  await page.goto(`/watch?v=${clips[0].id}`);
  const retry = page.getByRole("button", { name: "Retry video" });
  await expect(retry).toBeVisible();
  await expect(page.getByText("This video couldn't play.")).toBeVisible();
  broken = false;
  await retry.click();
  await expect(retry).toHaveCount(0);
  await expect.poll(() => page.locator("video").evaluate((element) => (element as HTMLVideoElement).readyState)).toBeGreaterThan(0);
  await expect(page).toHaveURL(new RegExp(`${clips[0].id}$`));
});
