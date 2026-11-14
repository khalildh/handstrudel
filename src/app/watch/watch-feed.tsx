"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { creatorHref, describeClipChords, isVideoID, loadPublicVideos, mediaURL, PAGE_SIZE, postSearch, type PublicVideo } from "../../lib/public-feed";
import WatchComments from "./watch-comments";
import { clipDuration, clipTitle, WatchArtwork, WatchFooter, WatchHeader, WatchIcon, WatchThumbnail } from "./watch-design";

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
  const [sharedLink, setSharedLink] = useState<{ id: string; message: string }>();
  const [embedFor, setEmbedFor] = useState<string>();
  const embedInput = useRef<HTMLTextAreaElement>(null);
  const player = useRef<HTMLVideoElement>(null);
  const stage = useRef<HTMLElement>(null);
  const paging = useRef<AbortController | null>(null);
  const listed = videos.find((video) => video.id === id);
  const selected = id ? listed ?? (shared?.id === id ? shared.video : undefined) : videos[0];
  const resolving = id && isVideoID(id) && !listed && shared?.id !== id;
  const setup = selected?.sound_setup?.version === 1 ? selected.sound_setup : null;
  const chords = describeClipChords(setup);
  const author = selected ? creatorHref(selected.username) : null;
  const currentIndex = videos.findIndex((video) => video.id === selected?.id);
  const nextVideo = videos[currentIndex + 1];
  const poster = selected ? mediaURL(selected.thumb_key) : undefined;
  const embedURL = selected && isVideoID(selected.id) ? `https://handstrudel.com/embed?v=${selected.id}` : null;
  const embedMarkup = embedURL ? `<iframe src="${embedURL}" title="HandStrudel performance" width="360" height="640" style="max-width:100%;border:0" loading="lazy" allowfullscreen></iframe>` : "";
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
    if (id) router.replace("/watch", { scroll: false });
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

  async function share(video: PublicVideo) {
    const url = new URL(`/watch?v=${video.id}`, window.location.origin).href;
    try {
      if (navigator.share) await navigator.share({ title: clipTitle(video), url });
      else {
        await navigator.clipboard.writeText(url);
        setSharedLink({ id: video.id, message: "Link copied" });
      }
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") return;
      setSharedLink({ id: video.id, message: "Couldn’t share. You can copy the link from your address bar." });
    }
  }

  return (
    <main className="watch-page">
      <WatchHeader />
      <div className="watch-heading watch-hero">
        <WatchArtwork id="watch-hero" />
        <div className="watch-hero-copy">
          <p className="watch-eyebrow"><span /> THE LISTENING ROOM</p>
          <h1>Performances<span>.</span></h1>
          <p className="watch-intro">Watch what people make when the air is the instrument.</p>
        </div>
      </div>
      <div className="watch-grid">
        <section ref={stage} className="watch-stage" aria-label="Video player">
          {selected ? (
            <>
              <div className="watch-screen" key={selected.id}>
                {poster && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img className="watch-screen-wash" src={poster} alt="" aria-hidden="true" onError={(event) => { event.currentTarget.hidden = true; }} />
                )}
                <div className="watch-screen-label" aria-hidden="true"><WatchIcon name="wave" /> ON SCREEN</div>
                <video ref={player} controls playsInline preload="metadata" poster={poster}
                  src={mediaURL(selected.video_key)}
                  aria-label={`Performance by @${selected.username}`} />
              </div>
              <div className="watch-caption">
                <div className="watch-caption-heading">
                  <div>
                    <h2>{clipTitle(selected)}</h2>
                    <div className="watch-byline">
                      {author ? <Link className="watch-author" href={author}>@{selected.username} <WatchIcon name="arrow" /></Link> : `@${selected.username}`}
                      {clipDuration(selected.duration_s) && <span>{clipDuration(selected.duration_s)}</span>}
                    </div>
                  </div>
                  <div className="watch-share-actions">
                    <button type="button" className="watch-action" onClick={() => share(selected)}><WatchIcon name="link" /> Share</button>
                    {embedURL && <button type="button" className="watch-action" aria-expanded={embedFor === selected.id}
                      onClick={() => { setEmbedFor(embedFor === selected.id ? undefined : selected.id); setSharedLink(undefined); }}>Embed</button>}
                  </div>
                </div>
                {embedURL && embedFor === selected.id && (
                  <div className="watch-embed-panel">
                    <label htmlFor="watch-embed-code">Embed this performance</label>
                    <textarea id="watch-embed-code" ref={embedInput} readOnly rows={3} value={embedMarkup}
                      onFocus={(event) => event.currentTarget.select()} />
                    <div>
                      <button type="button" className="watch-action watch-primary" onClick={async () => {
                        try {
                          await navigator.clipboard.writeText(embedMarkup);
                          setSharedLink({ id: selected.id, message: "Embed code copied" });
                        } catch {
                          embedInput.current?.focus();
                          setSharedLink({ id: selected.id, message: "Embed code selected. Copy it to your clipboard." });
                        }
                      }}>Copy embed code</button>
                      <Link className="watch-app-link" href={`/embed?v=${selected.id}`}>Open embed link <WatchIcon name="arrow" /></Link>
                    </div>
                  </div>
                )}
                {sharedLink?.id === selected.id && <p className="watch-inline-status" role="status">{sharedLink.message}</p>}
                {selected.source_video_id && selected.source_username && isVideoID(selected.source_video_id) && (
                  <Link className="watch-source" href={`/watch?v=${selected.source_video_id}`}>Inspired by @{selected.source_username}</Link>
                )}
                {(presetDetails || chords) && (
                  <div className="watch-preset-row" aria-label="Sound settings">
                    {presetDetails && <p className="watch-preset"><WatchIcon name="wave" /> {presetDetails}</p>}
                    {chords && (
                      <p className="watch-preset watch-preset-chords">
                        <span className="watch-preset-label">{chords.label}:</span>
                        <span>{chords.name}{chords.degrees && ` (${chords.degrees.join("–")})`}</span>
                      </p>
                    )}
                  </div>
                )}
                {isVideoID(selected.id) && (
                  <div className="watch-sound-actions">
                    <a className="watch-action watch-primary watch-open-ios" href={`handstrudel://watch/${selected.id}`}>Open in HandStrudel <WatchIcon name="arrow" /></a>
                    {setup && <a className="watch-action watch-primary" href={`handstrudel://sound/${selected.id}`}><WatchIcon name="play" /> Play this sound in the app</a>}
                    {selected.backing_enabled && <a className="watch-action" href={`handstrudel://play/${selected.id}`}>Play along</a>}
                    <a className="watch-app-link" href="https://apps.apple.com/app/id6764415289">Get the iOS app</a>
                  </div>
                )}
              </div>
              <WatchComments key={`comments-${selected.id}`} video={selected} />
            </>
          ) : (
            <div className="watch-state" role="status">
              <span className="watch-state-mark"><WatchIcon name="play" /></span>
              <h2>{resolving || (!id && loading) ? "Loading performances…" : id
                ? shared?.error ? "Couldn't load this performance" : "This performance is unavailable"
                : error || (search ? "No matching posts" : "No public performances yet")}</h2>
              {id && !resolving && <Link href="/watch">Browse all performances</Link>}
              {!id && search && !loading && !error && <button type="button" onClick={() => {
                setInput("");
                changeSearch(null);
              }}>Clear search</button>}
              {(shared?.error || error) && !loading && <button type="button" onClick={retry}>Try again</button>}
            </div>
          )}
        </section>
        <section className="watch-list" aria-label={search ? "Search results" : "Latest videos"}>
          <div className="watch-list-heading">
            <p className="watch-eyebrow"><span /> DISCOVER</p>
            <h2>{search ? `Results for “${search.text}”` : "Latest videos"}</h2>
          </div>
          <form className="watch-search" role="search" onSubmit={submitSearch}>
            <label className="watch-search-field">
              <WatchIcon name="search" />
              <input aria-label="Search posts" type="search" placeholder="Search clips or @creators"
                value={input} maxLength={120} onChange={(event) => {
                  const value = event.target.value;
                  setInput(value);
                  setSearchHint(false);
                  if (!value.trim()) changeSearch(null);
                }} />
            </label>
            <button className="watch-action" type="submit">Search</button>
            {search && <button className="watch-clear" aria-label="Clear search" type="button" onClick={() => {
              setInput("");
              setSearchHint(false);
              changeSearch(null);
            }}><WatchIcon name="close" /></button>}
          </form>
          {searchHint && <p className="watch-search-hint" role="status">Enter at least two characters.</p>}
          {videos.map((video) => (
            <div className="watch-clip-entry" key={video.id} data-current={video.id === selected?.id || undefined}>
              <button type="button" className="watch-clip" onClick={() => choose(video)}
                      aria-current={video.id === selected?.id ? "true" : undefined}>
                <WatchThumbnail video={video} />
                <span className="watch-clip-text">
                  <strong>{clipTitle(video)}</strong>
                  {video.instrument && <span>{video.instrument}</span>}
                </span>
              </button>
              {creatorHref(video.username) ? <Link className="watch-clip-profile" href={creatorHref(video.username)!}
                aria-label={`View @${video.username}'s profile`}>@{video.username}</Link> : <span className="watch-clip-profile">@{video.username}</span>}
            </div>
          ))}
          {loading && <p role="status">Loading videos…</p>}
          {!loading && !error && search && !videos.length && <p role="status">No matching posts.</p>}
          {!loading && error && !videos.length && id && <button className="watch-action" type="button" onClick={retry}>Retry list</button>}
          {error && videos.length > 0 && <p role="status">{error}</p>}
          {more && <button className="watch-action" type="button" onClick={loadMore} disabled={loadingMore}>
            {loadingMore ? "Loading…" : "Load more"}
          </button>}
          {nextVideo && selected && <button className="watch-action watch-next" type="button" onClick={() => choose(nextVideo)}>
            Next performance <WatchIcon name="next" />
          </button>}
        </section>
      </div>
      <WatchFooter />
    </main>
  );
}
