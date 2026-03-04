"use client";

import { MusicParams, PARAM_MAP, NOTES, NOTE_DISPLAY } from "../lib/music";
import { HandsState, MappingConfig } from "../lib/hand-mapping";
import HandPanel from "./HandPanel";

interface SidebarProps {
  codeHL: string;
  smoothed: MusicParams;
  hands: HandsState;
  noteDisplay: string;
  bpm: number;
  config: MappingConfig;
}

function paramRow(id: string, value: number) {
  const def = PARAM_MAP[id];
  if (!def) return { label: id, fraction: 0, value: "?" };
  const fraction = (value - def.min) / (def.max - def.min);
  return { label: def.label, fraction, value: def.format(value) };
}

export default function Sidebar({
  codeHL,
  smoothed,
  hands,
  noteDisplay,
  bpm,
  config,
}: SidebarProps) {
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
          paramRow(config.left.y, smoothed[config.left.y] ?? 0),
          paramRow(config.left.x, smoothed[config.left.x] ?? 0),
          paramRow(config.left.spread, smoothed[config.left.spread] ?? 0),
        ]}
      />

      <HandPanel
        side="right"
        detected={hands.right !== null}
        params={[
          paramRow(config.right.y, smoothed[config.right.y] ?? 0),
          paramRow(config.right.x, smoothed[config.right.x] ?? 0),
          paramRow(config.right.spread, smoothed[config.right.spread] ?? 0),
        ]}
      />

      <div id="bottom">
        <div id="cur-note">{noteDisplay}</div>
        <div id="cur-bpm">{Math.round(bpm)} bpm</div>
      </div>
    </div>
  );
}
