# Invent a sound (Debug prototype)

In a Debug build, open Music > Invent a sound. Enter a description or tap a starter prompt. **Generate with AI** is available in Simulator with either bridge below. **Generate two synth variations** is a deterministic, offline fallback and does not use AI. Hear auditions a note and a chord. Play with hands opens the Scale wheel; touch works without a camera. Save privately keeps the sample on the device. This experiment is not in Release builds and does not publish presets, record clips, or join SharePlay from the private sound session.

## Run Stable Audio locally on an Apple Silicon Mac

Install the official [Stable Audio 3 MLX runtime](https://github.com/Stability-AI/stable-audio-3/tree/main/optimized/mlx) outside the HandStrudel repository. The following pins the runtime used for the prototype. The first run downloads roughly 2 GB of model weights. Review the upstream licenses before downloading or distributing generated samples.

```sh
git clone https://github.com/Stability-AI/stable-audio-3.git
git -C stable-audio-3 checkout 790793b89ddceea612be9ce42ff6830d18f6fa57
cd stable-audio-3/optimized/mlx
./install.sh --download sm-music
```

From the HandStrudel repository, start the bridge using the absolute path to that installation:

```sh
HANDSTRUDEL_AUDIO_MLX_DIR=/absolute/path/to/stable-audio-3/optimized/mlx node scripts/sound-lab.mjs
```

Set `HANDSTRUDEL_LOCAL_AUDIO_LAB=1` in the Xcode Debug Run environment (or `SIMCTL_CHILD_HANDSTRUDEL_LOCAL_AUDIO_LAB=1` when launching with `xcrun simctl launch`). Open Invent a sound and pick **Generate with AI**. The simulator connects only to `127.0.0.1:54339`. Once the models are installed, prompts and audio stay on the Mac and there is no API charge. If the first generated note fails pitch validation, the app retries once locally. There is no automatic fallback to the paid service.

## Other ways to try it

- **Optional cloud bridge:** start `node scripts/sound-lab.mjs` with `STABILITY_API_KEY` set only in the bridge shell and `HANDSTRUDEL_AUDIO_MLX_DIR` unset. Generate with AI identifies this backend before sending anything. It makes one paid request to the [Stable Audio API](https://platform.stability.ai/docs/api-reference/) without automatic retries. This is a simulator experiment, not a production API.
- **Physical iPhone Debug build:** choose **Import a generated WAV** to load a 0.25 to 4 second WAV (at most 4 MB) from Files. Use a dry single note around C4. Import checks for weak or unstable pitch, trims and tunes the note to C4, and maps it for the sampler. The Mac loopback generator is not reachable from an iPhone.

Each sound is a short one-shot, not a multisampled or sustained instrument. Import is tuned for notes around C4; harmonically ambiguous samples can still need a retry. Do not publish or redistribute generated WAVs without checking the provider's terms for isolated samples.

## Checks

`node --test scripts/sound-lab.test.mjs` tests the bridge without credentials or charges. The iOS tests cover pitch correction, offline sampler renders of a single note and four chord tones, and prompt/save/play UI. With the local MLX bridge running, `testInventASoundRealLocalAIOnSimulator` makes a real model request and opens the result in the wheel. It skips if the local bridge is unavailable and cannot select the paid backend.
