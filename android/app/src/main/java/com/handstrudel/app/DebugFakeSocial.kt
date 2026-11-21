package com.handstrudel.app

import android.content.Intent
import android.util.Log
import com.handstrudel.BuildConfig
import com.handstrudel.models.DEFAULT_SOUNDFONT_INSTRUMENT
import com.handstrudel.models.FREE_PROGRESSION
import com.handstrudel.models.MusicKey
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupMode
import com.handstrudel.social.model.Video
import com.handstrudel.ui.nav.DefaultAppNavigator
import java.util.UUID

/**
 * DEBUG-only fake social backend for verifying deep-link routing on an emulator before
 * social (WS5) lands, without touching production. Enabled by launching with
 * `--ez debugFakeSocial true`. Every id resolves to a post that has comments, play-along
 * and a shared sound, except [MISSING_ID], which resolves to "not found".
 */
object DebugFakeSocial {
    const val EXTRA = "debugFakeSocial"
    val MISSING_ID: UUID = UUID(0, 0)

    fun installIfRequested(intent: Intent?, navigator: DefaultAppNavigator) {
        if (!BuildConfig.DEBUG || intent?.getBooleanExtra(EXTRA, false) != true) return
        Log.i("DebugFakeSocial", "fake social installed")
        navigator.socialConfigured = { true }
        navigator.fetchVideo = { id -> if (id == MISSING_ID) null else video(id) }
    }

    private fun video(id: UUID) = Video(
        id = id,
        userId = UUID(1, 1),
        videoKey = "debug",
        thumbKey = "debug",
        caption = "Debug performance",
        likeCount = 0,
        createdAt = "2026-11-21T00:00:00Z",
        username = "debug",
        soundSetup = SoundSetup(
            instrument = DEFAULT_SOUNDFONT_INSTRUMENT.id,
            waveform = "sawtooth",
            key = MusicKey.D,
            scale = ScaleSelection.PENTATONIC,
            progression = FREE_PROGRESSION.id,
            mode = SoundSetupMode.SCALE_CHORD_MELODY,
            bpm = 100.0,
            useSoundFont = true,
            autoStrum = false,
            padVolume = 0.6,
            gridOctave = 3,
            gridRange = 2,
        ),
        commentsEnabled = true,
        backingEnabled = true,
    )
}

/**
 * DEBUG-only: open shell sheets whose buttons live in other workstreams' screens
 * (`--es debugOpenSheet appearance|analytics`), for emulator verification.
 */
object DebugShellHooks {
    const val EXTRA = "debugOpenSheet"
    val openSheet = kotlinx.coroutines.flow.MutableStateFlow<String?>(null)

    fun handle(intent: Intent?) {
        if (!BuildConfig.DEBUG) return
        intent?.getStringExtra(EXTRA)?.let { openSheet.value = it }
    }
}
