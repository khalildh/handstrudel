import { expect, test } from "@playwright/test";
import { appStoreUrl, homepageAppStoreUrl } from "../../src/lib/app-store";

const campaign = "https://apps.apple.com/app/apple-store/id6764415289?pt=127873492&ct=website&mt=8";
const endpoint = "https://feed.handstrudel.test/rest/v1/rpc/record_homepage_download_click";

test("only valid Apple campaigns for HandStrudel can replace the download URL", () => {
  expect(homepageAppStoreUrl(campaign)).toBe(campaign);
  expect(homepageAppStoreUrl("https://example.com/app/id6764415289?pt=1&ct=website&mt=8")).toBe(appStoreUrl);
  expect(homepageAppStoreUrl(campaign.replace("6764415289", "123456789"))).toBe(appStoreUrl);
  expect(homepageAppStoreUrl(campaign.replace("&mt=8", ""))).toBe(appStoreUrl);
  expect(homepageAppStoreUrl("not a URL")).toBe(appStoreUrl);
});

for (const [placement, section] of [["header", ".home-header"], ["hero", ".home-hero"], ["footer", ".home-get"]]) {
  test(`the ${placement} records one click and reaches the campaign even when tracking fails`, async ({ page }) => {
    const writes: unknown[] = [];
    await page.route(endpoint, async (route) => {
      const request = route.request();
      if (request.method() === "POST") writes.push(request.postDataJSON());
      await route.fulfill({
        status: 503,
        headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" },
      });
    });
    await page.route(campaign, (route) => route.fulfill({ body: "App Store destination" }));
    await page.goto("/");
    const button = page.locator(section).getByRole("link", { name: /Get the app|Download for iPhone/ });
    await expect(button).toHaveAttribute("href", campaign);
    expect(writes).toEqual([]);
    await button.press("Enter");
    await page.waitForURL(campaign);
    await expect.poll(() => writes).toEqual([{ p_placement: placement }]);
  });
}

test("the campaign link still works without JavaScript", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ baseURL, javaScriptEnabled: false });
  try {
    const page = await context.newPage();
    await page.route(campaign, (route) => route.fulfill({ body: "App Store destination" }));
    await page.goto("/");
    await page.locator(".home-hero").getByRole("link", { name: "Download for iPhone" }).press("Enter");
    await page.waitForURL(campaign);
  } finally {
    await context.close();
  }
});

test("footer links are separated and open scrollable pages on narrow phones", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await page.goto("/");
  const links = page.getByRole("navigation", { name: "Site information" });
  await expect(links.getByRole("link")).toHaveText(["Support", "Privacy", "Terms"]);
  await expect(links.locator("ul")).toHaveText("Support / Privacy / Terms");
  for (const [label, heading, path] of [
    ["Support", "Support", "/support"],
    ["Privacy", "Privacy Policy", "/privacy"],
    ["Terms", "Terms of Use", "/terms"],
  ]) {
    await links.getByRole("link", { name: label, exact: true }).press("Enter");
    await expect(page).toHaveURL(new RegExp(`${path}/?$`));
    await expect(page.getByRole("heading", { name: heading, level: 1 })).toBeVisible();
    const footer = page.getByRole("link", { name: "Back to home" });
    await footer.scrollIntoViewIfNeeded();
    await expect(footer).toBeInViewport();
    await expect(links.getByRole("link", { name: label, exact: true })).toHaveAttribute("aria-current", "page");
    expect(await page.locator(".info-page").evaluate((element) => element.scrollWidth <= element.clientWidth)).toBe(true);
    await footer.press("Enter");
    await expect(page).toHaveURL(/\/$/);
  }
});
