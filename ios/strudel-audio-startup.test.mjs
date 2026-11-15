import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { setTimeout as wait } from "node:timers/promises";
import { chromium } from "@playwright/test";

const engine = await readFile(new URL("./HandStrudel/HandStrudel/Resources/strudel-engine.html", import.meta.url), "utf8");
const bundle = await readFile(process.env.HANDSTRUDEL_TEST_AUDIO_BUNDLE
    ?? new URL("./HandStrudel/HandStrudel/Resources/strudel-bundle.js", import.meta.url), "utf8");
const origin = "http://handstrudel-audio.test";

function deferred() {
    let resolve;
    const promise = new Promise((done) => { resolve = done; });
    return { promise, resolve };
}

async function withEngine(run) {
    const browser = await chromium.launch({ args: ["--autoplay-policy=no-user-gesture-required"] });
    try {
        const page = await browser.newPage();
        await page.addInitScript(() => {
            const fetchResource = window.fetch.bind(window);
            window.engineLogs = [];
            window.webkit = { messageHandlers: { strudelBridge: { postMessage: ({ log }) => {
                if (log) window.engineLogs.push(log);
            } } } };
            // WKURLSchemeHandler supplies this local resource on iOS.
            window.fetch = (input, options) => input === "app-samples://bundled-instruments.json"
                ? Promise.resolve(Response.json({ instruments: { test_instrument: { C4: "note.mp3" } } }))
                : fetchResource(input, options);
        });
        await page.route(origin + "/strudel-engine.html", (route) => route.fulfill({ contentType: "text/html", body: engine }));
        await page.route(origin + "/strudel-bundle.js", (route) => route.fulfill({ contentType: "text/javascript", body: bundle }));
        await page.route("https://**/*", (route) => route.abort());
        await run(page);
    } finally {
        await browser.close();
    }
}

async function playBundledEngine(page) {
    await page.goto(origin + "/strudel-engine.html");
    await page.waitForFunction(() => window._moduleReady === true);
    return page.evaluate(async () => {
        const result = await window.initStrudel();
        window.noteOn("startup-smoke", 60, "sine", 0.5);
        const voice = window._voices["startup-smoke"];
        let audibleSignal = false;
        if (voice?.gain) {
            const context = voice.gain.context;
            const analyser = context.createAnalyser();
            const sink = context.createGain();
            sink.gain.value = 0;
            voice.gain.connect(analyser);
            analyser.connect(sink);
            sink.connect(context.destination);
            const pcm = new Float32Array(analyser.fftSize);
            const deadline = performance.now() + 1800;
            do {
                await new Promise((resolve) => setTimeout(resolve, 90));
                analyser.getFloatTimeDomainData(pcm);
                audibleSignal = pcm.some((sample) => Math.abs(sample) >= 0.001);
            } while (!audibleSignal && performance.now() < deadline);
            voice.gain.disconnect(analyser);
            analyser.disconnect();
            sink.disconnect();
        }
        window.noteOff("startup-smoke");
        return { result, midi: voice?.midi, loadedBundledManifest: !!window._sampleInstruments.test_instrument, audibleSignal };
    });
}

test("the real bundle can play while the drum catalog request is still pending", { timeout: 15000 }, async () => {
    await withEngine(async (page) => {
        const catalog = deferred();
        const release = deferred();
        await page.route("https://raw.githubusercontent.com/**/strudel.json", async (route) => {
            catalog.resolve();
            await release.promise;
            await route.fulfill({ headers: { "access-control-allow-origin": "*" }, json: { bd: ["kick.wav"] } });
        });
        const deadline = new AbortController();
        try {
            const playback = playBundledEngine(page);
            await Promise.race([
                Promise.all([
                    catalog.promise,
                    playback.then((played) => assert.deepEqual(played, {
                        result: "ok", midi: 60, loadedBundledManifest: true, audibleSignal: true,
                    })),
                ]),
                wait(8000, undefined, { signal: deadline.signal }).then(() => { throw new Error("The catalog blocked playback."); }),
            ]);
        } finally {
            deadline.abort();
            release.resolve();
        }
        await page.waitForFunction(() => window.engineLogs.includes("drum samples loaded"));
    });
});

test("an offline drum catalog does not prevent Web synth playback", { timeout: 15000 }, async () => {
    await withEngine(async (page) => {
        assert.deepEqual(await playBundledEngine(page), {
            result: "ok", midi: 60, loadedBundledManifest: true, audibleSignal: true,
        });
        await page.waitForFunction(() => window.engineLogs.some((entry) => entry.startsWith("remote drum catalog unavailable")));
    });
});
