package com.handstrudel.ui.studio.home

import com.handstrudel.engine.StudioEngine
import com.handstrudel.models.SoundFontInstrument

/**
 * The Music home's instrument preview (iOS `StartOverlayView.playPreview`:
 * a short phrase on voice "studio-preview" through the SoundFont sampler
 * while no session runs).
 *
 * TODO(engine): `StudioEngine` has no way to sound the sampler while idle.
 * Needed seam: `fun previewStart(instrument: SoundFontInstrument): Boolean`
 * (iOS `soundFontEngine.startIfNeeded` + `setInstrument`),
 * `fun previewNoteOn(midi: Int, velocity: Double)` and `fun previewStop()`
 * (iOS `hardStop` + `releaseTemporaryVoice("studio-preview")`). Until then
 * [start] returns false and the home shows "Preview unavailable", which is
 * iOS's own failure path.
 */
internal object InstrumentPreview {
    fun start(engine: StudioEngine, instrument: SoundFontInstrument): Boolean = false
    fun noteOn(engine: StudioEngine, midi: Int) = Unit
    fun stop(engine: StudioEngine) = Unit
}
