# Rules for the Android parity workstream agents

Six agents work in parallel, one per workstream (shell, engine, studio-ui, capture, social, store), each in its own git worktree branched from Phase 0 (`0268e705`):

| Workstream | Worktree | Branch |
|---|---|---|
| shell | /Volumes/PRO-G40/Code/handstrudel-android-shell | claude/android-ws-shell |
| engine | /Volumes/PRO-G40/Code/handstrudel-android-engine | claude/android-ws-engine |
| studio-ui | /Volumes/PRO-G40/Code/handstrudel-android-studio-ui | claude/android-ws-studio-ui |
| capture | /Volumes/PRO-G40/Code/handstrudel-android-capture | claude/android-ws-capture |
| social | /Volumes/PRO-G40/Code/handstrudel-android-social | claude/android-ws-social |
| store | /Volumes/PRO-G40/Code/handstrudel-android-store | claude/android-ws-store |

## Scope
- The spec is `docs/android-parity.md`. Your workstream section (WS1–WS6), section 3.0 / 3.0.1 (Phase 0 decisions) and 3.7 (seam ownership) are binding.
- Edit only the files your workstream owns. If you need a change to a seam you don't own, don't edit it: code against the seam as it is, add a `// TODO(<owner-ws>):` note at the call site, and list the request in your report. Additive changes to your own seam are fine; never break another workstream's view of a seam (no renames/removals of seam members).
- Port behaviour from the iOS 1.0.1 code (`ios/HandStrudel/HandStrudel/`), matching it closely: copy, labels, limits, edge cases. Read the iOS code, not just the spec.
- Dependencies are already declared in `android/app/build.gradle.kts` in per-workstream blocks; only touch your own block.

## Build and machine limits (24 GB RAM shared by six agents)
- Environment: `export PATH=/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH`. Gradle/cargo need the sandbox disabled (network + ~/.gradle, ~/.cargo).
- Hold the build lock for every Gradle run, and use `--no-daemon`:
  `until mkdir /tmp/handstrudel-android-build.lock 2>/dev/null; do sleep 10; done; (cd android && ./gradlew --no-daemon <tasks>); rc=$?; rmdir /tmp/handstrudel-android-build.lock; exit $rc`
  Always release the lock, even on failure. Run long builds in the background and wait for the notification.
- Except engine (which changes Rust), set `CARGO_TARGET_DIR=/Volumes/PRO-G40/DerivedData/android-cargo-target` so the Rust core is built once.
- Disk is tight (~45 GB free on each drive). Don't create extra copies of assets; clean anything large you create in scratch.

## Emulator
- One emulator at a time across all agents: hold `/tmp/handstrudel-android-emulator.lock` (same mkdir pattern) for the whole time an emulator runs.
- The owner's `Pixel_9_Pro_Fold` AVD is nearly full; don't use it or install into it. Create a throwaway AVD (e.g. `ws-<name>`) from an installed system image, run headless (`-no-window -no-audio -no-snapshot`), and when finished kill the emulator and `avdmanager delete avd -n ws-<name>`. Release the lock.
- Verify real behaviour: drive the UI (adb `input`, `uiautomator dump`), screenshot with `adb exec-out screencap -p`, and assert the result. "It compiles" is not verified.

## Secrets and outside services
- Never print or commit the Supabase key (it comes into BuildConfig from `SocialConfig.swift` at build time), `supabase/functions/.env`, or any other secret.
- Don't touch production Supabase (project `eygrtqbtbhktptphqdnn`) with writes. Reads of public data (the anon feed) are OK. For anything that writes (sign-in, posting, likes), use a local Supabase stack: hold `/tmp/handstrudel-supabase.lock` while starting/using/stopping the shared one, or start an isolated one with its own project id and ports, and stop what you start. The emulator reaches the host at `10.0.2.2`.
- Don't create accounts on real services, don't enter real credentials. No RevenueCat/Google keys exist yet: code must degrade gracefully when they are absent (see spec section 4).

## Finishing
- Unit tests for your logic (`./gradlew :app:testDebugUnitTest`) must pass; `:app:assembleDebug` must pass.
- Commit to your branch with clear messages ending in `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Don't push, don't merge other branches.
- Report: what's done (feature by feature, against your WS section), what was verified on the emulator and how, what isn't done or verified, seam change requests for other workstreams, and confirm emulator/AVD/Supabase stacks are cleaned up.
