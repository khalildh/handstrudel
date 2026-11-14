import type { Metadata } from "next";
import { Suspense } from "react";
import WatchFeed from "./watch-feed";

export const metadata: Metadata = {
  title: "Watch performances · HandStrudel",
  description: "Watch public performances made with HandStrudel.",
};

export default function WatchPage() {
  return (
    <Suspense fallback={<main className="watch-page"><p role="status">Loading performances…</p></main>}>
      <WatchFeed />
    </Suspense>
  );
}
