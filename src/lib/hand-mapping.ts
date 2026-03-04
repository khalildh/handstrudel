import { MusicParams, PARAM_MAP } from "./music";

export interface HandData {
  x: number;
  y: number;
  spread: number;
  lm: HandLandmark[];
}

export interface HandsState {
  left: HandData | null;
  right: HandData | null;
}

export interface MappingConfig {
  left:  { y: string; x: string; spread: string };
  right: { y: string; x: string; spread: string };
}

export const DEFAULT_MAPPING: MappingConfig = {
  left:  { y: "noteIdx", x: "lpf",  spread: "reverb" },
  right: { y: "gain",    x: "bpm",  spread: "delay" },
};

/** Scale a 0–1 axis value into a param's min–max range. */
function scaleAxis(raw: number, paramId: string, invert: boolean): number {
  const def = PARAM_MAP[paramId];
  if (!def) return 0;
  const t = invert ? 1 - raw : raw;
  return def.min + t * (def.max - def.min);
}

export function mapHandsToParams(
  hands: HandsState,
  params: MusicParams,
  config: MappingConfig,
): void {
  if (hands.left) {
    params[config.left.y] = scaleAxis(hands.left.y, config.left.y, true);
    params[config.left.x] = scaleAxis(hands.left.x, config.left.x, true);
    params[config.left.spread] = scaleAxis(hands.left.spread, config.left.spread, false);
  }
  if (hands.right) {
    params[config.right.y] = scaleAxis(hands.right.y, config.right.y, true);
    params[config.right.x] = scaleAxis(hands.right.x, config.right.x, true);
    params[config.right.spread] = scaleAxis(hands.right.spread, config.right.spread, false);
  }
}
