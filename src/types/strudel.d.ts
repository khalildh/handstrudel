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
  export function registerSynthSounds(): void;
}

declare module "@strudel/mini" {}
declare module "@strudel/tonal" {}
