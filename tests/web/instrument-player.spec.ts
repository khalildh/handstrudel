import { expect, test, type Page } from "@playwright/test";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

// Plays a shared post's instrument in the browser against a mocked feed. The
// page's Web Audio oscillators are recorded (frequency at start) so the test
// checks what Strudel's audio engine actually played, not just the UI.

// Opening the player compiles lazy chunks on the dev server the first time.
test.describe.configure({ timeout: 90_000 });

const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "apikey" };
const shots = join(process.cwd(), "test-results/instrument-player");
mkdirSync(shots, { recursive: true });

const id = "53000000-0000-0000-0000-000000000001";
const sawSetup = {
  version: 1, key: "C", scale: "Major", progression: "pop", mode: "scalechordmelody", bpm: 120,
  useSoundFont: false, waveform: "sawtooth", instrument: "grand_piano",
  autoStrum: false, padVolume: 0.3, gridOctave: 3, gridRange: 2,
};
// A post's own instrument: chords on the RIGHT, a smaller rest hole and a deeper rim.
const rightWheel = {
  format: "handstrudel.instrument", format_version: 1, id: "test.right-wheel", name: "Right Wheel",
  surface: { type: "split_wheel", radius: 0.95, rest_radius: 0.3, octave_band_radius: 0.75 },
  chords: { side: "right" },
  notes: { source: "scale_one_octave", octave_band: true, highlight_chord_tones: true },
  sound: { instrument: "ignored: instruments never choose a sound" },
};
const post = {
  id, caption: "Wheel jam", video_key: "clips/wheel.mp4", thumb_key: "", username: "wheelmaker",
  duration_s: 1, instrument: "Saw", created_at: "2026-01-01T00:00:00Z", sound_setup: sawSetup, has_instrument: true,
};

interface Played { kind: string; midi: number[]; notes: string[]; s: string }

async function mockPost(page: Page, video: Record<string, unknown> = post, spec: unknown = rightWheel) {
  const specRequests: string[] = [];
  // Registered first: Playwright tries the most recently added route first.
  await page.route("https://feed.handstrudel.test/rest/v1/**", (route) => route.fulfill({ headers: cors, json: [] }));
  await page.route("https://feed.handstrudel.test/rest/v1/feed_videos**", (route) => {
    if (route.request().method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
    return route.fulfill({ headers: cors, json: [video] });
  });
  await page.route("https://feed.handstrudel.test/rest/v1/videos?**", (route) => {
    if (route.request().method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
    specRequests.push(route.request().url());
    return route.fulfill({ headers: cors, json: [{ instrument_spec: spec }] });
  });
  await page.route("https://media.handstrudel.test/**", (route) =>
    route.fulfill({ path: join(process.cwd(), "tests/web/fixture.mp4"), contentType: "video/mp4" }));
  // No camera or CDN in CI: MediaPipe fails to load and the player falls back to pointer input.
  await page.route("https://cdn.jsdelivr.net/**", (route) => route.abort());
  await page.route("https://unpkg.com/**", (route) => route.abort());
  await page.addInitScript(() => {
    const w = window as unknown as { __played: unknown[]; __oscillators: { type: string; hz: number }[] };
    w.__played = [];
    w.__oscillators = [];
    window.addEventListener("handstrudel:wheel-play", (event) => w.__played.push((event as CustomEvent).detail));
    const start = AudioScheduledSourceNode.prototype.start;
    AudioScheduledSourceNode.prototype.start = function (this: AudioScheduledSourceNode, ...args: number[]) {
      if (this instanceof OscillatorNode) w.__oscillators.push({ type: this.type, hz: this.frequency.value });
      return start.apply(this, args as [number?]);
    };
  });
  return specRequests;
}

const played = (page: Page) => page.evaluate(() => (window as unknown as { __played: Played[] }).__played);
const oscillators = (page: Page) =>
  page.evaluate(() => (window as unknown as { __oscillators: { type: string; hz: number }[] }).__oscillators);
const hz = (midi: number) => Math.round(440 * 2 ** ((midi - 69) / 12) * 100) / 100;

async function tap(page: Page, testId: string) {
  const box = await page.getByTestId(testId).boundingBox();
  if (!box) throw new Error(`${testId} isn't on screen`);
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
}

async function openPlayer(page: Page, navigate = true) {
  if (navigate) await page.goto(`/watch?v=${id}`);
  await page.getByRole("button", { name: "Play this in your browser" }).click();
  const player = page.getByRole("region", { name: "Instrument player" });
  // The player is a lazily loaded chunk; the dev server may compile it on first use.
  await expect(player).toBeVisible({ timeout: 30_000 });
  await expect(page.getByTestId("wheel-chord-0-label")).toBeVisible();
  return player;
}

test("a visitor plays the post's own instrument with the post's sound", async ({ page }) => {
  const specRequests = await mockPost(page);
  await page.goto(`/watch?v=${id}`);
  await page.locator(".watch-caption").screenshot({ path: join(shots, "watch-play-button.png") });
  expect(specRequests).toHaveLength(0); // the file is read only when someone plays
  const player = await openPlayer(page, false);
  // (React's dev double-mount may abort and repeat the first request.)
  expect(specRequests.length).toBeGreaterThanOrEqual(1);
  for (const url of specRequests) expect(new URL(url).searchParams.get("select")).toBe("instrument_spec");
  await expect(player.getByRole("heading", { name: "Right Wheel" })).toBeVisible();
  await expect(page.getByTestId("player-sound")).toHaveText("Sawtooth · C Major · Pop · 120 BPM");
  await expect(player).toContainText("Instrument from @wheelmaker’s post");
  // Pop = I V vi IV, voiced as 7ths on a scale-note wheel.
  await expect(page.getByTestId("wheel-chord-0-label")).toHaveText("Cmaj⁷");
  await expect(page.getByTestId("wheel-chord-1-label")).toHaveText("Gmaj⁷");
  await expect(page.getByTestId("wheel-chord-2-label")).toHaveText("Amin⁷");
  await expect(page.getByTestId("wheel-chord-3-label")).toHaveText("Fmaj⁷");
  // The file puts chords on the right half: chord 0 sits right of center, notes left.
  const stage = (await page.locator(".wheel-stage").boundingBox())!;
  const chord = (await page.getByTestId("wheel-chord-0-label").boundingBox())!;
  const note = (await page.getByTestId("wheel-note-0-label").boundingBox())!;
  expect(chord.x).toBeGreaterThan(stage.x + stage.width / 2);
  expect(note.x).toBeLessThan(stage.x + stage.width / 2);
  await page.screenshot({ path: join(shots, "watch-player-desktop.png") });

  await tap(page, "wheel-chord-0-label");
  await expect.poll(() => played(page)).toEqual([
    expect.objectContaining({ kind: "chord", midi: [48, 52, 55, 59], notes: ["c3", "e3", "g3", "b3"], s: "sawtooth" }),
  ]);
  await expect(page.getByTestId("wheel-held-chord")).toHaveText("Cmaj⁷");
  await expect.poll(async () => (await oscillators(page)).map((o) => `${o.type} ${o.hz.toFixed(2)}`))
    .toEqual(expect.arrayContaining([48, 52, 55, 59].map((m) => `sawtooth ${hz(m).toFixed(2)}`)));

  // Reach into the rim: the upper half of the G wedge plays an octave up.
  await tap(page, "wheel-chord-1-up-label");
  await expect.poll(async () => (await played(page)).at(-1)).toEqual(
    expect.objectContaining({ kind: "chord", midi: [67, 71, 74, 77] }));
  // Holding G7 tints its tones (D, F, G, B) among the C major notes.
  for (const lane of [1, 3, 4, 6]) await expect(page.getByTestId(`wheel-note-${lane}`)).toHaveAttribute("data-chord-tone", "true");
  for (const lane of [0, 2, 5]) await expect(page.getByTestId(`wheel-note-${lane}`)).not.toHaveAttribute("data-chord-tone");

  await tap(page, "wheel-note-4-label");
  await tap(page, "wheel-note-0-down-label");
  await expect.poll(async () => (await played(page)).slice(-2)).toEqual([
    expect.objectContaining({ kind: "note", midi: [67], notes: ["g4"] }),
    expect.objectContaining({ kind: "note", midi: [48], notes: ["c3"] }),
  ]);
  await expect.poll(async () => (await oscillators(page)).some((o) => o.hz.toFixed(2) === hz(48).toFixed(2))).toBe(true);

  // Dragging across zones strikes each new zone once, like a finger on iOS.
  const before = (await played(page)).length;
  const from = (await page.getByTestId("wheel-chord-2-label").boundingBox())!;
  const to = (await page.getByTestId("wheel-chord-3-label").boundingBox())!;
  await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
  await page.mouse.down();
  await page.mouse.move(from.x + from.width / 2 + 1, from.y + from.height / 2 + 1);
  await page.mouse.move(to.x + to.width / 2, to.y + to.height / 2, { steps: 6 });
  await page.mouse.up();
  await expect.poll(async () => (await played(page)).slice(before).map((p) => p.midi)).toEqual([
    [57, 60, 64, 67], // Am7
    [53, 57, 60, 64], // Fmaj7
  ]);
  await page.screenshot({ path: join(shots, "watch-player-playing.png") });

  // The page never navigated, so the universal link and the app buttons are untouched.
  expect(new URL(page.url()).pathname + new URL(page.url()).search).toBe(`/watch?v=${id}`);
  await page.getByRole("button", { name: "Close" }).first().click();
  await expect(player).toBeHidden();
  // (Shown only on touch devices, so check it by selector.)
  await expect(page.locator("a.watch-open-ios")).toHaveAttribute("href", `handstrudel://watch/${id}`);
  await expect(page.getByRole("link", { name: "Play this sound in the app" })).toHaveAttribute("href", `handstrudel://sound/${id}`);
});

test("after about 20 seconds of play a soft card offers the app", async ({ page }) => {
  await page.clock.install();
  await mockPost(page);
  await openPlayer(page);
  await tap(page, "wheel-chord-0-label");
  await expect.poll(async () => (await played(page)).length).toBe(1);
  await page.clock.fastForward(15_000);
  await expect(page.getByRole("dialog", { name: "Get the app" })).toHaveCount(0);
  await page.clock.fastForward(6_000);
  const card = page.getByRole("dialog", { name: "Get the app" });
  await expect(card).toBeVisible();
  await expect(card.getByRole("link", { name: "Record and post this in the app" }))
    .toHaveAttribute("href", "https://apps.apple.com/app/apple-store/id6764415289?pt=127873492&ct=website&mt=8");
  await page.screenshot({ path: join(shots, "watch-player-app-card.png") });
  await card.getByRole("button", { name: "Keep playing" }).click();
  await expect(card).toBeHidden();
  await tap(page, "wheel-chord-1-label");
  await expect.poll(async () => (await played(page)).length).toBe(2);
});

test("stopping after playing shows the card; posts without a file use the built-in wheel", async ({ page }) => {
  const split = { ...post, has_instrument: false, sound_setup: { ...sawSetup, mode: "splitchordmelody", key: "A", scale: "Minor",
    progression: "custom", customDegrees: [0, 5, 2, 6], useSoundFont: true, instrument: "nylon_guitar" } };
  const specRequests = await mockPost(page, split);
  const player = await openPlayer(page);
  expect(specRequests).toHaveLength(0);
  await expect(player.getByRole("heading", { name: "Split Wheel" })).toBeVisible();
  await expect(page.getByTestId("player-sound")).toHaveText("Nylon Guitar · A Minor · Custom · 120 BPM");
  // Split wheel: triads, chord tones over three octaves (9 lanes), no note rim.
  await expect(page.getByTestId("wheel-chord-0-label")).toHaveText("Amin");
  await expect(page.locator("[data-testid^='wheel-note-'][data-testid$='-label']")).toHaveCount(9);
  await expect(page.getByTestId("wheel-note-0-up")).toHaveCount(0);
  await tap(page, "wheel-chord-1-label"); // F major (degree 5 of A minor)
  await expect.poll(async () => (await played(page)).at(-1)).toEqual(
    expect.objectContaining({ kind: "chord", midi: [65, 69, 72], s: "gm_acoustic_guitar_nylon" }));
  await expect(page.getByTestId("wheel-note-0-label")).toHaveText("F");
  await tap(page, "wheel-note-8-label"); // top lane: the chord's fifth, two octaves up
  await expect.poll(async () => (await played(page)).at(-1)).toEqual(expect.objectContaining({ kind: "note", midi: [96] }));
  await page.getByRole("button", { name: "Stop" }).click();
  await expect(page.getByRole("dialog", { name: "Get the app" })).toBeVisible();
});

test("a post's file from a newer format falls back to the built-in wheel", async ({ page }) => {
  await mockPost(page, post, { ...rightWheel, format_version: 2 });
  const player = await openPlayer(page);
  await expect(player.getByRole("heading", { name: "Scale Wheel" })).toBeVisible();
  await expect(player).toContainText("isn’t playable on the web yet");
});

test("/play?v= opens the Web Studio with the post's instrument and sound", async ({ page }) => {
  await mockPost(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`/play?v=${id}`);
  const player = page.getByRole("region", { name: "Instrument player" });
  await expect(player.getByRole("heading", { name: "Right Wheel" })).toBeVisible();
  await expect(page.getByTestId("player-sound")).toHaveText("Sawtooth · C Major · Pop · 120 BPM");
  await page.getByRole("button", { name: "Start playing" }).click();
  // No camera here: the player says so and keeps pointer input.
  await expect(page.getByText("The camera didn’t start")).toBeVisible();
  await tap(page, "wheel-note-6-label");
  await expect.poll(async () => (await played(page)).at(-1)).toEqual(expect.objectContaining({ kind: "note", midi: [71] }));
  await page.screenshot({ path: join(shots, "play-post-mobile.png") });
  await expect(page.getByRole("link", { name: "Watch @wheelmaker’s performance" })).toHaveAttribute("href", `/watch?v=${id}`);
});
