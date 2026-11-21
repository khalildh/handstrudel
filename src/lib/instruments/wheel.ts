// Split-wheel zone math, ported from `ChordMelodyModeManager.splitWedgeIndex`
// / `splitOctaveShift` and `SplitTouchUIView.zone(at:)`. Angles are degrees
// clockwise from 12 o'clock. Each half fans its wedges from the top of its arc
// (index 0) to the bottom; the note half inverts so the top is the highest lane.

import type { WheelGeometry } from "./rules.ts";

export type WheelSide = "left" | "right";

/** A chord sub-zone: wedge index (top to bottom) and octave −1 / 0 / +1. */
export interface ChordZone { kind: "chord"; wedge: number; octave: number }
/** A note sub-zone: lane (0 = lowest pitch, at the bottom) and octave. */
export interface NoteZone { kind: "note"; lane: number; octave: number }
export type WheelZone = ChordZone | NoteZone;

export const zoneKey = (zone: WheelZone) =>
  zone.kind === "chord" ? `c${zone.wedge}:${zone.octave}` : `n${zone.lane}:${zone.octave}`;

const wrap = (angle: number) => {
  const a = angle % 360;
  return a < 0 ? a + 360 : a;
};

/** Wedge index on one semicircle, or null when the angle is on the other half. */
export function splitWedgeIndex(side: WheelSide, angle: number, count: number): number | null {
  if (count <= 0) return null;
  const a = wrap(angle);
  let t: number;
  if (side === "left") {
    if (a < 180) return null;
    t = (360 - a) / 180;
  } else {
    if (a >= 180) return null;
    t = a / 180;
  }
  return Math.max(0, Math.min(count - 1, Math.trunc(t * count)));
}

/**
 * Outer-rim octave shift: 0 inside the base band; in the rim, the half of the
 * wedge nearer the top of the arc is +1 and the half nearer the bottom −1.
 */
export function splitOctaveShift(
  geometry: WheelGeometry, side: WheelSide, angle: number, radius: number, wedgeIndex: number, count: number,
): number {
  if (radius < geometry.octaveBandRadius || count <= 0) return 0;
  const a = wrap(angle);
  let offsetFromTop: number;
  if (side === "left") {
    if (a < 180) return 0;
    offsetFromTop = 360 - a;
  } else {
    if (a >= 180) return 0;
    offsetFromTop = a;
  }
  const wedgeLength = 180 / count;
  return offsetFromTop - wedgeIndex * wedgeLength < wedgeLength / 2 ? 1 : -1;
}

export interface WheelLayout {
  geometry: WheelGeometry;
  /** Chord half on the right (instrument side mirrored by swap-hands). */
  chordsOnRight: boolean;
  chordCount: number;
  noteCount: number;
  /** Whether the note half has an octave rim. */
  notesOctaveBand: boolean;
}

/**
 * The zone under a point given as an offset from the wheel's center (`dx`
 * right, `dy` up) in units of half the play area's shorter side. Null in the
 * rest hole and outside every wedge.
 */
export function zoneAt(layout: WheelLayout, dx: number, dy: number): WheelZone | null {
  const outer = layout.geometry.radius;
  if (outer <= 0) return null;
  const radius = Math.min(1, Math.hypot(dx, dy) / outer);
  if (radius < layout.geometry.restRadius) return null;
  const angle = wrap(90 - (Math.atan2(dy, dx) * 180) / Math.PI);
  const chordSide: WheelSide = layout.chordsOnRight ? "right" : "left";
  const noteSide: WheelSide = layout.chordsOnRight ? "left" : "right";

  const chordWedge = splitWedgeIndex(chordSide, angle, Math.max(1, layout.chordCount));
  if (chordWedge !== null) {
    const octave = splitOctaveShift(layout.geometry, chordSide, angle, radius, chordWedge, Math.max(1, layout.chordCount));
    return { kind: "chord", wedge: chordWedge, octave };
  }
  const noteWedge = splitWedgeIndex(noteSide, angle, layout.noteCount);
  if (noteWedge !== null) {
    const octave = layout.notesOctaveBand
      ? splitOctaveShift(layout.geometry, noteSide, angle, radius, noteWedge, layout.noteCount)
      : 0;
    return { kind: "note", lane: layout.noteCount - 1 - noteWedge, octave };
  }
  return null;
}

/** Center angle of chord wedge `index` (0 at the top of its arc). */
export function chordCenterAngle(layout: WheelLayout, index: number) {
  const offset = (index + 0.5) * (180 / Math.max(1, layout.chordCount));
  return layout.chordsOnRight ? offset : wrap(360 - offset);
}

/** Center angle of note lane `lane` (0 = lowest, at the bottom of its arc). */
export function noteCenterAngle(layout: WheelLayout, lane: number) {
  const offset = (layout.noteCount - 1 - lane + 0.5) * (180 / Math.max(1, layout.noteCount));
  return layout.chordsOnRight ? wrap(360 - offset) : offset;
}

/** Point at `angle` degrees clockwise from 12 o'clock, `radius` from the center (y down). */
export function polar(cx: number, cy: number, angle: number, radius: number) {
  const r = (angle * Math.PI) / 180;
  return { x: cx + radius * Math.sin(r), y: cy - radius * Math.cos(r) };
}

/** SVG path for an annular wedge between two angles (clockwise from 12 o'clock). */
export function wedgePath(cx: number, cy: number, inner: number, outer: number, start: number, end: number) {
  const span = end - start;
  const large = Math.abs(span) > 180 ? 1 : 0;
  const sweep = span >= 0 ? 1 : 0;
  const p1 = polar(cx, cy, start, outer);
  const p2 = polar(cx, cy, end, outer);
  const p3 = polar(cx, cy, end, inner);
  const p4 = polar(cx, cy, start, inner);
  const f = (n: number) => n.toFixed(2);
  return `M${f(p1.x)} ${f(p1.y)}A${f(outer)} ${f(outer)} 0 ${large} ${sweep} ${f(p2.x)} ${f(p2.y)}`
    + `L${f(p3.x)} ${f(p3.y)}A${f(inner)} ${f(inner)} 0 ${large} ${1 - sweep} ${f(p4.x)} ${f(p4.y)}Z`;
}
