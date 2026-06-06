# SoundFonts

This folder holds the General MIDI **SoundFont** (`.sf2`) used by **SoundFont
mode** (`SoundFontEngine.swift` → `AVAudioUnitSampler`).

A SoundFont is **not committed to the repo** — it's a large binary and the
choice of bank (and its license) is the app owner's call. Drop one `.sf2` file
into this folder and rebuild; `SoundFontEngine` loads the first `.sf2`/`.dls`
it finds here. Until a file is present, SoundFont mode is selectable but silent.

## Recommended bank

**GeneralUser GS** by S. Christian Collins — high quality, ~30 MB, and its
license explicitly permits royalty-free use in commercial software (including
App Store apps). https://www.schristiancollins.com/generaluser.php

Any GM-compliant `.sf2` works; instrument selection uses standard GM program
numbers (see `SoundFontInstrument.swift`).

## Bundling notes

`Resources/soundfonts` is referenced in the Xcode project as a **folder
reference** (blue folder), so any file placed here is copied into the app
bundle automatically — no need to add it to the project manually. If you
regenerate the project with XcodeGen, the folder reference is preserved via
`project.yml`'s `resources:` entry.

> Licensing: confirm the redistribution terms of whatever SoundFont you ship.
> Many popular banks (e.g. TimGM6mb, FluidR3) are GPL or have attribution
> requirements that may not suit a closed-source App Store build.
