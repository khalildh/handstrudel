package com.handstrudel.engine.strudel

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewAssetLoader
import com.handstrudel.models.MIDI_NOTES
import com.handstrudel.models.MappingConfig
import com.handstrudel.models.NOTES
import com.handstrudel.models.PARAM_MAP
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONObject
import java.util.Locale
import kotlin.coroutines.resume

/**
 * Port of iOS `Engine/StrudelBridge.swift`: a hidden WebView running the same
 * `strudel-engine.html` + `strudel-bundle.js`, driven with the same JS API
 * (`initStrudel`, `strudelEval`, `noteOn`, `__hp.*`, …). Main thread only.
 */
@SuppressLint("SetJavaScriptEnabled")
class StrudelBridge(context: Context, debugMeter: Boolean) {
    private val main = Handler(Looper.getMainLooper())
    private val assets = StrudelAssets(context.applicationContext, debugMeter)
    private val loader = WebViewAssetLoader.Builder()
        .addPathHandler("/${StrudelAssets.URL_DIR}/", assets)
        .build()

    val webView: WebView = WebView(context.applicationContext)

    var isReady: Boolean = false
        private set

    var onBeat: ((Int) -> Unit)? = null
    var onLog: ((String) -> Unit)? = null
    var onNoteStarted: (() -> Unit)? = null

    /** iOS `tempoScale`: 0.5 while recording at half speed. */
    var tempoScale: Double = 1.0
        private set

    init {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            allowFileAccess = false
            allowContentAccess = false
        }
        webView.addJavascriptInterface(JsBridge(), "AndroidStrudel")
        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                loader.shouldInterceptRequest(request.url)

            override fun onPageFinished(view: WebView, url: String?) {
                Log.d(TAG, "page finished loading")
            }
        }
        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(message: android.webkit.ConsoleMessage): Boolean {
                if (message.messageLevel() == android.webkit.ConsoleMessage.MessageLevel.ERROR) {
                    Log.w(TAG, "JS: ${message.message()}")
                }
                return true
            }
        }
        webView.loadUrl(StrudelAssets.PAGE_URL)
    }

    private inner class JsBridge {
        @JavascriptInterface
        fun postMessage(json: String) {
            val body = runCatching { JSONObject(json) }.getOrNull() ?: return
            if (body.has("beat")) {
                val beat = body.optInt("beat", -1)
                if (beat >= 0) main.post { onBeat?.invoke(beat) }
            }
            body.optString("log", "").takeIf { it.isNotEmpty() }?.let { msg ->
                Log.d(TAG, "JS: $msg")
                main.post { onLog?.invoke(msg) }
            }
        }
    }

    /** iOS `initialize()`: one init promise per document, polled until ready/failed (20 s). */
    suspend fun initialize() {
        if (isReady) return
        val script = """
(() => {
  if (window._moduleReady !== true || typeof window.initStrudel !== 'function') return 'waiting';
  if (!window._handStrudelInitState) {
    window._handStrudelInitState = 'loading';
    Promise.resolve().then(() => window.initStrudel()).then(
      () => { window._handStrudelInitState = 'ready'; },
      () => { window._handStrudelInitState = 'failed'; }
    );
  }
  return window._handStrudelInitState;
})()
""".trimIndent()
        try {
            waitForWebAudio { evalForString(script) }
            isReady = true
        } catch (e: StrudelInitException) {
            if (e.failed) webView.evaluateJavascript("delete window._handStrudelInitState", null)
            throw e
        }
    }

    private suspend fun evalForString(script: String): String? = suspendCancellableCoroutine { cont ->
        webView.evaluateJavascript(script) { raw ->
            val value = raw?.takeIf { it != "null" }?.removeSurrounding("\"")
            if (cont.isActive) cont.resume(value)
        }
    }

    /** Evaluates [script] and returns its JSON result (debug/verification). */
    fun evaluateForResult(script: String, callback: (String?) -> Unit) = webView.evaluateJavascript(script) { callback(it) }

    fun evaluate(code: String) {
        webView.evaluateJavascript("void(strudelEval(${JSONObject.quote(code)}))", null)
    }

    fun setTempoScale(scale: Double, bpm: Double) {
        tempoScale = scale
        updateTempo(bpm)
    }

    fun updateTempo(bpm: Double) {
        js("__hp._cpm=${f(bpm / 4 * tempoScale, 2)}")
    }

    fun updateParams(params: Map<String, Double>, config: MappingConfig) {
        val ni = swiftRoundIdx(params["noteIdx"] ?: 10.0)
        val midi = MIDI_NOTES[ni]
        val cpm = (params["bpm"] ?: 120.0) / 4 * tempoScale
        val parts = mutableListOf("__hp._midi=$midi", "__hp._cpm=${f(cpm, 2)}")
        for (id in config.extraParamIds()) {
            val def = PARAM_MAP[id] ?: continue
            parts += "__hp.$id=${f(params[id] ?: def.defaultValue, 4)}"
        }
        js(parts.joinToString(";"))
    }

    fun updateScaleParams(params: Map<String, Double>, config: MappingConfig, midi: Int) {
        val cpm = (params["bpm"] ?: 120.0) / 4 * tempoScale
        val parts = mutableListOf("__hp._midi=$midi", "__hp._cpm=${f(cpm, 2)}")
        for (id in config.extraParamIds()) {
            val def = PARAM_MAP[id] ?: continue
            parts += "__hp.$id=${f(params[id] ?: def.defaultValue, 4)}"
        }
        js(parts.joinToString(";"))
    }

    fun updateChordParams(params: Map<String, Double>, config: MappingConfig, chordMidi: List<Int>) {
        val cpm = (params["bpm"] ?: 120.0) / 4 * tempoScale
        val first = chordMidi.firstOrNull() ?: 60
        val parts = mutableListOf("__hp._cpm=${f(cpm, 2)}", "__hp._midi=$first")
        for (i in 0 until 3) parts += "__hp._cm$i=${chordMidi.getOrElse(i) { first }}"
        for (id in config.extraParamIds()) {
            val def = PARAM_MAP[id] ?: continue
            parts += "__hp.$id=${f(params[id] ?: def.defaultValue, 4)}"
        }
        js(parts.joinToString(";"))
    }

    fun playHit(type: String) = js("playHit('$type')")

    fun updateDrumParams(intensity: Double, complexity: Double) =
        js("_drumIntensity=${f(intensity, 2)};_drumComplexity=${f(complexity, 2)}")

    fun noteOn(hand: String, midi: Int, waveform: String = "sawtooth", velocity: Double = 0.6) {
        val safeMidi = midi.coerceIn(0, 127)
        val safeVel = velocity.coerceIn(0.0, 1.0)
        js("noteOn('$hand',$safeMidi,'$waveform',${f(safeVel, 2)})")
        if (isReady && !hand.startsWith("jam-")) onNoteStarted?.invoke()
    }

    fun noteOff(hand: String) = js("noteOff('$hand')")

    fun noteSlide(hand: String, midi: Int) = js("noteSlide('$hand',$midi)")

    fun setSynthParam(id: String, value: Double) = js("__hp.$id=${f(value, 4)}")

    fun playNote(midi: Int, waveform: String = "sawtooth", velocity: Double = 0.6, duration: Double = 0.3) {
        val safeMidi = midi.coerceIn(0, 127)
        js("playNote($safeMidi,'$waveform',${f(velocity, 2)},${f(duration, 2)})")
    }

    fun stop() = js("strudelStop()")

    private fun js(script: String) = webView.evaluateJavascript(script, null)

    class StrudelInitException(message: String, val failed: Boolean) : Exception(message)

    companion object {
        private const val TAG = "StrudelBridge"

        internal fun f(value: Double, decimals: Int): String = String.format(Locale.US, "%.${decimals}f", value)

        private fun swiftRoundIdx(v: Double): Int =
            (Math.round(kotlin.math.abs(v)).toInt() * if (v < 0) -1 else 1).coerceIn(0, NOTES.size - 1)

        /** iOS `waitForWebAudio`: poll the init state until ready (or failed / 20 s timeout). */
        suspend fun waitForWebAudio(timeoutMillis: Long = 20_000, pollMillis: Long = 150, readState: suspend () -> String?) {
            val deadline = System.nanoTime() + timeoutMillis * 1_000_000
            while (System.nanoTime() < deadline) {
                val state = readState()
                if (state == "ready") return
                if (state == "failed") throw StrudelInitException("The web audio engine couldn't start.", failed = true)
                delay(pollMillis)
            }
            throw StrudelInitException("The web audio engine took too long to load.", failed = false)
        }
    }
}
