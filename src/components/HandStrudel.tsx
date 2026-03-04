"use client";

import { useRef, useState, useCallback, useEffect } from "react";
import {
  MusicParams,
  buildCode,
  buildCodeHL,
  NOTES,
  NOTE_DISPLAY,
  STRUCTS,
} from "../lib/music";
import { buildDefaultParams, smoothParams } from "../lib/params";
import {
  HandsState,
  MappingConfig,
  DEFAULT_MAPPING,
  mapHandsToParams,
} from "../lib/hand-mapping";
import { initializeStrudel } from "../lib/strudel";
import { initializeMediaPipe } from "../lib/mediapipe";
import StartOverlay from "./StartOverlay";
import Header from "./Header";
import Sidebar from "./Sidebar";
import CameraView from "./CameraView";

interface UIState {
  codeHL: string;
  smoothed: MusicParams;
  hands: HandsState;
  noteDisplay: string;
  bpm: number;
}

export default function HandStrudel() {
  const [overlay, setOverlay] = useState<"visible" | "fading" | "hidden">(
    "visible",
  );
  const [status, setStatus] = useState("click start");
  const [config, setConfig] = useState<MappingConfig>(DEFAULT_MAPPING);

  const defaults = buildDefaultParams(DEFAULT_MAPPING);
  const defaultNI = Math.round(defaults.noteIdx ?? 10);
  const [uiState, setUiState] = useState<UIState>({
    codeHL: buildCodeHL(defaults, 0, DEFAULT_MAPPING),
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
  const structIdxRef = useRef(0);
  const lastCodeRef = useRef("");
  const evaluateRef = useRef<
    ((code: string) => Promise<unknown>) | null
  >(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const lastBeatRef = useRef(-1);

  // DOM refs
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Cleanup refs
  const animFrameRef = useRef(0);
  const uiTimerRef = useRef(0);
  const structTimerRef = useRef(0);

  const handleStart = useCallback(async (cfg: MappingConfig) => {
    setConfig(cfg);
    configRef.current = cfg;

    // Reset params for chosen config
    const defs = buildDefaultParams(cfg);
    paramsRef.current = { ...defs };
    smoothedRef.current = { ...defs };

    // Fade out overlay
    setOverlay("fading");
    setTimeout(() => setOverlay("hidden"), 300);

    setStatus("initialising strudel…");

    try {
      const { evaluate, audioCtx } = await initializeStrudel();
      evaluateRef.current = evaluate;
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
        () => mapHandsToParams(handsRef.current, paramsRef.current, configRef.current),
      );

      setStatus("running — wave your hands");

      // Rotate struct every 8s
      structTimerRef.current = window.setInterval(() => {
        structIdxRef.current =
          (structIdxRef.current + 1) % STRUCTS.length;
      }, 8000);

      // 60fps animation loop
      const loop = () => {
        smoothParams(paramsRef.current, smoothedRef.current);
        mapHandsToParams(handsRef.current, paramsRef.current, configRef.current);

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

        // Eval on change
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
          smoothed: s,
          hands: { ...handsRef.current },
          noteDisplay: NOTE_DISPLAY[ni],
          bpm: s.bpm ?? 120,
        });
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
        smoothed={uiState.smoothed}
        hands={uiState.hands}
        noteDisplay={uiState.noteDisplay}
        bpm={uiState.bpm}
        config={config}
      />
    </div>
  );
}
