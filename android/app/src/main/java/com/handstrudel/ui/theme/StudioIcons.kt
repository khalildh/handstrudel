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

    private const val HAND =
        "M8.2,21.2C6.8,20.2 5.6,18.6 4.8,16.8L2.9,12.6A1.25,1.25 0 0 1 5.1,11.4L7.2,14.2L5.6,5.4" +
            "A1.3,1.3 0 0 1 8.15,4.9L9.8,11.4L10.2,3.3A1.3,1.3 0 0 1 12.8,3.3L12.9,11.3L14.6,4.4" +
            "A1.3,1.3 0 0 1 17.1,5L15.6,11.9L18.2,8A1.3,1.3 0 0 1 20.3,9.4L17.6,15.6" +
            "C16.6,19.2 14.6,21.4 11.8,21.4Z"

    /** SF `hand.raised` / `hand.raised.fingers.spread`: an outlined open hand. */
    val HandRaised: ImageVector = icon("hand.raised", HAND, stroke = 1.6f)

    /** SF `hand.raised.slash`: the open hand struck through. */
    val HandRaisedSlash: ImageVector = icon("hand.raised.slash", HAND, "M3,2.8L21.2,21", stroke = 1.6f)

    /** SF `ellipsis.circle`: a ring around three dots. */
    val EllipsisCircle: ImageVector = icon(
        "ellipsis.circle",
        "M3,12a9,9 0 1 0 18,0a9,9 0 1 0 -18,0z",
        fills = listOf(
            "M6.15,12a1.35,1.35 0 1 0 2.7,0a1.35,1.35 0 1 0 -2.7,0z" +
                "M10.65,12a1.35,1.35 0 1 0 2.7,0a1.35,1.35 0 1 0 -2.7,0z" +
                "M15.15,12a1.35,1.35 0 1 0 2.7,0a1.35,1.35 0 1 0 -2.7,0z",
        ),
        stroke = 1.6f,
    )

    /** SF `circle.lefthalf.filled`. */
    val CircleLeftHalfFilled: ImageVector = icon(
        "circle.lefthalf.filled", "M3,12a9,9 0 1 0 18,0a9,9 0 1 0 -18,0z",
        fills = listOf("M12,3a9,9 0 0 0 0,18z"), stroke = 1.7f,
    )

    /** SF `circle.circle`: two concentric rings. */
    val CircleCircle: ImageVector = icon(
        "circle.circle", "M3,12a9,9 0 1 0 18,0a9,9 0 1 0 -18,0z", "M7,12a5,5 0 1 0 10,0a5,5 0 1 0 -10,0z", stroke = 1.7f,
    )

    /** SF `music.quarternote.3`: three quarter notes, the middle one raised. */
    val MusicQuarterNote3: ImageVector = icon(
        "music.quarternote.3",
        "M7.1,18.6V6.4", "M13.6,16.1V3.9", "M20.1,18.6V6.4",
        fills = listOf(
            "M2.3,18.9a2.45,1.95 0 1 0 4.9,0a2.45,1.95 0 1 0 -4.9,0z" +
                "M8.8,16.4a2.45,1.95 0 1 0 4.9,0a2.45,1.95 0 1 0 -4.9,0z" +
                "M15.3,18.9a2.45,1.95 0 1 0 4.9,0a2.45,1.95 0 1 0 -4.9,0z",
        ),
        stroke = 1.7f,
    )

    private const val PIANO_BODY = "M4.5,4.5h15a2,2 0 0 1 2,2v11a2,2 0 0 1 -2,2h-15a2,2 0 0 1 -2,-2v-11a2,2 0 0 1 2,-2z"

    /** SF `pianokeys`: solid white keys with the black keys and key gaps cut out. */
    val PianoKeys: ImageVector = icon(
        "pianokeys",
        fills = listOf(
            PIANO_BODY +
                listOf(7.25f, 12f, 16.75f).joinToString("") { x ->
                    "M${x - 1.3f},4.5H${x + 1.3f}V12.6H${x + 0.45f}V19.5H${x - 0.45f}V12.6H${x - 1.3f}Z"
                },
        ),
        evenOdd = true,
    )

    /** SF `pianokeys.inverse`: an outlined keyboard with solid black keys. */
    val PianoKeysInverse: ImageVector = icon(
        "pianokeys.inverse",
        PIANO_BODY, "M7.25,12.6V19.5M12,12.6V19.5M16.75,12.6V19.5",
        fills = listOf(listOf(7.25f, 12f, 16.75f).joinToString("") { x -> "M${x - 1.4f},4.5H${x + 1.4f}V12.9H${x - 1.4f}Z" }),
        stroke = 1.5f,
    )

    /** SF `waveform.path`: a flat line breaking into a tall oscillation in the middle. */
    val WaveformPath: ImageVector = icon(
        "waveform.path",
        "M1.5,12H5L6.3,9.4L7.6,14.8L8.9,6.4L10.3,18.4L11.7,3.6L13.1,20.4L14.5,6L15.8,16.4L17.1,9.2L18.4,12H22.5",
        stroke = 1.6f,
    )

    /** SF `guitars`: a V-shaped electric, an electric and an acoustic side by side. */
    val Guitars: ImageVector = icon(
        "guitars",
        "M5,3V11.2", "M5,11.2L2,20.6L5,18.6L8,20.6Z", "M4,3H6",
        "M12,3V12.2", "M11,3H13",
        "M12,12.2c-2.2,0 -3.2,1.4 -2.8,3.1c0.3,1.4 -0.6,2 -0.6,3c0,1.4 1.4,2.3 3.4,2.3c2,0 3.4,-0.9 3.4,-2.3c0,-1 -0.9,-1.6 -0.6,-3c0.4,-1.7 -0.6,-3.1 -2.8,-3.1z",
        "M19,3V13", "M18,3H20",
        "M19,13c-1.7,0 -2.6,1.1 -2.4,2.5c0.2,1.1 -0.5,1.6 -0.5,2.5c0,1.3 1.2,2.3 2.9,2.3c1.7,0 2.9,-1 2.9,-2.3c0,-0.9 -0.7,-1.4 -0.5,-2.5c0.2,-1.4 -0.7,-2.5 -2.4,-2.5z",
        stroke = 1.3f,
    )

    /** SF `square.grid.3x3`: nine small rounded squares. */
    val SquareGrid3x3: ImageVector = icon(
        "square.grid.3x3",
        *listOf(3f, 10f, 17f).flatMap { y -> listOf(3f, 10f, 17f).map { x -> "M${x + 1f},${y}h2a1,1 0 0 1 1,1v2a1,1 0 0 1 -1,1h-2a1,1 0 0 1 -1,-1v-2a1,1 0 0 1 1,-1z" } }.toTypedArray(),
        stroke = 1.4f,
    )

    /** SF `beats.headphones`: an arched band with solid ear cups. */
    val BeatsHeadphones: ImageVector = icon(
        "beats.headphones",
        "M4.2,15.5V12a7.8,7.8 0 0 1 15.6,0V15.5",
        fills = listOf(
            "M4.4,13.6h1.4a1.2,1.2 0 0 1 1.2,1.2v4.6a1.2,1.2 0 0 1 -1.2,1.2h-1.4a1.2,1.2 0 0 1 -1.2,-1.2v-4.6a1.2,1.2 0 0 1 1.2,-1.2z" +
                "M18.2,13.6h1.4a1.2,1.2 0 0 1 1.2,1.2v4.6a1.2,1.2 0 0 1 -1.2,1.2h-1.4a1.2,1.2 0 0 1 -1.2,-1.2v-4.6a1.2,1.2 0 0 1 1.2,-1.2z",
        ),
        stroke = 1.6f,
    )

    /** SF `music.note.list`: three list rules beside a flagged note. */
    val MusicNoteList: ImageVector = icon(
        "music.note.list",
        "M2.5,6H11", "M2.5,10.5H11", "M2.5,15H9", "M18.2,4.2V17.4",
        fills = listOf(
            "M12.9,17.6a2.65,2.1 0 1 0 5.3,0a2.65,2.1 0 1 0 -5.3,0z" +
                "M17.4,3.4L21.6,2.3V6.4L17.4,7.5Z",
        ),
        stroke = 1.7f,
    )

    /** SF `music.note`: a single flagged eighth note. */
    val MusicNote: ImageVector = icon(
        "music.note", "M14.5,4V17.2",
        fills = listOf("M9.2,17.4a2.65,2.1 0 1 0 5.3,0a2.65,2.1 0 1 0 -5.3,0z" + "M13.8,3.2L18.6,5.6V9.4L13.8,7Z"),
        stroke = 1.7f,
    )

    private const val VIDEO_BODY = "M4.5,6.5h9a2,2 0 0 1 2,2v7a2,2 0 0 1 -2,2h-9a2,2 0 0 1 -2,-2v-7a2,2 0 0 1 2,-2z"
    private const val VIDEO_LENS = "M15.5,10.3L20.6,7.3a0.6,0.6 0 0 1 0.9,0.5V16.2a0.6,0.6 0 0 1 -0.9,0.5L15.5,13.7"

    /** SF `video`: an outlined camcorder. */
    val Video: ImageVector = icon("video", VIDEO_BODY, VIDEO_LENS, stroke = 1.6f)

    /** SF `video.slash`: the camcorder struck through. */
    val VideoSlash: ImageVector = icon("video.slash", VIDEO_BODY, VIDEO_LENS, "M3,3.5L21,20.5", stroke = 1.6f)

    /** SF `mic`: an outlined capsule microphone on a stand. */
    val Mic: ImageVector = icon(
        "mic", "M9,5.5a3,3 0 0 1 6,0v5.5a3,3 0 0 1 -6,0z", "M5.5,11a6.5,6.5 0 0 0 13,0", "M12,17.5V21", "M9,21H15",
        stroke = 1.6f,
    )

    /** SF `camera.filters`: three overlapping rings. */
    val CameraFilters: ImageVector = icon(
        "camera.filters",
        "M7.6,8.2a4.4,4.4 0 1 0 8.8,0a4.4,4.4 0 1 0 -8.8,0z",
        "M3.9,14.6a4.4,4.4 0 1 0 8.8,0a4.4,4.4 0 1 0 -8.8,0z",
        "M11.3,14.6a4.4,4.4 0 1 0 8.8,0a4.4,4.4 0 1 0 -8.8,0z",
        stroke = 1.5f,
    )

    /** SF `dice`: two outlined dice with pips. */
    val Dice: ImageVector = icon(
        "dice",
        "M5,9.5h7a2.5,2.5 0 0 1 2.5,2.5v7a2.5,2.5 0 0 1 -2.5,2.5h-7a2.5,2.5 0 0 1 -2.5,-2.5v-7a2.5,2.5 0 0 1 2.5,-2.5z",
        "M9.5,6.5V5a2.5,2.5 0 0 1 2.5,-2.5h7a2.5,2.5 0 0 1 2.5,2.5v7a2.5,2.5 0 0 1 -2.5,2.5h-1.5",
        fills = listOf(
            "M5.3,12.8a1.1,1.1 0 1 0 2.2,0a1.1,1.1 0 1 0 -2.2,0z" + "M9.5,18.2a1.1,1.1 0 1 0 2.2,0a1.1,1.1 0 1 0 -2.2,0z" +
                "M7.4,15.5a1.1,1.1 0 1 0 2.2,0a1.1,1.1 0 1 0 -2.2,0z" + "M14.4,5.5a1.1,1.1 0 1 0 2.2,0a1.1,1.1 0 1 0 -2.2,0z" +
                "M17.4,9.5a1.1,1.1 0 1 0 2.2,0a1.1,1.1 0 1 0 -2.2,0z",
        ),
        stroke = 1.5f,
    )

    /** SF `chevron.down` / `chevron.up` at a bold weight. */
    val ChevronDown: ImageVector = icon("chevron.down", "M4.5,8.5L12,16L19.5,8.5", stroke = 2.6f)
    val ChevronUp: ImageVector = icon("chevron.up", "M4.5,15.5L12,8L19.5,15.5", stroke = 2.6f)
}
