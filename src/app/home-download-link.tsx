"use client";

import type { ReactNode } from "react";
import { publicSupabaseKey, publicSupabaseUrl } from "@/lib/public-supabase";

type Placement = "header" | "hero" | "footer";

export function HomeDownloadAnchor({ placement, href, className, children }: {
  placement: Placement;
  href: string;
  className: string;
  children: ReactNode;
}) {
  function recordClick() {
    // Let the browser open the App Store even if tracking is blocked or slow.
    void fetch(`${publicSupabaseUrl}/rest/v1/rpc/record_homepage_download_click`, {
      method: "POST",
      headers: { apikey: publicSupabaseKey, "Content-Type": "application/json" },
      credentials: "omit",
      referrerPolicy: "no-referrer",
      keepalive: true,
      body: JSON.stringify({ p_placement: placement }),
    }).catch(() => {});
  }

  return (
    <a className={className} href={href} onClick={recordClick}
      onAuxClick={(event) => { if (event.button === 1) recordClick(); }}>
      {children}
    </a>
  );
}
