"use client";

import { useRef, useState, useCallback, useEffect } from "react";
import {
  MusicParams,
  buildCode,
  buildCodeHL,
  buildHydraCode,
  buildHydraCodeHL,
  hasHydraMapping,
  NOTES,
  NOTE_DISPLAY,
  STRUCTS,
} from "../lib/music";
import { buildDefaultParams, smoothParams } from "../lib/params";
import {
  HandsState,
  MappingConfig,
  DEFAULT_MAPPING,
  DEFAULT_HYDRA_MAPPING,
  mapHandsToParams,
  getSaveAxes,
} from "../lib/hand-mapping";
import { initializeStrudel } from "../lib/strudel";
import { initializeMediaPipe } from "../lib/mediapipe";
import StartOverlay from "./StartOverlay";
import Header from "./Header";
import Sidebar from "./Sidebar";
import CameraView from "./CameraView";

export interface SavedSnippet {
  code: string;
  timestamp: number;
  bpm: number;
}

interface UIState {
  codeHL: string;
  hydraCodeHL: string;
  smoothed: MusicParams;
  hands: HandsState;
  noteDisplay: string;
  bpm: number;
}

function buildTrackCode(slots: number[], speed: number, snippets: SavedSnippet[]): string | null {
  const codes = slots.map(i => snippets[i]?.code).filter(Boolean);
  if (codes.length === 0) return null;
  const inner = codes.length === 1 ? codes[0] : `slowcat(${codes.join(", ")})`;
  return speed === 1 ? inner : `(${inner}).slow(${1 / speed})`;
}

export default function HandStrudel() {
  const [overlay, setOverlay] = useState<"visible" | "fading" | "hidden">(
    "visible",
  );
  const [status, setStatus] = useState("click start");
  const [config, setConfig] = useState<MappingConfig>(DEFAULT_MAPPING);
  const [hydraConfig, setHydraConfig] = useState<MappingConfig>(DEFAULT_HYDRA_MAPPING);
  const [advanced, setAdvanced] = useState(false);

  const defaults = buildDefaultParams(DEFAULT_MAPPING);
  const defaultNI = Math.round(defaults.noteIdx ?? 10);
  const [uiState, setUiState] = useState<UIState>({
    codeHL: buildCodeHL(defaults, 0, DEFAULT_MAPPING),
    hydraCodeHL: "",
    smoothed: { ...defaults },
    hands: { left: null, right: null },
    noteDisplay: NOTE_DISPLAY[defaultNI],
    bpm: defaults.bpm ?? 120,
  });

  // Hot-path refs (mutated at 60fps, never trigger React re-renders)
  const paramsRef = useRef<MusicParams>({ ...defaults });
  const smoothedRef = useRef<MusicParams>({ ...defaults });
  const handsRef = useRef<HandsState>({ left: null, right: null });
  const configRef = useRef<MappingConfig>(DEFAULT_MAPPING);
  const hydraConfigRef = useRef<MappingConfig>(DEFAULT_HYDRA_MAPPING);
  const advancedRef = useRef(false);
  const structIdxRef = useRef(0);
  const lastCodeRef = useRef("");
  const evaluateRef = useRef<
    ((code: string) => Promise<unknown>) | null
  >(null);
  const evalHydraRef = useRef<((code: string) => void) | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const lastBeatRef = useRef(-1);

  // Save-gesture refs
  const savedSnippetsRef = useRef<SavedSnippet[]>([]);
  const saveArmedRef = useRef<Map<string, boolean>>(new Map());
  const lastSaveTimeRef = useRef(0);
  const [savedSnippets, setSavedSnippets] = useState<SavedSnippet[]>([]);

  // Snippet playback (multiple simultaneous via Set)
  const playingSetRef = useRef<Set<number>>(new Set());
  const [playingSet, setPlayingSet] = useState<Set<number>>(new Set());

  // Track sequencer
  const trackRef = useRef<{ slots: number[]; speed: number }>({ slots: [], speed: 1 });
  const trackPlayingRef = useRef(false);
  const [track, setTrack] = useState<{ slots: number[]; speed: number }>({ slots: [], speed: 1 });
  const [trackPlaying, setTrackPlaying] = useState(false);

  // Hydra visuals
  const hydraEnabledRef = useRef(false);
  const [hydraEnabled, setHydraEnabled] = useState(false);
  const lastHydraCodeRef = useRef("");

  // DOM refs
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Cleanup refs
  const animFrameRef = useRef(0);
  const uiTimerRef = useRef(0);
  const structTimerRef = useRef(0);

  const handleImportSnippets = useCallback((snippets: SavedSnippet[]) => {
    savedSnippetsRef.current = [...savedSnippetsRef.current, ...snippets];
    setSavedSnippets(savedSnippetsRef.current);
  }, []);

  const handlePlaySnippet = useCallback((idx: number) => {
    // Stop track playback
    if (trackPlayingRef.current) {
      trackPlayingRef.current = false;
      setTrackPlaying(false);
    }

    const set = new Set(playingSetRef.current);
    if (set.has(idx)) {
      set.delete(idx);
    } else {
      set.add(idx);
    }
    playingSetRef.current = set;
    setPlayingSet(new Set(set));

    if (set.size === 0) {
      // Resume live code
      lastCodeRef.current = ""; // force re-eval on next frame
    } else {
      // Evaluate single or stacked snippets
      const codes = Array.from(set)
        .map((i) => savedSnippetsRef.current[i]?.code)
        .filter(Boolean);
      const code = codes.length === 1 ? codes[0] : `stack(${codes.join(", ")})`;
      evaluateRef.current?.(code).catch((e: unknown) => console.warn("eval:", e));
    }
  }, []);

  const handleAddToTrack = useCallback((idx: number) => {
    const next = { ...trackRef.current, slots: [...trackRef.current.slots, idx] };
    trackRef.current = next;
    setTrack(next);
    if (trackPlayingRef.current) {
      const code = buildTrackCode(next.slots, next.speed, savedSnippetsRef.current);
      if (code) evaluateRef.current?.(code).catch((e: unknown) => console.warn("eval:", e));
    }
  }, []);

  const handleRemoveFromTrack = useCallback((slotIdx: number) => {
    const slots = trackRef.current.slots.filter((_, i) => i !== slotIdx);
    const next = { ...trackRef.current, slots };
    trackRef.current = next;
    setTrack(next);
    if (slots.length === 0 && trackPlayingRef.current) {
      trackPlayingRef.current = false;
      setTrackPlaying(false);
      lastCodeRef.current = "";
    } else if (trackPlayingRef.current) {
      const code = buildTrackCode(slots, trackRef.current.speed, savedSnippetsRef.current);
      if (code) evaluateRef.current?.(code).catch((e: unknown) => console.warn("eval:", e));
    }
  }, []);

  const handleTrackSpeedChange = useCallback((speed: number) => {
    const next = { ...trackRef.current, speed };
    trackRef.current = next;
    setTrack(next);
    if (trackPlayingRef.current) {
      const code = buildTrackCode(trackRef.current.slots, speed, savedSnippetsRef.current);
      if (code) evaluateRef.current?.(code).catch((e: unknown) => console.warn("eval:", e));
    }
  }, []);

  const handleToggleTrackPlay = useCallback(() => {
    if (trackPlayingRef.current) {
      trackPlayingRef.current = false;
      setTrackPlaying(false);
      lastCodeRef.current = "";
    } else {
      if (trackRef.current.slots.length === 0) return;
      playingSetRef.current = new Set();
      setPlayingSet(new Set());
      trackPlayingRef.current = true;
      setTrackPlaying(true);
      const code = buildTrackCode(trackRef.current.slots, trackRef.current.speed, savedSnippetsRef.current);
      if (code) evaluateRef.current?.(code).catch((e: unknown) => console.warn("eval:", e));
    }
  }, []);

  const handleHydraToggle = useCallback(() => {
    const next = !hydraEnabledRef.current;
    hydraEnabledRef.current = next;
    setHydraEnabled(next);
    const c = document.getElementById("hydra-canvas");
    if (!next) {
      lastHydraCodeRef.current = "";
      // Clear the Hydra canvas by rendering black
      evalHydraRef.current?.("solid(0,0,0,0).out()");
      if (c) (c as HTMLCanvasElement).style.display = "none";
    } else {
      if (c) (c as HTMLCanvasElement).style.display = "";
      lastHydraCodeRef.current = ""; // force re-eval
    }
  }, []);

  const handleStart = useCallback(async (cfg: MappingConfig, hCfg: MappingConfig, adv: boolean) => {
    setConfig(cfg);
    setHydraConfig(hCfg);
    setAdvanced(adv);
    configRef.current = cfg;
    hydraConfigRef.current = hCfg;
    advancedRef.current = adv;

    // Reset params for chosen config (merge music + hydra defaults)
    const musicDefs = buildDefaultParams(cfg);
    const hydraDefs = buildDefaultParams(hCfg);
    const defs = { ...musicDefs, ...hydraDefs };
    paramsRef.current = { ...defs };
    smoothedRef.current = { ...defs };

    // Fade out overlay
    setOverlay("fading");
    setTimeout(() => setOverlay("hidden"), 300);

    setStatus("initialising strudel…");

    try {
      const { evaluate, evalHydra, audioCtx } = await initializeStrudel();
      evaluateRef.current = evaluate;
      evalHydraRef.current = evalHydra;
      audioCtxRef.current = audioCtx;

      const initCode = buildCode(paramsRef.current, structIdxRef.current, cfg);
      console.log("Initial code:", initCode);
      await evaluate(initCode);
      lastCodeRef.current = initCode;

      setStatus("requesting camera…");

      if (!videoRef.current || !canvasRef.current) {
        throw new Error("Video or canvas element not found");
      }

      await initializeMediaPipe(
        videoRef.current,
        canvasRef.current,
        handsRef,
        () => {
          mapHandsToParams(handsRef.current, paramsRef.current, configRef.current);
          mapHandsToParams(handsRef.current, paramsRef.current, hydraConfigRef.current);
        },
      );

      setStatus("running — wave your hands");

      // Rotate struct every 8s
      structTimerRef.current = window.setInterval(() => {
        structIdxRef.current =
          (structIdxRef.current + 1) % STRUCTS.length;
      }, 8000);

      // 60fps animation loop (mapHandsToParams runs in MediaPipe callback, not here)
      const loop = () => {
        smoothParams(paramsRef.current, smoothedRef.current);

        // Beat flash (direct DOM for performance)
        const ctx = audioCtxRef.current;
        if (ctx) {
          try {
            const cpm = (smoothedRef.current.bpm ?? 120) / 4;
            const beat =
              Math.floor(((ctx.currentTime * cpm) / 60) * 4) % 4;
            if (beat !== lastBeatRef.current) {
              lastBeatRef.current = beat;
              const d = document.getElementById("bd" + beat);
              if (d) {
                d.classList.add(beat % 2 === 0 ? "on-l" : "on-r");
                setTimeout(
                  () => d.classList.remove("on-l", "on-r"),
                  80,
                );
              }
            }
          } catch {
            /* ignore beat flash errors */
          }
        }

        // Eval on change (skip when playing saved snippets)
        if (playingSetRef.current.size === 0 && !trackPlayingRef.current) {
          const code = buildCode(
            smoothedRef.current,
            structIdxRef.current,
            configRef.current,
          );
          if (code !== lastCodeRef.current) {
            lastCodeRef.current = code;
            evaluateRef
              .current?.(code)
              .catch((e: unknown) => console.warn("eval:", e));
          }

          // Hydra visuals (evaluated separately in global scope)
          if (hydraEnabledRef.current) {
            const hydraCode = buildHydraCode(smoothedRef.current);
            if (hydraCode !== lastHydraCodeRef.current) {
              lastHydraCodeRef.current = hydraCode;
              evalHydraRef.current?.(hydraCode);
            }
          }
        }

        // Save-gesture trigger
        const saveAxes = getSaveAxes(configRef.current);
        const now = performance.now();
        for (const { side, axisKey } of saveAxes) {
          const hand = handsRef.current[side];
          if (!hand) continue;
          const raw = hand[axisKey];
          if (typeof raw !== "number") continue;
          const armKey = `${side}:${axisKey}`;
          const armed = saveArmedRef.current.get(armKey) ?? true;
          if (raw > 0.8 && armed && now - lastSaveTimeRef.current > 1000) {
            const snippet: SavedSnippet = {
              code: lastCodeRef.current,
              timestamp: Date.now(),
              bpm: Math.round(smoothedRef.current.bpm ?? 120),
            };
            savedSnippetsRef.current = [...savedSnippetsRef.current, snippet];
            saveArmedRef.current.set(armKey, false);
            lastSaveTimeRef.current = now;
          } else if (raw < 0.3) {
            saveArmedRef.current.set(armKey, true);
          }
        }

        animFrameRef.current = requestAnimationFrame(loop);
      };

      animFrameRef.current = requestAnimationFrame(loop);

      // UI state updates at ~15fps
      uiTimerRef.current = window.setInterval(() => {
        const s = { ...smoothedRef.current };
        const ni = Math.max(
          0,
          Math.min(NOTES.length - 1, Math.round(s.noteIdx ?? 10)),
        );
        setUiState({
          codeHL: buildCodeHL(s, structIdxRef.current, configRef.current),
          hydraCodeHL: hydraEnabledRef.current ? buildHydraCodeHL(s) : "",
          smoothed: s,
          hands: { ...handsRef.current },
          noteDisplay: NOTE_DISPLAY[ni],
          bpm: s.bpm ?? 120,
        });
        setSavedSnippets(savedSnippetsRef.current);
      }, 66);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setStatus("error: " + msg);
      setOverlay("visible");
      console.error(err);
    }
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
      if (uiTimerRef.current) clearInterval(uiTimerRef.current);
      if (structTimerRef.current) clearInterval(structTimerRef.current);
    };
  }, []);

  return (
    <div id="app">
      <Header status={status} />
      <CameraView videoRef={videoRef} canvasRef={canvasRef}>
        {overlay !== "hidden" && (
          <StartOverlay
            onStart={handleStart}
            fading={overlay === "fading"}
          />
        )}
      </CameraView>
      <Sidebar
        codeHL={uiState.codeHL}
        hydraCodeHL={uiState.hydraCodeHL}
        smoothed={uiState.smoothed}
        hands={uiState.hands}
        noteDisplay={uiState.noteDisplay}
        bpm={uiState.bpm}
        config={config}
        advanced={advanced}
        savedSnippets={savedSnippets}
        playingSet={playingSet}
        onPlaySnippet={handlePlaySnippet}
        track={track}
        trackPlaying={trackPlaying}
        onAddToTrack={handleAddToTrack}
        onRemoveFromTrack={handleRemoveFromTrack}
        onTrackSpeedChange={handleTrackSpeedChange}
        onToggleTrackPlay={handleToggleTrackPlay}
        hydraEnabled={hydraEnabled}
        hydraAvailable={hasHydraMapping(hydraConfig)}
        onHydraToggle={handleHydraToggle}
        onImportSnippets={handleImportSnippets}
      />
    </div>
  );
}
