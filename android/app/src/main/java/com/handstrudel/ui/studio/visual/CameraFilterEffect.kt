package com.handstrudel.ui.studio.visual

import android.graphics.ColorMatrixColorFilter
import android.graphics.RenderEffect
import android.os.Build
import android.view.View
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color

/**
 * Applies a filter's colour matrix to the camera preview view (iOS applies
 * `.saturation/.contrast/.brightness/.hueRotation` to `CameraView`). Uses
 * `View.setRenderEffect` on API 31+; below that only the overlay applies.
 */
fun applyCameraFilter(view: View, filter: CameraFilter) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
    view.setRenderEffect(
        if (filter.isIdentity) null
        else RenderEffect.createColorFilterEffect(ColorMatrixColorFilter(filter.colorMatrix)),
    )
}

/** The filter's colour wash (iOS `overlayColor.opacity(...).blendMode(...)`), drawn over the camera. */
@Composable
fun CameraFilterOverlay(filter: CameraFilter, modifier: Modifier = Modifier) {
    val rgb = filter.overlayColor ?: return
    if (filter.overlayOpacity <= 0f) return
    val blend = when (filter.blendMode) {
        FilterBlend.NORMAL -> BlendMode.SrcOver
        FilterBlend.MULTIPLY -> BlendMode.Multiply
        FilterBlend.SCREEN -> BlendMode.Screen
        FilterBlend.SOFT_LIGHT -> BlendMode.Softlight
    }
    Canvas(modifier) {
        drawRect(Color(rgb.r, rgb.g, rgb.b, filter.overlayOpacity), blendMode = blend)
    }
}
