import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Community Guidelines · HandStrudel' };

const page = { maxWidth: 700, margin: '0 auto', padding: '40px 20px', fontFamily: 'system-ui', color: '#fff', background: '#000', minHeight: '100vh', lineHeight: 1.55 } as const;
const link = { color: '#00ff9d' } as const;

export default function Community() {
  return (
    <div style={page}>
      <h1 style={{ color: '#00ff9d' }}>Community Guidelines</h1>
      <p><strong>Last updated:</strong> November 2026</p>

      <p>HandStrudel is a place to show off music you made with your hands. Keep it fun, kind, and about the music. These guidelines are part of our <a href="/terms" style={link}>Terms of Use</a>.</p>

      <h2>Post</h2>
      <ul>
        <li>Performances you recorded in HandStrudel, your own hands, your own takes.</li>
        <li>Captions that describe what you played, how you made it, or what you&apos;re going for.</li>
        <li>Duets, covers, and remixes of ideas, as long as the recording is yours.</li>
      </ul>

      <h2>Don&apos;t post</h2>
      <ul>
        <li><strong>Nudity or sexual content</strong> of any kind.</li>
        <li><strong>Hate, harassment, or bullying</strong>: attacks on people for who they are, threats, or targeting someone.</li>
        <li><strong>Violence, self-harm, or dangerous acts.</strong></li>
        <li><strong>Anything involving minors</strong> that is sexual, exploitative, or puts them at risk.</li>
        <li><strong>Illegal activity</strong>, including drugs, weapons sales, or scams.</li>
        <li><strong>Spam</strong>: repetitive posts, misleading links, or engagement bait.</li>
        <li><strong>Other people&apos;s content</strong>: someone else&apos;s video, or copyrighted music you don&apos;t have rights to.</li>
        <li><strong>Private information</strong> about anyone, including yourself (addresses, phone numbers, IDs).</li>
        <li><strong>Impersonation</strong> of another person or brand.</li>
      </ul>

      <h2>Be safe</h2>
      <p>Record in a space where you&apos;re comfortable with what the camera sees. Your recordings show your screen and your hands; avoid filming other people without their permission.</p>

      <h2>Report and block</h2>
      <p>If you see something that breaks these rules, use the options menu on the post or comment to report it. Posts and comments with several reports are hidden automatically while we review them, and we act on reports within 24 hours. You can also <strong>Block</strong> anyone so you won&apos;t see each other&apos;s posts or comments. If you&apos;re watching on the web, email <a href="mailto:hello@handstrudel.com" style={link}>hello@handstrudel.com</a> to report a comment.</p>

      <h2>What happens if you break the rules</h2>
      <p>We remove content that breaks these guidelines, and accounts that do it repeatedly or seriously are suspended or deleted. Illegal content is reported to the authorities.</p>

      <h2>Contact</h2>
      <p>Report something urgent or appeal a decision: <a href="mailto:hello@handstrudel.com" style={link}>hello@handstrudel.com</a></p>
    </div>
  );
}
