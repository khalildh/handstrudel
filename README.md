# HandStrudel

A browser-based hand-tracking musical instrument. Wave your hands in front of your webcam to control a live-coded synthesizer in real time.

**[Live Demo](https://khalildh.github.io/handstrudel/)**

## How It Works

HandStrudel uses your webcam and [MediaPipe Hands](https://google.github.io/mediapipe/solutions/hands) to track both hands in real time. Hand gestures are mapped to synthesizer parameters powered by [Strudel](https://strudel.cc/).

### Configurable Mapping

Before starting, a config screen lets you assign any hand axis to any music parameter for each hand:

- **Basic axes** — vertical position, horizontal position, finger spread
- **Advanced axes** — pinch, fist, rotation, thumb/index/middle/ring/pinky curl

Available parameters include note selection, low-pass filter, reverb, volume, tempo, delay, distortion, pan, vowel filter, octave, pattern density, chord size, and more.

### Save & Playback

Any axis can be mapped to a **save gesture** — when the gesture crosses a threshold, the current Strudel code is snapshotted. Saved snippets appear in the sidebar with play/pause buttons to replay them independently of live hand control.

A step sequencer cycles through rhythmic patterns every 8 seconds, triggering notes based on the current parameters. The generated Strudel code is displayed live in the sidebar.

## Tech Stack

- **[Strudel](https://strudel.cc/)** — live-coded music patterns via `@strudel/core`, `@strudel/mini`, `@strudel/tonal`, `@strudel/webaudio`
- **[MediaPipe Hands](https://google.github.io/mediapipe/solutions/hands)** — real-time hand landmark detection (loaded via CDN)
- **[Next.js](https://nextjs.org/)** — React framework with static export for GitHub Pages
- **TypeScript** — type-safe throughout

## Development

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000), grant camera access, and wave your hands.

## Build & Deploy

```bash
npm run build    # outputs to out/
npx serve out    # preview the static build locally
```

Pushing to `main` triggers GitHub Actions to build and deploy to GitHub Pages automatically.
