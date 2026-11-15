import type { Metadata } from "next";
import Link from "next/link";
import { HomePreview } from "./home-preview";
import { WatchArtwork, WatchIcon } from "./watch/watch-design";
import "./home.css";

const appStore = "https://apps.apple.com/app/id6764415289";
const piano = "/watch?v=41ba66c5-6f0a-4697-99e8-5261f7cb6240";
const kalimba = "/watch?v=385e21ab-7160-4378-b897-c602de952140";
const media = `${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}/home`;

export const metadata: Metadata = {
  title: "HandStrudel for iPhone | Make music with your hands",
  description: "Turn gestures and taps into melodies and chords. Download HandStrudel for iPhone, watch a performance, or try the browser instrument.",
  itunes: { appId: "6764415289" },
};

export const viewport = { themeColor: "#f7f6f1" };

function DownloadLink({ compact = false }: { compact?: boolean }) {
  return (
    <a className={`home-download${compact ? " home-download-compact" : ""}`} href={appStore}>
      {!compact && (
        <svg viewBox="0 0 24 24" width="23" height="23" fill="none" stroke="currentColor" strokeWidth="1.55" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <rect x="5.5" y="2.5" width="13" height="19" rx="3" />
          <path d="M10 5h4m-2 4v7m-2.5-2.5L12 16l2.5-2.5" />
        </svg>
      )}
      <span>{compact ? "Get the app" : "Download for iPhone"}</span>
      <WatchIcon name="arrow" />
    </a>
  );
}

function Brand() {
  return (
    <Link className="watch-wordmark" href="/" aria-label="HandStrudel home">
      <span className="watch-brand-mark"><WatchIcon name="wave" /></span>handstrudel
    </Link>
  );
}

const steps = [
  { n: "01", title: "Play in the air.", detail: "Move your hands over the wheel and pinch to play. Your iPhone tracks the gesture and turns it into a note." },
  { n: "02", title: "Or play by touch.", detail: "Tap for a melody or hold down a chord. Choose a key, scale, and sound that make it feel like yours." },
  { n: "03", title: "Catch the good take.", detail: "Record a performance when you find something you love, then share it with someone who should hear it." },
];

export default function Home() {
  return (
    <div className="home-page">
      <header className="home-header">
        <div className="home-shell home-nav">
          <Brand />
          <nav aria-label="Main navigation">
            <Link href="/watch">Watch</Link>
            <Link className="home-nav-studio" href="/play" prefetch={false}>Web studio</Link>
            <DownloadLink compact />
          </nav>
        </div>
      </header>

      <main className="home-shell">
        <section className="home-hero" aria-labelledby="home-title">
          <div className="home-hero-copy">
            <p className="home-kicker"><span /> THE GESTURE INSTRUMENT FOR iPHONE</p>
            <h1 id="home-title">The air is<br /><em>your instrument.</em></h1>
            <p className="home-lede">Pinch a note out of thin air, or tap the wheel. HandStrudel turns the way you move into music.</p>
            <div className="home-hero-actions">
              <DownloadLink />
              <Link className="home-text-link" href="/play" prefetch={false}>Try in browser <WatchIcon name="next" /></Link>
            </div>
            <p className="home-download-note">Free to download <span aria-hidden="true">·</span> Made for iPhone</p>
          </div>

          <HomePreview
            poster={`${media}/dreamy-piano.jpg`}
            video={`${media}/dreamy-piano.mp4`}
            watchUrl={piano}
          />
        </section>

        <section className="home-process" aria-labelledby="home-process-title">
          <div className="home-section-heading">
            <div>
              <p className="home-kicker"><span /> FROM GESTURE TO SOUND</p>
              <h2 id="home-process-title">Make music your way.</h2>
            </div>
            <p>Start with a single note. The wheel puts melody and harmony within reach, whether you play by gesture or touch.</p>
          </div>
          <ol className="home-steps">
            {steps.map(({ n, title, detail }) => (
              <li key={n}>
                <span className="home-step-index" aria-hidden="true">{n}</span>
                <h3>{title}</h3>
                <p>{detail}</p>
              </li>
            ))}
          </ol>
        </section>

        <section className="home-watch" aria-labelledby="home-watch-title">
          <div className="home-watch-copy">
            <p className="home-kicker"><span /> THE WATCH ROOM</p>
            <h2 id="home-watch-title">See what hands can do.</h2>
            <p>Watch short performances, see the sound and chords behind them, and find an idea to play yourself.</p>
            <Link className="home-watch-link" href="/watch">Watch performances <WatchIcon name="next" /></Link>
          </div>
          <Link className="home-watch-clip" href={kalimba} aria-label="Watch Kalimba Study">
            <WatchArtwork id="home-kalimba" />
            <div className="home-clip-picture">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={`${media}/kalimba-study.jpg`} width="320" height="694" alt="" loading="lazy" />
            </div>
            <span className="home-clip-info"><small>PERFORMANCE 01</small><strong>Kalimba Study</strong><span>E major</span></span>
            <span className="home-clip-play"><WatchIcon name="play" /></span>
          </Link>
        </section>

        <section className="home-get" aria-labelledby="home-get-title">
          <WatchArtwork id="home-download" />
          <div>
            <p className="home-kicker"><span /> HANDSTRUDEL FOR iPHONE</p>
            <h2 id="home-get-title">Play your first note.</h2>
          </div>
          <div><DownloadLink /><p className="home-download-note">Available on the App Store</p></div>
        </section>
      </main>

      <footer className="home-shell home-footer">
        <Brand />
        <nav aria-label="Site information">
          <Link href="/support">Support</Link>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
        </nav>
      </footer>
    </div>
  );
}
