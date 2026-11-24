package com.handstrudel.ui.studio.home

import com.handstrudel.ui.theme.StudioIcons

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.MusicKey
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundFontInstrument
import com.handstrudel.ui.studio.common.StudioSettingsPanel
import com.handstrudel.ui.studio.pickers.GMCategory
import com.handstrudel.ui.studio.pickers.gmCategory
import com.handstrudel.ui.theme.LocalStudioPalette
import com.handstrudel.ui.theme.StudioPalette
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * iOS `StudioSettingsHero`: compact artwork strip, "CURRENT SOUND", serif
 * title and "Key Scale / Progression". Used by the Sound setup sheet and the
 * control sheet's Sound tab.
 */
@Composable
fun StudioSettingsHero(
    title: String,
    key: MusicKey,
    scale: ScaleSelection,
    progression: ChordProgression?,
    instrument: SoundFontInstrument?,
    modifier: Modifier = Modifier,
) {
    val palette = LocalStudioPalette.current
    StudioSettingsPanel(modifier.testTag("studio-current-sound")) {
        if (instrument != null && progression != null) {
            SoundArtwork(instrument, key, scale, progression, compact = true, modifier = Modifier.fillMaxWidth().height(74.dp))
        }
        Column(
            Modifier.fillMaxWidth()
                .background(Brush.horizontalGradient(listOf(palette.surface, palette.glow.copy(alpha = 0.24f))))
                .padding(horizontal = 17.dp, vertical = 13.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Icon(StudioIcons.Waveform, null, tint = palette.accent, modifier = Modifier.size(12.dp))
                Text(
                    "CURRENT SOUND", fontSize = 11.sp, fontFamily = StudioFonts.Mono,
                    fontWeight = FontWeight.SemiBold, letterSpacing = 1.6.sp, color = palette.accent,
                )
            }
            Text(title, fontSize = 34.sp, fontFamily = StudioFonts.Serif, color = palette.ink, lineHeight = 38.sp)
            Text(
                listOfNotNull("${key.displayName} ${scale.displayName}", progression?.name).joinToString(" / "),
                fontSize = 12.sp, fontFamily = StudioFonts.Mono, color = palette.muted,
            )
        }
    }
}

/**
 * iOS `SoundArtwork`: radial glow, dot grid, an instrument-shaped "weave" of
 * lines bent by the scale and progression, and a 12-tick pitch ruler. Drawn
 * in a 210 pt-tall field; [compact] squashes it into the given height.
 */
@Composable
fun SoundArtwork(
    instrument: SoundFontInstrument,
    key: MusicKey,
    scale: ScaleSelection,
    progression: ChordProgression,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    val palette = LocalStudioPalette.current
    val density = LocalDensity.current.density
    Canvas(modifier) {
        val fieldH = if (compact) 210f * density else size.height
        val field = Size(size.width, fieldH)
        clipRect {
            scale(1f, if (compact) size.height / fieldH else 1f, pivot = Offset.Zero) {
                drawArtwork(field, density, palette, instrument, key, scale.intervals, progression.degrees)
            }
        }
    }
}

/** iOS `SoundArtworkVoice`. */
internal class SoundArtworkVoice(instrument: SoundFontInstrument) {
    enum class Contour { BOW, PULSE, PLUCK, BREATH, RIPPLE }

    val program = instrument.program.toDouble()
    val contour: Contour
    val lines: Int
    val envelope: Double
    val spread: Double

    init {
        val (c, l, e, s) = when (instrument.gmCategory) {
            GMCategory.STRINGS, GMCategory.ENSEMBLE, GMCategory.SYNTH_PAD -> Quad(Contour.BOW, 24, 0.7, 78.0)
            GMCategory.PIANO, GMCategory.CHROMATIC_PERCUSSION, GMCategory.PERCUSSIVE -> Quad(Contour.PULSE, 16, 0.45, 92.0)
            GMCategory.GUITAR, GMCategory.BASS, GMCategory.ETHNIC -> Quad(Contour.PLUCK, 19, 0.55, 64.0)
            GMCategory.BRASS, GMCategory.REED, GMCategory.PIPE -> Quad(Contour.BREATH, 20, 1.35, 50.0)
            else -> Quad(Contour.RIPPLE, 22, 0.9, 70.0)
        }
        contour = c; lines = l; envelope = e; spread = s
    }

    fun wave(t: Double, layer: Double, phase: Double): Double {
        val sweep = t * Math.PI
        val color = phase + program * 0.21
        val carrier = sin(sweep * (2.8 + (program % 9) * 0.25) + layer * 2.7 + color)
        val overtone = cos(sweep * (5 + (program % 6)) + layer * 4 + color)
        return when (contour) {
            Contour.BOW -> carrier * 39 + overtone * 11
            Contour.PULSE -> (abs(carrier).pow(4) * 2 - 1) * (18 + layer * 17) + overtone * 8
            Contour.PLUCK -> carrier * 19 + overtone * 28 * (1 - t * 0.7)
            Contour.BREATH -> carrier * (23 + layer * 25) + overtone * 5
            Contour.RIPPLE -> carrier * 25 + overtone * (9 + layer * 17)
        }
    }

    private data class Quad(val c: Contour, val l: Int, val e: Double, val s: Double)
}

private fun interpolated(values: List<Int>, position: Double): Double {
    if (values.isEmpty()) return 3.0
    val index = min(position.toInt(), values.size - 1)
    val raw = position - index
    val eased = raw * raw * (3 - 2 * raw)
    return values[index] + (values[min(index + 1, values.size - 1)] - values[index]) * eased
}

private fun DrawScope.drawArtwork(
    field: Size, d: Float, palette: StudioPalette, instrument: SoundFontInstrument,
    key: MusicKey, intervals: List<Int>, degrees: List<Int>,
) {
    // Background glow + dot grid (iOS points → px via d).
    drawRect(
        Brush.radialGradient(
            listOf(palette.glow, palette.background),
            center = Offset(field.width * 0.55f, field.height * 0.37f),
            radius = max(field.width * 0.65f, field.height),
        ),
        size = field,
    )
    val step = 14f * d
    var x = step
    while (x < field.width) {
        var y = step
        while (y < field.height) {
            drawCircle(palette.muted.copy(alpha = 0.27f), radius = 0.65f * d, center = Offset(x, y))
            y += step
        }
        x += step
    }

    // Weave lines (coordinates in iOS points, scaled by d).
    val voice = SoundArtworkVoice(instrument)
    val phase = key.semitone * Math.PI / 6
    val chords = degrees.take(16)
    val left = 17.0
    val widthPt = max(1.0, field.width / d - left * 2)
    val brush = Brush.linearGradient(
        listOf(palette.accent.copy(alpha = 0.10f), palette.accent.copy(alpha = 0.85f), palette.overtone.copy(alpha = 0.52f)),
        start = Offset.Zero, end = Offset(field.width, field.height * 0.2f),
    )
    for (line in 0 until voice.lines) {
        val layer = line.toDouble() / (voice.lines - 1)
        val path = Path()
        for (s in 0..120) {
            val t = s / 120.0
            val env = max(0.0, sin(t * Math.PI)).pow(voice.envelope)
            val scaleColor = interpolated(intervals, t * (intervals.size - 1).coerceAtLeast(0)) / 12
            val contour = interpolated(chords, t * (chords.size - 1).coerceAtLeast(0)) / 6
            val base = 105 + (layer - 0.5) * voice.spread
            val shape = (scaleColor - 0.5) * 20 - (contour - 0.5) * 30
            val yPt = base + shape + voice.wave(t, layer, phase) * env
            val px = ((left + t * widthPt) * d).toFloat()
            val py = (yPt * d).toFloat()
            if (s == 0) path.moveTo(px, py) else path.lineTo(px, py)
        }
        drawPath(path, brush, style = Stroke(width = (if (line % 6 == 0) 1.4f else 0.65f) * d))
    }

    // Pitch ruler.
    val selected = intervals.map { (it + key.semitone) % 12 }.toSet()
    for (pitch in 0 until 12) {
        val h = when { pitch == key.semitone -> 13f; pitch in selected -> 7f; else -> 2f } * d
        val px = ((left + pitch * widthPt / 11) * d).toFloat()
        val color = if (pitch == key.semitone) palette.accent
        else palette.muted.copy(alpha = if (pitch in selected) 0.8f else 0.35f)
        drawRoundRect(color, topLeft = Offset(px - d, field.height - 18f * d - h), size = Size(2f * d, h), cornerRadius = CornerRadius(d))
    }
}
