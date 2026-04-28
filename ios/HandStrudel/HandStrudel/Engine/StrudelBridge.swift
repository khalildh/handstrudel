import WebKit
import UIKit

private func debugLog(_ msg: String) {
    #if DEBUG
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("debug.log")
    let line = "\(Date()): [bridge] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }
    #endif
}

final class StrudelBridge: NSObject, ObservableObject, WKNavigationDelegate {
    private var webView: WKWebView!
    @Published var isReady = false
    @Published var hydraEnabled = false

    var onBeat: ((Int) -> Void)?
    var onLog: ((String) -> Void)?
    private var moduleReadyContinuation: CheckedContinuation<Void, Never>?
    private var pageLoaded = false

    override init() {
        super.init()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        contentController.add(self, name: "strudelBridge")
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        debugLog("loading HTML file")
        if let htmlURL = Bundle.main.url(forResource: "strudel-engine", withExtension: "html") {
            debugLog("HTML URL: \(htmlURL)")
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            debugLog("ERROR: strudel-engine.html not found in bundle!")
        }
    }

    // WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        debugLog("page finished loading")
        pageLoaded = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        debugLog("page FAILED to load: \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        debugLog("page FAILED provisional navigation: \(error)")
    }

    var view: WKWebView { webView }

    func initialize() async throws {
        debugLog("initialize() called, waiting for module ready...")

        // Poll for module ready with timeout (simpler and more reliable than continuations)
        let deadline = Date().addingTimeInterval(20)
        var moduleReady = false

        while Date() < deadline {
            let result = try? await webView.evaluateJavaScript("window._moduleReady === true")
            if let ready = result as? Bool, ready {
                moduleReady = true
                break
            }
            // Check for errors and module started status
            let started = try? await webView.evaluateJavaScript("window._moduleStarted === true")
            let lastErr = try? await webView.evaluateJavaScript("window._lastError")
            debugLog("module not ready yet, pageLoaded=\(pageLoaded), moduleStarted=\(started ?? false), lastError=\(lastErr ?? "none")")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        guard moduleReady else {
            debugLog("TIMEOUT: module never became ready")
            // Try to get any JS errors
            let errors = try? await webView.evaluateJavaScript("document.body?.innerText || 'no body'")
            debugLog("page content: \(errors ?? "nil")")
            throw NSError(domain: "StrudelBridge", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "JS module load timed out after 20s"])
        }

        debugLog("module ready! calling initStrudel()...")
        do {
            _ = try await webView.evaluateJavaScript("initStrudel()")
        } catch {
            // "unsupported type" is OK — initStrudel ran fine, WKWebView just can't serialize the Promise result
            debugLog("initStrudel eval result: \(error.localizedDescription)")
        }
        // Wait a beat for async init to finish
        try? await Task.sleep(nanoseconds: 500_000_000)
        let ready = try? await webView.evaluateJavaScript("window._moduleReady === true && typeof strudelEval === 'function'")
        debugLog("post-init check: \(ready ?? false)")
        isReady = true
    }

    func evaluate(_ code: String) {
        let escaped = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        // Wrap in void() to avoid WKWebView trying to serialize the Promise return value
        webView.evaluateJavaScript("void(strudelEval(`\(escaped)`))") { _, error in
            if let error { debugLog("eval error: \(error)") }
        }
    }

    func evalHydra(_ code: String) {
        let escaped = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        webView.evaluateJavaScript("hydraEval(`\(escaped)`)") { _, error in
            if let error { debugLog("hydra eval error: \(error)") }
        }
    }

    func updateParams(_ params: MusicParams, config: MappingConfig) {
        let ni = max(0, min(NOTES.count - 1, Int((params["noteIdx"] ?? 10).rounded())))
        let midi = MIDI_NOTES[ni]
        let cpm = (params["bpm"] ?? 120) / 4

        var js = "__hp._midi=\(midi);__hp._cpm=\(String(format: "%.2f", cpm));"

        for id in extraParamIds(config) {
            guard let def = PARAM_MAP[id] else { continue }
            let val = params[id] ?? def.defaultValue
            js += "__hp.\(id)=\(String(format: "%.4f", val));"
        }

        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func updateScaleParams(_ params: MusicParams, config: MappingConfig, midi: Int) {
        let cpm = (params["bpm"] ?? 120) / 4

        var js = "__hp._midi=\(midi);__hp._cpm=\(String(format: "%.2f", cpm));"

        for id in extraParamIds(config) {
            guard let def = PARAM_MAP[id] else { continue }
            let val = params[id] ?? def.defaultValue
            js += "__hp.\(id)=\(String(format: "%.4f", val));"
        }

        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func updateChordParams(_ params: MusicParams, config: MappingConfig, chordMidi: [Int]) {
        let cpm = (params["bpm"] ?? 120) / 4

        var js = "__hp._cpm=\(String(format: "%.2f", cpm));__hp._midi=\(chordMidi.first ?? 60);"
        // Set individual chord voice MIDI values
        for i in 0..<3 {
            let midi = i < chordMidi.count ? chordMidi[i] : (chordMidi.first ?? 60)
            js += "__hp._cm\(i)=\(midi);"
        }

        for id in extraParamIds(config) {
            guard let def = PARAM_MAP[id] else { continue }
            let val = params[id] ?? def.defaultValue
            js += "__hp.\(id)=\(String(format: "%.4f", val));"
        }

        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func setHydraEnabled(_ enabled: Bool) {
        hydraEnabled = enabled
        let js = enabled ? "showHydra()" : "hideHydra()"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func playHit(_ type: String) {
        webView.evaluateJavaScript("playHit('\(type)')", completionHandler: nil)
    }

    func noteOn(hand: String, midi: Int, waveform: String = "sawtooth", velocity: Double = 0.6) {
        webView.evaluateJavaScript("noteOn('\(hand)',\(midi),'\(waveform)',\(String(format: "%.2f", velocity)))", completionHandler: nil)
    }

    func noteOff(hand: String) {
        webView.evaluateJavaScript("noteOff('\(hand)')", completionHandler: nil)
    }

    func noteSlide(hand: String, midi: Int) {
        webView.evaluateJavaScript("noteSlide('\(hand)',\(midi))", completionHandler: nil)
    }

    func playNote(midi: Int, waveform: String = "sawtooth", velocity: Double = 0.6, duration: Double = 0.3) {
        webView.evaluateJavaScript("playNote(\(midi),'\(waveform)',\(String(format: "%.2f", velocity)),\(String(format: "%.2f", duration)))", completionHandler: nil)
    }

    func stop() {
        webView.evaluateJavaScript("strudelStop()", completionHandler: nil)
    }
}

extension StrudelBridge: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        if let beat = body["beat"] as? Int {
            onBeat?(beat)
        }

        if let log = body["log"] as? String {
            debugLog("JS: \(log)")
            onLog?(log)
        }
    }
}
