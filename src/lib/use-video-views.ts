"use client";

import { useRef, useState } from "react";
import { recordPublicVideoView } from "./public-feed";

const receipts = new Map<string, string>();

function receiptFor(id: string) {
  const cached = receipts.get(id);
  if (cached) return cached;
  const key = `handstrudel.clip-view.${id}`;
  let receipt = crypto.randomUUID();
  try {
    receipt = sessionStorage.getItem(key) ?? receipt;
    sessionStorage.setItem(key, receipt);
  } catch {
    // Some embedded browsers disable session storage.
  }
  receipts.set(id, receipt);
  return receipt;
}

export function useVideoViews(id?: string, publishedCount?: number) {
  const [totals, setTotals] = useState<Record<string, number>>({});
  const watch = useRef<{ id: string; previous?: number; watched: number; submitted: boolean } | undefined>(undefined);
  const resetSample = () => { if (watch.current) watch.current.previous = undefined; };

  function sample(video: HTMLVideoElement) {
    if (!id || publishedCount === undefined || !Number.isFinite(video.duration) || video.duration <= 0) return;
    if (!watch.current || watch.current.id !== id) watch.current = { id, watched: 0, submitted: false };
    const progress = watch.current;
    if (progress.submitted) return;
    if (video.paused || video.seeking || document.visibilityState !== "visible" || video.readyState < 2) {
      resetSample();
      return;
    }
    const delta = video.currentTime - (progress.previous ?? video.currentTime);
    progress.previous = video.currentTime;
    if (delta <= 0 || delta > 0.6) return;
    progress.watched += delta;
    if (progress.watched < Math.min(2, video.duration / 2)) return;
    progress.submitted = true;
    void recordPublicVideoView(id, receiptFor(id)).then((count) => {
      if (count !== null) setTotals((previous) => ({ ...previous, [id]: Math.max(previous[id] ?? 0, count) }));
    }).catch(() => {});
  }

  return {
    count: id && totals[id] !== undefined ? Math.max(totals[id], publishedCount ?? 0) : publishedCount,
    sample,
    resetSample,
  };
}
