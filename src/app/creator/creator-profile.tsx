"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { isCreatorHandle, loadPublicCreator, loadPublicVideos, mediaURL, PAGE_SIZE, type PublicCreator, type PublicVideo } from "../../lib/public-feed";

export default function CreatorProfile() {
  const handle = useSearchParams().get("u")?.toLowerCase() ?? "";
  return <CreatorView key={handle} handle={handle} />;
}

type ProfileState = { status: "loading" | "missing" | "failed" }
  | { status: "ready"; creator: PublicCreator; videos: PublicVideo[]; more: boolean };

function CreatorView({ handle }: { handle: string }) {
  const [state, setState] = useState<ProfileState>({ status: "loading" });
  const [attempt, setAttempt] = useState(0);
  const [paging, setPaging] = useState(false);
  const [pageError, setPageError] = useState(false);
  const pageRequest = useRef<AbortController | null>(null);

  useEffect(() => {
    if (!isCreatorHandle(handle)) return;
    const request = new AbortController();
    Promise.all([loadPublicCreator(handle, request.signal), loadPublicVideos({ creator: handle }, request.signal)])
      .then(([creator, videos]) => {
        if (request.signal.aborted) return;
        setState(creator ? { status: "ready", creator, videos, more: videos.length === PAGE_SIZE } : { status: "missing" });
      }).catch(() => {
        if (!request.signal.aborted) setState({ status: "failed" });
      });
    return () => {
      request.abort();
      pageRequest.current?.abort();
    };
  }, [handle, attempt]);

  async function loadMore() {
    if (pageRequest.current || state.status !== "ready" || !state.more) return;
    const request = new AbortController();
    pageRequest.current = request;
    setPaging(true);
    setPageError(false);
    try {
      const page = await loadPublicVideos({ creator: handle, after: state.videos.at(-1) }, request.signal);
      if (request.signal.aborted) return;
      setState((current) => {
        if (current.status !== "ready") return current;
        const seen = new Set(current.videos.map((video) => video.id));
        return { ...current, videos: [...current.videos, ...page.filter((video) => !seen.has(video.id))], more: page.length === PAGE_SIZE };
      });
    } catch {
      if (!request.signal.aborted) setPageError(true);
    } finally {
      pageRequest.current = null;
      if (!request.signal.aborted) setPaging(false);
    }
  }

  return (
    <main className="watch-page">
      <header className="watch-top">
        <Link className="watch-wordmark" href="/">hand<strong>strudel</strong></Link>
        <Link className="watch-action" href="/watch">Browse performances</Link>
      </header>
      {isCreatorHandle(handle) && state.status === "ready" ? (
        <>
          <div className="watch-heading creator-heading">
            <div className="creator-monogram" aria-hidden="true">{state.creator.username[0].toUpperCase()}</div>
            <div>
              <p>{state.creator.display_name ? `@${state.creator.username}` : "HandStrudel creator"}</p>
              <h1>{state.creator.display_name || `@${state.creator.username}`}</h1>
            </div>
          </div>
          <section className="creator-performances" aria-labelledby="creator-performances-title">
            <h2 id="creator-performances-title">Public performances</h2>
            {state.videos.length === 0 && <p>This creator hasn&apos;t posted any public performances yet.</p>}
            <div className="creator-grid">
              {state.videos.map((video) => (
                <Link className="creator-clip" key={video.id} href={`/watch?v=${encodeURIComponent(video.id)}`}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={mediaURL(video.thumb_key)} alt="" loading="lazy" />
                  <div>
                    <strong>{video.caption || video.instrument || "Performance"}</strong>
                    {video.duration_s != null && <small>{Math.ceil(video.duration_s)}s</small>}
                  </div>
                </Link>
              ))}
            </div>
            {pageError && <p role="status">Couldn&apos;t load more performances.</p>}
            {state.more && <button className="watch-action" type="button" disabled={paging} onClick={loadMore}>
              {paging ? "Loading…" : pageError ? "Try again" : "Load more"}
            </button>}
          </section>
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
    </main>
  );
}
