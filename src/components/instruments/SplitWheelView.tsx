"use client";

// The split wheel drawn in SVG, after the iOS `SplitChordMelodyOverlayView`:
// chord wedges colored by scale degree on one half, note wedges on the other,
// outer ±1 octave rims, a rest hole showing the held chord. Pointer input
// (mouse, pen, any number of fingers) goes through the same zone math as iOS
// touch (`zoneAt`), and each pointer strikes again when it crosses into a new
// zone, like `SplitTouchUIView`.

import { useEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from "react";
import {
  chordCenterAngle, noteCenterAngle, polar, wedgePath, zoneAt, zoneKey, type WheelLayout, type WheelZone,
} from "../../lib/instruments/wheel";

export interface SplitWheelModel {
  layout: WheelLayout;
  /** Scale degree per chord wedge (for colors). */
  degrees: number[];
  chordNames: string[];
  noteNames: string[];
  /** Note lanes that are tones of the held chord (tinted green). */
  chordToneLanes: Set<number>;
  /** Shown in the rest hole. */
  heldChordName: string;
}

export interface WheelCursor { id: string; x: number; y: number; pinching: boolean }

interface Props {
  model: SplitWheelModel;
  /** Zones lit by hands (keys from `zoneKey`). */
  litZones: Set<string>;
  /** Hand positions in the stage's pixel space, for cursors. */
  cursors?: WheelCursor[];
  disabled?: boolean;
  onStrike: (zone: WheelZone) => void;
  /** Reports the stage size so hand positions can be mapped onto it. */
  onResize?: (size: { width: number; height: number }) => void;
}

// SwiftUI colors used by the iOS overlay.
const GREEN = "#34c759";
const CYAN = "#32ade6";
const DEGREE_COLORS = [GREEN, "#9980e6", "#b399e6", "#66cce6", "#ff2d55", "#e69966", "#e66666"];
const degreeColor = (degree: number) => DEGREE_COLORS[degree] ?? "#8e8e93";

export default function SplitWheelView({ model, litZones, cursors = [], disabled, onStrike, onResize }: Props) {
  const stage = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ width: 0, height: 0 });
  const pointers = useRef(new Map<number, string | null>());
  const [touched, setTouched] = useState<Set<string>>(new Set());
  const strike = useRef(onStrike);
  strike.current = onStrike;

  useEffect(() => {
    const element = stage.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => {
      const next = { width: entry.contentRect.width, height: entry.contentRect.height };
      setSize(next);
      onResize?.(next);
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, [onResize]);

  const { layout } = model;
  const { width, height } = size;
  const cx = width / 2;
  const cy = height / 2;
  const half = Math.min(width, height) / 2;
  const outer = half * layout.geometry.radius;
  const rest = outer * layout.geometry.restRadius;
  const band = outer * layout.geometry.octaveBandRadius;
  const active = new Set([...litZones, ...touched]);
  const chordWedge = 180 / Math.max(1, layout.chordCount);
  const noteWedge = 180 / Math.max(1, layout.noteCount);

  function zoneFor(event: PointerEvent<HTMLDivElement>) {
    const rect = event.currentTarget.getBoundingClientRect();
    if (!half) return null;
    const dx = (event.clientX - rect.left - cx) / half;
    const dy = (cy - (event.clientY - rect.top)) / half;
    return zoneAt(layout, dx, dy);
  }

  function publish() {
    setTouched(new Set([...pointers.current.values()].filter((key): key is string => key !== null)));
  }

  function enter(pointer: number, zone: WheelZone | null) {
    const key = zone ? zoneKey(zone) : null;
    if (pointers.current.get(pointer) === key) return;
    pointers.current.set(pointer, key);
    if (zone) strike.current(zone);
    publish();
  }

  function onPointerDown(event: PointerEvent<HTMLDivElement>) {
    if (disabled || (event.pointerType === "mouse" && event.button !== 0)) return;
    event.currentTarget.setPointerCapture?.(event.pointerId);
    pointers.current.delete(event.pointerId);
    enter(event.pointerId, zoneFor(event));
  }

  function onPointerMove(event: PointerEvent<HTMLDivElement>) {
    if (!pointers.current.has(event.pointerId)) return;
    enter(event.pointerId, zoneFor(event));
  }

  function onPointerEnd(event: PointerEvent<HTMLDivElement>) {
    if (pointers.current.delete(event.pointerId)) publish();
  }

  function onKey(event: KeyboardEvent, zone: WheelZone) {
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    if (!disabled) strike.current(zone);
  }

  // Octave rim halves: the half nearer the top of the arc plays up.
  const rimHalves = (center: number, wedge: number, rightHalf: boolean) => {
    const start = center - wedge / 2;
    const end = center + wedge / 2;
    return rightHalf
      ? { up: [start, center], down: [center, end], upMid: center - wedge / 4, downMid: center + wedge / 4 }
      : { up: [center, end], down: [start, center], upMid: center + wedge / 4, downMid: center - wedge / 4 };
  };

  const chordShapes = model.chordNames.map((name, wedge) => {
    const color = degreeColor(model.degrees[wedge] ?? -1);
    const center = chordCenterAngle(layout, wedge);
    const lit = (octave: number) => active.has(zoneKey({ kind: "chord", wedge, octave }));
    const rim = rimHalves(center, chordWedge, layout.chordsOnRight);
    const fill = (on: boolean) => (on ? `${color}80` : "rgba(255,255,255,0.05)");
    const stroke = (on: boolean) => (on ? color : "rgba(255,255,255,0.1)");
    const label = polar(cx, cy, center, (rest + band) / 2);
    const up = polar(cx, cy, rim.upMid, (band + outer) / 2);
    const down = polar(cx, cy, rim.downMid, (band + outer) / 2);
    const anyLit = lit(0) || lit(1) || lit(-1);
    return (
      <g key={`chord-${wedge}`} className="wheel-zone" role="button" tabIndex={disabled ? -1 : 0}
        aria-label={`Chord ${name}`} data-testid={`wheel-chord-${wedge}`} data-active={anyLit || undefined}
        onKeyDown={(event) => onKey(event, { kind: "chord", wedge, octave: 0 })}>
        <path d={wedgePath(cx, cy, rest, band, center - chordWedge / 2, center + chordWedge / 2)}
          fill={fill(lit(0))} stroke={stroke(lit(0))} strokeWidth={lit(0) ? 2.5 : 1} />
        <path d={wedgePath(cx, cy, band, outer, rim.up[0], rim.up[1])} fill={fill(lit(1))} stroke={stroke(lit(1))}
          strokeWidth={lit(1) ? 2.5 : 0.5} data-testid={`wheel-chord-${wedge}-up`} />
        <path d={wedgePath(cx, cy, band, outer, rim.down[0], rim.down[1])} fill={fill(lit(-1))} stroke={stroke(lit(-1))}
          strokeWidth={lit(-1) ? 2.5 : 0.5} data-testid={`wheel-chord-${wedge}-down`} />
        <text x={label.x} y={label.y} className="wheel-label wheel-chord-label" data-testid={`wheel-chord-${wedge}-label`}
          fill={anyLit ? "#fff" : "rgba(255,255,255,0.75)"}>{name}</text>
        <text x={up.x} y={up.y} className="wheel-arrow" fill={lit(1) ? "#fff" : "rgba(255,255,255,0.35)"}
          data-testid={`wheel-chord-${wedge}-up-label`}>↑</text>
        <text x={down.x} y={down.y} className="wheel-arrow" fill={lit(-1) ? "#fff" : "rgba(255,255,255,0.35)"}
          data-testid={`wheel-chord-${wedge}-down-label`}>↓</text>
      </g>
    );
  });

  const noteShapes = model.noteNames.map((name, lane) => {
    const tone = model.chordToneLanes.has(lane);
    const color = tone ? GREEN : CYAN;
    const center = noteCenterAngle(layout, lane);
    const lit = (octave: number) => active.has(zoneKey({ kind: "note", lane, octave }));
    const anyLit = lit(0) || lit(1) || lit(-1);
    const label = polar(cx, cy, center, layout.notesOctaveBand ? (rest + band) / 2 : (rest + outer) / 2);
    const common = {
      className: "wheel-zone", role: "button", tabIndex: disabled ? -1 : 0, "aria-label": `Note ${name}`,
      "data-testid": `wheel-note-${lane}`, "data-active": anyLit || undefined, "data-chord-tone": tone || undefined,
      onKeyDown: (event: KeyboardEvent) => onKey(event, { kind: "note", lane, octave: 0 }),
    };
    if (!layout.notesOctaveBand) {
      return (
        <g key={`note-${lane}`} {...common}>
          <path d={wedgePath(cx, cy, rest, outer, center - noteWedge / 2, center + noteWedge / 2)}
            fill={lit(0) ? `${CYAN}73` : "rgba(255,255,255,0.05)"} stroke={lit(0) ? `${CYAN}d9` : "rgba(255,255,255,0.08)"}
            strokeWidth={lit(0) ? 2.5 : 1} />
          <text x={label.x} y={label.y} className="wheel-label wheel-note-label" data-testid={`wheel-note-${lane}-label`}
            fill={anyLit ? "#fff" : `${CYAN}bf`}>{name}</text>
        </g>
      );
    }
    const rim = rimHalves(center, noteWedge, !layout.chordsOnRight);
    const up = polar(cx, cy, rim.upMid, (band + outer) / 2);
    const down = polar(cx, cy, rim.downMid, (band + outer) / 2);
    const baseFill = lit(0) ? `${color}99` : tone ? `${color}4d` : `${CYAN}29`;
    const rimFill = (on: boolean) => (on ? `${color}8c` : tone ? `${color}29` : `${color}1a`);
    return (
      <g key={`note-${lane}`} {...common}>
        <path d={wedgePath(cx, cy, rest, band, center - noteWedge / 2, center + noteWedge / 2)} fill={baseFill}
          stroke={lit(0) ? color : tone ? `${color}d9` : `${CYAN}8c`} strokeWidth={lit(0) ? 2.5 : 1.2} className="wheel-outlined" />
        <path d={wedgePath(cx, cy, band, outer, rim.up[0], rim.up[1])} fill={rimFill(lit(1))}
          stroke={lit(1) ? color : `${color}59`} strokeWidth={lit(1) ? 1.8 : 1} className="wheel-outlined"
          data-testid={`wheel-note-${lane}-up`} />
        <path d={wedgePath(cx, cy, band, outer, rim.down[0], rim.down[1])} fill={rimFill(lit(-1))}
          stroke={lit(-1) ? color : `${color}59`} strokeWidth={lit(-1) ? 1.8 : 1} className="wheel-outlined"
          data-testid={`wheel-note-${lane}-down`} />
        <text x={label.x} y={label.y} className="wheel-label wheel-note-label" data-testid={`wheel-note-${lane}-label`}
          fill="#fff">{name}</text>
        <text x={up.x} y={up.y} className="wheel-arrow wheel-arrow-small" fill={lit(1) ? "#fff" : `${color}59`}
          data-testid={`wheel-note-${lane}-up-label`}>↑</text>
        <text x={down.x} y={down.y} className="wheel-arrow wheel-arrow-small" fill={lit(-1) ? "#fff" : `${color}59`}
          data-testid={`wheel-note-${lane}-down-label`}>↓</text>
      </g>
    );
  });

  return (
    <div ref={stage} className="wheel-stage" data-disabled={disabled || undefined}
      onPointerDown={onPointerDown} onPointerMove={onPointerMove} onPointerUp={onPointerEnd}
      onPointerCancel={onPointerEnd} onLostPointerCapture={onPointerEnd}>
      {width > 0 && (
        <svg className="wheel-svg" width={width} height={height} viewBox={`0 0 ${width} ${height}`}
          role="group" aria-label="Instrument wheel">
          {chordShapes}
          {noteShapes}
          <path d={`M${cx} ${cy - outer}V${cy - rest}M${cx} ${cy + rest}V${cy + outer}`}
            stroke="rgba(255,255,255,0.18)" strokeLinecap="round" />
          <circle cx={cx} cy={cy} r={rest} fill="rgba(0,0,0,0.25)" stroke="rgba(255,255,255,0.15)" />
          {model.heldChordName && (
            <text x={cx} y={cy} className="wheel-held" data-testid="wheel-held-chord"
              style={{ fontSize: Math.max(12, Math.min(28, rest * 0.42)) }}>{model.heldChordName}</text>
          )}
          {cursors.map((cursor) => (
            <circle key={cursor.id} cx={cursor.x} cy={cursor.y} r={cursor.pinching ? 13 : 9}
              className="wheel-cursor" data-pinching={cursor.pinching || undefined} />
          ))}
        </svg>
      )}
    </div>
  );
}
