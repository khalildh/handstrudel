# SoundFonts

This folder holds the General MIDI **SoundFont** (`.sf2`) used by **SoundFont
mode** (`SoundFontEngine.swift` → `AVAudioUnitSampler`) and by the SoundFont
voicing path in **Split** / **Radial** chord+melody.

`Resources/soundfonts/GeneralUser-GS.sf2` is **committed** to the repo so a
fresh clone produces a working release build out of the box — Split mode (the
default on first launch) routes through the sampler, so a missing `.sf2` would
land new users in silence.

## The bundled bank

**GeneralUser GS** by S. Christian Collins — ~31 MB, GM-compliant, and licensed
for royalty-free use in commercial software including App Store apps. See
https://www.schristiancollins.com/generaluser.php for the upstream project.

Instrument selection uses standard GM program numbers (see
`SoundFontInstrument.swift`). `SoundFontEngine` loads the first `.sf2`/`.dls`
it finds in this folder, so any GM-compliant bank can drop in as a replacement.

## Bundling notes

`Resources/soundfonts` is referenced in the Xcode project as a **folder
reference** (blue folder), so any file placed here is copied into the app
bundle automatically — no need to add it to the project manually. If you
regenerate the project with XcodeGen, the folder reference is preserved via
`project.yml`'s `resources:` entry.

> If you ever swap the bank for another one: confirm its redistribution terms
> first. Several popular banks (TimGM6mb, FluidR3) are GPL-licensed and not
> safe for a closed-source App Store build.
