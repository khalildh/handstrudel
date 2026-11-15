"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useRef, useState } from "react";
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

  if (video) return <EmbeddedClip key={video.id} video={video} />;

  return (
    <main className="embed-page">
      <p role="status">{!valid ? "This performance is unavailable." : result?.id !== id
        ? "Loading performance…" : result.failed ? "Couldn’t load this performance." : "This performance is unavailable."}</p>
    </main>
  );
}

function EmbeddedClip({ video }: { video: PublicVideo }) {
  const [playbackFailed, setPlaybackFailed] = useState(false);
  const hadPlayerFocus = useRef(false);
  const watchLink = useRef<HTMLAnchorElement>(null);
  const src = mediaURL(video.video_key);
  const unavailable = playbackFailed || !src;
  const title = clipTitle(video);

  useEffect(() => {
    if (playbackFailed && hadPlayerFocus.current) watchLink.current?.focus();
  }, [playbackFailed]);

  return (
    <main className={unavailable ? "embed-page embed-page-recovery" : "embed-page"}>
      {!unavailable && (
        <video controls playsInline preload="none" aria-label={title}
          poster={mediaURL(video.thumb_key)} src={src} onError={({ currentTarget }) => {
            if (!currentTarget.error || currentTarget.error.code === MediaError.MEDIA_ERR_ABORTED) return;
            hadPlayerFocus.current = document.activeElement === currentTarget;
            setPlaybackFailed(true);
          }} />
      )}
      <p className="embed-playback-status" role="status">{unavailable ? "This performance can't play here." : ""}</p>
      <a ref={watchLink} href={`https://handstrudel.com/watch?v=${encodeURIComponent(video.id)}`}
        className={unavailable ? "watch-action watch-primary embed-recovery-link" : undefined}
        target="_blank" rel="noopener noreferrer">
        {unavailable ? "Open on HandStrudel" : (
          <>
            <WatchIcon name="wave" />
            <span><strong>{title}</strong><small>@{video.username} · HandStrudel</small></span>
          </>
        )}
        <WatchIcon name="arrow" />
      </a>
    </main>
  );
}
