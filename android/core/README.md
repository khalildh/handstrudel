# `:core` — Rust shared music logic

This Gradle module wraps the [`handstrudel-core`](../../core) Rust crate as an
Android library. It compiles the crate to `.so` files for all four Android
ABIs, runs UniFFI to generate Kotlin bindings, and ships both inside the
`:core` AAR so the app can call shared logic exactly like any other Kotlin
library.

## Build

Normally you do nothing — Gradle's `preBuild` depends on `:core:buildRustCore`,
which runs `cargo ndk` + `uniffi-bindgen` whenever the Rust sources change.
You can also kick it manually:

```bash
./gradlew :core:buildRustCore
```

This produces:

```
core/src/main/jniLibs/
    arm64-v8a/libhandstrudel_core.so
    armeabi-v7a/libhandstrudel_core.so
    x86_64/libhandstrudel_core.so
    x86/libhandstrudel_core.so
core/src/main/kotlin/uniffi/handstrudel_core/handstrudel_core.kt
```

Both directories are gitignored — they're build artifacts, not source.

## Prerequisites

The Gradle task shells out to `cargo` and `cargo ndk`, so you need them on
`PATH` (or wherever the task looks):

```bash
brew install rustup
rustup default stable
rustup target add aarch64-linux-android armv7-linux-androideabi \
                  x86_64-linux-android i686-linux-android
cargo install cargo-ndk
brew install --cask android-ndk
```

`build.gradle.kts` falls back to `/opt/homebrew/share/android-ndk` if
`ANDROID_NDK_HOME` is unset, so the Homebrew install works out of the box on
Apple Silicon. Otherwise export `ANDROID_NDK_HOME` to point at your NDK.

## Calling from app code

```kotlin
import uniffi.handstrudel_core.MusicKey
import uniffi.handstrudel_core.Scale
import uniffi.handstrudel_core.chordNotes
import uniffi.handstrudel_core.midiNoteName

val cmaj = chordNotes(MusicKey.C, Scale.MAJOR, 0)
    .joinToString(" ") { midiNoteName(it) }      // "C3 E3 G3"
```

JNA loads `libhandstrudel_core.so` lazily on first call into the binding.
