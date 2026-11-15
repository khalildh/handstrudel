// The Bug Fix: npm ensures all @strudel/* packages share ONE @strudel/core
// instance, so evalScope registers note/s/struct/etc onto the SAME globalThis
// that evaluate()'s new Function() reads from.
// With CDN-based ESM imports (esm.sh), each package got its own @strudel/core
// copy, so `note` was never in evaluate()'s scope.

import { repl, evalScope, reify, getTime } from "@strudel/core";
import {
  webaudioOutput,
  initAudio,
  getAudioContext,
  registerSynthSounds,
} from "@strudel/webaudio";
import { registerSoundfonts } from "@strudel/soundfonts";

declare const Hydra: new (opts: Record<string, unknown>) => { synth: { hush?: () => void } };

function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve();
    const s = document.createElement("script");
    s.src = src;
    s.onload = () => resolve();
    s.onerror = (error) => {
      s.remove();
      reject(error);
    };
    document.head.appendChild(s);
  });
}

export async function initializeStrudel(surface: HTMLElement) {
  registerSynthSounds();
  // Registers thousands of General MIDI instruments into the `s()` namespace
  // (e.g. s("gm_acoustic_piano")). Sample data is lazy-loaded from a CDN the
  // first time each instrument plays, and runs through the same effects chain.
  registerSoundfonts();

  await evalScope(
    import("@strudel/core"),
    import("@strudel/mini"),
    import("@strudel/tonal"),
    import("@strudel/webaudio"),
    import("@strudel/soundfonts"),
  );

  // initAudio directly initializes audio (not initAudioOnFirstClick which
  // waits for a future mousedown and would hang since we're already in one)
  await initAudio();
  const audioCtx = getAudioContext();
  await loadScript("https://unpkg.com/hydra-synth");

  // Audio tap for video recording: intercept all connections to audioCtx.destination
  // and mirror them to a MediaStreamAudioDestinationNode so we can capture audio.
  const recordingDest = audioCtx.createMediaStreamDestination();
  const origConnect = AudioNode.prototype.connect as (
    this: AudioNode,
    destinationNode: AudioNode,
    output?: number,
    input?: number,
  ) => AudioNode;
  const connectRecording = function (
    this: AudioNode,
    ...connectArgs: [AudioNode, number?, number?] | [AudioParam, number?]
  ): AudioNode | void {
    const result = origConnect.apply(this, connectArgs as [AudioNode, number?, number?]);
    if (connectArgs[0] === audioCtx.destination) {
      try {
        origConnect.call(this, recordingDest);
      } catch {
        /* already connected or incompatible — ignore */
      }
    }
    return result;
  } as typeof AudioNode.prototype.connect;

  // Initialize Hydra visual synthesis via CDN (avoids SSR/build issues)
  const canvas = document.createElement("canvas");
  canvas.id = "hydra-canvas";
  const resizeCanvas = () => {
    if (canvas.width !== surface.clientWidth) canvas.width = surface.clientWidth;
    if (canvas.height !== surface.clientHeight) canvas.height = surface.clientHeight;
  };
  resizeCanvas();
  canvas.style.display = "none"; // hidden until user enables
  const hydra = new Hydra({
    canvas,
    detectAudio: false,
    makeGlobal: true,
    autoLoop: true,
  });
  surface.append(canvas);
  const resizeObserver = new ResizeObserver(resizeCanvas);
  resizeObserver.observe(surface);
  AudioNode.prototype.connect = connectRecording;

  // Register H() — bridges Strudel patterns to Hydra parameter functions
  // H("1 2 3") returns a function that queries the pattern at the current time
  (globalThis as Record<string, unknown>).H = (pat: string) =>
    () => reify(pat).queryArc(getTime(), getTime())[0]?.value ?? 0;

  const { evaluate, start, stop } = repl({
    defaultOutput: webaudioOutput,
    getTime: () => audioCtx?.currentTime ?? 0,
    onSchedulerError: (e: unknown) => console.error("sched:", e),
    onEvalError: (e: unknown) => console.error("eval:", e),
  });

  // Hydra globals (osc, noise, shape, etc.) live on globalThis via makeGlobal.
  // Strudel's evaluate() uses a sandboxed scope that can't see them.
  // evalHydra runs code in the true global scope where Hydra functions exist.
  const evalHydra = (code: string) => {
    try {
      new Function(code)();
    } catch (e) {
      console.warn("hydra eval:", e);
    }
  };

  // Global object for signal-based parameter updates (mutated at 60fps, read by Strudel scheduler)
  (globalThis as Record<string, unknown>).__hp = {};

  const dispose = () => {
    stop();
    resizeObserver.disconnect();
    canvas.remove();
    if (AudioNode.prototype.connect === connectRecording) AudioNode.prototype.connect = origConnect;
    hydra.synth?.hush?.();
  };
  return { evaluate, evalHydra, start, dispose, audioCtx, recordingDest };
}
