package com.handstrudel.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

/**
 * Small monochrome glyphs drawn to look like the SF Symbols iOS uses where
 * material-icons-extended has no close match. 24x24 viewport, tinted by `Icon`.
 */
object StudioIcons {
    private fun icon(name: String, vararg strokes: String, fills: List<String> = emptyList(), evenOdd: Boolean = false, stroke: Float = 1.7f) =
        ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply {
            fills.forEach {
                addPath(
                    addPathNodes(it), fill = SolidColor(Color.Black),
                    pathFillType = if (evenOdd) PathFillType.EvenOdd else PathFillType.NonZero,
                )
            }
            strokes.forEach {
                addPath(
                    addPathNodes(it), stroke = SolidColor(Color.Black), strokeLineWidth = stroke,
                    strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
                )
            }
        }.build()

    /**
     * SF `square.stack` (measured from iOS at 17 pt semibold: 15 x 20 pt): a rounded square
     * with two shorter rails stacked above it.
     */
    val SquareStack: ImageVector = icon(
        "square.stack",
        "M7.5,8h9a3,3 0 0 1 3,3v7.5a3,3 0 0 1 -3,3h-9a3,3 0 0 1 -3,-3v-7.5a3,3 0 0 1 3,-3z",
        "M7,5H17",
        "M9,2.2H15",
        stroke = 1.9f,
    )

    /** SF `xmark` at a bold weight. */
    val XMark: ImageVector = icon("xmark", "M5.5,5.5L18.5,18.5M18.5,5.5L5.5,18.5", stroke = 2.4f)

    /** SF `repeat`: two rounded rails with arrowheads, wider than tall. */
    val Repeat: ImageVector = icon(
        "repeat",
        "M3,12.5V10.5a3.5,3.5 0 0 1 3.5,-3.5H20", "M16.5,3.5L20,7L16.5,10.5",
        "M21,11.5V13.5a3.5,3.5 0 0 1 -3.5,3.5H4", "M7.5,13.5L4,17L7.5,20.5",
        stroke = 2.1f,
    )

    /** SF `tortoise`: domed shell, head, two legs. */
    val Tortoise: ImageVector = icon(
        "tortoise",
        "M3.5,15.5C3.5,10.5 7,7 11.25,7C15.5,7 19,10.5 19,15.5Z",
        "M7.25,15.5L8.75,10.5H13.75L15.25,15.5",
        "M19,13.5C19.6,11.6 22.5,11.4 22.5,13.4C22.5,14.9 21,15.5 19,15.5",
        "M6.5,15.5V18.5H8.25V15.5",
        "M14.25,15.5V18.5H16V15.5",
        "M3.5,15.5L1.75,16.75",
    )

    /** SF `metronome`: trapezoid body, base line, pendulum with weight. */
    val Metronome: ImageVector = icon(
        "metronome",
        "M9.25,3h5.5a1.2,1.2 0 0 1 1.15,0.9L19.8,19.4a1.2,1.2 0 0 1 -1.15,1.6H5.35a1.2,1.2 0 0 1 -1.15,-1.6L8.1,3.9A1.2,1.2 0 0 1 9.25,3z",
        "M5.75,16.5h12.5",
        "M12,16.5L14.25,7",
        "M12.35,10.9l2.4,0.75",
    )

    /** SF `metronome.fill`: solid body with the pendulum and base cut out. */
    val MetronomeFill: ImageVector = icon(
        "metronome.fill",
        fills = listOf(
            "M9.25,3h5.5a1.2,1.2 0 0 1 1.15,0.9L19.8,19.4a1.2,1.2 0 0 1 -1.15,1.6H5.35a1.2,1.2 0 0 1 -1.15,-1.6L8.1,3.9A1.2,1.2 0 0 1 9.25,3z" +
                "M11.3,15.6L13.55,6.9L14.95,7.25L12.75,15.6z" +
                "M6.2,16.4h11.6v1.5H6.2z",
        ),
        evenOdd = true,
    )

    /** SF `film.stack`: a film strip with sprocket rails and a frame behind it. */
    val FilmStack: ImageVector = icon(
        "film.stack",
        "M5.5,8.5h13a2,2 0 0 1 2,2v8.5a2,2 0 0 1 -2,2h-13a2,2 0 0 1 -2,-2v-8.5a2,2 0 0 1 2,-2z",
        "M7.5,8.5V21M16.5,8.5V21",
        "M3.5,12.6H7.5M3.5,16.9H7.5M16.5,12.6H20.5M16.5,16.9H20.5",
        "M5.75,5.5h12.5",
        "M8,2.75h8",
    )

    /** SF `waveform.badge.plus`: waveform bars with a plus badge. */
    val WaveformBadgePlus: ImageVector = icon(
        "waveform.badge.plus",
        "M2.5,11V14M5.5,8V17M8.5,4.5V20.5M11.5,8.5V16.5M14.5,10.5V14.5M17.5,12V13",
        "M19.5,2.5V8.5M16.5,5.5H22.5",
        stroke = 1.8f,
    )

    /** SF `bubble` (iOS 17+): a round speech bubble with a tail at the bottom left. */
    val Bubble: ImageVector = icon(
        "bubble",
        "M12,3.5C16.97,3.5 21,7.08 21,11.5C21,15.92 16.97,19.5 12,19.5C10.9,19.5 9.85,19.33 8.88,19L4.5,20.75L5.65,16.9C4.03,15.45 3,13.57 3,11.5C3,7.08 7.03,3.5 12,3.5Z",
    )

    /** SF `target`: concentric rings with a solid centre. */
    val Target: ImageVector = icon(
        "target",
        "M3,12a9,9 0 1 0 18,0a9,9 0 1 0 -18,0z",
        "M7,12a5,5 0 1 0 10,0a5,5 0 1 0 -10,0z",
        fills = listOf("M10.25,12a1.75,1.75 0 1 0 3.5,0a1.75,1.75 0 1 0 -3.5,0z"),
    )

    /** SF `slider.horizontal.3`: three rails, each with a ring knob (right, left, right). */
    val SliderHorizontal3: ImageVector = icon(
        "slider.horizontal.3",
        "M3,6H13.6M18.4,6H21", "M13.6,6a2.4,2.4 0 1 0 4.8,0a2.4,2.4 0 1 0 -4.8,0z",
        "M3,12H5.6M10.4,12H21", "M5.6,12a2.4,2.4 0 1 0 4.8,0a2.4,2.4 0 1 0 -4.8,0z",
        "M3,18H13.6M18.4,18H21", "M13.6,18a2.4,2.4 0 1 0 4.8,0a2.4,2.4 0 1 0 -4.8,0z",
        stroke = 1.9f,
    )

    /** SF `arrow.up.arrow.down`: an up arrow on the left, a down arrow on the right. */
    val ArrowUpArrowDown: ImageVector = icon(
        "arrow.up.arrow.down",
        "M7,20V4", "M2.8,8.2L7,4L11.2,8.2",
        "M17,4V20", "M12.8,15.8L17,20L21.2,15.8",
        stroke = 1.6f,
    )

    /**
     * SF `waveform`: six rounded bars (measured heights 5.1, 12.9, 20, 10.4, 15.7, 6.7 on a
     * 20-unit span). Material's GraphicEq has five even bars and reads differently.
     */
    val Waveform: ImageVector = icon(
        "waveform",
        "M2,9.45V14.55", "M6,5.55V18.45", "M10,2V22", "M14,6.8V17.2", "M18,4.15V19.85", "M22,8.65V15.35",
        stroke = 2.0f,
    )

    /** SF `checkmark` at a bold weight. */
    val Checkmark: ImageVector = icon("checkmark", "M4,12.8L9.4,18.2L20,5.8", stroke = 2.7f)
}
