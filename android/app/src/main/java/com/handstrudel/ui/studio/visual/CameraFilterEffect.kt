package com.handstrudel.ui.studio.visual

import android.graphics.ColorMatrixColorFilter
import android.graphics.RenderEffect
import android.os.Build
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.graphicsLayer

/**
 * The filter's colour matrix as a layer effect (iOS applies `.saturation/.contrast/
 * .brightness/.hueRotation` to the ZStack of the camera and the colour overlay, so the
 * overlay is filtered too). Put it on a container that holds [CameraFilterOverlay] and
 * the preview. API 31+ only; below that just the overlay shows.
 */
fun Modifier.cameraFilterEffect(filter: CameraFilter): Modifier =
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) this
    else graphicsLayer {
        renderEffect = if (filter.isIdentity) null
        else RenderEffect.createColorFilterEffect(ColorMatrixColorFilter(filter.colorMatrix)).asComposeRenderEffect()
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
