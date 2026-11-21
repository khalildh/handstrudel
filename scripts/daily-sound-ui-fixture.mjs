// Loopback Supabase stand-in for the daily sound UI test and screenshots.
//
//   PORT=54383 node scripts/daily-sound-ui-fixture.mjs
//   HANDSTRUDEL_DAILY_FIXTURE_URL=http://127.0.0.1:54383 (passed to the UI test runner as TEST_RUNNER_…)
//
// Signed out, `daily_sound_today` has no streak. After the email-code sign-in (any code)
// it returns a 7-day streak with a used freeze and a lent hand theme.
// FIXTURE_THUMBNAIL=/path/to.jpg serves that image for every take thumbnail.
import { createServer } from "node:http";
import { readFileSync } from "node:fs";

const viewer = "20000000-0000-0000-0000-0000000000d1";
const thumbnail = process.env.FIXTURE_THUMBNAIL ? readFileSync(process.env.FIXTURE_THUMBNAIL) : null;
const now = new Date();
const startOfDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
const day = (offset) => new Date(startOfDay.getTime() + offset * 86_400_000);
const isoDay = (date) => date.toISOString().slice(0, 10);
const setup = {
  version: 1, instrument: "grand_piano", waveform: "sine", key: "Eb", scale: "Major", progression: "pop",
  mode: "scalechordmelody", bpm: 92, useSoundFont: true, autoStrum: false, padVolume: 0.3, gridOctave: 3, gridRange: 2,
};
const clip = (index, username, caption, likes) => ({
  id: `31000000-0000-0000-0000-00000000000${index}`,
  user_id: `21000000-0000-0000-0000-00000000000${index}`,
  username, display_name: null, caption, instrument: "Grand Piano", like_count: likes, view_count: 10 * likes,
  video_key: `fixture/take-${index}.mp4`, thumb_key: `fixture/take-${index}.jpg`,
  created_at: new Date(startOfDay.getTime() + index * 3_600_000).toISOString(),
  sound_setup: setup, comments_enabled: true, backing_enabled: index === 1,
});
const featured = clip(1, "loopmaker", "Night drive in E flat", 42);
const takes = [clip(2, "cara", "First try", 9), clip(3, "dan_plays", "Slower", 4), clip(4, "eve", "", 1)];
const signedIn = new Set();

function payload(authorized) {
  return {
    day: isoDay(day(0)), starts_at: day(0).toISOString(), ends_at: day(1).toISOString(), server_now: now.toISOString(),
    sound: { setup, title: "Night Drive", note: "Keep the left hand on the root and let the chords ring.", source: "scheduled", video: featured },
    take_count: takes.length, takes,
    streak: authorized ? {
      current: 7, best: 12, posted_today: false, alive: true, freeze_covering: [], freeze_available: false,
      freeze_used_on: isoDay(day(-2)), ends_at: day(1).toISOString(), badges: [3, 7], next_milestone: 30,
      theme_grant: { theme_id: "purple_gold", expires_at: day(6).toISOString() },
    } : null,
  };
}

createServer((request, response) => {
  const url = new URL(request.url, "http://localhost");
  const token = (request.headers.authorization ?? "").replace(/^Bearer /, "");
  const send = (value, status = 200) => response.writeHead(status, { "Content-Type": "application/json" }).end(JSON.stringify(value));
  request.resume();
  switch (url.pathname) {
    case "/rest/v1/rpc/daily_sound_today":
      return send(payload(signedIn.has(token)));
    case "/rest/v1/rpc/daily_streak_profile":
      return send({ current: 7, best: 12, badges: [3, 7] });
    case "/auth/v1/otp":
      return send({});
    case "/auth/v1/logout":
      signedIn.delete(token);
      return response.writeHead(204).end();
    case "/auth/v1/verify":
      signedIn.add("daily-fixture-token");
      return send({
        access_token: "daily-fixture-token", token_type: "bearer", expires_in: 3600,
        expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: "daily-fixture-refresh",
        user: { id: viewer, aud: "authenticated", app_metadata: {}, user_metadata: {}, created_at: now.toISOString(), updated_at: now.toISOString() },
      });
    case "/rest/v1/profiles":
      return send({ id: viewer, username: "streaker", display_name: "Daily Player", avatar_key: null, accepted_terms_at: now.toISOString() });
  }
  if (/^\/fixture\/take-\d\.jpg$/.test(url.pathname) && thumbnail) {
    return response.writeHead(200, { "Content-Type": "image/jpeg", "Content-Length": thumbnail.length }).end(thumbnail);
  }
  if (url.pathname.startsWith("/rest/v1/rpc/")) return send(null);
  if (url.pathname.startsWith("/rest/v1/")) return send([]);
  return send({ message: "Not in the daily sound fixture" }, 404);
}).listen(Number(process.env.PORT ?? 54383), "127.0.0.1", function () {
  console.log(`Daily sound fixture ready at http://127.0.0.1:${this.address().port}`);
});
