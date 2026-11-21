package com.handstrudel.app

import com.handstrudel.models.MusicKey
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupMode
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.Video
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.UUID

class DeepLinkRouterTest {
    private val id = UUID.fromString("3f2b8c1e-4a5d-4e6f-9a0b-1c2d3e4f5a6b")
    private val setup = SoundSetup(
        instrument = "grand_piano", waveform = "sawtooth", key = MusicKey.C, scale = ScaleSelection.PENTATONIC,
        progression = "free", mode = SoundSetupMode.SCALE_CHORD_MELODY, bpm = 120.0, useSoundFont = true,
        autoStrum = false, padVolume = 0.6, gridOctave = 3, gridRange = 2,
    )

    private fun video(commentsEnabled: Boolean? = true, sound: SoundSetup? = setup) = Video(
        id = id, userId = UUID(1, 1), videoKey = "v", thumbKey = "t", caption = "", likeCount = 0,
        createdAt = "2026-01-01T00:00:00Z", soundSetup = sound, commentsEnabled = commentsEnabled,
    )

    @Test fun extractsLinksFromUrls() {
        assertEquals(PerformanceLink.Watch(id), DeepLinkRouter.linkFromUrl("https://handstrudel.com/watch?v=$id"))
        assertEquals(PerformanceLink.Watch(id), DeepLinkRouter.linkFromUrl("handstrudel://watch/$id"))
        assertEquals(PerformanceLink.Comments(id), DeepLinkRouter.linkFromUrl("handstrudel://comments/$id"))
        assertEquals(PerformanceLink.Sound(id), DeepLinkRouter.linkFromUrl("handstrudel://sound/$id"))
        assertEquals(PerformanceLink.PlayAlong(id), DeepLinkRouter.linkFromUrl("handstrudel://play/$id"))
        assertNull(DeepLinkRouter.linkFromUrl("https://handstrudel.com/watch?v=$id&v=$id"))
        assertNull(DeepLinkRouter.linkFromUrl("https://evil.com/watch?v=$id"))
        assertNull(DeepLinkRouter.linkFromUrl(null))
    }

    @Test fun watch() {
        val v = video()
        assertEquals(DeepLinkRouter.Outcome.ShowPost(v), DeepLinkRouter.resolve(PerformanceLink.Watch(id), v))
        assertEquals(
            DeepLinkRouter.Outcome.Error("This performance is no longer available."),
            DeepLinkRouter.resolve(PerformanceLink.Watch(id), null),
        )
    }

    @Test fun commentsNeedTheCommentsFlag() {
        val v = video()
        assertEquals(DeepLinkRouter.Outcome.ShowComments(v), DeepLinkRouter.resolve(PerformanceLink.Comments(id), v))
        // iOS shows the sheet for closed comments too (`commentsEnabled != nil`).
        val closed = video(commentsEnabled = false)
        assertEquals(DeepLinkRouter.Outcome.ShowComments(closed), DeepLinkRouter.resolve(PerformanceLink.Comments(id), closed))
        val error = DeepLinkRouter.Outcome.Error("Comments are not available for this performance.")
        assertEquals(error, DeepLinkRouter.resolve(PerformanceLink.Comments(id), video(commentsEnabled = null)))
        assertEquals(error, DeepLinkRouter.resolve(PerformanceLink.Comments(id), null))
    }

    @Test fun playAlong() {
        val v = video()
        assertEquals(DeepLinkRouter.Outcome.PlayAlong(v), DeepLinkRouter.resolve(PerformanceLink.PlayAlong(id), v))
        assertEquals(
            DeepLinkRouter.Outcome.Error("This backing track is no longer available."),
            DeepLinkRouter.resolve(PerformanceLink.PlayAlong(id), null),
        )
    }

    @Test fun sound() {
        assertEquals(DeepLinkRouter.Outcome.TrySound(setup), DeepLinkRouter.resolve(PerformanceLink.Sound(id), video()))
        val error = DeepLinkRouter.Outcome.Error(
            "The creator hasn't shared a sound setup for this clip, or it is no longer available.",
        )
        assertEquals(error, DeepLinkRouter.resolve(PerformanceLink.Sound(id), video(sound = null)))
        assertEquals(error, DeepLinkRouter.resolve(PerformanceLink.Sound(id), null))
    }
}
