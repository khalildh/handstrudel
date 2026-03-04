import { MusicParams } from "./music";

export const DEFAULT_PARAMS: MusicParams = {
  noteIdx: 10,
  gain: 0.55,
  lpf: 3000,
  reverb: 0.2,
  bpm: 120,
  delay: 0.12,
};

const ALPHA = 0.1;

export function smoothParams(
  target: MusicParams,
  smoothed: MusicParams,
): void {
  for (const k of Object.keys(target) as (keyof MusicParams)[]) {
    smoothed[k] = smoothed[k] + (target[k] - smoothed[k]) * ALPHA;
  }
}
