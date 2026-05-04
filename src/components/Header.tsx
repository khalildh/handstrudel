"use client";

import { AspectRatio } from "../lib/recorder";

interface HeaderProps {
  status: string;
  canRecord: boolean;
  recording: boolean;
  recordingTime: number;
  recordingAspect: AspectRatio;
  onToggleRecording: () => void;
  onAspectChange: (aspect: AspectRatio) => void;
  sidebarOpen?: boolean;
  onToggleSidebar?: () => void;
}

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

const ASPECT_LABELS: Record<AspectRatio, string> = {
  "16:9": "16:9",
  "9:16": "9:16",
  "1:1": "1:1",
};

export default function Header({
  status,
  canRecord,
  recording,
  recordingTime,
  recordingAspect,
  onToggleRecording,
  onAspectChange,
  sidebarOpen,
  onToggleSidebar,
}: HeaderProps) {
  return (
    <div id="header">
      <span className="logo">HANDSTRUDEL</span>
      <span className="sep">|</span>
      <span id="status">{status}</span>

      {canRecord && (
        <div id="rec-controls">
          {!recording && (
            <select
              className="rec-aspect"
              value={recordingAspect}
              onChange={(e) => onAspectChange(e.target.value as AspectRatio)}
              title="Video aspect ratio"
            >
              {(Object.keys(ASPECT_LABELS) as AspectRatio[]).map((a) => (
                <option key={a} value={a}>
                  {ASPECT_LABELS[a]}
                </option>
              ))}
            </select>
          )}
          <button
            className={`rec-btn${recording ? " rec-btn-active" : ""}`}
            onClick={onToggleRecording}
            title={recording ? "Stop recording" : "Start recording"}
          >
            <span className="rec-dot" />
            {recording ? formatTime(recordingTime) : "REC"}
          </button>
        </div>
      )}

      <div id="beat-row">
        <div className="bd" id="bd0" />
        <div className="bd" id="bd1" />
        <div className="bd" id="bd2" />
        <div className="bd" id="bd3" />
      </div>

      {onToggleSidebar && (
        <button
          className="sidebar-toggle"
          onClick={onToggleSidebar}
          aria-label={sidebarOpen ? "Hide panel" : "Show panel"}
          aria-expanded={sidebarOpen}
        >
          {sidebarOpen ? "×" : "≡"}
        </button>
      )}
    </div>
  );
}
