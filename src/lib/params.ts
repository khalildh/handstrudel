import { MusicParams, PARAM_MAP } from "./music";
import { MappingConfig } from "./hand-mapping";

export function buildDefaultParams(config: MappingConfig): MusicParams {
  const params: MusicParams = {};
  const ids = new Set<string>();
  for (const v of Object.values(config.left)) ids.add(v);
  for (const v of Object.values(config.right)) ids.add(v);
  for (const id of ids) {
    const def = PARAM_MAP[id];
    if (def) params[id] = def.default;
  }
  return params;
}

const ALPHA = 0.1;

export function smoothParams(
  target: MusicParams,
  smoothed: MusicParams,
): void {
  for (const k of Object.keys(target)) {
    if (k in smoothed) {
      smoothed[k] = smoothed[k] + (target[k] - smoothed[k]) * ALPHA;
    } else {
      smoothed[k] = target[k];
    }
  }
}
