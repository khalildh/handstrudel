package com.handstrudel.engine

import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class StrudelBridge(context: Context) {
    private val webView: WebView
    private val _isReady = MutableStateFlow(false)
    val isReady = _isReady.asStateFlow()

    var onBeat: ((Int) -> Unit)? = null
    var onLog: ((String) -> Unit)? = null

    init {
        webView = WebView(context).apply {
            @SuppressLint("SetJavaScriptEnabled")
            settings.javaScriptEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            settings.domStorageEnabled = true
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

            addJavascriptInterface(JsBridge(), "Android")

            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    Log.d("StrudelBridge", "Page loaded")
                }
            }
            webChromeClient = WebChromeClient()

            loadUrl("file:///android_asset/strudel-engine.html")
        }
    }

    fun initialize() {
        webView.evaluateJavascript("void(initStrudel())", null)
    }

    fun evaluate(code: String) {
        val escaped = code.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
        webView.evaluateJavascript("void(strudelEval('$escaped'))", null)
    }

    fun stop() {
        webView.evaluateJavascript("void(strudelStop())", null)
    }

    fun playHit(type: String) {
        webView.evaluateJavascript("void(playHit('$type'))", null)
    }

    fun noteOn(hand: String, midi: Int, waveform: String, velocity: Double) {
        val vel = velocity.coerceIn(0.0, 1.0)
        webView.evaluateJavascript(
            "void(noteOn('$hand', $midi, '$waveform', $vel))", null
        )
    }

    fun noteOff(hand: String) {
        webView.evaluateJavascript("void(noteOff('$hand'))", null)
    }

    fun noteSlide(hand: String, midi: Int) {
        webView.evaluateJavascript("void(noteSlide('$hand', $midi))", null)
    }

    fun updateParams(params: Map<String, Double>) {
        val js = params.entries.joinToString(";") { (k, v) -> "__hp.$k=$v" }
        webView.evaluateJavascript(js, null)
    }

    fun setDrumParams(intensity: Double, complexity: Double) {
        webView.evaluateJavascript(
            "_drumIntensity=$intensity;_drumComplexity=$complexity", null
        )
    }

    fun getWebView(): WebView = webView

    private inner class JsBridge {
        @JavascriptInterface
        fun onReady() {
            Log.d("StrudelBridge", "Strudel ready")
            _isReady.value = true
        }

        @JavascriptInterface
        fun onBeat(beat: Int) {
            onBeat?.invoke(beat)
        }

        @JavascriptInterface
        fun onLog(msg: String) {
            Log.d("StrudelBridge", msg)
            onLog?.invoke(msg)
        }
    }
}
