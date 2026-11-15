"use client";

import Link from "next/link";
import { WatchIcon } from "../app/watch/watch-design";
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
  studioLive: boolean;
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
  studioLive,
  onToggleSidebar,
}: HeaderProps) {
  return (
    <header id="header">
      <Link className="watch-wordmark" href="/" aria-label="HandStrudel home">
        <span className="watch-brand-mark"><WatchIcon name="wave" /></span>handstrudel
      </Link>
      <span className="studio-header-tag">WEB STUDIO</span>
      {studioLive && <span id="status"><span className="studio-live-dot" />{status}</span>}
      <nav className="studio-nav" aria-label="Main navigation">
        <Link href="/watch">Watch</Link>
      </nav>

      {canRecord && (
        <div id="rec-controls">
          {!recording && (
            <select
              className="rec-aspect"
              value={recordingAspect}
              onChange={(e) => onAspectChange(e.target.value as AspectRatio)}
              aria-label="Video aspect ratio"
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

      {studioLive && <div id="beat-row" aria-hidden="true">
        <div className="bd" id="bd0" />
        <div className="bd" id="bd1" />
        <div className="bd" id="bd2" />
        <div className="bd" id="bd3" />
      </div>}

      {onToggleSidebar && (
        <button
          className="sidebar-toggle"
          onClick={onToggleSidebar}
          aria-label={sidebarOpen ? "Hide panel" : "Show panel"}
          aria-expanded={sidebarOpen}
        >
          <span aria-hidden="true">{sidebarOpen ? "Close" : "Panel"}</span>
        </button>
      )}
    </header>
  );
}
