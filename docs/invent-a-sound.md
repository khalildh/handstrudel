# Invent a sound (Debug prototype)

In a Debug build, open Music > Invent a sound. Enter a description or tap a starter prompt. The local synth generates two deterministic pluck/bell variations without a network request. Hear auditions a note and a chord. Play with hands opens the normal Scale wheel with the new sampler sound; touch still works without a camera. Save privately keeps the sample in the on-device library. The experiment is not available in Release builds and does not publish presets, record clips, or join SharePlay from the private sound session.

## Try an actual audio model

- **On an iPhone:** generate a dry, single note around C4 with a provider you have rights to use. Save a 0.25–4 second WAV (max 4 MB) to Files and choose Import a generated WAV. Import measures pitch, rejects weak or unstable pitches, trims and tunes the note to C4, and maps it for the sampler.
- **In Simulator:** run `node scripts/sound-lab.mjs` with `STABILITY_API_KEY` set in that shell. Do not put that key in the app or scheme. Set `HANDSTRUDEL_LOCAL_AUDIO_LAB=1` in the Debug Run scheme (or use `SIMCTL_CHILD_HANDSTRUDEL_LOCAL_AUDIO_LAB=1` with `xcrun simctl launch`). Generate with Stable Audio submits one paid request to the [Stable Audio API](https://platform.stability.ai/docs/api-reference/) via the Mac loopback bridge. It is deliberately not a production API.

Each sound is a short one-shot, not a multisampled or sustained instrument. Import is tuned for notes around C4; harmonically ambiguous samples can still need a retry. Do not publish or redistribute generated WAVs without checking the provider's terms for isolated samples.

## Checks

`node --test scripts/sound-lab.test.mjs` exercises provider polling and validation without credentials or charges. The iOS prototype tests cover pitch correction, actual offline native sampler renders of a single note and four simultaneous chord tones, and the prompt/save/play UI.
