import type { Metadata } from "next";
import Link from "next/link";
import { infoViewport, SiteInfoPage } from "../site-info-page";

export const metadata: Metadata = { title: "Support | HandStrudel" };
export const viewport = infoViewport;

export default function Support() {
  return (
    <SiteInfoPage title="Support" path="/support">
      <h2>Play your first note</h2>
      <p>Open Music and start the studio. Tap or click a wedge to hear a note. To play in the air, allow camera access, hold your hands where the camera can see them, and pinch your thumb and index finger over a wedge.</p>

      <h2>Camera or hand tracking not working?</h2>
      <p>Check that HandStrudel has camera access. On iPhone, look in Settings for HandStrudel. On Mac, open System Settings, then Privacy &amp; Security, then Camera. Reopen the app after changing the setting and choose Air + touch if the app is in touch-only mode.</p>
      <p>Try a well-lit room with your hands fully in frame. You can still play by tapping or clicking the wheel without a camera. You can also try the <Link href="/play" prefetch={false}>browser studio</Link>.</p>

      <h2>Contact</h2>
      <p>Email <a href="mailto:support@handstrudel.com">support@handstrudel.com</a>. If something isn&apos;t working, include your device, OS, and app version.</p>

      <h2>Report a bug</h2>
      <p>You can also open an issue on <a href="https://github.com/khalildh/handstrudel/issues">GitHub</a>.</p>
    </SiteInfoPage>
  );
}
