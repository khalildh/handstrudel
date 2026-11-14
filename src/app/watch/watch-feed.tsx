"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { creatorHref, isVideoID, loadPublicVideos, mediaURL, PAGE_SIZE, postSearch, type PublicVideo } from "../../lib/public-feed";
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
  const [input, setInput] = useState("");
  const [search, setSearch] = useState<ReturnType<typeof postSearch>>(null);
  const [searchHint, setSearchHint] = useState(false);
  const [playOnSelect, setPlayOnSelect] = useState(false);
  const player = useRef<HTMLVideoElement>(null);
  const stage = useRef<HTMLElement>(null);
  const paging = useRef<AbortController | null>(null);
  const listed = videos.find((video) => video.id === id);
  const selected = id ? listed ?? (shared?.id === id ? shared.video : undefined) : videos[0];
  const resolving = id && isVideoID(id) && !listed && shared?.id !== id;
  const setup = selected?.sound_setup?.version === 1 ? selected.sound_setup : null;
  const author = selected ? creatorHref(selected.username) : null;
  const presetDetails = [
    selected?.instrument,
    typeof setup?.key === "string" && typeof setup.scale === "string" ? `${setup.key} ${setup.scale}` : null,
    typeof setup?.bpm === "number" && setup.bpm >= 20 && setup.bpm <= 400 ? `${Math.round(setup.bpm)} BPM` : null,
  ].filter(Boolean).join(" · ");

  useEffect(() => {
    const request = new AbortController();
    loadPublicVideos({ search }, request.signal).then((items) => {
      if (request.signal.aborted) return;
      setVideos(items);
      setMore(items.length === PAGE_SIZE);
      setLoading(false);
    }).catch(() => {
      if (request.signal.aborted) return;
      setError("Couldn't load performances.");
      setLoading(false);
    });
    return () => {
      request.abort();
      paging.current?.abort();
    };
  }, [attempt, search]);

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
    paging.current?.abort();
    setLoadingMore(false);
    setError("");
    setLoading(true);
    setShared(undefined);
    setAttempt((count) => count + 1);
  }

  function changeSearch(next: ReturnType<typeof postSearch>) {
    if (next?.filter === search?.filter) return;
    paging.current?.abort();
    setLoadingMore(false);
    setLoading(true);
    setMore(false);
    setError("");
    setVideos([]);
    setPlayOnSelect(false);
    setSearch(next);
  }

  function submitSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const next = postSearch(input);
    const invalid = input.trim().length > 0 && !next;
    setSearchHint(invalid);
    if (!invalid) changeSearch(next);
  }

  async function loadMore() {
    if (loadingMore || !videos.length) return;
    const request = new AbortController();
    paging.current?.abort();
    paging.current = request;
    setLoadingMore(true);
    setError("");
    try {
      const items = await loadPublicVideos({ after: videos[videos.length - 1], search }, request.signal);
      if (request.signal.aborted) return;
      setVideos((previous) => {
        const seen = new Set(previous.map((video) => video.id));
        return [...previous, ...items.filter((video) => !seen.has(video.id))];
      });
      setMore(items.length === PAGE_SIZE);
    } catch {
      if (!request.signal.aborted) setError("Couldn't load more performances.");
    } finally {
      if (paging.current === request) {
        paging.current = null;
        if (!request.signal.aborted) setLoadingMore(false);
      }
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
      <form className="watch-search" role="search" onSubmit={submitSearch}>
        <input aria-label="Search posts" type="search" placeholder="Caption, instrument, or @creator"
               value={input} maxLength={120} onChange={(event) => {
                 const value = event.target.value;
                 setInput(value);
                 setSearchHint(false);
                 if (!value.trim()) changeSearch(null);
               }} />
        <button className="watch-action" type="submit">Search</button>
        {search && <button className="watch-action" type="button" onClick={() => {
          setInput("");
          setSearchHint(false);
          changeSearch(null);
        }}>Clear</button>}
      </form>
      {searchHint && <p className="watch-search-hint" role="status">Enter at least two characters.</p>}
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
                <h2>{author ? <Link className="watch-author" href={author}>@{selected.username} <span aria-hidden="true">↗</span></Link> : `@${selected.username}`}</h2>
                {selected.caption && <p>{selected.caption}</p>}
                {selected.source_video_id && selected.source_username && isVideoID(selected.source_video_id) && (
                  <Link href={`/watch?v=${selected.source_video_id}`}>Inspired by @{selected.source_username}</Link>
                )}
                {presetDetails && <span>{presetDetails}</span>}
                {isVideoID(selected.id) && (
                  <div className="watch-sound-actions">
                    <a className="watch-action watch-open-ios" href={`handstrudel://watch/${selected.id}`}>Open in HandStrudel</a>
                    {setup && <a className="watch-action" href={`handstrudel://sound/${selected.id}`}>Play this sound in the app</a>}
                    {selected.backing_enabled && <a className="watch-action" href={`handstrudel://play/${selected.id}`}>Play along</a>}
                    <a className={setup || selected.backing_enabled ? undefined : "watch-open-ios"} href="https://apps.apple.com/app/id6764415289">Get the iOS app</a>
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
                : error || (search ? "No matching posts" : "No public performances yet")}</h2>
              {id && !resolving && <Link href="/watch">Browse all performances</Link>}
              {(shared?.error || error) && !loading && <button type="button" onClick={retry}>Try again</button>}
            </div>
          )}
        </section>
        <section className="watch-list" aria-label={search ? "Search results" : "Latest videos"}>
          <h2>{search ? `Results for “${search.text}”` : "Latest videos"}</h2>
          {videos.map((video) => (
            <div className="watch-clip-entry" key={video.id}>
              <button type="button" className="watch-clip" onClick={() => choose(video)}
                      aria-current={video.id === selected?.id ? "true" : undefined}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={mediaURL(video.thumb_key)} alt="" loading="lazy" />
                <span className="watch-clip-text">
                  <strong>{video.caption || video.instrument || "Performance"}</strong>
                  <span>@{video.username}</span>
                </span>
                {video.duration_s ? <small>{Math.ceil(video.duration_s)}s</small> : null}
              </button>
              {creatorHref(video.username) && <Link className="watch-clip-profile" href={creatorHref(video.username)!}
                aria-label={`View @${video.username}'s profile`}>Profile</Link>}
            </div>
          ))}
          {loading && <p role="status">Loading videos…</p>}
          {!loading && !error && search && !videos.length && <p role="status">No matching posts.</p>}
          {!loading && error && !videos.length && id && <button className="watch-action" type="button" onClick={retry}>Retry list</button>}
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
