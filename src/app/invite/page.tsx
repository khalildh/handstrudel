import type { Metadata } from "next";
import { infoViewport, SiteInfoPage } from "../site-info-page";
import { InviteCode } from "./invite-code";

export const metadata: Metadata = {
  title: "You're invited | HandStrudel",
  description: "Play music with your hands. Join HandStrudel with a friend's invite.",
};
export const viewport = infoViewport;

// If HandStrudel is installed, iOS opens this link in the app (see apple-app-site-association)
// and the code is filled in for you. Otherwise this page shows the code to enter after installing.
export default function Invite() {
  return (
    <SiteInfoPage title="You're invited" path="/invite">
      <p>A friend invited you to HandStrudel, the instrument you play with your hands.</p>
      <InviteCode />
      <h2>How it works</h2>
      <ol>
        <li>Get HandStrudel from the App Store. It&apos;s free.</li>
        <li>Create an account. When you choose your username, tap <strong>Did someone introduce you?</strong>, then paste the code, or search for your friend&apos;s @username.</li>
        <li>Post your first take. Once it passes our routine content check, you and your friend each get 7 days of HandStrudel+, free. No purchase needed, and it doesn&apos;t renew.</li>
      </ol>
      <p className="invite-fine-print">Add the code (or your friend&apos;s @username) while setting up your account, before your first post. Each person can be rewarded for up to 10 friends.</p>
    </SiteInfoPage>
  );
}
