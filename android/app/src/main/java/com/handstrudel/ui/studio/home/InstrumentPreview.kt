package com.handstrudel.ui.studio.home

import com.handstrudel.engine.StudioEngine
import com.handstrudel.models.SoundFontInstrument

/**
 * The Music home's instrument preview (iOS `StartOverlayView.playPreview`:
 * a short phrase on voice "studio-preview" through the SoundFont sampler
 * while no session runs). False from [start] shows "Preview unavailable",
 * iOS's own failure path.
 */
internal object InstrumentPreview {
    fun start(engine: StudioEngine, instrument: SoundFontInstrument): Boolean = engine.previewStart(instrument)
    fun noteOn(engine: StudioEngine, midi: Int) = engine.previewNoteOn(midi, 0.7)
    fun stop(engine: StudioEngine) = engine.previewStop()
}
