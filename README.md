# HandStrudel

A browser-based hand-tracking musical instrument. Wave your hands in front of your webcam to control a live-coded synthesizer in real time.

**[Live Demo](https://khalildh.github.io/handstrudel/)**

## How It Works

HandStrudel uses your webcam and [MediaPipe Hands](https://google.github.io/mediapipe/solutions/hands) to track both hands in real time. Hand position and finger spread are mapped to synthesizer parameters powered by [Strudel](https://strudel.cc/):

### Left Hand
- **Pitch** — vertical position selects notes from a pentatonic scale (C2–E5)
- **Filter (LPF)** — horizontal position sweeps a low-pass filter (120–6120 Hz)
- **Reverb** — finger spread controls reverb wet mix

### Right Hand
- **Volume** — vertical position controls gain
- **Tempo** — horizontal position sets BPM (50–205)
- **Delay** — finger spread controls delay wet mix

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

Open [http://localhost:3000/handstrudel](http://localhost:3000/handstrudel), grant camera access, and wave your hands.

## Build & Deploy

```bash
npm run build    # outputs to out/
npx serve out    # preview the static build locally
```

Pushing to `main` triggers GitHub Actions to build and deploy to GitHub Pages automatically.
