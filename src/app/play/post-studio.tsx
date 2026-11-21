"use client";

// The Web Studio started from a shared post: that post's instrument and sound,
// playable by hand tracking (camera on once sound starts), mouse or touch.

import Link from "next/link";
import { useEffect, useState } from "react";
import PostInstrumentPlayer from "../../components/instruments/PostInstrumentPlayer";
import { loadPublicVideos, type PublicVideo } from "../../lib/public-feed";
import { WatchHeader } from "../watch/watch-design";

export default function PostStudio({ id }: { id: string }) {
  const [post, setPost] = useState<PublicVideo | null>();
  const [attempt, setAttempt] = useState(0);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const request = new AbortController();
    setFailed(false);
    loadPublicVideos({ id }, request.signal).then(([video]) => {
      if (!request.signal.aborted) setPost(video ?? null);
    }).catch(() => {
      if (!request.signal.aborted) setFailed(true);
    });
    return () => request.abort();
  }, [id, attempt]);

  return (
    <main className="post-studio watch-page">
      <WatchHeader />
      {post ? (
        <>
          <PostInstrumentPlayer post={post} cameraFirst />
          <nav className="post-studio-links" aria-label="More">
            <Link href={`/watch?v=${post.id}`}>Watch @{post.username}’s performance</Link>
            <Link href="/play">Open the full Web Studio</Link>
          </nav>
        </>
      ) : (
        <div className="watch-state" role="status">
          <h2>{failed ? "Couldn't load this performance" : post === null ? "This performance is unavailable" : "Loading the performance…"}</h2>
          {failed && <button type="button" onClick={() => setAttempt((count) => count + 1)}>Try again</button>}
          {post === null && <Link href="/play">Open the Web Studio</Link>}
        </div>
      )}
    </main>
  );
}
