# iOS release checks

The iOS CI job runs the unit target and five signed-out Studio and Feed
journeys on a simulator. The shared `HandStrudel` scheme also includes the
full UI target. Some UI tests need local fixtures and deliberately skip
without them; read the `.xcresult` skip messages before calling a run complete.

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
