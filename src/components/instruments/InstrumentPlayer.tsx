"use client";

// Plays a shared post's instrument with its sound in the browser: by mouse,
// touch or hand tracking (MediaPipe, as in the Web Studio). The instrument
// file supplies the structure; the post's sound_setup (or the visitor's
// choices) supplies the music.

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { homepageAppStoreUrl } from "../../lib/app-store";
import type { HandsState } from "../../lib/hand-mapping";
import { playWheelStrike, startWheelAudio, warmUpSound } from "../../lib/instruments/audio";
import {
  chordDisplayName, chordNameSuffix, chordTones, chordToneLanes, noteLanes, pitchClassName, swapHands, wheelRules,
} from "../../lib/instruments/rules";
import type { WheelSound } from "../../lib/instruments/sound";
import type { InstrumentSpec } from "../../lib/instruments/spec";
import { zoneAt, zoneKey, type WheelLayout, type WheelZone } from "../../lib/instruments/wheel";
import SplitWheelView, { type SplitWheelModel, type WheelCursor } from "./SplitWheelView";
import "./instrument-player.css";

/** Seconds of play before the "post it in the app" card appears. */
export const APP_PROMPT_AFTER_MS = 20_000;

interface Props {
  spec: InstrumentSpec;
  sound: WheelSound;
  /** e.g. "Instrument from @maker's post" or "Built-in Scale Wheel". */
  instrumentNote?: string;
  /** Start with the camera on (Web Studio) or off (watch page). */
  cameraFirst?: boolean;
  /** Audio was already started by the click that opened the player. */
  audioStarted?: boolean;
  onClose?: () => void;
}

// Pinch hysteresis from ChordMelodyModeManager (chord hand / melody hand).
const PINCH_ON = 0.7;
const PINCH_OFF = 0.3;

export default function InstrumentPlayer({ spec, sound, instrumentNote, cameraFirst, audioStarted, onClose }: Props) {
  const [started, setStarted] = useState(Boolean(audioStarted));
  const [audioError, setAudioError] = useState(false);
  const [swap, setSwap] = useState(false);
  const [heldDegree, setHeldDegree] = useState<number | null>(null);
  const [firstStrikeAt, setFirstStrikeAt] = useState<number | null>(null);
  const [prompt, setPrompt] = useState(false);
  const [promptDismissed, setPromptDismissed] = useState(false);
  const [camera, setCamera] = useState<"off" | "starting" | "on" | "failed">("off");
  const [cursors, setCursors] = useState<WheelCursor[]>([]);
  const [handZones, setHandZones] = useState<Set<string>>(new Set());

  const rules = useMemo(() => wheelRules(spec, sound.voicing), [spec, sound.voicing]);
  const chordsOnRight = swapHands(rules, swap);
  const degrees = sound.degrees.length ? sound.degrees : [0];
  const melodyDegree = heldDegree ?? degrees[0];
  const lanes = useMemo(() => noteLanes(rules, sound.key, sound.scale, melodyDegree), [rules, sound, melodyDegree]);
  const layout: WheelLayout = useMemo(() => ({
    geometry: rules.geometry, chordsOnRight, chordCount: degrees.length, noteCount: lanes.length,
    notesOctaveBand: rules.notesOctaveBand,
  }), [rules, chordsOnRight, degrees.length, lanes.length]);
  const suffix = chordNameSuffix(rules);
  const model: SplitWheelModel = {
    layout,
    degrees,
    chordNames: degrees.map((degree) => chordDisplayName(sound.key, sound.scale, degree) + suffix),
    noteNames: lanes.map(pitchClassName),
    chordToneLanes: chordToneLanes(rules, sound.key, sound.scale, melodyDegree, lanes),
    heldChordName: heldDegree === null ? "" : chordDisplayName(sound.key, sound.scale, heldDegree) + suffix,
  };

  // Latest values for the hand-tracking loop, which runs outside React renders.
  const live = useRef({ layout, lanes, degrees, rules, sound, started });
  live.current = { layout, lanes, degrees, rules, sound, started };

  const strike = useCallback((zone: WheelZone) => {
    const { degrees, lanes, rules, sound, started } = live.current;
    if (!started) return;
    let midi: number[];
    if (zone.kind === "chord") {
      const degree = degrees[Math.max(0, Math.min(degrees.length - 1, zone.wedge))];
      midi = chordTones(rules, sound.key, sound.scale, degree).map((note) => note + zone.octave * 12);
      setHeldDegree(degree);
    } else {
      if (!lanes.length) return;
      const lane = Math.max(0, Math.min(lanes.length - 1, zone.lane));
      midi = [lanes[lane] + (rules.notesOctaveBand ? zone.octave * 12 : 0)];
    }
    setFirstStrikeAt((at) => at ?? Date.now());
    void playWheelStrike(zone.kind, midi, sound.sound, sound.bpm);
  }, []);

  async function start() {
    setAudioError(false);
    try {
      await startWheelAudio();
      setStarted(true);
      void warmUpSound(sound.sound);
    } catch {
      setAudioError(true);
    }
  }

  useEffect(() => {
    if (audioStarted) void warmUpSound(sound.sound);
  }, [audioStarted, sound.sound]);

  // The soft "post it in the app" card, after about 20 seconds of play.
  useEffect(() => {
    if (firstStrikeAt === null || promptDismissed) return;
    const timer = window.setTimeout(() => setPrompt(true), Math.max(0, firstStrikeAt + APP_PROMPT_AFTER_MS - Date.now()));
    return () => window.clearTimeout(timer);
  }, [firstStrikeAt, promptDismissed]);

  function stop() {
    stopCamera();
    if (firstStrikeAt !== null && !promptDismissed) setPrompt(true);
    else onClose?.();
  }

  // ── Hand tracking ────────────────────────────────────────────────
  const video = useRef<HTMLVideoElement>(null);
  const skeleton = useRef<HTMLCanvasElement>(null);
  const stageSize = useRef({ width: 0, height: 0 });
  const handsRef = useRef<HandsState>({ left: null, right: null });
  const handState = useRef(new Map<string, { pinching: boolean; zone: string | null }>());
  const stopTracking = useRef<(() => void) | null>(null);

  const onHands = useCallback(() => {
    const element = video.current;
    const { width, height } = stageSize.current;
    if (!element || !width || !height) return;
    const vw = element.videoWidth || 640;
    const vh = element.videoHeight || 480;
    // The video fills the stage like CSS object-fit: cover, mirrored.
    const scale = Math.max(width / vw, height / vh);
    const offsetX = (width - vw * scale) / 2;
    const offsetY = (height - vh * scale) / 2;
    const half = Math.min(width, height) / 2;
    const nextCursors: WheelCursor[] = [];
    const lit = new Set<string>();
    for (const side of ["left", "right"] as const) {
      const hand = handsRef.current[side];
      const state = handState.current.get(side) ?? { pinching: false, zone: null };
      if (!hand) {
        handState.current.delete(side);
        continue;
      }
      const tip = hand.lm[4];
      const index = hand.lm[8];
      const x = offsetX + (1 - (tip.x + index.x) / 2) * vw * scale;
      const y = offsetY + ((tip.y + index.y) / 2) * vh * scale;
      const pinching = state.pinching ? hand.pinch > PINCH_OFF : hand.pinch > PINCH_ON;
      const zone = pinching ? zoneAt(live.current.layout, (x - width / 2) / half, (height / 2 - y) / half) : null;
      const key = zone ? zoneKey(zone) : null;
      if (zone && key !== state.zone) strike(zone);
      if (key) lit.add(key);
      handState.current.set(side, { pinching, zone: key });
      nextCursors.push({ id: side, x, y, pinching });
    }
    setCursors(nextCursors);
    setHandZones((previous) => (sameSet(previous, lit) ? previous : lit));
  }, [strike]);

  async function startCamera() {
    if (!video.current || !skeleton.current || camera === "starting" || camera === "on") return;
    setCamera("starting");
    try {
      const { initializeMediaPipe } = await import("../../lib/mediapipe");
      stopTracking.current = await initializeMediaPipe(video.current, skeleton.current, handsRef, onHands);
      setCamera("on");
    } catch {
      setCamera("failed");
    }
  }

  function stopCamera() {
    stopTracking.current?.();
    stopTracking.current = null;
    const stream = video.current?.srcObject;
    if (stream instanceof MediaStream) stream.getTracks().forEach((track) => track.stop());
    if (video.current) video.current.srcObject = null;
    handState.current.clear();
    setCursors([]);
    setHandZones(new Set());
    setCamera((state) => (state === "failed" ? state : "off"));
  }

  useEffect(() => () => stopCamera(), []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (cameraFirst && started) void startCamera();
  }, [cameraFirst, started]); // eslint-disable-line react-hooks/exhaustive-deps

  const appStore = homepageAppStoreUrl();
  const progression = sound.progressionName === "Free" ? "Free layout" : sound.progressionName;

  return (
    <section className="instrument-player" aria-label="Instrument player" data-instrument={spec.id}>
      <header className="instrument-player-head">
        <div>
          <p className="instrument-player-eyebrow">PLAYING IN YOUR BROWSER</p>
          <h2>{spec.name}</h2>
          <p className="instrument-player-sound" data-testid="player-sound">
            {sound.soundLabel} · {sound.keyName} {sound.scaleName} · {progression} · {Math.round(sound.bpm)} BPM
          </p>
          {instrumentNote && <p className="instrument-player-note">{instrumentNote}</p>}
        </div>
        <div className="instrument-player-controls">
          <button type="button" className="watch-action" aria-pressed={camera === "on"}
            onClick={() => (camera === "on" ? stopCamera() : void startCamera())} disabled={!started || camera === "starting"}>
            {camera === "on" ? "Camera off" : camera === "starting" ? "Starting camera…" : "Play with hands"}
          </button>
          <button type="button" className="watch-action" aria-pressed={swap} onClick={() => setSwap((value) => !value)}>
            Swap hands
          </button>
          <button type="button" className="watch-action" onClick={stop}>Stop</button>
        </div>
      </header>
      {camera === "failed" && (
        <p className="instrument-player-status" role="status">The camera didn’t start. You can still play with a mouse or by touch.</p>
      )}
      <div className="instrument-player-stage" data-camera={camera}>
        <video ref={video} className="instrument-player-video" playsInline muted aria-hidden="true" />
        <canvas ref={skeleton} className="instrument-player-skeleton" aria-hidden="true" />
        <SplitWheelView model={model} litZones={handZones} cursors={cursors} disabled={!started}
          onStrike={strike} onResize={(next) => { stageSize.current = next; }} />
        {!started && (
          <div className="instrument-player-start">
            <button type="button" className="watch-action watch-primary" onClick={start}>Start playing</button>
            {audioError && <p role="status">Sound couldn’t start in this browser. Try again.</p>}
          </div>
        )}
      </div>
      <p className="instrument-player-hint">
        Tap or drag across the wheel. Chords on one half, notes on the other; reach into the rim to play an octave up or down.
        {camera === "on" && " With the camera on, pinch to play."}
      </p>
      {prompt && (
        <aside className="instrument-player-card" aria-label="Get the app" role="dialog">
          <div>
            <strong>Record and post this in the app</strong>
            <p>HandStrudel for iPhone records your performance with this instrument and sound, ready to share.</p>
          </div>
          <div className="instrument-player-card-actions">
            <a className="watch-action watch-primary" href={appStore}>Record and post this in the app</a>
            <button type="button" className="watch-action" onClick={() => { setPrompt(false); setPromptDismissed(true); }}>
              Keep playing
            </button>
            {onClose && <button type="button" className="watch-clear-link" onClick={onClose}>Close player</button>}
          </div>
        </aside>
      )}
    </section>
  );
}

function sameSet(a: Set<string>, b: Set<string>) {
  if (a.size !== b.size) return false;
  for (const value of a) if (!b.has(value)) return false;
  return true;
}
