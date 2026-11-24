package com.handstrudel.social

import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.Video
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.UUID

/** Phase 0 checks for the social seam models (social WS extends these in AT/social/). */
class SocialModelSeamTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val id = "6f1c2b9e-1d2a-4c3b-9e8f-7a6b5c4d3e2f"

    private fun row(soundSetup: String) = """
        {"id":"$id","user_id":"0b7e1a52-3f4d-4e9a-8c1b-2d3e4f5a6b7c","video_key":"videos/u/screened/a.mp4",
         "thumb_key":"thumbs/u/screened/a.jpg","caption":"hi","like_count":3,
         "created_at":"2026-05-01T12:34:56.123456+00:00","username":"maker","sound_setup":$soundSetup,
         "unknown_column":1}
    """.trimIndent()

    @Test fun videoDecodesValidSoundSetup() {
        val setup = """{"autoStrum":false,"bpm":120,"gridOctave":3,"gridRange":2,"instrument":"grand_piano",
            "key":"C","mode":"scalechordmelody","padVolume":0.6,"progression":"free","scale":"Pentatonic",
            "useSoundFont":true,"version":1,"waveform":"sawtooth"}"""
        val video = json.decodeFromString(Video.serializer(), row(setup))
        assertEquals(UUID.fromString(id), video.id)
        assertEquals(3, video.likeCount)
        assertNotNull(video.createdAtInstant)
        assertNotNull(video.soundSetup)
        assertEquals("https://handstrudel.com/watch?v=$id", video.watchUrl)
    }

    @Test fun videoTurnsBadSoundSetupIntoNull() {
        for (bad in listOf("null", "\"junk\"", """{"version":2}""",
            """{"autoStrum":false,"bpm":5,"gridOctave":3,"gridRange":2,"instrument":"grand_piano","key":"C",
               "mode":"scalechordmelody","padVolume":0.6,"progression":"free","scale":"Pentatonic",
               "useSoundFont":true,"version":1,"waveform":"sawtooth"}""")) {
            assertNull(bad, json.decodeFromString(Video.serializer(), row(bad)).soundSetup)
        }
    }

    @Test fun performanceLinkParsesIosForms() {
        val uuid = UUID.fromString(id)
        assertEquals(PerformanceLink.Watch(uuid), PerformanceLink.parse("https://handstrudel.com/watch?v=$id"))
        assertEquals(PerformanceLink.Watch(uuid), PerformanceLink.parse("https://handstrudel.com/watch/?v=$id"))
        assertEquals(PerformanceLink.Watch(uuid), PerformanceLink.parse("handstrudel://watch/$id"))
        assertEquals(PerformanceLink.Comments(uuid), PerformanceLink.parse("handstrudel://comments/$id"))
        assertEquals(PerformanceLink.Sound(uuid), PerformanceLink.parse("handstrudel://sound/$id"))
        assertEquals(PerformanceLink.PlayAlong(uuid), PerformanceLink.parse("handstrudel://play/$id"))
        assertNull(PerformanceLink.parse("https://handstrudel.com/watch?v=$id&v=$id"))
        assertNull(PerformanceLink.parse("https://evil.com/watch?v=$id"))
        assertNull(PerformanceLink.parse("https://user:pw@handstrudel.com/watch?v=$id"))
        assertNull(PerformanceLink.parse("https://handstrudel.com:8443/watch?v=$id"))
        assertNull(PerformanceLink.parse("handstrudel://other/$id"))
        assertNull(PerformanceLink.parse("handstrudel://watch/$id/extra"))
        assertNull(PerformanceLink.parse("handstrudel://watch/not-a-uuid"))
    }
}
