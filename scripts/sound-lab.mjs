import { createServer } from "node:http";
import { pathToFileURL } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";

const service = "https://api.stability.ai/v2beta/audio";
const maxWAVBytes = 4_000_000;

export async function generateNote(prompt, key, { request = fetch, wait = sleep, signal = AbortSignal.timeout(85_000) } = {}) {
  if (typeof prompt !== "string" || !prompt.trim() || prompt.length > 400) throw new Error("Invalid sound prompt");
  const headers = { Authorization: `Bearer ${key}` };
  const body = new FormData();
  body.set("model", "stable-audio-3");
  body.set("duration", "2");
  body.set("output_format", "wav");
  body.set("prompt", `Single dry isolated pitched C4 note at 261.63 Hz, one attack. ${prompt.trim()}. No chord, rhythm, voice, melody, backing track, or pitch bend.`);
  const start = await request(`${service}/stable-audio/text-to-audio`, {
    method: "POST", headers: { ...headers, Accept: "application/json" }, body, signal, redirect: "error",
  });
  if (!start.ok) throw new Error(`Stability generation failed (HTTP ${start.status})`);
  const { id } = await start.json();
  if (typeof id !== "string" || !/^[a-f0-9]{64}$/.test(id)) throw new Error("Invalid generation ID");
  for (let i = 0; i < 25; i++) {
    const result = await request(`${service}/results/${id}`, {
      headers: { ...headers, Accept: "audio/*" }, signal, redirect: "error",
    });
    if (result.status === 202) {
      await result.body?.cancel();
      await wait(2500, undefined, { signal });
      continue;
    }
    if (!result.ok || !result.body) throw new Error(`Stability result failed (HTTP ${result.status})`);
    const blocks = [];
    let length = 0;
    for await (const block of result.body) {
      length += block.length;
      if (length > maxWAVBytes) throw new Error("Generated WAV is too large");
      blocks.push(block);
    }
    const wav = Buffer.concat(blocks, length);
    if (wav.toString("ascii", 0, 4) !== "RIFF" || wav.toString("ascii", 8, 12) !== "WAVE") {
      throw new Error("Provider did not return a WAV");
    }
    return wav;
  }
  throw new Error("Generation timed out");
}

function serve(key) {
  let active = false;
  createServer(async (req, res) => {
    const reply = (status, message) => res.writeHead(status, { "Content-Type": "text/plain" }).end(message);
    if (req.method !== "POST" || req.url !== "/generate" || req.headers["content-type"] !== "application/json" ||
        req.headers.host !== "127.0.0.1:54339" || req.headers.origin) {
      return reply(404, "Not found");
    }
    if (active) return reply(429, "Generation already running");
    active = true;
    const cancelled = new AbortController();
    res.on("close", () => cancelled.abort());
    try {
      let payload = "";
      req.setEncoding("utf8");
      for await (const chunk of req) {
        payload += chunk;
        if (payload.length > 4096) return reply(413, "Prompt too large");
      }
      let prompt;
      try { ({ prompt } = JSON.parse(payload)); }
      catch { return reply(400, "Invalid prompt"); }
      if (typeof prompt !== "string" || !prompt.trim() || prompt.length > 400) return reply(400, "Invalid prompt");
      const wav = await generateNote(prompt, key, { signal: AbortSignal.any([AbortSignal.timeout(85_000), cancelled.signal]) });
      res.writeHead(200, { "Content-Type": "audio/wav", "Content-Length": wav.length, "Cache-Control": "no-store" }).end(wav);
    } catch (error) {
      if (!cancelled.signal.aborted) reply(502, error.message);
    } finally {
      active = false;
    }
  }).listen(54339, "127.0.0.1", () => console.log("Sound Lab listening on 127.0.0.1:54339 (one paid generation per request)"));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const key = process.env.STABILITY_API_KEY;
  if (!key) {
    console.error("Set STABILITY_API_KEY in the bridge process, not in the iOS app.");
    process.exitCode = 1;
  } else serve(key);
}
