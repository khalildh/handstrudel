"use client";

import { Analytics, type BeforeSend } from "@vercel/analytics/next";

const pagePathsOnly: BeforeSend = (event) => {
  // Watch and creator URLs carry post IDs and usernames in their query strings.
  const url = new URL(event.url, window.location.origin);
  url.search = "";
  url.hash = "";
  return { ...event, url: url.href };
};

export function SiteAnalytics() {
  return <Analytics beforeSend={pagePathsOnly} />;
}
