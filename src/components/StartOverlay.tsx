"use client";

interface StartOverlayProps {
  onStart: () => void;
  fading?: boolean;
}

export default function StartOverlay({ onStart, fading }: StartOverlayProps) {
  return (
    <div id="start" style={fading ? { opacity: 0 } : undefined}>
      <h1>HANDSTRUDEL</h1>
      <button id="start-btn" onClick={onStart}>
        ▶ START
      </button>
      <div className="hint">
        allow camera when prompted
        <br />
        <span className="gl">left hand</span> → pitch · filter · reverb
        <br />
        <span className="gr">right hand</span> → volume · tempo · delay
        <br />
        hands generate &amp; re-evaluate real Strudel code
      </div>
    </div>
  );
}
