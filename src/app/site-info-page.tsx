import type { ReactNode } from "react";
import Link from "next/link";
import { SiteInfoLinks } from "./site-info-links";
import { WatchIcon } from "./watch/watch-design";
import "./home.css";

export const infoViewport = { themeColor: "#f7f6f1" };

export function SiteInfoPage({ title, path, children }: {
  title: string;
  path: string;
  children: ReactNode;
}) {
  return (
    <div className="home-page info-page">
      <header className="home-header">
        <div className="home-shell home-nav">
          <Link className="watch-wordmark" href="/" aria-label="HandStrudel home">
            <span className="watch-brand-mark"><WatchIcon name="wave" /></span>handstrudel
          </Link>
          <nav aria-label="Main navigation"><Link href="/watch">Watch</Link></nav>
        </div>
      </header>
      <main className="home-shell info-main" aria-labelledby="info-title">
        <p className="home-kicker"><span /> HANDSTRUDEL &nbsp;/&nbsp; INFO</p>
        <h1 id="info-title">{title}</h1>
        <div className="info-content">{children}</div>
      </main>
      <footer className="home-shell home-footer info-footer">
        <Link className="home-text-link" href="/">Back to home</Link>
        <SiteInfoLinks current={path} />
      </footer>
    </div>
  );
}
