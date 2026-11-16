"use client";

import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";

function pagePathsOnly<Event extends { url: string }>(event: Event): Event {
  // Watch and creator URLs carry post IDs and usernames in their query strings.
  const url = new URL(event.url, window.location.origin);
  url.search = "";
  url.hash = "";
  return { ...event, url: url.href };
}

export function SiteAnalytics() {
  return (
    <>
      <Analytics beforeSend={pagePathsOnly} />
      <SpeedInsights beforeSend={pagePathsOnly} />
    </>
  );
}
