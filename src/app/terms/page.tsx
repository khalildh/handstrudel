import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Terms of Use · HandStrudel' };

const page = { maxWidth: 700, margin: '0 auto', padding: '40px 20px', fontFamily: 'system-ui', color: '#fff', background: '#000', minHeight: '100vh', lineHeight: 1.55 } as const;
const link = { color: '#00ff9d' } as const;

export default function Terms() {
  return (
    <div style={page}>
      <h1 style={{ color: '#00ff9d' }}>Terms of Use</h1>
      <p><strong>Last updated:</strong> November 2026</p>

      <p>These terms apply when you use the HandStrudel app and website (&ldquo;HandStrudel&rdquo;, &ldquo;we&rdquo;). By creating an account or posting a video you agree to them, and to our <a href="/community" style={link}>Community Guidelines</a> and <a href="/privacy" style={link}>Privacy Policy</a>.</p>

      <h2>Who can use HandStrudel</h2>
      <p>You must be at least 13 years old to create an account. If you are under the age of majority where you live, a parent or guardian must agree to these terms on your behalf.</p>

      <h2>Your account</h2>
      <p>You can sign in with Apple or with a one-time code sent to your email. Keep access to your account secure and don&apos;t impersonate anyone. You can delete your account at any time from your profile; this permanently removes your profile and every video you&apos;ve posted.</p>

      <h2>Your content</h2>
      <p>You own the videos and captions you post. By posting, you give HandStrudel a worldwide, non-exclusive, royalty-free license to host, store, display, and distribute that content inside HandStrudel and in promotion of HandStrudel, for as long as it stays posted. You confirm you have the rights to everything in your post, including any people, audio, or music it contains.</p>
      <p>Posts are public. Anyone can watch them in the app, including people who aren&apos;t signed in.</p>

      <h2>No objectionable content or abusive behavior</h2>
      <p>There is <strong>zero tolerance</strong> for objectionable content or abusive users. Don&apos;t post anything that breaks the <a href="/community" style={link}>Community Guidelines</a>: no nudity or sexual content, no hate, harassment, threats, or bullying, no violence or self-harm, no illegal activity, no spam, and nothing that infringes someone else&apos;s rights.</p>

      <h2>Reporting, blocking, and moderation</h2>
      <p>Every post can be reported and every user can be blocked from inside the app. Reported posts are hidden automatically once several people report them, and we review reports within 24 hours. We may remove any content and suspend or terminate any account that breaks these terms, without notice.</p>

      <h2>The app</h2>
      <p>HandStrudel is provided &ldquo;as is&rdquo;. We work hard to keep it running, but we don&apos;t guarantee it will always be available or error-free, and we may change or discontinue features. Purchases are handled by Apple and are subject to Apple&apos;s terms.</p>

      <h2>Liability</h2>
      <p>To the extent the law allows, HandStrudel isn&apos;t liable for indirect or consequential damages, or for content posted by other users. Nothing in these terms limits rights you have under consumer law that can&apos;t be waived.</p>

      <h2>Changes</h2>
      <p>We may update these terms. If the changes are significant we&apos;ll let you know in the app. Continuing to use HandStrudel after a change means you accept the updated terms.</p>

      <h2>Contact</h2>
      <p>Questions or reports: <a href="mailto:hello@handstrudel.com" style={link}>hello@handstrudel.com</a></p>
    </div>
  );
}
