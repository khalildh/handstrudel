"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { isVideoID, loadPublicVideos, mediaURL, PAGE_SIZE, type PublicVideo } from "../../lib/public-feed";
import WatchComments from "./watch-comments";

export default function WatchFeed() {
  const router = useRouter();
  const id = useSearchParams().get("v")?.toLowerCase();
  const [videos, setVideos] = useState<PublicVideo[]>([]);
  const [shared, setShared] = useState<{ id: string; video?: PublicVideo; error?: boolean }>();
  const [loading, setLoading] = useState(true);
  const [more, setMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);
  const [playOnSelect, setPlayOnSelect] = useState(false);
  const player = useRef<HTMLVideoElement>(null);
  const stage = useRef<HTMLElement>(null);
  const listed = videos.find((video) => video.id === id);
  const selected = id ? listed ?? (shared?.id === id ? shared.video : undefined) : videos[0];
  const resolving = id && isVideoID(id) && !listed && shared?.id !== id;
  const setup = selected?.sound_setup?.version === 1 ? selected.sound_setup : null;
  const presetDetails = [
    selected?.instrument,
    typeof setup?.key === "string" && typeof setup.scale === "string" ? `${setup.key} ${setup.scale}` : null,
    typeof setup?.bpm === "number" && setup.bpm >= 20 && setup.bpm <= 400 ? `${Math.round(setup.bpm)} BPM` : null,
  ].filter(Boolean).join(" · ");

  useEffect(() => {
    const request = new AbortController();
    loadPublicVideos({}, request.signal).then((items) => {
      if (request.signal.aborted) return;
      setVideos(items);
      setMore(items.length === PAGE_SIZE);
      setLoading(false);
    }).catch(() => {
      if (request.signal.aborted) return;
      setError("Couldn't load performances.");
      setLoading(false);
    });
    return () => request.abort();
  }, [attempt]);

  useEffect(() => {
    if (!id || !isVideoID(id) || listed) return;
    const request = new AbortController();
    loadPublicVideos({ id }, request.signal).then(([video]) => {
      if (!request.signal.aborted) setShared({ id, video });
    }).catch(() => {
      if (!request.signal.aborted) setShared({ id, error: true });
    });
    return () => request.abort();
  }, [id, listed, attempt]);

  useEffect(() => {
    if (playOnSelect) void player.current?.play().catch(() => {});
  }, [selected?.id, playOnSelect]);

  function retry() {
    setError("");
    setLoading(true);
    setShared(undefined);
    setAttempt((count) => count + 1);
  }

  async function loadMore() {
    if (loadingMore || !videos.length) return;
    setLoadingMore(true);
    setError("");
    try {
      const items = await loadPublicVideos({ after: videos[videos.length - 1] });
      setVideos((previous) => {
        const seen = new Set(previous.map((video) => video.id));
        return [...previous, ...items.filter((video) => !seen.has(video.id))];
      });
      setMore(items.length === PAGE_SIZE);
    } catch {
      setError("Couldn't load more performances.");
    } finally {
      setLoadingMore(false);
    }
  }

  function choose(video: PublicVideo) {
    if (video.id === selected?.id) void player.current?.play().catch(() => {});
    setPlayOnSelect(true);
    router.push(`/watch?v=${video.id}`, { scroll: false });
    if (stage.current && stage.current.getBoundingClientRect().top < 0) {
      stage.current.scrollIntoView({ block: "start" });
    }
  }

  return (
    <main className="watch-page">
      <header className="watch-top">
        <Link className="watch-wordmark" href="/">hand<strong>strudel</strong></Link>
        <Link className="watch-action" href="/">Make music <span aria-hidden="true">↗</span></Link>
      </header>
      <div className="watch-heading"><h1>Performances</h1></div>
      <div className="watch-grid">
        <section ref={stage} className="watch-stage" aria-label="Video player">
          {selected ? (
            <>
              <video
                key={selected.id}
                ref={player}
                controls
                playsInline
                preload="metadata"
                poster={mediaURL(selected.thumb_key)}
                src={mediaURL(selected.video_key)}
                aria-label={`Performance by @${selected.username}`}
              />
              <div className="watch-caption">
                <h2>@{selected.username}</h2>
                {selected.caption && <p>{selected.caption}</p>}
                {selected.source_video_id && selected.source_username && isVideoID(selected.source_video_id) && (
                  <Link href={`/watch?v=${selected.source_video_id}`}>Inspired by @{selected.source_username}</Link>
                )}
                {presetDetails && <span>{presetDetails}</span>}
                {isVideoID(selected.id) && (selected.backing_enabled || setup) && (
                  <div className="watch-sound-actions">
                    {setup && <a className="watch-action" href={`handstrudel://sound/${selected.id}`}>Play this sound in the app</a>}
                    {selected.backing_enabled && <a className="watch-action" href={`handstrudel://play/${selected.id}`}>Play along</a>}
                    <a href="https://apps.apple.com/app/id6764415289">Get the iOS app</a>
                  </div>
                )}
              </div>
              <WatchComments key={selected.id} video={selected} />
            </>
          ) : (
            <div className="watch-state" role="status">
              <span aria-hidden="true">▶</span>
              <h2>{resolving || (!id && loading) ? "Loading performances…" : id
                ? shared?.error ? "Couldn't load this performance" : "This performance is unavailable"
                : error || "No public performances yet"}</h2>
              {id && !resolving && <Link href="/watch">Browse all performances</Link>}
              {(shared?.error || error) && !loading && <button type="button" onClick={retry}>Try again</button>}
            </div>
          )}
        </section>
        <section className="watch-list" aria-label="Latest videos">
          <h2>Latest videos</h2>
          {videos.map((video) => (
            <button key={video.id} type="button" className="watch-clip" onClick={() => choose(video)}
                    aria-current={video.id === selected?.id ? "true" : undefined}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={mediaURL(video.thumb_key)} alt="" loading="lazy" />
              <span className="watch-clip-text">
                <strong>@{video.username}</strong>
                <span>{video.caption || video.instrument || "Performance"}</span>
              </span>
              {video.duration_s ? <small>{Math.ceil(video.duration_s)}s</small> : null}
            </button>
          ))}
          {loading && <p role="status">Loading videos…</p>}
          {error && videos.length > 0 && <p role="status">{error}</p>}
          {more && <button className="watch-action" type="button" onClick={loadMore} disabled={loadingMore}>
            {loadingMore ? "Loading…" : "Load more"}
          </button>}
        </section>
      </div>
      <footer className="watch-footer">
        <Link href="/community">Community Guidelines</Link>
        <a href="mailto:hello@handstrudel.com">Report a video</a>
      </footer>
    </main>
  );
}
