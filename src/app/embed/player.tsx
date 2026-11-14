"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { isVideoID, loadPublicVideos, mediaURL, type PublicVideo } from "../../lib/public-feed";
import { clipTitle, WatchIcon } from "../watch/watch-design";

export default function EmbeddedPerformance() {
  const id = useSearchParams().get("v")?.toLowerCase() ?? "";
  const valid = isVideoID(id);
  const [result, setResult] = useState<{ id: string; video?: PublicVideo; failed?: boolean }>();
  const video = result?.id === id ? result.video : undefined;
  useEffect(() => {
    if (!valid) return;
    const request = new AbortController();
    loadPublicVideos({ id }, request.signal).then(([video]) => {
      if (!request.signal.aborted) setResult({ id, video });
    }).catch(() => {
      if (!request.signal.aborted) setResult({ id, failed: true });
    });
    return () => request.abort();
  }, [id, valid]);

  return (
    <main className="embed-page">
      {video ? (
        <>
          <video key={video.id} controls playsInline preload="none" aria-label={clipTitle(video)}
            poster={mediaURL(video.thumb_key)} src={mediaURL(video.video_key)} />
          <a href={`https://handstrudel.com/watch?v=${video.id}`} target="_blank" rel="noopener noreferrer">
            <WatchIcon name="wave" />
            <span><strong>{clipTitle(video)}</strong><small>@{video.username} · HandStrudel</small></span>
            <WatchIcon name="arrow" />
          </a>
        </>
      ) : (
        <p role="status">{!valid ? "This performance is unavailable." : result?.id !== id
          ? "Loading performance…" : result.failed ? "Couldn’t load this performance." : "This performance is unavailable."}</p>
      )}
    </main>
  );
}
