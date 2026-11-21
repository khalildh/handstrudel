package com.handstrudel.ui.studio

import com.handstrudel.ui.studio.overlays.LEARN_PICKER_SONGS
import com.handstrudel.ui.studio.overlays.LEARN_PRACTICE
import com.handstrudel.ui.studio.overlays.learnSongId
import org.junit.Assert.assertEquals
import org.junit.Test

class LearnSongPickerCatalogTest {

    @Test fun songIdsAreSnakeCaseNames() {
        assertEquals("twinkle_twinkle", learnSongId("Twinkle Twinkle"))
        assertEquals("mary_had_a_little_lamb", learnSongId("Mary Had a Little Lamb"))
        assertEquals("up_down_10", learnSongId("Up & Down 10"))
    }

    @Test fun pickerListsTheEightBundledSongsInIosOrder() {
        assertEquals(
            listOf(
                "twinkle_twinkle", "ode_to_joy", "mary_had_a_little_lamb", "when_the_saints",
                "amazing_grace", "frere_jacques", "jingle_bells", "scarborough_fair",
            ),
            LEARN_PICKER_SONGS.map { it.id },
        )
        assertEquals(listOf(100, 108, 110, 112, 80, 120, 130, 90), LEARN_PICKER_SONGS.map { it.bpm })
    }

    @Test fun practiceIds() {
        assertEquals(listOf("ascending_10", "descending_10", "arpeggio_14", "random_12"), LEARN_PRACTICE.map { it.id })
    }
}
