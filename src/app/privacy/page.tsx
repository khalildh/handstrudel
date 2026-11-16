import type { Metadata } from "next";
import { infoViewport, SiteInfoPage } from "../site-info-page";

export const metadata: Metadata = { title: "Privacy Policy | HandStrudel" };
export const viewport = infoViewport;

export default function Privacy() {
  return (
    <SiteInfoPage title="Privacy Policy" path="/privacy">
      <p><strong>Last updated:</strong> November 2026</p>

      <h2>Overview</h2>
      <p>HandStrudel is a hand-tracking musical instrument app. Your privacy matters to us. This policy explains what data we collect and how we use it. You can play, watch videos, and read comments without an account. You need an account to post videos or comments and use other social features.</p>

      <h2>Data processed only on your device</h2>
      <h3>Camera</h3>
      <p>HandStrudel uses your camera to track hand gestures in real time. Camera frames are processed <strong>entirely on your device</strong> using Apple&apos;s Vision framework and are never sent to us or anyone else. The only video that leaves your device is a recording you explicitly choose to post or share.</p>

      <h3>Microphone</h3>
      <p>Clips include the app&apos;s audio. If you enable the microphone for a solo take, the clip can also include your voice and sounds around you. The recording stays on your device unless you post or share it. Audio in a public clip is public too.</p>

      <h3>App settings</h3>
      <p>Your preferences (instrument, key, scale, BPM, and so on) are stored locally on your device.</p>

      <h2>If you create an account</h2>
      <p>When you sign in and post, we collect:</p>
      <ul>
        <li><strong>Account identifiers:</strong> a user ID, and your email address (or Apple&apos;s private relay address if you use Sign in with Apple and hide your email).</li>
        <li><strong>Profile:</strong> your username, when you accepted our terms, and any display name or profile photo you choose to add. <strong>Your profile photo is public.</strong> We upload only the image you select, not your photo library, and strip its metadata.</li>
        <li><strong>Your posts:</strong> the videos, thumbnails, and captions you post, plus the instrument and play mode used. <strong>Posts are public.</strong></li>
        <li><strong>Your comments:</strong> the text you post, its timestamp, and the video or comment you reply to. <strong>Comments and your username are public.</strong></li>
        <li><strong>Activity:</strong> likes, follows, blocks, reports, and the performances you save. Your saved list is private to your account.</li>
      </ul>
      <p>We use this only to run HandStrudel: to sign you in, show your posts, power the feed, keep the community safe, and contact you about your account. We don&apos;t sell your data, show ads, or track you across other apps or websites.</p>

      <h2>Public video views</h2>
      <p>Public videos also show aggregate view counts. We count playback, not just loading the page, and use a random code for each watched clip to avoid counting the same session's replays. The code is not reused across clips and is separate from optional usage analytics.</p>

      <h2>Optional app usage analytics</h2>
      <p>You can opt in from Account settings in the app. We count days the app is used, use on a later day, first notes played, and recordings started, saved to Private drafts, and posted. We store daily totals, not individual activity histories. The app does not send account or device IDs, played pitches, custom scale names, gestures, audio, or camera imagery with these events. Turn off Usage Analytics in Account settings to stop sending events.</p>

      <h2>Website analytics and download metrics</h2>
      <p>We use <a href="https://vercel.com/docs/analytics/privacy-policy">Vercel Web Analytics</a> to count visitors and page views and understand how people find the website. This includes information such as the page path, referrer, general location, and browser or device type. We remove query strings and fragments from reported page URLs. Analytics does not use third-party cookies or link visits to HandStrudel accounts.</p>
      <p>We use Vercel Speed Insights to measure how quickly pages load and respond. These measurements are not linked to HandStrudel accounts, and we remove query strings and fragments from the page URLs reported with them.</p>
      <p>We count homepage App Store button clicks by day and button location. These counts don&apos;t include an account ID and don&apos;t use a tracking cookie. The buttons carry a shared campaign label so Apple can report aggregate App Store downloads from the homepage. We don&apos;t match individual clicks to downloads.</p>

      <h2>Service providers</h2>
      <p>We use a small number of providers to run the service, who process data only on our behalf:</p>
      <ul>
        <li><strong>Supabase</strong> — accounts, sign-in, and the database.</li>
        <li><strong>Cloudflare R2</strong> — storing and serving posted videos, thumbnails, and public profile photos.</li>
        <li><strong>Sightengine</strong> — automated content screening of videos and thumbnails you submit for public posting. Recordings kept in Private drafts are not submitted.</li>
        <li><strong>Resend</strong> — sending sign-in code emails.</li>
        <li><strong>Vercel</strong> — hosting the website and providing website analytics.</li>
        <li><strong>Apple</strong> — Sign in with Apple and in-app purchases (we never see payment details).</li>
        <li><strong>RevenueCat</strong> — managing in-app purchase status, linked to your account ID when you&apos;re signed in.</li>
      </ul>

      <h2>Your choices</h2>
      <ul>
        <li>Delete any of your posts at any time from your profile.</li>
        <li>Replace or remove your public photo from Edit Profile. Previously shared image URLs may remain in caches for a limited time.</li>
        <li>Delete your comments using the menu beside them.</li>
        <li>Delete your account from your profile (<strong>⋯ → Delete account</strong>). This permanently removes your profile, posts, comments, and files from our systems.</li>
        <li>Email us to ask for a copy of your data or to correct it.</li>
      </ul>

      <h2>SharePlay / Jam Sessions</h2>
      <p>During SharePlay jam sessions, musical note events are shared between participants via Apple&apos;s GroupActivities framework. No camera, audio, or personal data is transmitted.</p>

      <h2>Children</h2>
      <p>Accounts are for people 13 and older. We don&apos;t knowingly collect personal information from children under 13; if you believe a child has created an account, contact us and we&apos;ll delete it.</p>

      <h2>Changes</h2>
      <p>We may update this policy. Changes will be posted on this page, and significant changes will be announced in the app.</p>

      <h2>Contact</h2>
      <p>Questions or requests: <a href="mailto:hello@handstrudel.com">hello@handstrudel.com</a></p>
    </SiteInfoPage>
  );
}
