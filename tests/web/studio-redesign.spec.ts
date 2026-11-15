import { expect, test } from "@playwright/test";

for (const viewport of [{ width: 1280, height: 900 }, { width: 320, height: 640 }, { width: 667, height: 375 }]) {
  test(`studio setup stays reachable at ${viewport.width} x ${viewport.height}`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await page.goto("/play");
    await expect(page.getByRole("heading", { name: "Make music in the air." })).toBeVisible();
    await expect(page.getByText("Camera stays off until you start.", { exact: false })).toBeVisible();
    await expect(page.getByRole("link", { name: "Watch performances" })).toHaveAttribute("href", "/watch");
    await expect(page.getByRole("combobox", { name: "Instrument" })).toBeVisible();
    const start = page.getByRole("button", { name: "Start camera" });
    await start.scrollIntoViewIfNeeded();
    await expect(start).toBeInViewport();
    expect(await page.locator("#start").evaluate(el => el.scrollWidth <= el.clientWidth)).toBe(true);

    const mappings = page.getByText("Customize gesture mapping");
    await expect(page.getByRole("combobox", { name: "left hand Y pos sound" })).toBeHidden();
    await mappings.press("Enter");
    await expect(page.getByRole("combobox", { name: "left hand Y pos sound" })).toBeVisible();
    const advanced = page.getByRole("button", { name: "Advanced" });
    await advanced.press("Enter");
    await expect(advanced).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByRole("combobox", { name: "right hand pinch visual" })).toBeVisible();
    expect(await page.locator("#start").evaluate(el => el.scrollWidth <= el.clientWidth)).toBe(true);
  });
}

test("retry after denied permission enters the studio without leftover setup or visual canvases", async ({ page }) => {
  await page.route("https://unpkg.com/hydra-synth", (route) => route.fulfill({
    contentType: "application/javascript",
    body: "window.Hydra = class { synth = { hush() {} }; };",
  }));
  await page.route("https://cdn.jsdelivr.net/npm/@mediapipe/**", (route) => route.fulfill({
    headers: { "access-control-allow-origin": "*" },
    contentType: "application/javascript",
    body: route.request().url().includes("camera_utils")
      ? "window.Camera = class { async start() { await navigator.mediaDevices.getUserMedia({ video: true }); } stop() {} };"
      : "window.Hands = class { setOptions() {} onResults() {} };",
  }));
  await page.addInitScript(() => {
    Reflect.set(window, "studioCameraCount", 0);
    Object.defineProperty(navigator.mediaDevices, "getUserMedia", {
      value: async () => {
        const count = Number(Reflect.get(window, "studioCameraCount")) + 1;
        Reflect.set(window, "studioCameraCount", count);
        if (count === 1) throw new DOMException("Blocked for this test", "NotAllowedError");
        return new MediaStream();
      },
    });
  });

  await page.goto("/play");
  const start = page.getByRole("button", { name: "Start camera" });
  await expect(start).toBeVisible();
  expect(await page.evaluate(() => Reflect.get(window, "studioCameraCount"))).toBe(0);
  await start.press("Enter");
  await expect(page.getByRole("alert").filter({ hasText: "Camera access was blocked" })).toBeVisible();
  await expect(page.locator("#hydra-canvas")).toHaveCount(0);

  await start.press("Enter");
  await expect(page.getByText("Camera live")).toBeVisible();
  expect(await page.evaluate(() => Reflect.get(window, "studioCameraCount"))).toBe(2);
  await expect(page.getByRole("heading", { name: "Make music in the air." })).toHaveCount(0);
  await expect(page.locator("#cam-area #hydra-canvas")).toHaveCount(1);
  await expect(page.getByRole("button", { name: "REC" })).toBeVisible();
});
