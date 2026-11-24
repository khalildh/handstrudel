package com.handstrudel.engine.debug

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import com.handstrudel.engine.HandData
import com.handstrudel.engine.HandStrudelEngine
import com.handstrudel.engine.HandsState
import com.handstrudel.engine.PlayInput
import com.handstrudel.engine.StudioMode
import com.handstrudel.models.MusicKey
import com.handstrudel.models.Scale
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.chordProgression
import com.handstrudel.models.soundFontInstrument
import com.handstrudel.store.StoreGate
import org.json.JSONObject

/**
 * DEBUG builds only: drive and inspect the engine over adb, for emulator
 * verification without a camera.
 *
 *     adb shell am broadcast -a com.handstrudel.debug.ENGINE -p com.handstrudel.app --es cmd "mode melodic"
 *     adb logcat -s EngineDebug
 *
 * Commands: `start [air|touch]`, `stop`, `pause`, `resume`, `mode <raw>`, `sf <raw> <bool>`,
 * `instrument <id>`, `waveform <id>`, `key <raw>`, `scale <raw>`, `progression <id>`, `bpm <n>`,
 * `drum <1|2> <loop> [volume] [bpm]`, `hands <lx> <ly> <lp> <rx> <ry> <rp>` (`-` = no hand),
 * `touch <split-chord|split-melody|scale-chord|scale-melody|radial-chord|radial-melody|zones-chord|zones-melody> <id> <a> [b]`,
 * `exit <id>`, `grid-on <id> <lane>`, `grid-slide <id> <lane>`, `grid-off <id>`, `drum-tap <lane>`,
 * `learn <songId>`, `learn-tap <lane>`, `quantize <bool> [div]`, `autostrum <bool>`, `swap <bool>`,
 * `preview <instrumentId>`, `firstnote <midi>`, `strudel <code>`, `state`,
 * `handframes <seconds>` (loop the images in `<files>/handframes` (push via `run-as`), sorted by name,
 * at ~30 fps as raw front-camera frames through the real frame transform and hand tracker).
 */
internal object EngineDebugReceiver {
    private const val ACTION = "com.handstrudel.debug.ENGINE"
    private const val TAG = "EngineDebug"

    private lateinit var appContext: Context

    fun register(context: Context, engine: HandStrudelEngine) {
        appContext = context.applicationContext
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val cmd = intent.getStringExtra("cmd") ?: return
                try { run(engine, cmd.trim().split(Regex("\\s+"))) } catch (e: Exception) { Log.e(TAG, "cmd '$cmd' failed", e) }
            }
        }
        val filter = IntentFilter(ACTION)
        if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        else context.registerReceiver(receiver, filter)
    }

    private fun b(s: String?) = s == "true" || s == "on" || s == "1"

    private fun run(e: HandStrudelEngine, a: List<String>) {
        when (a[0]) {
            "start" -> e.start(if (a.getOrNull(1) == "air") PlayInput.AIR else PlayInput.TOUCH)
            "stop" -> e.stop()
            "pause" -> e.pause()
            "resume" -> e.resume()
            "mode" -> e.switchMode(StudioMode.fromRaw(a[1]) ?: error("unknown mode ${a[1]}"))
            "sf" -> e.setUseSoundFont(StudioMode.fromRaw(a[1]) ?: error("mode"), b(a[2]))
            "instrument" -> e.setSoundFontInstrument(soundFontInstrument(a[1]))
            "waveform" -> e.setWaveform(a[1])
            "key" -> e.setKey(MusicKey.fromRaw(a[1]) ?: error("key"))
            "scale" -> e.setScale(ScaleSelection.BuiltIn(Scale.fromRaw(a.drop(1).joinToString(" ")) ?: error("scale")))
            "progression" -> e.setProgression(chordProgression(a[1]) ?: error("progression"))
            "bpm" -> e.setManualBPM(a[1].toDouble())
            "drum" -> {
                val t = a[1].toInt()
                e.setDrumLoop(t, a[2])
                a.getOrNull(3)?.let { e.setDrumVolume(t, it.toDouble()) }
                a.getOrNull(4)?.let { e.setDrumBPM(t, it.toDouble()) }
            }
            "hands" -> {
                fun hand(i: Int, chirality: String) =
                    if (a[i] == "-") null else HandData.synthetic(a[i].toDouble(), a[i + 1].toDouble(), a[i + 2].toDouble(), chirality)
                e.injectHands(HandsState(hand(1, "Left"), hand(4, "Right")))
            }
            "touch" -> {
                val id = a[2]
                val x = a[3].toInt()
                val y = a.getOrNull(4)?.toInt() ?: 0
                when (a[1]) {
                    "split-chord" -> e.splitTouchEnterChord(id, x, y)
                    "split-melody" -> e.splitTouchEnterMelody(id, x)
                    "scale-chord" -> e.scaleTouchEnterChord(id, x, y)
                    "scale-melody" -> e.scaleTouchEnterMelody(id, x)
                    "radial-chord" -> e.radialTouchEnterChord(id, x)
                    "radial-melody" -> e.radialTouchEnterMelody(id, x)
                    "zones-chord" -> e.zonesTouchEnterChord(id, x)
                    "zones-melody" -> e.zonesTouchEnterMelody(id, x)
                }
            }
            "exit" -> e.splitTouchExit(a[1])
            "grid-on" -> e.gridLaneTouchOn(a[1], a[2].toInt())
            "grid-slide" -> e.gridLaneTouchSlide(a[1], a[2].toInt())
            "grid-off" -> e.gridLaneTouchOff(a[1])
            "drum-tap" -> e.drumLaneTap(a[1].toInt())
            "learn" -> e.loadLearnSong(a[1])
            "learn-tap" -> e.tapLearnLane(a[1].toInt())
            "quantize" -> { e.setQuantizeEnabled(b(a[1])); a.getOrNull(2)?.let { e.setQuantizeDiv(it.toInt()) } }
            "autostrum" -> e.setAutoStrum(b(a[1]))
            "swap" -> e.setSwapHands(b(a[1]))
            "preview" -> e.previewInstrument(soundFontInstrument(a[1]), listOf(60, 64, 67, 72))
            "firstnote" -> e.playFirstNote(a[1].toInt())
            "strudel" -> e.strudel.evaluate(a.drop(1).joinToString(" "))
            "apply" -> {
                // apply <json SoundSetup> (everything unlocked)
                val setup = com.handstrudel.models.SoundSetup.decode(a.drop(1).joinToString(" "))
                val ok = e.applySoundSetup(setup, AllUnlocked)
                Log.i(TAG, "apply=$ok")
            }
            "js" -> e.strudel.evaluateForResult(a.drop(1).joinToString(" ")) { Log.i(TAG, "JS $it") }
            "state" -> logState(e)
            "handframes" -> playHandFrames(e, a.getOrNull(1)?.toDouble() ?: 10.0)
            else -> Log.w(TAG, "unknown command ${a[0]}")
        }
    }

    /** Bumped by each `handframes` command; an older playback thread stops when it changes. */
    private val handFramesGeneration = java.util.concurrent.atomic.AtomicInteger(0)
    private val handFramesLock = Any()
    private var lastFrameTimestamp = 0L

    /**
     * MediaPipe's live-stream mode needs strictly increasing timestamps. Two overlapping
     * playbacks used to interleave the same clock reading and crash the graph ("received
     * packets having a smaller timestamp"), so frames are stamped from one monotonic clock.
     */
    private fun feedFrame(e: HandStrudelEngine, raw: android.graphics.Bitmap) {
        val frame = com.handstrudel.ui.studio.orientFrameForDetection(raw, 0)
        synchronized(handFramesLock) {
            lastFrameTimestamp = maxOf(android.os.SystemClock.uptimeMillis(), lastFrameTimestamp + 1)
            e.handTracker.detectAsync(frame, lastFrameTimestamp)
        }
    }

    /**
     * Real MediaPipe on real images, standing in for CameraX when the emulator has no hands to
     * film. A new command replaces the running one; when playback ends a few blank frames are
     * sent so the stage drops the hands instead of freezing on the last pose.
     */
    private fun playHandFrames(e: HandStrudelEngine, seconds: Double) {
        val dir = java.io.File(appContext.filesDir, "handframes")
        val files = dir.listFiles { f -> f.extension.lowercase() in setOf("jpg", "jpeg", "png") }?.sortedBy { it.name }.orEmpty()
        if (files.isEmpty()) { Log.w(TAG, "handframes: no images in $dir"); return }
        val generation = handFramesGeneration.incrementAndGet()
        Thread {
            val frames = files.mapNotNull { android.graphics.BitmapFactory.decodeFile(it.path) }
            if (frames.isEmpty()) { Log.w(TAG, "handframes: no readable images in $dir"); return@Thread }
            val end = android.os.SystemClock.uptimeMillis() + (seconds * 1000).toLong()
            var i = 0
            while (android.os.SystemClock.uptimeMillis() < end && handFramesGeneration.get() == generation) {
                val raw = frames[i++ % frames.size]
                feedFrame(e, raw)
                Thread.sleep(33)
            }
            if (handFramesGeneration.get() == generation) {
                val blank = android.graphics.Bitmap.createBitmap(frames[0].width, frames[0].height, android.graphics.Bitmap.Config.ARGB_8888)
                repeat(3) {
                    feedFrame(e, blank)
                    Thread.sleep(33)
                }
            }
            Log.i(TAG, "handframes: played $i frames from ${frames.size} images")
        }.start()
    }

    private fun logState(e: HandStrudelEngine) {
        val cm = e.chordMelody.value
        val learn = e.learn.value
        val o = JSONObject()
            .put("playInput", e.playInput.value.raw).put("cameraIssue", e.cameraIssue.value?.name ?: "none")
            .put("running", e.isRunning.value).put("paused", e.isPaused.value).put("status", e.status.value)
            .put("mode", e.mode.value.raw).put("activeSoundFont", e.activeSoundFontRouting)
            .put("strudelReady", e.strudel.isReady).put("beat", e.currentBeat.value)
            .put("key", e.selectedKey.value.rawValue).put("scale", e.selectedScale.value.rawValue)
            .put("instrument", e.selectedSoundFontInstrument.value.id).put("waveform", e.selectedWaveform.value)
            .put("nativeVoices", e.soundFont.activeVoiceCount).put("nativePeak", e.soundFont.output.takePeak().toDouble())
            .put("chord", cm.currentChordName).put("degree", cm.currentDegree ?: -1).put("melodyLane", cm.melodyLane ?: -1)
            .put("touchedZones", cm.touchedChordZones.size).put("touchedLanes", cm.touchedMelodyLanes.size)
            .put("note", e.noteDisplay.value).put("lastGridNote", e.lanes.value.lastGridNote).put("lastDrumHit", e.lanes.value.lastDrumHit)
            .put("learnSong", learn.currentSongId ?: "").put("learnScore", "${learn.score.perfectHits}/${learn.score.goodHits}/${learn.score.misses}")
            .put("drum1", e.drumTrack1.value.loopId).put("drum2", e.drumTrack2.value.loopId)
            .put("presets", e.presets.value.size).put("customScales", e.customScales.value.size)
        e.strudel.evaluateForResult(
            "JSON.stringify({peak: (window.__hsPeak ? window.__hsPeak() : -1), voices: Object.keys(window._voices || {}).length, " +
                "ctx: (typeof getAudioContext === 'function' ? getAudioContext().state : 'none'), " +
                "t: (typeof getAudioContext === 'function' ? getAudioContext().currentTime : -1)})",
        ) { web ->
            o.put("web", web ?: "null")
            Log.i(TAG, "STATE $o")
        }
    }

    private object AllUnlocked : StoreGate {
        override val isConfigured = true
        override val state: kotlinx.coroutines.flow.StateFlow<com.handstrudel.store.StoreState> = kotlinx.coroutines.flow.MutableStateFlow(com.handstrudel.store.StoreState())
        override fun isUnlocked(packId: String?) = true
        override val hasProAccess = true
        override val hasPlusFeatures = true
        override val hasSubscription = true
        override suspend fun purchase(activity: android.app.Activity, productId: String): com.handstrudel.store.PurchaseResult = com.handstrudel.store.PurchaseResult.Failed("unused")
        override suspend fun restore(packId: String?): com.handstrudel.store.RestoreOutcome? = null
        override suspend fun logIn(appUserId: String) {}
        override suspend fun logOut() {}
        override fun bind(userId: kotlinx.coroutines.flow.StateFlow<java.util.UUID?>) {}
    }
}
