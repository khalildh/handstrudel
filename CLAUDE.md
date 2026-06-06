# HandStrudel

Browser-based hand-tracking musical instrument. Webcam hand gestures control live-generated [Strudel](https://strudel.cc) code in real time.

## Quick Start

```bash
npm run dev      # dev server (Next.js 15, React 19)
npm run build    # production build (static export)
```

Deploys as a static site to GitHub Pages at `/handstrudel`.

## Architecture

Single-page app. One root component (`HandStrudel`) owns all state. No routing, no backend.

### Data Flow (60fps hot path)

```
MediaPipe hands → handsRef → mapHandsToParams → paramsRef → smoothParams → smoothedRef
                                                                              ↓
                                                            buildCode → evaluate (Strudel REPL)
```

- **Refs** (`paramsRef`, `smoothedRef`, `handsRef`) are mutated at 60fps in `requestAnimationFrame` — never trigger React re-renders
- **React state** (`uiState`) is synced from refs at ~15fps via `setInterval(66ms)` for sidebar display
- Code is only re-evaluated when `buildCode` output changes (string comparison)

### Mapping System

Users map hand axes to music params via `MappingConfig`:
```
{ left: { y: "noteIdx", x: "lpf", spread: "reverb" }, right: { ... } }
```

- Axes: `y`, `x`, `spread` (basic) + `pinch`, `fist`, `rotation`, `thumbCurl`, `indexCurl`, `middleCurl`, `ringCurl`, `pinkyCurl` (advanced)
- Special values: `"none"` (unmapped), `"save"` (gesture trigger, not a param), `"instrument"` (gesture trigger that cycles the sound)
- `PARAM_DEFS` in `music.ts` defines all musical parameters with ranges, defaults, formatters, and Strudel code generators

### Save Gesture

Axes can be mapped to `"save"` instead of a param. When the axis value crosses > 0.8, it snapshots the current Strudel code. Hysteresis (must drop below 0.3 to re-arm) and debounce (1s minimum) prevent spam.

### Instruments / SoundFonts

The melody's sound source is selectable from `INSTRUMENTS` in `music.ts` — built-in oscillator synths plus General MIDI soundfonts registered by `@strudel/soundfonts` (ids like `gm_acoustic_piano`). Soundfonts share the `s()` namespace and run through the existing effects chain; their sample data lazy-loads from a CDN on first use. The chosen instrument id is threaded through `buildCode`/`buildSignalCode`/`buildCodeHL` and held in `instrumentRef` (mirrored to `instrument` state). It can be picked up front in `StartOverlay`, changed live via the Sidebar dropdown, or cycled by an `"instrument"` gesture axis (same hysteresis/debounce as save). Changing it sets `lastStructKeyRef = ""` to force a live re-eval.

### Snippet Playback

Saved snippets appear in the Sidebar with play/pause buttons. Multiple snippets can play simultaneously via `playingSetRef` (a `Set<number>`). When any snippet is playing, the 60fps loop skips live code evaluation. Stacked snippets are combined with `stack()`. Toggling all snippets off resumes live hand-controlled code (clears `lastCodeRef` to force re-eval).

### Track Sequencer

Saved snippets can be arranged into an ordered track via the Sidebar's track builder. Uses `slowcat()` to play each snippet for one cycle before advancing. Speed control (0.25×–4×) applies `.slow(1/speed)` to the overall pattern. State is in `track` (slots + speed) with a mirrored `trackRef` for the 60fps loop. `trackPlayingRef` gates code evaluation alongside `playingSetRef`. Track and individual snippet playback are mutually exclusive — starting one stops the other. `buildTrackCode()` (module-level helper) generates the Strudel code.

## File Map

```
src/
  app/
    page.tsx          ← Dynamic import of HandStrudel (SSR disabled)
    layout.tsx        ← JetBrains Mono font, metadata
    globals.css       ← All styles (single file, CSS variables)
  components/
    HandStrudel.tsx   ← Root component: 60fps loop, state management, orchestration
    StartOverlay.tsx  ← Pre-session config screen (axis→param mapping dropdowns)
    Sidebar.tsx       ← Code display, param meters, saved snippets
    HandPanel.tsx     ← Per-hand param visualization bars
    Header.tsx        ← Status bar with beat indicator
    CameraView.tsx    ← Video + canvas overlay wrapper
  lib/
    hand-mapping.ts   ← MappingConfig, axis defs, mapHandsToParams, getSaveAxes
    music.ts          ← PARAM_DEFS, buildCode/buildCodeHL, notes, structs
    params.ts         ← buildDefaultParams, smoothParams (EMA α=0.1)
    strudel.ts        ← Strudel REPL initialization (evalScope, webaudio)
    mediapipe.ts      ← MediaPipe Hands setup, landmark→axis computation
    drawing.ts        ← Canvas hand skeleton renderer
  types/
    mediapipe.d.ts    ← MediaPipe global type declarations
    strudel.d.ts      ← Strudel module type declarations
```

## Key Patterns

- **No test suite** — verify changes with `npm run build`
- **All styles in one CSS file** — `globals.css` with `--var` tokens. No CSS modules or Tailwind
- **HTML string templating** — `buildCodeHL` returns syntax-highlighted HTML rendered via `dangerouslySetInnerHTML`
- **MediaPipe loaded via CDN scripts** — not npm packages; loaded dynamically in `mediapipe.ts`
- **Strudel loaded via npm** — `@strudel/*` packages are transpiled by Next.js (see `next.config.ts`)
- **Struct rotation** — musical structure pattern changes every 8s via `setInterval`
- **Mirror camera** — video is CSS `scaleX(-1)`, handedness labels are swapped in `mediapipe.ts`

## Gotchas

- Strudel's `evalScope` must share one `@strudel/core` instance across all packages. This works because they're all npm deps (not CDN ESM imports). See comment in `strudel.ts`
- `output: "export"` in next.config means no API routes or server components
- `basePath` differs between dev (empty) and prod (`/handstrudel`)
