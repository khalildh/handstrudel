"use client";

import { useState } from "react";
import { MusicParams, PARAM_MAP, NOTES, NOTE_DISPLAY } from "../lib/music";
import { HandsState, MappingConfig } from "../lib/hand-mapping";
import HandPanel from "./HandPanel";
import type { SavedSnippet } from "./HandStrudel";

interface SidebarProps {
  codeHL: string;
  smoothed: MusicParams;
  hands: HandsState;
  noteDisplay: string;
  bpm: number;
  config: MappingConfig;
  advanced: boolean;
  savedSnippets: SavedSnippet[];
  playingIdx: number | null;
  onPlaySnippet: (idx: number) => void;
}

function paramRow(id: string, value: number) {
  const def = PARAM_MAP[id];
  if (!def) return { label: id, fraction: 0, value: "?" };
  const fraction = (value - def.min) / (def.max - def.min);
  return { label: def.label, fraction, value: def.format(value) };
}

function buildParamRows(sideConfig: Record<string, string>, smoothed: MusicParams) {
  return Object.entries(sideConfig)
    .filter(([, paramId]) => paramId !== "none" && paramId !== "save")
    .map(([, paramId]) => paramRow(paramId, smoothed[paramId] ?? 0));
}

export default function Sidebar({
  codeHL,
  smoothed,
  hands,
  noteDisplay,
  bpm,
  config,
  advanced,
  savedSnippets,
  playingIdx,
  onPlaySnippet,
}: SidebarProps) {
  const [copiedIdx, setCopiedIdx] = useState<number | null>(null);

  const handleCopy = (code: string, idx: number) => {
    navigator.clipboard.writeText(code).then(() => {
      setCopiedIdx(idx);
      setTimeout(() => setCopiedIdx(null), 600);
    });
  };

  return (
    <div id="sidebar">
      <div id="code-wrap">
        <div className="c-comment">{"// live-generated strudel"}</div>
        <div
          id="code-display"
          dangerouslySetInnerHTML={{ __html: codeHL }}
        />
      </div>

      {savedSnippets.length > 0 && (
        <div className="saved-list">
          <div className="saved-title">💾 SAVED</div>
          {savedSnippets.map((s, i) => (
            <div
              key={s.timestamp}
              className={`saved-item${copiedIdx === i ? " saved-item-copied" : ""}${playingIdx === i ? " saved-item-playing" : ""}`}
              title={s.code}
            >
              <button
                className="saved-play"
                onClick={() => onPlaySnippet(i)}
              >
                {playingIdx === i ? "⏸" : "▶"}
              </button>
              <span className="saved-code" onClick={() => handleCopy(s.code, i)}>
                {s.code.split("\n")[0]}
              </span>
            </div>
          ))}
        </div>
      )}

      <HandPanel
        side="left"
        detected={hands.left !== null}
        params={buildParamRows(config.left, smoothed)}
        compact={advanced}
      />

      <HandPanel
        side="right"
        detected={hands.right !== null}
        params={buildParamRows(config.right, smoothed)}
        compact={advanced}
      />

      <div id="bottom">
        <div id="cur-note">{noteDisplay}</div>
        <div id="cur-bpm">{Math.round(bpm)} bpm</div>
      </div>
    </div>
  );
}
