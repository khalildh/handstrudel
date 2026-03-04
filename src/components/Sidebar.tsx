"use client";

import { MusicParams, NOTES, NOTE_DISPLAY } from "../lib/music";
import { HandsState } from "../lib/hand-mapping";
import HandPanel from "./HandPanel";

interface SidebarProps {
  codeHL: string;
  smoothed: MusicParams;
  hands: HandsState;
  noteDisplay: string;
  bpm: number;
}

export default function Sidebar({
  codeHL,
  smoothed,
  hands,
  noteDisplay,
  bpm,
}: SidebarProps) {
  const ni = Math.max(
    0,
    Math.min(NOTES.length - 1, Math.round(smoothed.noteIdx)),
  );

  return (
    <div id="sidebar">
      <div id="code-wrap">
        <div className="c-comment">{"// live-generated strudel"}</div>
        <div
          id="code-display"
          dangerouslySetInnerHTML={{ __html: codeHL }}
        />
      </div>

      <HandPanel
        side="left"
        detected={hands.left !== null}
        params={[
          {
            label: "pitch",
            fraction: smoothed.noteIdx / (NOTES.length - 1),
            value: NOTE_DISPLAY[ni],
          },
          {
            label: "lpf",
            fraction: (smoothed.lpf - 120) / 6000,
            value: Math.round(smoothed.lpf) + "hz",
          },
          {
            label: "reverb",
            fraction: smoothed.reverb / 0.9,
            value: smoothed.reverb.toFixed(2),
          },
        ]}
      />

      <HandPanel
        side="right"
        detected={hands.right !== null}
        params={[
          {
            label: "gain",
            fraction: smoothed.gain / 0.9,
            value: smoothed.gain.toFixed(2),
          },
          {
            label: "bpm",
            fraction: (smoothed.bpm - 50) / 155,
            value: Math.round(smoothed.bpm) + " bpm",
          },
          {
            label: "delay",
            fraction: smoothed.delay / 0.55,
            value: smoothed.delay.toFixed(2),
          },
        ]}
      />

      <div id="bottom">
        <div id="cur-note">{noteDisplay}</div>
        <div id="cur-bpm">{Math.round(bpm)} bpm</div>
      </div>
    </div>
  );
}
