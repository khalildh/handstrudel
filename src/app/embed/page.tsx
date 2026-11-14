import type { Metadata } from "next";
import { Suspense } from "react";
import EmbeddedPerformance from "./player";

export const metadata: Metadata = {
  title: "HandStrudel performance",
  robots: { index: false, follow: false },
};

export default function EmbedPage() {
  return <Suspense fallback={<main className="embed-page"><p role="status">Loading performance…</p></main>}><EmbeddedPerformance /></Suspense>;
}
