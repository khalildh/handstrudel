import assert from "node:assert/strict";
import { screenUpload, shouldHold } from "./sightengine.ts";

const frame = (sexual_activity: number, sexual_display: number) => ({ nudity: { sexual_activity, sexual_display } });
const video = (...frames: unknown[]) => ({ status: "success", data: { frames } });

Deno.test("checks every sampled frame and holds explicit content at the cutoff", () => {
  assert.equal(shouldHold(video(frame(0.01, 0.01), frame(0.3, 0.5)), "video"), true);
  assert.equal(shouldHold(video(frame(0.8, 1)), "video"), true);
  assert.equal(shouldHold(video(frame(0.04, 0.08), frame(0.2, 0.49)), "video"), false);
});

Deno.test("screens thumbnails independently without treating ordinary suggestiveness as explicit", () => {
  assert.equal(shouldHold({ status: "success", ...frame(0, 0.68) }, "image"), true);
  assert.equal(shouldHold({ status: "success", nudity: { ...frame(0, 0).nudity, suggestive: 0.99 } }, "image"), false);
});

Deno.test("scanner failures and incomplete scores cannot turn into approval", () => {
  for (const invalid of [null, { ...video(frame(0, 0)), status: "failure" }, video(), video(frame(0, 0), {}), video(frame(NaN, 1))]) {
    assert.throws(() => shouldHold(invalid, "video"));
  }
  assert.throws(() => shouldHold({ status: "success", nudity: { sexual_activity: 0 } }, "image"));
});

Deno.test("both clip and thumbnail must clear; an upstream failure rejects the upload", async () => {
  const clip = new ArrayBuffer(3);
  const thumbnail = new ArrayBuffer(2);
  const requests: [ArrayBuffer, string][] = [];
  assert.equal(await screenUpload(clip, thumbnail, async (bytes, kind) => {
    requests.push([bytes, kind]);
    return kind === "image";
  }), "held");
  assert.deepEqual(requests, [[clip, "video"], [thumbnail, "image"]]);
  assert.equal(await screenUpload(clip, thumbnail, async () => false), "clear");
  await assert.rejects(screenUpload(clip, thumbnail, async (_, kind) => {
    if (kind === "video") throw new Error("Screening video HTTP 503 (unknown_error:0)");
    return false;
  }), /HTTP 503/);
});
