export default function Support() {
  return (
    <div style={{ maxWidth: 700, margin: '0 auto', padding: '40px 20px', fontFamily: 'system-ui', color: '#fff', background: '#000', minHeight: '100vh' }}>
      <h1 style={{ color: '#00ff9d' }}>Support</h1>

      <h2>Getting Started</h2>
      <p>HandStrudel uses your camera to track your hands and turn gestures into music.</p>
      <ol>
        <li>Pick a vibe (Dreamy, Gritty, Bouncy, or Chill)</li>
        <li>Tap LET&apos;S GO</li>
        <li>Wave your hands in front of the camera</li>
        <li>Move up/down for pitch, spread fingers for effects</li>
      </ol>

      <h2>Modes</h2>
      <ul>
        <li><strong>Melodic</strong> — Continuous synth controlled by hand position</li>
        <li><strong>Grid</strong> — Pinch to play individual notes on a visual grid</li>
        <li><strong>Drums</strong> — Tap drum pads or use hand velocity for air drumming</li>
      </ul>

      <h2>Tips</h2>
      <ul>
        <li>In Grid mode, hold up 1-5 fingers on your free hand to change octave</li>
        <li>Swipe left/right to change camera filters</li>
        <li>Shake your phone to randomize settings</li>
        <li>Use the red circle button to record loops and layer them</li>
        <li>Say &quot;Hey Siri, start dreamy in HandStrudel&quot;</li>
      </ul>

      <h2>Contact</h2>
      <p>Need help? Email us at <a href="mailto:support@handstrudel.com" style={{ color: '#00ff9d' }}>support@handstrudel.com</a></p>

      <h2>Report a Bug</h2>
      <p>Found a bug? Open an issue on <a href="https://github.com/khalildh/handstrudel/issues" style={{ color: '#00ff9d' }}>GitHub</a></p>
    </div>
  );
}
