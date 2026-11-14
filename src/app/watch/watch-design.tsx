import Link from "next/link";
import { mediaURL, type PublicVideo } from "../../lib/public-feed";

const paths = {
  wave: <path d="M3 10v4m4-8v12m5-15v18m5-14v10m4-7v4" />,
  arrow: <path d="M6 18 18 6M8 6h10v10" />,
  next: <path d="M5 12h14m-6-6 6 6-6 6" />,
  back: <path d="M19 12H5m6 6-6-6 6-6" />,
  play: <path d="M9 5v14l11-7z" fill="currentColor" stroke="none" />,
  search: <><circle cx="10.5" cy="10.5" r="5.5" /><path d="m15 15 5 5" /></>,
  close: <path d="m7 7 10 10M17 7 7 17" />,
  link: <path d="m9 15 6-6m-7 9-1 1a4 4 0 0 1-6-6l4-4a4 4 0 0 1 6 0m2 6a4 4 0 0 0 6 0l4-4a4 4 0 0 0-6-6l-1 1" transform="translate(1 2) scale(.9)" />,
  message: <path d="M20 11.5a7.5 7.5 0 0 1-7.5 7.5H5l1.8-3.5A7.5 7.5 0 1 1 20 11.5Z" />,
  chevron: <path d="m7 10 5 5 5-5" />,
};

export function WatchIcon({ name }: { name: keyof typeof paths }) {
  return <svg className="watch-icon" viewBox="0 0 24 24" width="20" height="20" fill="none"
    stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>;
}

export function WatchHeader({ creator = false }: { creator?: boolean }) {
  return (
    <header className="watch-top">
      <Link className="watch-wordmark" href="/" aria-label="HandStrudel home">
        <span className="watch-brand-mark"><WatchIcon name="wave" /></span>handstrudel
      </Link>
      <nav className="watch-nav" aria-label="Main navigation">
        <Link className="watch-nav-feed" href="/watch" aria-current={creator ? undefined : "page"}>Watch</Link>
        <Link className="watch-action watch-create" href="/">Make music <WatchIcon name="arrow" /></Link>
      </nav>
    </header>
  );
}

export function WatchFooter() {
  return (
    <footer className="watch-footer">
      <span><WatchIcon name="wave" /> HANDSTRUDEL</span>
      <div>
        <Link href="/community">Community guidelines</Link>
        <Link href="/privacy">Privacy</Link>
        <a href="mailto:hello@handstrudel.com">Report a video</a>
      </div>
    </footer>
  );
}

export function WatchArtwork({ id }: { id: string }) {
  return (
    <svg className="watch-artwork" viewBox="0 0 500 210" fill="none" aria-hidden="true" preserveAspectRatio="xMidYMid slice">
      <defs>
        <linearGradient id={`${id}-ink`}>
          <stop stopColor="#4963e8" stopOpacity="0" />
          <stop offset=".38" stopColor="#4963e8" />
          <stop offset=".78" stopColor="#223ee2" />
          <stop offset="1" stopColor="#223ee2" stopOpacity="0" />
        </linearGradient>
        <pattern id={`${id}-dots`} width="16" height="16" patternUnits="userSpaceOnUse">
          <circle cx="2" cy="2" r="1" fill="#2b44d2" opacity=".28" />
        </pattern>
        <linearGradient id={`${id}-fade`}><stop stopColor="black" /><stop offset=".38" stopColor="white" /></linearGradient>
        <mask id={`${id}-mask`}><rect width="500" height="210" fill={`url(#${id}-fade)`} /></mask>
      </defs>
      <g mask={`url(#${id}-mask)`}>
        <rect width="500" height="210" fill={`url(#${id}-dots)`} />
        <circle cx="350" cy="70" r="44" fill="#e7f396" />
        {Array.from({ length: 17 }, (_, i) => (
          <path key={i} d={`M -6 ${114 + i * 3} C 126 ${186 - i * 2}, 179 ${17 + i * 7}, 252 ${36 + i * 7} S 366 ${212 - i * 7}, 507 ${93 - i * 2}`}
            stroke={`url(#${id}-ink)`} strokeWidth={i % 4 === 0 ? 1.5 : .8} opacity={.42 + i * .025} />
        ))}
      </g>
    </svg>
  );
}

export function clipTitle(video: PublicVideo) {
  return video.caption.trim() || video.instrument?.trim() || "Untitled performance";
}

export function clipDuration(seconds: PublicVideo["duration_s"]) {
  if (seconds == null || !Number.isFinite(seconds) || seconds <= 0) return null;
  const time = Math.ceil(seconds);
  return `${Math.floor(time / 60)}:${String(time % 60).padStart(2, "0")}`;
}

export function WatchThumbnail({ video, showPlay = false }: { video: PublicVideo; showPlay?: boolean }) {
  const time = clipDuration(video.duration_s);
  return (
    <span className="watch-thumbnail" aria-hidden="true">
      <WatchIcon name="wave" />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={mediaURL(video.thumb_key)} alt="" loading="lazy" onError={(event) => { event.currentTarget.hidden = true; }} />
      {showPlay && <span className="watch-thumbnail-play"><WatchIcon name="play" /></span>}
      {time && <span className="watch-duration">{time}</span>}
    </span>
  );
}
