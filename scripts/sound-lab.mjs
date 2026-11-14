import { createServer } from "node:http";
import { execFile } from "node:child_process";
import { access, mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { isAbsolute, join } from "node:path";
import { pathToFileURL } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";
import { promisify } from "node:util";

const service = "https://api.stability.ai/v2beta/audio";
const maxWAVBytes = 4_000_000;
const modelPrompt = (text) => `Isolated musical instrument sample: ${text.trim()}. One sustained middle C (C4, 261.63 Hz), exactly one strike with a clean decay. Dry close-miked studio recording of the solo instrument. No other notes, no backing music.`;

function validateWAV(wav) {
  if (wav.toString("ascii", 0, 4) !== "RIFF" || wav.toString("ascii", 8, 12) !== "WAVE") {
    throw new Error("Provider did not return a WAV");
  }
  return wav;
}

export async function generateLocalNote(prompt, directory, { run = promisify(execFile), signal = AbortSignal.timeout(45_000) } = {}) {
  const scratch = await mkdtemp(join(tmpdir(), "handstrudel-note-"));
  try {
    const output = join(scratch, "note.wav");
    // Never interpolate user input into a shell command.
    await run(join(directory, ".venv/bin/python"), [
      "scripts/sa3_mlx.py", "--prompt", modelPrompt(prompt),
      "--negative-prompt", "chords, multiple notes, arpeggio, melody, vocals, percussion, reverb",
      "--dit", "sm-music", "--decoder", "same-s", "--seconds", "2", "--cfg", "2.5", "--out", output,
    ], {
      cwd: directory, signal, maxBuffer: 256_000,
      env: { ...process.env, HF_HUB_OFFLINE: "1", HF_HUB_DISABLE_TELEMETRY: "1", HF_HUB_DISABLE_IMPLICIT_TOKEN: "1" },
    });
    if ((await stat(output)).size > maxWAVBytes) throw new Error("Generated WAV is too large");
    return validateWAV(await readFile(output));
  } finally {
    await rm(scratch, { recursive: true, force: true });
  }
}

export async function generateNote(prompt, key, { request = fetch, wait = sleep, signal = AbortSignal.timeout(85_000) } = {}) {
  if (typeof prompt !== "string" || !prompt.trim() || prompt.length > 400) throw new Error("Invalid sound prompt");
  const headers = { Authorization: `Bearer ${key}` };
  const body = new FormData();
  body.set("model", "stable-audio-3");
  body.set("duration", "2");
  body.set("output_format", "wav");
  body.set("prompt", modelPrompt(prompt));
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
    return validateWAV(Buffer.concat(blocks, length));
  }
  throw new Error("Generation timed out");
}

export function soundLabServer(provider, generate, deadlineMs) {
  let active = false;
  return createServer({ requestTimeout: 10_000, headersTimeout: 5_000 }, async (req, res) => {
    const reply = (status, message) => res.writeHead(status, { "Content-Type": "text/plain", "Cache-Control": "no-store" }).end(message);
    if (req.headers.host !== `127.0.0.1:${req.socket.localPort}` || req.headers.origin) {
      return reply(404, "Not found");
    }
    if (req.method === "GET" && req.url === "/status") {
      return res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" }).end(JSON.stringify({ provider }));
    }
    if (req.method !== "POST" || req.url !== "/generate" || req.headers["content-type"] !== "application/json") {
      return reply(404, "Not found");
    }
    if (req.headers["x-handstrudel-audio-provider"] !== provider) return reply(409, "The bridge changed. Check its status and try again.");
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
      const signal = AbortSignal.any([AbortSignal.timeout(deadlineMs), cancelled.signal]);
      const wav = await generate(prompt, signal);
      res.writeHead(200, { "Content-Type": "audio/wav", "Content-Length": wav.length, "Cache-Control": "no-store" }).end(wav);
    } catch {
      if (!cancelled.signal.aborted) reply(502, "The audio model failed to generate a WAV. Check the bridge terminal.");
    } finally {
      active = false;
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const directory = process.env.HANDSTRUDEL_AUDIO_MLX_DIR;
  const key = process.env.STABILITY_API_KEY;
  const listen = (provider, generate, deadline) => soundLabServer(provider, async (prompt, signal) => {
    try { return await generate(prompt, signal); }
    catch (error) {
      // execFile's message contains the command line and full prompt.
      console.error(`${provider}: ${error.name} (${error.code ?? "generation failed"})`, error.stderr?.trim().split("\n").at(-1) ?? "");
      throw error;
    }
  }, deadline).listen(54339, "127.0.0.1", () => console.log(`Sound Lab: ${provider} on 127.0.0.1:54339`));
  if (directory) {
    try {
      if (!isAbsolute(directory)) throw new Error("Expected an absolute path");
      for (const required of [".venv/bin/python", "scripts/sa3_mlx.py", "models/mlx/dit_sm-music_f16.npz",
        "models/mlx/same_s_decoder_f32.npz", "models/mlx/t5gemma_f16.npz"]) {
        await access(join(directory, required));
      }
      listen("stable-audio-local", (prompt, signal) => generateLocalNote(prompt, directory, { signal }), 45_000);
    } catch {
      console.error("HANDSTRUDEL_AUDIO_MLX_DIR must point to an installed Stable Audio 3 optimized/mlx directory.");
      process.exitCode = 1;
    }
  } else if (key) {
    listen("stable-audio-cloud", (prompt, signal) => generateNote(prompt, key, { signal }), 85_000);
  } else {
    console.error("Set HANDSTRUDEL_AUDIO_MLX_DIR for local generation or STABILITY_API_KEY for the paid API.");
    process.exitCode = 1;
  }
}
