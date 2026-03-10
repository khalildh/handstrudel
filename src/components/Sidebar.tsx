"use client";

import { useState } from "react";
import { MusicParams, PARAM_MAP, NOTES, NOTE_DISPLAY } from "../lib/music";
import { HandsState, MappingConfig } from "../lib/hand-mapping";
import HandPanel from "./HandPanel";
import type { SavedSnippet } from "./HandStrudel";

interface SidebarProps {
  codeHL: string;
  hydraCodeHL: string;
  smoothed: MusicParams;
  hands: HandsState;
  noteDisplay: string;
  bpm: number;
  config: MappingConfig;
  advanced: boolean;
  savedSnippets: SavedSnippet[];
  playingSet: Set<number>;
  onPlaySnippet: (idx: number) => void;
  track: { slots: number[]; speed: number };
  trackPlaying: boolean;
  onAddToTrack: (idx: number) => void;
  onRemoveFromTrack: (slotIdx: number) => void;
  onTrackSpeedChange: (speed: number) => void;
  onToggleTrackPlay: () => void;
  hydraEnabled: boolean;
  hydraAvailable: boolean;
  onHydraToggle: () => void;
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
  hydraCodeHL,
  smoothed,
  hands,
  noteDisplay,
  bpm,
  config,
  advanced,
  savedSnippets,
  playingSet,
  onPlaySnippet,
  track,
  trackPlaying,
  onAddToTrack,
  onRemoveFromTrack,
  onTrackSpeedChange,
  onToggleTrackPlay,
  hydraEnabled,
  hydraAvailable,
  onHydraToggle,
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

      {hydraCodeHL && (
        <div id="hydra-code-wrap">
          <div className="c-comment">{"// live-generated hydra"}</div>
          <div
            id="hydra-code-display"
            dangerouslySetInnerHTML={{ __html: hydraCodeHL }}
          />
        </div>
      )}

      {hydraAvailable && (
        <div className="hydra-toggle">
          <span className="hydra-label">HYDRA</span>
          <button
            className={`hydra-btn${hydraEnabled ? " hydra-btn-active" : ""}`}
            onClick={onHydraToggle}
          >
            {hydraEnabled ? "on" : "off"}
          </button>
        </div>
      )}

      {savedSnippets.length > 0 && (
        <div className="saved-list">
          <div className="saved-title">💾 SAVED</div>
          {savedSnippets.map((s, i) => (
            <div
              key={s.timestamp}
              className={`saved-item${copiedIdx === i ? " saved-item-copied" : ""}${playingSet.has(i) ? " saved-item-playing" : ""}`}
              title={s.code}
            >
              <button
                className="saved-play"
                onClick={() => onPlaySnippet(i)}
              >
                {playingSet.has(i) ? "⏸" : "▶"}
              </button>
              <button
                className="saved-add-track"
                onClick={(e) => { e.stopPropagation(); onAddToTrack(i); }}
                title="Add to track"
              >
                +
              </button>
              <span className="saved-bpm">{s.bpm}</span>
              <span className="saved-code" onClick={() => handleCopy(s.code, i)}>
                {s.code.split("\n")[0]}
              </span>
            </div>
          ))}
        </div>
      )}

      {savedSnippets.length > 0 && (
        <div className="track-builder">
          <div className="track-header">
            <span className="track-title">▦ TRACK</span>
            <button
              className={`track-play${trackPlaying ? " track-play-active" : ""}`}
              onClick={onToggleTrackPlay}
              disabled={track.slots.length === 0}
            >
              {trackPlaying ? "⏹" : "▶"}
            </button>
            <input
              type="range"
              className="track-speed"
              min={0.25}
              max={4}
              step={0.25}
              value={track.speed}
              onChange={(e) => onTrackSpeedChange(parseFloat(e.target.value))}
            />
            <span className="track-speed-label">{track.speed}×</span>
          </div>
          {track.slots.length > 0 && (
            <div className="track-slots">
              {track.slots.map((snippetIdx, slotIdx) => (
                <div key={slotIdx} className="track-slot" title={savedSnippets[snippetIdx]?.code.split("\n")[0] ?? ""}>
                  <span className="track-slot-num">{snippetIdx + 1}</span>
                  <button
                    className="track-slot-remove"
                    onClick={() => onRemoveFromTrack(slotIdx)}
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          )}
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
