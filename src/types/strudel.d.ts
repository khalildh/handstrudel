declare module "@strudel/core" {
  export function repl(options: {
    defaultOutput: unknown;
    getTime: () => number;
    onSchedulerError?: (e: unknown) => void;
    onEvalError?: (e: unknown) => void;
  }): {
    evaluate: (code: string) => Promise<unknown>;
    start: () => void;
    stop: () => void;
  };
  export function evalScope(
    ...modules: Promise<unknown>[]
  ): Promise<void>;
  export function reify(pattern: string): {
    queryArc: (start: number, end: number) => { value: number }[];
  };
  export function getTime(): number;
}

declare module "@strudel/webaudio" {
  export const webaudioOutput: unknown;
  export function initAudio(options?: Record<string, unknown>): Promise<void>;
  export function getAudioContext(): AudioContext;
  export function setAudioContext(context: AudioContext): AudioContext;
  export function registerSynthSounds(): void;
  /** Trigger one sound at absolute time `t` (seconds) for `duration` seconds. */
  export function superdough(value: Record<string, unknown>, t: number, duration: number): Promise<void>;
}

declare module "@strudel/soundfonts" {
  export function registerSoundfonts(): void;
}

declare module "@strudel/mini" {}
declare module "@strudel/tonal" {}
