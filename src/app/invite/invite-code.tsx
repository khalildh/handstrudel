"use client";

import { type MouseEvent, useEffect, useState } from "react";

const appStore = "https://apps.apple.com/app/id6764415289";

/**
 * Reads `?c=` on the client (the site is a static export). "Get the app" copies the code first,
 * so the new person can paste it with the app's Paste button when they set up their account.
 * The page says so; nothing else is matched or tracked.
 */
export function InviteCode() {
  const [code, setCode] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    const raw = new URLSearchParams(window.location.search).get("c") ?? "";
    const normalized = raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
    setCode(/^[A-Z2-9]{8}$/.test(normalized) ? normalized : "");
  }, []);

  const copy = async () => {
    if (!code) return false;
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      return true;
    } catch {
      return false;
    }
  };

  const getApp = async (event: MouseEvent<HTMLAnchorElement>) => {
    if (!code) return;
    event.preventDefault();
    await copy();
    window.location.href = appStore;
  };

  return (
    <div className="invite-card">
      {code ? (
        <>
          <p className="invite-label">Your invite code</p>
          <p className="invite-code" aria-live="polite">{code}</p>
          <p><a className="watch-app-link" href={appStore} onClick={getApp}>Copy code &amp; get the app</a></p>
          <p className="invite-fine-print" aria-live="polite">
            {copied
              ? "Code copied. In the app, tap Paste when it asks who introduced you."
              : "Tapping the button copies your code to the clipboard, so you can paste it when you set up your account."}
          </p>
          <button type="button" className="home-text-link" onClick={copy}>{copied ? "Copied" : "Just copy the code"}</button>
        </>
      ) : code === "" ? (
        <>
          <p>This invite link is missing its code. You can still name the friend who introduced you by their @username when you set up your account.</p>
          <p><a className="watch-app-link" href={appStore}>Get HandStrudel on the App Store</a></p>
        </>
      ) : (
        <p><a className="watch-app-link" href={appStore}>Get HandStrudel on the App Store</a></p>
      )}
    </div>
  );
}
