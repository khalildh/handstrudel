"use client";

import Link from "next/link";
import { useRef, useState } from "react";
import { WatchIcon } from "./watch/watch-design";

function StudioArtwork() {
  return (
    <svg className="home-studio-art" viewBox="0 0 620 580" preserveAspectRatio="xMidYMid slice" fill="none" aria-hidden="true">
      <defs>
        <pattern id="home-studio-grid" width="21" height="21" patternUnits="userSpaceOnUse">
          <circle cx="1" cy="1" r="0.9" fill="#3850bf" opacity=".31" />
        </pattern>
        <linearGradient id="home-studio-wave">
          <stop stopColor="#3c53dc" stopOpacity="0" />
          <stop offset=".29" stopColor="#3c53dc" />
          <stop offset=".76" stopColor="#3547c2" />
          <stop offset="1" stopColor="#3547c2" stopOpacity="0" />
        </linearGradient>
      </defs>
      <rect width="620" height="580" fill="url(#home-studio-grid)" />
      <circle cx="442" cy="202" r="111" fill="#e4eea1" />
      <circle cx="442" cy="202" r="128" stroke="#3a51bf" opacity=".36" strokeDasharray="2 8" />
      <circle cx="442" cy="202" r="145" stroke="#3a51bf" opacity=".18" />
      {Array.from({ length: 16 }, (_, i) => (
        <path key={i} d={`M-105 ${301 + i * 10} C 98 ${376 - i * 2}, 147 ${73 + i * 13}, 308 ${208 + i * 7} S 483 ${575 - i * 12}, 728 ${233 + i * 6}`}
          stroke="url(#home-studio-wave)" strokeWidth={i % 4 === 0 ? 1.5 : 1} opacity={.45 + .018 * i} />
      ))}
    </svg>
  );
}

export function HomePreview({ poster, video, watchUrl }: { poster: string; video: string; watchUrl: string }) {
  const player = useRef<HTMLVideoElement>(null);
  const [playing, setPlaying] = useState(false);
  const [failed, setFailed] = useState(false);

  async function togglePlayback() {
    const clip = player.current;
    if (!clip) return;
    if (!clip.paused && !clip.ended) {
      clip.pause();
      return;
    }
    try { await clip.play(); }
    catch (error) {
      if (!(error instanceof DOMException && error.name === "AbortError")) setFailed(true);
    }
  }

  return (
    <figure className="home-preview" aria-label="Dreamy Piano preview">
      <div className="home-stage">
        <StudioArtwork />
        <div className="home-stage-index"><span /><span>STUDIO STUDY<br /><strong>01 / PIANO</strong></span></div>
        <div className="home-phone">
          <video
            ref={player}
            src={video}
            poster={poster}
            preload="none"
            playsInline
            aria-label="HandStrudel iPhone demo, with piano audio"
            onPlay={() => setPlaying(true)}
            onPause={() => setPlaying(false)}
            onEnded={() => setPlaying(false)}
            onError={() => setFailed(true)}
          />
        </div>
        <span className="home-stage-label"><WatchIcon name="wave" /> iPHONE APP PREVIEW</span>
      </div>
      <figcaption className="home-preview-controls">
        <div className="home-preview-title"><Link href={watchUrl}>Dreamy Piano</Link><span>C major <span aria-hidden="true">·</span> 84 BPM</span></div>
        {failed ? (
          <Link className="home-demo-control" href={watchUrl}>Watch demo <WatchIcon name="arrow" /></Link>
        ) : (
          <button className="home-demo-control" type="button" onClick={togglePlayback}>
            {playing ? (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5h3v14H8zm5 0h3v14h-3z" /></svg>
            ) : <WatchIcon name="play" />}
            {playing ? "Pause demo" : "Play demo"}
          </button>
        )}
      </figcaption>
    </figure>
  );
}
