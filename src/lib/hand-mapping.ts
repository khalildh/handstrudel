import { MusicParams, NOTES } from "./music";

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

export function mapHandsToParams(
  hands: HandsState,
  params: MusicParams,
): void {
  if (hands.left) {
    params.noteIdx = (1 - hands.left.y) * (NOTES.length - 1);
    params.lpf = 120 + (1 - hands.left.x) * 6000;
    params.reverb = Math.min(0.9, hands.left.spread * 0.9);
  }
  if (hands.right) {
    params.gain = Math.max(0.03, (1 - hands.right.y) * 0.9);
    params.bpm = 50 + (1 - hands.right.x) * 155;
    params.delay = Math.min(0.55, hands.right.spread * 0.55);
  }
}
