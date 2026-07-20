# handstrudel-core

Shared music logic for HandStrudel — written once in Rust, callable from iOS
(Swift), Android (Kotlin), and Web (Wasm/JS) via [UniFFI](https://mozilla.github.io/uniffi-rs/).

The audio output, hand tracking, and UI stay native per platform. Only the
deterministic "brain" lives here: music theory, pinch hysteresis, parameter
smoothing, and the mode state machines that turn `HandsState` → musical
actions.

## What's inside

| Module | Mirrors Swift | Exposed to FFI |
| --- | --- | --- |
| `music` | `Models/MusicTheory.swift` | `MusicKey`, `Scale`, `scale_notes`, `chord_notes`, `midi_note_name`, `quantize_to_scale`, `chord_display_name`, … |
| `pinch` | `Engine/PinchDetector.swift` | _internal_ — composed by mode managers |
| `smoother` | `Engine/ParamSmoother.swift` | `ParamSmoother` |
| `hands` | `Engine/HandTrackingManager` shape | `HandData`, `HandsState` |
| `grid_mode` | `Engine/GridModeManager.swift` | `GridModeManager`, `NoteAction` |
| `chord_melody_mode` | `Engine/ChordMelodyModeManager.swift` | `ChordMelodyModeManager`, `ChordMelodyAction`, `ChordToneTables` |

## Building

```bash
cd core
cargo build      # native build for the host (used for tests)
cargo test       # unit tests mirror the Swift behavior
```

## Cross-compiling for Android

Prerequisites (one-time):

```bash
brew install rustup
rustup default stable
rustup target add aarch64-linux-android armv7-linux-androideabi \
                  x86_64-linux-android i686-linux-android
cargo install cargo-ndk
brew install --cask android-ndk
export ANDROID_NDK_HOME=/opt/homebrew/share/android-ndk
```

Build all four Android ABIs at once and copy the `.so` files into the Android
project's `jniLibs/`:

```bash
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -t x86 \
          -o ../android/core/src/main/jniLibs \
          build --release
```

The Android Gradle build does this automatically — see [`../android/core/build.gradle.kts`](../android/core/build.gradle.kts).

## Generating Kotlin / Swift bindings

UniFFI generates language bindings from the compiled `.so`/`.dylib` (the FFI
metadata is embedded in the library, so the same artifact drives both
languages):

```bash
# Kotlin (for Android)
cargo run -p handstrudel-core --bin uniffi-bindgen -- generate \
    --library target/aarch64-linux-android/release/libhandstrudel_core.so \
    --language kotlin \
    --out-dir ../android/core/src/main/kotlin

# Swift (for iOS) — once you wire up the xcframework
cargo run -p handstrudel-core --bin uniffi-bindgen -- generate \
    --library target/release/libhandstrudel_core.dylib \
    --language swift \
    --out-dir ../ios/HandStrudel/HandStrudelCore
```

## Calling from Kotlin

```kotlin
import uniffi.handstrudel_core.MusicKey
import uniffi.handstrudel_core.Scale
import uniffi.handstrudel_core.chordNotes
import uniffi.handstrudel_core.GridModeManager

val notes = chordNotes(MusicKey.C, Scale.MAJOR, 0)        // [48, 52, 55]
val grid = GridModeManager()
val actions = grid.checkNotes(hands, scaleNotes, false, false)
```

## Design notes

- **All FFI types are values** — `HandsState`, `HandData`, `NoteAction`, etc.
  cross the boundary by value. Stateful objects (`GridModeManager`,
  `ChordMelodyModeManager`, `ParamSmoother`) are `uniffi::Object`s with
  interior `Mutex<State>` so methods can take `&self`.
- **No std collections in the public surface** — `Vec`, `Option`, primitives,
  and `HashMap<String, f64>` only. UniFFI's type system maps these cleanly to
  both Kotlin and Swift.
- **No closures across the boundary** — Swift's chord-melody manager takes
  `chordTones(_:)` closures; here the caller pre-resolves a
  [`ChordToneTables`](handstrudel-core/src/chord_melody_mode.rs) record
  indexed by degree instead. Same result, one less cross-language gotcha.
