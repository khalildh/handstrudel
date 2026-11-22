package com.handstrudel.ui.studio.onboarding

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.ui.studio.common.WheelGeometry
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlin.math.roundToInt

/** iOS `OnboardingView` copy, as a pure function of (played, canSuggestPinching). */
object OnboardingCopy {
    fun title(played: Boolean, pinch: Boolean) =
        if (!played) "Play your first note" else if (pinch) "Now try a pinch" else "Tap or slide to play"

    fun body(played: Boolean, pinch: Boolean) = when {
        !played -> "Tap the highlighted note on the wheel."
        pinch -> "Hold your hand over a note and pinch your thumb and index finger. You can also tap or drag on the wheel."
        else -> "Tap or slide across the wheel for a melody. Touch its other half to play chords."
    }

    fun button(played: Boolean) = if (played) "Keep playing" else "Skip"
}

/**
 * iOS `OnboardingView`: shown once over the running Scale wheel. A dimming
 * layer blocks other touches until the highlighted first note (the middle
 * scale note) is played; then the card suggests a pinch (camera) or touch.
 */
@Composable
fun OnboardingOverlay(
    noteName: String,
    melodyLaneCount: Int,
    swapHands: Boolean,
    canSuggestPinching: Boolean,
    playFirstNote: () -> Unit,
    onDone: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    var played by remember { mutableStateOf(false) }
    BoxWithConstraints(Modifier.fillMaxSize().testTag("onboarding")) {
        val density = LocalDensity.current
        val w = with(density) { maxWidth.toPx() }
        val h = with(density) { maxHeight.toPx() }
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.16f)).then(
                if (!played) Modifier.clickable(remember { MutableInteractionSource() }, indication = null) {} else Modifier,
            ),
        )
        AnimatedVisibility(!played, exit = fadeOut()) {
            val (tx, ty) = WheelGeometry.onboardingTarget(w, h, melodyLaneCount, swapHands)
            val half = with(density) { 26.5.dp.toPx() }
            Box(
                Modifier
                    .offset { IntOffset((tx - half).roundToInt(), (ty - half).roundToInt()) }
                    .size(53.dp)
                    .clip(CircleShape)
                    .background(palette.accent)
                    .border(1.dp, Color.White.copy(alpha = 0.6f), CircleShape)
                    .clickable { playFirstNote(); played = true }
                    .testTag("onboarding-first-note"),
                contentAlignment = Alignment.Center,
            ) { Text(noteName, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = palette.onAccent) }
        }
        Column(
            Modifier.align(Alignment.BottomCenter).navigationBarsPadding()
                .padding(horizontal = 20.dp).padding(bottom = 18.dp)
                .widthIn(max = 430.dp).fillMaxWidth()
                .clip(RoundedCornerShape(20.dp)).background(palette.surface).padding(17.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            Text(OnboardingCopy.title(played, canSuggestPinching), fontSize = 22.sp, fontFamily = StudioFonts.Serif, color = palette.ink)
            Text(OnboardingCopy.body(played, canSuggestPinching), fontSize = 15.sp, color = palette.muted)
            Text(
                OnboardingCopy.button(played),
                // iOS `.buttonStyle(.bordered)`: 17 pt label on a tinted rounded rectangle.
                fontSize = 17.sp, color = palette.accent,
                modifier = Modifier.testTag("onboarding-got-it").clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    .background(palette.accent.copy(alpha = 0.15f)).clickable(onClick = onDone)
                    .padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }
    }
}
