# HandStrudel

A browser-based hand-tracking musical instrument. Wave your hands in front of your webcam to control a synthesizer in real time.

**[Live Demo](https://khalildh.github.io/handstrudel/handstrudel.html)**

## How It Works

HandStrudel uses your webcam and [MediaPipe Hands](https://google.github.io/mediapipe/solutions/hands) to track both hands in real time. Hand position and finger spread are mapped to synthesizer parameters powered by [Tone.js](https://tonejs.github.io/):

### Left Hand
- **Pitch** — vertical position selects notes from a pentatonic scale (C3–E5)
- **Filter (LPF)** — horizontal position sweeps a low-pass filter (180–5680 Hz)
- **Reverb** — finger spread controls reverb wet mix

### Right Hand
- **Volume** — vertical position controls gain
- **Tempo** — horizontal position sets BPM (55–195)
- **Delay** — finger spread controls delay wet mix

A step sequencer cycles through rhythmic patterns (tresillo, four-on-the-floor, clave, dense) every 8 seconds, triggering notes based on the current parameters.

## Tech Stack

- **MediaPipe Hands** — real-time hand landmark detection
- **Tone.js** — Web Audio synthesizer, effects chain, and transport
- **Vanilla HTML/CSS/JS** — single-file, no build step

## Running Locally

Open `handstrudel.html` in a browser. Grant camera access when prompted, then wave your hands.
