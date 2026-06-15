package com.handstrudel.engine

import com.handstrudel.models.MusicKey
import com.handstrudel.models.Scale
import uniffi.handstrudel_core.MusicKey as CoreKey
import uniffi.handstrudel_core.Scale as CoreScale

/// One element on the chord half of the Split wheel — wedge + octave sub-band.
/// Used as a hashable id for touch highlight tracking.
data class ChordSubzone(val wedge: Int, val octave: Int)

internal fun HandsState.toCoreHands(): uniffi.handstrudel_core.HandsState =
    uniffi.handstrudel_core.HandsState(
        left = this.left?.toCoreHand(),
        right = this.right?.toCoreHand()
    )

internal fun HandData.toCoreHand(): uniffi.handstrudel_core.HandData =
    uniffi.handstrudel_core.HandData(
        pinchX = this.pinchX,
        pinchY = this.pinchY,
        pinch = this.pinch
    )

fun MusicKey.toCoreKey(): CoreKey = when (this) {
    MusicKey.C -> CoreKey.C
    MusicKey.Db -> CoreKey.DB
    MusicKey.D -> CoreKey.D
    MusicKey.Eb -> CoreKey.EB
    MusicKey.E -> CoreKey.E
    MusicKey.F -> CoreKey.F
    MusicKey.Gb -> CoreKey.GB
    MusicKey.G -> CoreKey.G
    MusicKey.Ab -> CoreKey.AB
    MusicKey.A -> CoreKey.A
    MusicKey.Bb -> CoreKey.BB
    MusicKey.B -> CoreKey.B
}

fun Scale.toCoreScale(): CoreScale = when (this) {
    Scale.MAJOR -> CoreScale.MAJOR
    Scale.MINOR -> CoreScale.MINOR
    Scale.DORIAN -> CoreScale.DORIAN
    Scale.PENTATONIC -> CoreScale.PENTATONIC
    Scale.BLUES -> CoreScale.BLUES
    Scale.HARMONIC_MINOR -> CoreScale.HARMONIC_MINOR
    Scale.MELODIC_MINOR -> CoreScale.MELODIC_MINOR
    Scale.PHRYGIAN -> CoreScale.PHRYGIAN
    Scale.LYDIAN -> CoreScale.LYDIAN
    Scale.MIXOLYDIAN -> CoreScale.MIXOLYDIAN
    Scale.LOCRIAN -> CoreScale.LOCRIAN
    Scale.WHOLE_TONE -> CoreScale.WHOLE_TONE
    Scale.CHROMATIC -> CoreScale.CHROMATIC
    Scale.HUNGARIAN_MINOR -> CoreScale.HUNGARIAN_MINOR
    Scale.HIRAJOSHI -> CoreScale.HIRAJOSHI
}
