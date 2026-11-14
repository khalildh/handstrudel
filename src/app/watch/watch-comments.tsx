"use client";

import { useEffect, useState } from "react";
import { COMMENT_PAGE_SIZE, loadPublicComments, type PublicComment, type PublicVideo } from "../../lib/public-feed";
import { WatchIcon } from "./watch-design";

export default function WatchComments({ video }: { video: PublicVideo }) {
  const [open, setOpen] = useState(false);
  if (video.comments_enabled === undefined) return null;
  if (!video.comments_enabled) return <p className="watch-comments-note">Comments are off.</p>;

  return (
    <details className="watch-comments" onToggle={(event) => setOpen(event.currentTarget.open)}>
      <summary><WatchIcon name="message" /> Comments <span>{video.comment_count ?? 0}</span><WatchIcon name="chevron" /></summary>
      {open && (
        <div className="watch-comment-panel">
          <WatchCommentList videoID={video.id} />
          <div className="watch-sound-actions">
            <a className="watch-action" href={`handstrudel://comments/${video.id}`}>Join the conversation in the app</a>
            <a href="https://apps.apple.com/app/id6764415289">Get the iOS app</a>
            <a href={`mailto:hello@handstrudel.com?subject=${encodeURIComponent("Report a comment")}&body=${encodeURIComponent(`Video: https://handstrudel.com/watch?v=${video.id}\n\nComment author and reason:\n`)}`}>Report a comment</a>
          </div>
        </div>
      )}
    </details>
  );
}

function WatchCommentList({ videoID, parentID }: { videoID: string; parentID?: string }) {
  const [items, setItems] = useState<PublicComment[]>([]);
  const [pending, setPending] = useState(true);
  const [more, setMore] = useState(false);
  const [error, setError] = useState(false);
  const [offset, setOffset] = useState(0);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    const request = new AbortController();
    loadPublicComments(videoID, parentID, offset, request.signal).then((page) => {
      if (request.signal.aborted) return;
      setItems((previous) => offset === 0 ? page : [...previous, ...page.filter((item) => !previous.some((current) => current.id === item.id))]);
      setMore(page.length === COMMENT_PAGE_SIZE);
      setPending(false);
    }).catch(() => {
      if (request.signal.aborted) return;
      setError(true);
      setPending(false);
    });
    return () => request.abort();
  }, [videoID, parentID, offset, retry]);

  return (
    <>
      {items.length > 0 && (
        <ul className="watch-comment-list">
          {items.map((item) => (
            <li key={item.id}>
              <strong>@{item.username}</strong>
              <p>{item.body}</p>
              {item.like_count != null && item.like_count > 0 && (
                <p className="watch-comments-note-inline">{item.like_count} {item.like_count === 1 ? "like" : "likes"}</p>
              )}
              {item.reply_count > 0 && <WatchReplies videoID={videoID} comment={item} />}
            </li>
          ))}
        </ul>
      )}
      {pending && <p role="status">Loading {parentID ? "replies" : "comments"}…</p>}
      {error && (
        <div role="status">
          Couldn't load {parentID ? "replies" : "comments"}.{" "}
          <button type="button" onClick={() => { setError(false); setPending(true); setRetry(retry + 1); }}>Try again</button>
        </div>
      )}
      {!pending && !error && items.length === 0 && <p>{parentID ? "No replies yet." : "No comments yet."}</p>}
      {!pending && !error && more &&
        <button type="button" onClick={() => { setPending(true); setOffset(offset + COMMENT_PAGE_SIZE); }}>
          More {parentID ? "replies" : "comments"}
        </button>
      }
    </>
  );
}

function WatchReplies({ videoID, comment }: { videoID: string; comment: PublicComment }) {
  const [open, setOpen] = useState(false);
  return (
    <details className="watch-comment-replies" onToggle={(event) => setOpen(event.currentTarget.open)}>
      <summary>Replies ({comment.reply_count})</summary>
      {open && <WatchCommentList videoID={videoID} parentID={comment.id} />}
    </details>
  );
}
