// Per-GM-program level trims (dB) that match TinySoundFont's output level to Apple's
// AVAudioUnitSampler (the iOS SoundFont engine) for the bundled GeneralUser-GS.sf2.
// Measured offline on a Mac: a C-major triad at velocities 0.5 and 0.9 rendered for 2 s
// through both engines with the app's settings (TSF: 0 dB, SF2 velocity curve; Apple:
// sampler into the main mixer, GM melodic bank), trim = mean(Apple RMS - TSF RMS).
// Clamped to +/-12 dB; program 49 is 0 (Apple's render of it was invalid).
#pragma once
static const float kSamplerLevelTrimDb[128] = {
      6.20f,   6.03f,  -1.69f,   6.63f,  -3.56f, -12.00f,  -4.53f,  -5.72f,
     -4.93f,  -4.68f,  -3.08f,  -5.13f,   9.39f,  -3.97f,  -4.34f,  -3.87f,
     -4.26f,  -4.26f,  -4.25f,  -4.29f,   4.15f,  -4.16f,  -4.38f,  -4.27f,
     -4.86f,   4.81f,  -4.13f,  -4.43f,  -4.76f,  -4.77f,  -6.13f,  -6.76f,
     -3.99f,  -3.91f,  -4.13f,  -3.93f,  -4.17f, -12.00f, -12.00f,  -3.58f,
     -4.24f,  -4.22f,  -4.24f,  -4.25f,  -4.89f,  -4.59f,  -4.42f,  -4.41f,
     -4.28f,   0.00f,  -4.68f,  -5.56f,  -1.67f,  -4.30f,  -4.35f,  -4.22f,
     -4.66f,  -4.50f,  -4.90f,  -4.70f,   4.29f,  -0.78f,  12.00f, -12.00f,
     -4.59f,  -4.44f,  -6.65f,  -4.60f,  -4.89f,  -4.24f,  -4.24f,  -4.47f,
     -4.55f,  -4.24f,  -4.24f,  -4.29f,  -4.63f,  -4.27f,  -6.91f,  -4.26f,
     -5.40f,  12.00f,  -5.09f,  -4.47f,  -3.04f,  -4.23f,  -8.77f,  -3.89f,
      1.98f,   9.72f,  -4.43f,  -4.91f,  -5.06f,  -7.16f,  -4.54f,  -4.84f,
      2.56f,  -8.37f,  -5.13f,  -7.07f,  -5.34f,  -3.68f,  -5.48f,  -5.10f,
     -4.25f,  -4.36f,  -6.44f,  -4.31f,  -4.74f,  -3.65f,  -4.24f,  -4.92f,
     -4.77f,  -4.51f,  -4.24f,  -4.14f,  -4.90f,  -3.55f,  -4.15f,  -4.64f,
     -3.67f,  -6.18f,  -2.88f,  -4.28f,  -1.84f,   2.04f,  -3.77f,  -2.89f,
};
