# iOS release checks

The iOS CI job runs the unit target and six signed-out Studio and Feed
journeys on a simulator. The shared `HandStrudel` scheme also includes the
full UI target. Some UI tests need local fixtures and deliberately skip
without them; read the `.xcresult` skip messages before calling a run complete.

## App Store Connect handoff

Before uploading, confirm that the version and build number are unused in
App Store Connect. The local candidate is **1.0.2 (43)**; check it against
the version train and TestFlight history. Use a Release archive from the
reviewed commit, not a Debug install.

- **Age rating:** The feed has user-generated content and social-media
  capabilities (public clips, comments, likes, sharing). Do not claim that
  social media is disabled for under-13 users through Apple's Declared Age
  Range API: the app does not implement that check. HandStrudel does not
  share real-world location or offer dating features. Review all answers,
  including the [November 16 descriptors](https://developer.apple.com/news/?id=yxkh08us),
  before submitting.
- **Privacy:** Check the App Store privacy answers against the archive's
  privacy manifests and the [live privacy policy](https://handstrudel.com/privacy).
  Public clips can include account-linked audio. The opt-in usage counter
  sends product interaction events for analytics without account or device
  IDs, not for tracking. Review the SDK disclosures too.
- **App Review access:** Supply working, dedicated reviewer access to all
  sign-in features. Confirm the reviewer can complete the email-code flow
  independently and can post, report, block, restore purchases, and delete
  their account. Include where each of those controls is found. Confirm the
  support inbox and report queue have an owner before submission.
- **Release notes (draft):** "Reply to any performance with your own take,
  and see every take on a sound on its new sound page. Play the daily sound
  to build a streak, learn a post's notes in Learn mode, and choose triads or
  7ths for wheel chords. Get notified when people play along, comment or
  reply, and invite friends to earn rewards."
- **Before the app:** deploy 1.0.2's migrations and Edge Functions
  (`send-push`, `grant-invite-rewards`, `moderation-media`), set their
  secrets (see `supabase/functions/.env.example`), then seed the official
  posts and daily-sound schedule (`scripts/seed-official/README.md`).

## On representative iPhones

Use the candidate build, a staging account for writes, and a clean install
as well as an upgrade with old drafts and presets.

- **First note:** Try both touch and air play. Deny camera access first, play
  a note and hold a chord by touch, then restore permissions. In air play,
  move between wedges, briefly occlude a pinching hand, and verify a visible
  unpinch still releases immediately.
- **Recording:** Make a normal and a half-speed performance. Stop early,
  trim, export, and play the exported clips in Photos with the sound on.
  Reopen an unshared private draft after relaunch. Check that a cancelled
  export or post does not delete it.
- **SharePlay:** Join a FaceTime call from two phones. On both ends, hold
  single notes and a four-note chord for at least three seconds and release
  deliberately. Repeat and overlap accents, test both a sampled instrument
  and a Web synth, and rejoin while the other player holds a note. Neither
  phone should hear a truncated chord or a note stuck after leaving.
- **Discovery:** Open a creator, watch and seek a clip, then play a public
  free-instrument preset. Follow, bookmark, reply, and tap a notification
  with staging accounts. Verify a shared link in Safari and from Messages,
  both with and without the app installed.
- **Commerce:** In the StoreKit sandbox, verify new purchase, restore,
  cancellation, and the separate lifetime vs managed subscription states.
  Leave App Store review prompts and production purchases out of smoke tests.

Record the build, iOS versions, devices, pass/fail and unresolved evidence.
A simulator test run or an unsigned device build does not replace these
device checks or an App Store submission review.
