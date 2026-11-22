package com.handstrudel.ui.studio.common

/** Shared stage constants. */
object StageMetrics {
    /**
     * Camera frame aspect (width / height) after rotation: the ImageAnalysis
     * target is 480×640 portrait. Fallback until frames arrive; overlays use [videoAspect].
     */
    const val VIDEO_ASPECT = 0.75f

    /** The live frame aspect (iOS `handTracker.videoWidth / videoHeight`). */
    fun videoAspect(engine: com.handstrudel.engine.StudioEngine): Float =
        engine.cameraAspect.toFloat().takeIf { it.isFinite() && it > 0f } ?: VIDEO_ASPECT
}
