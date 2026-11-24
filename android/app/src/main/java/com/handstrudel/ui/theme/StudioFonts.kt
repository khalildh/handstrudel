package com.handstrudel.ui.theme

import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import com.handstrudel.R

/**
 * Open-licensed stand-ins for the Apple system designs iOS uses (Apple's SF Rounded,
 * New York and SF Mono can't be bundled on Android). All three are OFL 1.1 variable fonts
 * from github.com/google/fonts; licence texts ship in `assets/licenses/`.
 *
 * - [Rounded]  = `Font.Design.rounded`    -> Nunito (wght 200-1000)
 * - [Serif]    = `Font.Design.serif`      -> Newsreader, text optical size (titles)
 * - [SerifDisplay] = New York at display sizes ("Play the air.") -> Newsreader opsz 72
 * - [Mono]     = `Font.Design.monospaced` -> JetBrains Mono (wght 100-800)
 *
 * Each family registers one [Font] per weight that iOS uses, pinned with a `wght`
 * variation, so `fontWeight = FontWeight.Black` etc. resolve to the right instance.
 */
object StudioFonts {
    private val weights = listOf(
        FontWeight.Light, FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold,
        FontWeight.Bold, FontWeight.ExtraBold, FontWeight.Black,
    )

    @OptIn(ExperimentalTextApi::class)
    private fun family(res: Int, maxWeight: Int, opsz: Float? = null): FontFamily = FontFamily(
        weights.map { w ->
            val settings = buildList {
                add(FontVariation.weight(w.weight.coerceAtMost(maxWeight)))
                if (opsz != null) add(FontVariation.Setting("opsz", opsz))
            }
            Font(res, weight = w, variationSettings = FontVariation.Settings(*settings.toTypedArray()))
        },
    )

    /** SF Pro Rounded stand-in. Nunito's Black (900) matches `.black`; 1000 is unused. */
    val Rounded: FontFamily = family(R.font.nunito, maxWeight = 1000)

    /** New York stand-in for titles (`.title`/`.largeTitle`, `.serif`). */
    val Serif: FontFamily = family(R.font.newsreader, maxWeight = 800, opsz = 20f)

    /** New York at display sizes (the 30-51 pt home headline). */
    val SerifDisplay: FontFamily = family(R.font.newsreader, maxWeight = 800, opsz = 72f)

    /** SF Mono stand-in. */
    val Mono: FontFamily = family(R.font.jetbrains_mono, maxWeight = 800)
}
