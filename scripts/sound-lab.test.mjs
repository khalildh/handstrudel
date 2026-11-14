import assert from "node:assert/strict";
import { stat, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import test from "node:test";
import { generateLocalNote, generateNote, soundLabServer } from "./sound-lab.mjs";

const sample = Buffer.from("RIFF0000WAVEfixture");

test("submits one isolated-note generation and polls pending result to WAV", async () => {
  const id = "a".repeat(64);
  let calls = 0;
  const result = await generateNote("glass bell", "fixture", {
    wait: async () => {},
    request: async (url, options) => {
      calls++;
      if (calls === 1) {
        assert.match(url, /stable-audio\/text-to-audio$/);
        assert.equal(options.body.get("output_format"), "wav");
        assert.match(options.body.get("prompt"), /glass bell.*C4/);
        return Response.json({ id }, { status: 202 });
      }
      assert.match(url, new RegExp("/results/" + id + "$"));
      return calls === 2 ? new Response(null, { status: 202 }) : new Response(sample);
    },
  });
  assert.equal(calls, 3);
  assert.deepEqual(result, sample);
});

test("local runtime gets one literal prompt argument and its WAV is read before cleanup", async () => {
  let scratch;
  const wav = await generateLocalNote('glass bell; $(echo "hello")', "/model runtime", {
    run: async (file, args, options) => {
      assert.equal(file, "/model runtime/.venv/bin/python");
      assert.equal(options.cwd, "/model runtime");
      assert.match(args[args.indexOf("--prompt") + 1], /\$\(echo "hello"\).*C4/);
      assert.equal(args[args.indexOf("--seconds") + 1], "2");
      scratch = dirname(args.at(-1));
      await writeFile(args.at(-1), sample);
    },
  });
  assert.deepEqual(wav, sample);
  await assert.rejects(stat(scratch), { code: "ENOENT" });
});

test("bridge reports which provider is selected and rejects mismatched and browser requests", async (t) => {
  let calls = 0;
  const server = soundLabServer("stable-audio-local", async () => { calls++; return sample; }, 5000);
  t.after(() => server.close());
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  const status = await fetch(`${url}/status`);
  assert.deepEqual(await status.json(), { provider: "stable-audio-local" });
  const post = (provider, headers = {}) => fetch(`${url}/generate`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-HandStrudel-Audio-Provider": provider, ...headers },
    body: JSON.stringify({ prompt: "glass bell" }),
  });
  assert.equal((await post("stable-audio-local", { Origin: "https://example.com" })).status, 404);
  assert.equal((await post("stable-audio-cloud")).status, 409);
  assert.equal(calls, 0);
  const output = await post("stable-audio-local");
  assert.deepEqual(Buffer.from(await output.arrayBuffer()), sample);
  assert.equal(calls, 1);
});

test("invalid response never becomes an importable sample", async () => {
  await assert.rejects(() => generateNote("bell", "fixture", {
    request: async (_, { method }) => method === "POST"
      ? Response.json({ id: "b".repeat(64) })
      : new Response("not wave"),
  }), /did not return a WAV/);
});
