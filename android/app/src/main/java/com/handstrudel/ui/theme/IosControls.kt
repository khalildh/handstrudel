package com.handstrudel.ui.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Slider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp

/**
 * The two stock UIKit controls iOS 1.0.1 uses throughout (SwiftUI `Toggle` and `Slider`
 * with `.tint(...)`), drawn to the measured iOS geometry so every Android screen that
 * ports one of them looks the same. Material's Switch/Slider read very differently
 * (inset thumb, thick track), so Android uses these instead.
 */
object IosControls {
    /** iOS off-track / maximum-track fill: `rgba(120,120,128)` at 32 % (dark) or 16 % (light). */
    fun offTrack(light: Boolean): Color = Color(0xFF787880).copy(alpha = if (light) 0.16f else 0.32f)
}

/**
 * iOS `Toggle` switch: 51 x 31 pt track, 27 pt white round thumb inset 2 pt, [tint] track
 * when on and a translucent grey track when off.
 */
@Composable
fun IosSwitch(
    checked: Boolean,
    onCheckedChange: ((Boolean) -> Unit)?,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = LocalStudioPalette.current.accent,
    offTrack: Color = IosControls.offTrack(LocalStudioTheme.current.isLight),
) {
    val track by animateColorAsState(if (checked) tint else offTrack, tween(200), label = "iosSwitchTrack")
    val x by animateDpAsState(if (checked) 22.dp else 2.dp, tween(200), label = "iosSwitchThumb")
    val toggle = if (onCheckedChange != null) {
        Modifier.toggleable(
            value = checked,
            enabled = enabled,
            role = Role.Switch,
            interactionSource = remember { MutableInteractionSource() },
            indication = null,
            onValueChange = onCheckedChange,
        )
    } else Modifier
    Box(
        modifier.then(toggle).size(51.dp, 31.dp).alpha(if (enabled) 1f else 0.5f)
            .background(track, CircleShape),
        contentAlignment = Alignment.CenterStart,
    ) {
        Box(
            Modifier.offset(x = x).size(27.dp)
                .shadow(2.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.25f), spotColor = Color.Black.copy(alpha = 0.25f))
                .background(Color.White, CircleShape),
        )
    }
}

/**
 * iOS `Slider`: a 4 pt rounded track ([tint] up to the value, grey after) under a 27 pt
 * white round thumb. Material's slider supplies the gestures, steps and accessibility.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IosSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    valueRange: ClosedFloatingPointRange<Float> = 0f..1f,
    steps: Int = 0,
    enabled: Boolean = true,
    onValueChangeFinished: (() -> Unit)? = null,
    tint: Color = LocalStudioPalette.current.accent,
    inactiveTrack: Color = IosControls.offTrack(LocalStudioTheme.current.isLight),
    thumbSize: androidx.compose.ui.unit.Dp = 27.dp,
) {
    val interaction = remember { MutableInteractionSource() }
    Slider(
        value = value.coerceIn(valueRange.start, valueRange.endInclusive),
        onValueChange = onValueChange,
        modifier = modifier.alpha(if (enabled) 1f else 0.5f),
        enabled = enabled,
        valueRange = valueRange,
        steps = steps,
        onValueChangeFinished = onValueChangeFinished,
        interactionSource = interaction,
        thumb = {
            Box(
                Modifier.size(thumbSize)
                    .shadow(2.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.25f), spotColor = Color.Black.copy(alpha = 0.25f))
                    .background(Color.White, CircleShape),
            )
        },
        track = { state ->
            val span = state.valueRange.endInclusive - state.valueRange.start
            val fraction = if (span <= 0f) 0f else ((state.value - state.valueRange.start) / span).coerceIn(0f, 1f)
            // Material lays the track out between the thumb centres; iOS runs it to the
            // control's edges, so draw half a thumb past each end.
            Canvas(Modifier.fillMaxWidth().height(4.dp).padding(horizontal = 0.dp)) {
                val extend = thumbSize.toPx() / 2f - size.height / 2f
                val y = size.height / 2f
                val startX = -extend
                val endX = size.width + extend
                val valueX = size.width * fraction
                drawLine(inactiveTrack, Offset(startX, y), Offset(endX, y), size.height, StrokeCap.Round)
                drawLine(tint, Offset(startX, y), Offset(valueX, y), size.height, StrokeCap.Round)
            }
        },
    )
}
