# HandStrudel

A hand-tracking musical instrument for web and iOS. Wave your hands to control a live synthesizer in real time.

**[handstrudel.com](https://handstrudel.com)** — try it now in your browser

## How It Works

HandStrudel uses your camera and hand tracking to detect both hands in real time. Hand gestures are mapped to synthesizer parameters powered by [Strudel](https://strudel.cc/).

### Web App
- Works in any modern browser with a webcam
- [MediaPipe Hands](https://google.github.io/mediapipe/solutions/hands) for hand tracking
- Configurable axis-to-parameter mapping (pitch, filter, reverb, tempo, delay, and more)
- Save gesture snapshots, stack snippets, and arrange tracks

### iOS App
- Native SwiftUI app with Apple Vision hand tracking
- Full-screen portrait camera with glowing neon hand skeleton overlay
- 4 preset vibes: Dreamy, Gritty, Bouncy, Chill
- Synth waveform selection (sine, square, triangle, sawtooth)
- Dual drum tracks with volume and speed control
- 7-second screen recording with Instagram Stories/Reels sharing
- Lockable manual parameter overrides

## Tech Stack

**Web:**
- [Strudel](https://strudel.cc/) — live-coded music patterns
- [MediaPipe Hands](https://google.github.io/mediapipe/solutions/hands) — hand landmark detection
- [Next.js](https://nextjs.org/) — static export
- TypeScript

**iOS:**
- SwiftUI + Apple Vision framework
- WKWebView running Strudel (hybrid architecture)
- AVCaptureSession + CADisplayLink (60fps)
- ReplayKit for screen recording

## Development

```bash
# Web
npm install
npm run dev

# iOS
cd ios/HandStrudel
xcodegen generate
open HandStrudel.xcodeproj
```

## Links

- **Web:** [handstrudel.com](https://handstrudel.com)
- **GitHub:** [github.com/khalildh/handstrudel](https://github.com/khalildh/handstrudel)
