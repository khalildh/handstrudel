package com.handstrudel.ui.theme

import androidx.compose.ui.graphics.Color
import com.handstrudel.app.InMemoryPrefsStore
import com.handstrudel.app.StoreBackedAppPrefs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Hex values must match iOS `Views/StudioTheme.swift` exactly. */
class StudioPaletteTest {
    private fun hex(c: Color): Int {
        val argb = (c.alpha * 255 + 0.5f).toInt() shl 24 or ((c.red * 255 + 0.5f).toInt() shl 16) or
            ((c.green * 255 + 0.5f).toInt() shl 8) or (c.blue * 255 + 0.5f).toInt()
        return argb and 0xFFFFFF
    }

    private data class Expected(
        val background: Int, val surface: Int, val ink: Int, val muted: Int, val accent: Int, val onAccent: Int,
        val mediaAccent: Int, val mediaOnAccent: Int, val glow: Int, val overtone: Int, val borderOpacity: Float,
    )

    private val ios = mapOf(
        StudioTheme.VOLT to Expected(0x0A0C0C, 0x141816, 0xF3F6EE, 0xA5AFA5, 0xD3F974, 0x0A0C0C, 0xD3F974, 0x0A0C0C, 0x2B401F, 0x42BD8C, 0.12f),
        StudioTheme.TIDE to Expected(0x081320, 0x102339, 0xF0F8FF, 0xA1B9D0, 0x84E5FF, 0x081320, 0x84E5FF, 0x081320, 0x15405D, 0x8B9DFF, 0.12f),
        StudioTheme.AFTERGLOW to Expected(0x181326, 0x292038, 0xFFF4E8, 0xC2AFC5, 0xFFBE76, 0x241625, 0xFFBE76, 0x241625, 0x533047, 0xFF7D9C, 0.12f),
        // Paper's media accent differs from its accent, so mediaOnAccent is the fixed 0x25100C.
        StudioTheme.PAPER to Expected(0xFAF4E8, 0xEFE4D2, 0x261C19, 0x614B41, 0x963424, 0xFFF8EF, 0xFFAA92, 0x25100C, 0xEFD2AD, 0xB75447, 0.17f),
    )

    @Test fun paletteHexMatchesIos() {
        assertEquals(StudioTheme.entries.toSet(), ios.keys)
        ios.forEach { (theme, e) ->
            val p = theme.palette
            assertEquals("$theme background", e.background, hex(p.background))
            assertEquals("$theme surface", e.surface, hex(p.surface))
            assertEquals("$theme ink", e.ink, hex(p.ink))
            assertEquals("$theme muted", e.muted, hex(p.muted))
            assertEquals("$theme accent", e.accent, hex(p.accent))
            assertEquals("$theme onAccent", e.onAccent, hex(p.onAccent))
            assertEquals("$theme mediaAccent", e.mediaAccent, hex(p.mediaAccent))
            assertEquals("$theme mediaOnAccent", e.mediaOnAccent, hex(p.mediaOnAccent))
            assertEquals("$theme glow", e.glow, hex(p.glow))
            assertEquals("$theme overtone", e.overtone, hex(p.overtone))
            assertEquals("$theme recording", 0xFF524F, hex(p.recording))
            assertEquals("$theme border rgb", e.ink, hex(p.border))
            assertEquals("$theme border opacity", e.borderOpacity, p.border.alpha, 0.01f)
            listOf(p.background, p.surface, p.ink, p.accent).forEach { assertEquals(1f, it.alpha) }
        }
    }

    @Test fun namesAndSchemes() {
        assertEquals(listOf("volt", "tide", "afterglow", "paper"), StudioTheme.entries.map { it.raw })
        assertEquals(listOf("Volt", "Deep Tide", "Afterglow", "Paper & Ink"), StudioTheme.entries.map { it.title })
        assertEquals(
            listOf("Lime on charcoal", "Glacier blue on deep navy", "Honey and coral on indigo", "Rust red on warm ivory"),
            StudioTheme.entries.map { it.subtitle },
        )
        assertTrue(StudioTheme.PAPER.isLight)
        assertFalse(StudioTheme.VOLT.isLight || StudioTheme.TIDE.isLight || StudioTheme.AFTERGLOW.isLight)
    }

    @Test fun storedUnderStudioThemeKeyDefaultingToVolt() {
        val store = InMemoryPrefsStore()
        assertEquals(StudioTheme.VOLT, StoreBackedAppPrefs(store).studioTheme.value)
        StoreBackedAppPrefs(store).setStudioTheme(StudioTheme.PAPER)
        assertEquals("paper", store.getString("studioTheme"))
        assertEquals(StudioTheme.PAPER, StoreBackedAppPrefs(store).studioTheme.value)
        store.putString("studioTheme", "neon")
        assertEquals(StudioTheme.VOLT, StoreBackedAppPrefs(store).studioTheme.value)
    }

    @Test fun materialSchemeFollowsPalette() {
        val p = StudioTheme.PAPER.palette
        val scheme = p.materialColorScheme(light = true)
        assertEquals(p.accent, scheme.primary)
        assertEquals(p.background, scheme.background)
        assertEquals(p.ink, scheme.onSurface)
    }
}
