package com.handstrudel.engine.strudel

import android.content.Context
import android.webkit.WebResourceResponse
import androidx.webkit.WebViewAssetLoader
import java.io.ByteArrayInputStream
import java.io.IOException

/**
 * Serves the iOS Strudel engine (`strudel-engine.html`, `strudel-bundle.js`,
 * `instrument-samples/`) from APK assets under
 * `https://appassets.androidplatform.net/strudel/`. The files are copied from
 * `ios/HandStrudel/HandStrudel/Resources` at build time (`generateStrudelAssets`),
 * so both platforms run the same bundle and samples.
 *
 * The HTML is served with an Android shim injected before the bundle: it
 * forwards `window.webkit.messageHandlers.strudelBridge.postMessage` to the
 * `AndroidStrudel` JavaScript interface and maps the bundle's `app-samples://`
 * URLs (iOS `SampleSchemeHandler`) to the asset loader. iOS is untouched.
 */
internal class StrudelAssets(private val context: Context, private val debugMeter: Boolean) : WebViewAssetLoader.PathHandler {

    override fun handle(path: String): WebResourceResponse? {
        if (path == SHIM_PATH) return text(shimScript(), "application/javascript")
        val assetPath = "$ASSET_DIR/$path"
        return try {
            if (path == HTML_FILE) {
                val html = context.assets.open(assetPath).bufferedReader().use { it.readText() }
                text(injectShim(html), "text/html")
            } else {
                val stream = context.assets.open(assetPath)
                WebResourceResponse(mimeFor(path), null, stream).apply {
                    responseHeaders = mapOf("Access-Control-Allow-Origin" to "*", "Cache-Control" to "max-age=31536000")
                }
            }
        } catch (e: IOException) {
            WebResourceResponse("text/plain", "utf-8", 404, "Not Found", emptyMap(), ByteArrayInputStream(ByteArray(0)))
        }
    }

    private fun text(body: String, mime: String) =
        WebResourceResponse(mime, "utf-8", ByteArrayInputStream(body.toByteArray(Charsets.UTF_8)))

    private fun shimScript(): String = buildString {
        append(SHIM_JS.replace("__SAMPLES_BASE__", "$ORIGIN/$URL_DIR/instrument-samples/"))
        if (debugMeter) append(METER_JS)
    }

    companion object {
        const val ORIGIN = "https://appassets.androidplatform.net"
        const val URL_DIR = "strudel"
        const val ASSET_DIR = "strudel"
        const val HTML_FILE = "strudel-engine.html"
        const val SHIM_PATH = "android-shim.js"
        const val PAGE_URL = "$ORIGIN/$URL_DIR/$HTML_FILE"

        /** Insert the shim as the first script of `<head>` so it runs before everything else. */
        fun injectShim(html: String): String {
            val tag = "<script src=\"$SHIM_PATH\"></script>"
            val head = html.indexOf("<head>")
            return if (head >= 0) html.substring(0, head + 6) + "\n    " + tag + html.substring(head + 6) else tag + html
        }

        fun mimeFor(path: String): String = when (path.substringAfterLast('.', "").lowercase()) {
            "js", "mjs" -> "application/javascript"
            "json" -> "application/json"
            "mp3" -> "audio/mpeg"
            "html" -> "text/html"
            "wav" -> "audio/wav"
            else -> "application/octet-stream"
        }

        private val SHIM_JS = """
(function () {
  if (!window.AndroidStrudel) return;
  window.webkit = window.webkit || {};
  window.webkit.messageHandlers = {
    strudelBridge: { postMessage: function (m) { try { window.AndroidStrudel.postMessage(JSON.stringify(m)); } catch (e) {} } }
  };
  var samplesBase = '__SAMPLES_BASE__';
  var nativeFetch = window.fetch.bind(window);
  window.fetch = function (input, init) {
    var url = typeof input === 'string' ? input : (input && input.url);
    if (typeof url === 'string' && url.indexOf('app-samples://') === 0) {
      return nativeFetch(samplesBase + url.substring('app-samples://'.length), init);
    }
    return nativeFetch(input, init);
  };
})();
""".trimIndent()

        /**
         * Debug builds only: every connection into an AudioContext's destination
         * also feeds one analyser, so `__hsPeak()` reports whether the WebView is
         * actually producing sound (emulator verification).
         */
        private val METER_JS = """

(function () {
  var connect = AudioNode.prototype.connect;
  var analysers = new WeakMap();
  function analyserFor(ctx) {
    var a = analysers.get(ctx);
    if (!a) { a = ctx.createAnalyser(); a.fftSize = 2048; analysers.set(ctx, a); window.__hsAnalyser = a; }
    return a;
  }
  AudioNode.prototype.connect = function (dest) {
    var r = connect.apply(this, arguments);
    try { if (dest instanceof AudioDestinationNode) connect.call(this, analyserFor(dest.context)); } catch (e) {}
    return r;
  };
  window.__hsPeak = function () {
    var a = window.__hsAnalyser;
    if (!a) return 0;
    var buf = new Float32Array(a.fftSize);
    a.getFloatTimeDomainData(buf);
    var p = 0;
    for (var i = 0; i < buf.length; i++) { var v = Math.abs(buf[i]); if (v > p) p = v; }
    return p;
  };
})();
""".trimIndent()
    }
}
