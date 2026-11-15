"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { isCreatorHandle, loadPublicCreator, loadPublicVideos, mediaURL, PAGE_SIZE, postSearch, type PublicCreator, type PublicVideo } from "../../lib/public-feed";
import { clipTitle, WatchArtwork, WatchFooter, WatchHeader, WatchIcon, WatchThumbnail } from "../watch/watch-design";

export default function CreatorProfile() {
  const handle = useSearchParams().get("u")?.toLowerCase() ?? "";
  return <CreatorView key={handle} handle={handle} />;
}

type ProfileState = { status: "loading" | "missing" | "failed" }
  | { status: "ready"; creator: PublicCreator };

function CreatorView({ handle }: { handle: string }) {
  const [state, setState] = useState<ProfileState>({ status: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    if (!isCreatorHandle(handle)) return;
    const request = new AbortController();
    loadPublicCreator(handle, request.signal)
      .then((creator) => {
        if (request.signal.aborted) return;
        setState(creator ? { status: "ready", creator } : { status: "missing" });
      }).catch(() => {
        if (!request.signal.aborted) setState({ status: "failed" });
      });
    return () => request.abort();
  }, [handle, attempt]);

  return (
    <main className="watch-page creator-page">
      <WatchHeader creator />
      <Link className="creator-back" href="/watch"><WatchIcon name="back" /> All performances</Link>
      {isCreatorHandle(handle) && state.status === "ready" ? (
        <>
          <div className="watch-heading watch-hero creator-heading">
            <WatchArtwork id="creator-hero" />
            <CreatorAvatar key={state.creator.avatar_key} creator={state.creator} />
            <div className="watch-hero-copy">
              <p className="watch-eyebrow"><span /> ARTIST PROFILE</p>
              <h1>{state.creator.display_name || `@${state.creator.username}`}</h1>
              {state.creator.display_name && <p className="watch-intro">@{state.creator.username}</p>}
              <CreatorShare title={state.creator.display_name || `@${state.creator.username}`} getURL={() => {
                const url = new URL(window.location.href);
                url.search = new URLSearchParams({ u: state.creator.username }).toString();
                url.hash = "";
                return url.href;
              }} />
            </div>
          </div>
          <CreatorLibrary handle={handle} />
        </>
      ) : (
        <div className="watch-state" role="status">
          <h1>{!isCreatorHandle(handle) || state.status === "missing" ? "Creator unavailable"
            : state.status === "failed" ? "Couldn't load the creator" : "Loading creator…"}</h1>
          {state.status === "failed" && <button type="button" onClick={() => {
            setState({ status: "loading" });
            setAttempt((count) => count + 1);
          }}>Try again</button>}
        </div>
      )}
      <WatchFooter />
    </main>
  );
}

function CreatorLibrary({ handle }: { handle: string }) {
  const [draft, setDraft] = useState("");
  const [query, setQuery] = useState("");
  const [invalid, setInvalid] = useState(false);
  const searchInput = useRef<HTMLInputElement>(null);

  return (
    <section className="creator-performances" aria-labelledby="creator-performances-title">
      <div className="creator-library-heading">
        <h2 id="creator-performances-title">Public performances</h2>
        <form className="creator-search" role="search" aria-label="Creator performances" onSubmit={(event) => {
          event.preventDefault();
          const value = draft.trim();
          const invalid = !!value && !postSearch(value);
          setInvalid(invalid);
          if (!invalid) setQuery(value);
        }}>
          <div className="creator-search-field">
            <WatchIcon name="search" />
            <input ref={searchInput} type="search" value={draft} maxLength={80}
              aria-label="Search this creator's performances" placeholder="Search by caption or instrument"
              aria-invalid={invalid || undefined} aria-describedby={invalid ? "creator-search-error" : undefined}
              onChange={(event) => {
                setDraft(event.target.value);
                setInvalid(false);
              }} />
            {(draft || query) && <button className="creator-search-clear" type="button" aria-label="Clear search" onClick={() => {
              setDraft("");
              setQuery("");
              setInvalid(false);
              searchInput.current?.focus();
            }}><WatchIcon name="close" /></button>}
          </div>
          <button className="watch-action" type="submit">Search</button>
          {invalid && <p className="creator-search-error" id="creator-search-error" role="alert">Enter at least two characters to search.</p>}
        </form>
      </div>
      <CreatorResults key={query} handle={handle} query={query} />
    </section>
  );
}

type ResultPage = { videos: PublicVideo[]; after?: PublicVideo; more: boolean; focusId?: string };

function CreatorResults({ handle, query }: { handle: string; query: string }) {
  const [results, setResults] = useState<ResultPage>();
  const [attempt, setAttempt] = useState(0);
  const [paging, setPaging] = useState(false);
  const [error, setError] = useState(false);
  const pageRequest = useRef<AbortController | null>(null);
  const moreButton = useRef<HTMLButtonElement>(null);
  const summary = useRef<HTMLParagraphElement>(null);

  useEffect(() => {
    const request = new AbortController();
    loadPublicVideos({ creator: handle, search: postSearch(query) }, request.signal)
      .then((videos) => {
        if (!request.signal.aborted) setResults({ videos, after: videos.at(-1), more: videos.length === PAGE_SIZE });
      }).catch(() => {
        if (!request.signal.aborted) setError(true);
      });
    return () => {
      request.abort();
      pageRequest.current?.abort();
    };
  }, [handle, query, attempt]);

  async function loadMore() {
    if (pageRequest.current || !results?.more) return;
    const request = new AbortController();
    pageRequest.current = request;
    setPaging(true);
    setError(false);
    try {
      const page = await loadPublicVideos({ creator: handle, search: postSearch(query), after: results.after }, request.signal);
      if (request.signal.aborted) return;
      const seen = new Set(results.videos.map((video) => video.id));
      const added = page.filter((video) => !seen.has(video.id));
      const moveFocus = document.activeElement === moreButton.current;
      if (moveFocus && added.length === 0 && page.length < PAGE_SIZE) summary.current?.focus({ preventScroll: true });
      setResults({
        videos: [...results.videos, ...added],
        after: page.at(-1),
        more: page.length === PAGE_SIZE,
        focusId: moveFocus ? added[0]?.id : undefined,
      });
    } catch {
      if (!request.signal.aborted) setError(true);
    } finally {
      pageRequest.current = null;
      if (!request.signal.aborted) setPaging(false);
    }
  }

  const count = results?.videos.length ?? 0;
  return (
    <>
      <p className="creator-results-status" role="status" ref={summary} tabIndex={-1}>
        {!results ? error ? "Couldn't load performances." : query ? "Searching performances..." : "Loading performances..."
          : count ? `Showing ${count} ${query ? "matching " : ""}${count === 1 ? "performance" : "performances"} · Newest first`
          : query ? `No performances match “${query}”. Try a different search or clear it.`
          : "This creator hasn't posted any public performances yet."}
      </p>
      {results && count > 0 && <ul className="creator-grid" role="list">
        {results.videos.map((video) => <CreatorClip key={video.id} video={video} focusOnAppend={results.focusId === video.id} />)}
      </ul>}
      {results && <p className="creator-results-status" role="status">
        {error ? "Couldn't load more performances." : paging ? "Loading more performances..." : ""}
      </p>}
      {results?.more && <button className="watch-action" type="button" ref={moreButton} aria-disabled={paging} onClick={loadMore}>
        {error ? "Try again" : paging ? "Loading..." : "Load more"}
      </button>}
      {!results && error && <button className="watch-action" type="button" onClick={() => {
        setError(false);
        setAttempt((count) => count + 1);
      }}>Try again</button>}
    </>
  );
}

const clipDate = new Intl.DateTimeFormat("en", { dateStyle: "medium", timeZone: "UTC" });

function CreatorClip({ video, focusOnAppend }: { video: PublicVideo; focusOnAppend: boolean }) {
  const link = useRef<HTMLAnchorElement>(null);
  const title = clipTitle(video);
  useEffect(() => {
    if (focusOnAppend) link.current?.focus();
  }, [focusOnAppend]);
  return (
    <li className="creator-card">
      <Link className="creator-clip" ref={link} href={`/watch?v=${encodeURIComponent(video.id)}`}>
        <WatchThumbnail video={video} showPlay />
        <div className="creator-clip-copy">
          <strong>{title}</strong>
          {video.instrument?.trim() && video.instrument.trim() !== title && <small>{video.instrument.trim()}</small>}
          <time dateTime={video.created_at}>{clipDate.format(new Date(video.created_at))}</time>
        </div>
      </Link>
      <CreatorShare compact title={title} getURL={() => link.current?.href} />
    </li>
  );
}

function CreatorShare({ compact = false, title, getURL }: {
  compact?: boolean; title: string; getURL: () => string | undefined;
}) {
  const [message, setMessage] = useState("");
  const [manualURL, setManualURL] = useState("");
  const label = compact ? `Share ${title}` : "Share profile";

  async function share() {
    const url = getURL();
    if (!url) return;
    setManualURL("");
    setMessage("");
    if (navigator.share) {
      try {
        await navigator.share({ title, url });
        return;
      } catch (error) {
        if (error instanceof Error && error.name === "AbortError") return;
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      setMessage(compact ? "Performance link copied." : "Profile link copied.");
    } catch {
      setManualURL(url);
      setMessage("Copy the link below to share.");
    }
  }

  return (
    <div className={compact ? "creator-share creator-share-clip" : "creator-share creator-share-profile"}>
      <button className="watch-action" type="button" aria-label={compact ? label : undefined} title={label} onClick={share}>
        <WatchIcon name="link" />{!compact && label}
      </button>
      <p className="creator-share-status" role="status">{message}</p>
      {manualURL && <input className="creator-share-url" type="url" readOnly value={manualURL}
        aria-label={compact ? `Link to ${title}` : "Profile link"}
        onFocus={(event) => event.currentTarget.select()} />}
    </div>
  );
}

function CreatorAvatar({ creator }: { creator: PublicCreator }) {
  const [failed, setFailed] = useState(false);
  const src = creator.avatar_key ? mediaURL(creator.avatar_key) : undefined;
  return (
    <div className="creator-monogram" aria-hidden="true">
      {creator.username[0].toUpperCase()}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      {src && !failed && <img src={src} alt="" onError={() => setFailed(true)} />}
    </div>
  );
}
