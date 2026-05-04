export default function Privacy() {
  return (
    <div style={{ maxWidth: 700, margin: '0 auto', padding: '40px 20px', fontFamily: 'system-ui', color: '#fff', background: '#000', minHeight: '100vh' }}>
      <h1 style={{ color: '#00ff9d' }}>Privacy Policy</h1>
      <p><strong>Last updated:</strong> May 2026</p>

      <h2>Overview</h2>
      <p>HandStrudel is a hand-tracking musical instrument app. Your privacy matters to us. This policy explains what data we collect and how we use it.</p>

      <h2>Data We Collect</h2>
      <h3>Camera Data</h3>
      <p>HandStrudel uses your device&apos;s camera to track hand gestures in real-time. Camera images are processed <strong>entirely on your device</strong> using Apple&apos;s Vision framework. No camera data, images, or hand tracking data is ever sent to our servers or any third party.</p>

      <h3>Microphone Data</h3>
      <p>When you record a video to share, the microphone captures audio. This audio stays on your device and is only shared when you explicitly choose to share the recording.</p>

      <h3>App Settings</h3>
      <p>Your preferences (selected preset, key, scale, BPM, etc.) are stored locally on your device using UserDefaults. This data never leaves your device.</p>

      <h3>In-App Purchases</h3>
      <p>Purchases are handled entirely by Apple&apos;s App Store. We do not collect or store any payment information.</p>

      <h2>Data We Do NOT Collect</h2>
      <ul>
        <li>No personal information (name, email, phone number)</li>
        <li>No location data</li>
        <li>No analytics or tracking</li>
        <li>No advertising identifiers</li>
        <li>No data shared with third parties</li>
      </ul>

      <h2>SharePlay / Jam Sessions</h2>
      <p>When using SharePlay for jam sessions, musical note events are shared between participants via Apple&apos;s GroupActivities framework. Only note/drum hit data is transmitted — no camera, audio, or personal data.</p>

      <h2>Children&apos;s Privacy</h2>
      <p>HandStrudel does not knowingly collect any personal information from children under 13.</p>

      <h2>Changes</h2>
      <p>We may update this policy from time to time. Changes will be posted on this page.</p>

      <h2>Contact</h2>
      <p>Questions? Email us at <a href="mailto:support@handstrudel.com" style={{ color: '#00ff9d' }}>support@handstrudel.com</a></p>
    </div>
  );
}
