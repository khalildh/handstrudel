import assert from "node:assert/strict";
import test from "node:test";
import { generateNote } from "./sound-lab.mjs";

test("submits one isolated-note generation and polls pending result to WAV", async () => {
  const sample = Buffer.from("RIFF0000WAVEfixture");
  const id = "a".repeat(64);
  let calls = 0;
  const result = await generateNote("glass bell", "fixture", {
    wait: async () => {},
    request: async (url, options) => {
      calls++;
      if (calls === 1) {
        assert.match(url, /stable-audio\/text-to-audio$/);
        assert.equal(options.body.get("output_format"), "wav");
        assert.match(options.body.get("prompt"), /C4.*glass bell/);
        return Response.json({ id }, { status: 202 });
      }
      assert.match(url, new RegExp("/results/" + id + "$"));
      return calls === 2 ? new Response(null, { status: 202 }) : new Response(sample);
    },
  });
  assert.equal(calls, 3);
  assert.deepEqual(result, sample);
});

test("invalid response never becomes an importable sample", async () => {
  await assert.rejects(() => generateNote("bell", "fixture", {
    request: async (_, { method }) => method === "POST"
      ? Response.json({ id: "b".repeat(64) })
      : new Response("not wave"),
  }), /did not return a WAV/);
});
