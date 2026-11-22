package com.handstrudel.ui.social.feed
import com.handstrudel.ui.theme.IosSlider
import com.handstrudel.ui.theme.IosControls

import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.data.FeedPlaybackPosition
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlin.math.abs

/** iOS `FeedProgressStrip.height`. */
val FeedProgressStripHeight = 44.dp

/**
 * iOS `FeedProgressStrip` + `FeedSeekSlider`: a scrubber (pauses while held, seeks on
 * release) with `0:03 / 0:12`. A vertical swipe over it pages the feed instead.
 */
@Composable
fun FeedProgressStrip(
    clip: FeedClip,
    durationHint: Double?,
    modifier: Modifier = Modifier,
    onVerticalSwipe: ((Float) -> Unit)? = null,
) {
    val p = LocalStudioPalette.current
    val position by clip.position.collectAsState()
    val failed by clip.failed.collectAsState()
    val shown = position ?: FeedPlaybackPosition.of(durationHint ?: 0.0, 0.0)
    val elapsed = FeedPlaybackPosition.timeLabel(shown?.seconds ?: 0.0)
    val duration = shown?.let { FeedPlaybackPosition.timeLabel(it.duration) } ?: "--:--"
    var editing by remember(clip) { mutableStateOf(false) }
    val density = LocalDensity.current
    Row(
        modifier.height(FeedProgressStripHeight).alpha(if (failed) 0.45f else 1f)
            .then(if (onVerticalSwipe != null) Modifier.pointerInput(clip) {
                var dy = 0f
                val threshold = with(density) { 48.dp.toPx() }
                detectVerticalDragGestures(onDragStart = { dy = 0f; clip.setEditing(false) }, onDragEnd = {
                    if (abs(dy) >= threshold) onVerticalSwipe(dy)
                }) { _, amount -> dy += amount }
            } else Modifier),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IosSlider(
            value = (shown?.seconds ?: 0.0).toFloat(),
            valueRange = 0f..maxOf(0.001f, (shown?.duration ?: 1.0).toFloat()),
            enabled = shown != null && !failed,
            onValueChange = {
                if (!editing) { editing = true; clip.setEditing(true) }
                clip.setSeconds(it.toDouble())
            },
            onValueChangeFinished = { editing = false; clip.setEditing(false) },
            // iOS `UISlider` with only `minimumTrackTintColor` set: white thumb, dark-appearance grey track.
            tint = p.mediaAccent,
            inactiveTrack = IosControls.offTrack(light = false),
            modifier = Modifier.weight(1f).testTag("feed-video-progress").semantics {
                contentDescription = "Video progress"
                stateDescription = if (failed) "Playback unavailable" else "$elapsed of $duration"
            },
        )
        Spacer(Modifier.width(8.dp))
        Text("$elapsed / $duration", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}
