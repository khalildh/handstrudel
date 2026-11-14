import type { Metadata } from "next";
import { Suspense } from "react";
import CreatorProfile from "./creator-profile";

export const metadata: Metadata = {
  title: "Creator profile · HandStrudel",
  description: "Browse a HandStrudel creator's public performances.",
};

export default function CreatorPage() {
  return (
    <Suspense fallback={<main className="watch-page"><p role="status">Loading creator…</p></main>}>
      <CreatorProfile />
    </Suspense>
  );
}
