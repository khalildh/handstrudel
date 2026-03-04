// The Bug Fix: npm ensures all @strudel/* packages share ONE @strudel/core
// instance, so evalScope registers note/s/struct/etc onto the SAME globalThis
// that evaluate()'s new Function() reads from.
// With CDN-based ESM imports (esm.sh), each package got its own @strudel/core
// copy, so `note` was never in evaluate()'s scope.

import { repl, evalScope } from "@strudel/core";
import {
  webaudioOutput,
  initAudio,
  getAudioContext,
  registerSynthSounds,
} from "@strudel/webaudio";

export async function initializeStrudel() {
  registerSynthSounds();

  await evalScope(
    import("@strudel/core"),
    import("@strudel/mini"),
    import("@strudel/tonal"),
    import("@strudel/webaudio"),
  );

  // initAudio directly initializes audio (not initAudioOnFirstClick which
  // waits for a future mousedown and would hang since we're already in one)
  await initAudio();
  const audioCtx = getAudioContext();

  const { evaluate, start, stop } = repl({
    defaultOutput: webaudioOutput,
    getTime: () => audioCtx?.currentTime ?? 0,
    onSchedulerError: (e: unknown) => console.error("sched:", e),
    onEvalError: (e: unknown) => console.error("eval:", e),
  });

  return { evaluate, start, stop, audioCtx };
}
