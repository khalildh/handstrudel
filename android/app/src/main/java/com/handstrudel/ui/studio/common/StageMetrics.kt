package com.handstrudel.ui.studio.common

/** Shared stage constants. */
object StageMetrics {
    /**
     * Camera frame aspect (width / height) after rotation: the ImageAnalysis
     * target is 480×640 portrait. iOS reads `handTracker.videoWidth / videoHeight`.
     * TODO(engine): expose the live frame aspect on `StudioEngine`/`HandTrackingManager`.
     */
    const val VIDEO_ASPECT = 0.75f
}
