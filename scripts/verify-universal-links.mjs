// macOS, Node 20+: node scripts/verify-universal-links.mjs [--live]
// The Swift parser is covered by SocialTests.testUniversalPerformanceLinksOnlyOpenCanonicalVideoURLs.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
assert(args.length === 0 || (args.length === 1 && args[0] === "--live"),
  "Usage: node scripts/verify-universal-links.mjs [--live]");

const watch = new URL("https://handstrudel.com/watch?v=52000000-0000-0000-0000-000000000001");
const associationPath = "/.well-known/apple-app-site-association";
const appID = "TVAG3T3Y65.com.handstrudel.app";
const ios = "ios/HandStrudel";
const fromRoot = (path) => new URL(`../${path}`, import.meta.url);
const json = (path) => JSON.parse(readFileSync(fromRoot(path), "utf8"));
const plist = (path) => JSON.parse(execFileSync("plutil",
  ["-convert", "json", "-o", "-", fileURLToPath(fromRoot(path))], { encoding: "utf8" }));

const { objects } = plist(`${ios}/HandStrudel.xcodeproj/project.pbxproj`);
const app = Object.values(objects).find((object) =>
  object.isa === "PBXNativeTarget" && object.name === "HandStrudel" &&
  object.productType === "com.apple.product-type.application");
assert(app, "Missing the HandStrudel application target");
const release = objects[app.buildConfigurationList].buildConfigurations
  .map((key) => objects[key]).find((config) => config.name === "Release");
assert(release, "Missing the HandStrudel Release configuration");
const settings = release.buildSettings;
assert.equal(`${settings.DEVELOPMENT_TEAM}.${settings.PRODUCT_BUNDLE_IDENTIFIER}`, appID, "Release App ID");
const entitlements = plist(`${ios}/${settings.CODE_SIGN_ENTITLEMENTS}`);
assert(entitlements["com.apple.developer.associated-domains"]?.includes(`applinks:${watch.host}`),
  "The Release entitlement must claim the canonical host");
const info = plist(`${ios}/${settings.INFOPLIST_FILE}`);
assert.equal(info.CFBundleIdentifier, "$(PRODUCT_BUNDLE_IDENTIFIER)", "The app plist must use the Release bundle ID");
assert(info.CFBundleURLTypes?.some((type) => type.CFBundleURLSchemes?.includes("handstrudel")),
  "The optional Open in HandStrudel button requires the handstrudel URL scheme");

const aasa = json(`public${associationPath}`);
assert.deepEqual(aasa.applinks.details, [{
  appIDs: [appID],
  components: [watch.pathname, `${watch.pathname}/`].map((path) => ({ "/": path, "?": { v: "*" } })),
}], "AASA must claim only the two watch paths with a v query item for the release app");
const vercel = json("vercel.json");
assert.equal(vercel.cleanUrls, true, "The static watch page must be served without .html");
const associationHeaders = vercel.headers?.find(({ source }) => source === associationPath)?.headers;
assert(associationHeaders?.some(({ key, value }) => key.toLowerCase() === "content-type" && value === "application/json"),
  "The origin AASA must be served as application/json");
assert(existsSync(fromRoot("src/app/watch/page.tsx")), "Missing the browser fallback route");
console.log(`Repo: ${appID} claims applinks:${watch.host}; AASA, URL scheme and /watch fallback agree`);

async function get(url, mime) {
  const response = await fetch(url, { redirect: "manual", signal: AbortSignal.timeout(10_000) });
  assert.equal(response.status, 200, `${url}: expected a direct 200 (no redirect)`);
  const contentType = response.headers.get("content-type") ?? "";
  assert.equal(contentType.split(";")[0].trim().toLowerCase(), mime, `${url}: Content-Type`);
  console.log(`${url}: ${response.status} ${contentType}, no redirect`);
  return response;
}

if (args.includes("--live")) {
  const origin = new URL(associationPath, watch);
  const apple = new URL(`https://app-site-association.cdn-apple.com/a/v1/${watch.host}`);
  for (const url of [origin, apple]) {
    const response = await get(url, "application/json");
    assert.deepEqual(await response.json(), aasa, `${url}: deployed AASA differs from repo`);
  }
  // The synthetic UUID verifies the page is served, not that a real clip plays.
  const fallback = await get(watch, "text/html");
  assert.match(await fallback.text(), /<title>Watch performances\b/, "Expected the watch page, not a generic HTML response");
}
