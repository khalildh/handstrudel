import WebKit
import UIKit

/// Serves bundled instrument sample files (mp3 + JSON) to the JS layer.
///
/// WKWebView blocks `fetch()` to file:// URLs for safety reasons, so the JS
/// can't directly load the audio files in the app's Resources folder. We
/// register a custom scheme — `app-samples://<relative/path>` — that maps to
/// `HandStrudel.app/instrument-samples/<relative/path>` and returns the bytes
/// over the URL Scheme Task API. No private APIs, no file-origin overrides.
final class SampleSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let reqURL = urlSchemeTask.request.url else {
            debugLog("[samples] no URL on request")
            urlSchemeTask.didFailWithError(NSError(domain: "SampleSchemeHandler", code: 1))
            return
        }
        var relative = (reqURL.host ?? "") + reqURL.path
        if relative.hasPrefix("/") { relative.removeFirst() }
        debugLog("[samples] req: \(reqURL.absoluteString) → host=\(reqURL.host ?? "nil") path=\(reqURL.path) relative=\(relative)")
        guard let resBase = Bundle.main.url(forResource: "instrument-samples", withExtension: nil) else {
            debugLog("[samples] ERROR: instrument-samples folder missing from bundle")
            urlSchemeTask.didFailWithError(NSError(domain: "SampleSchemeHandler", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "instrument-samples folder missing from bundle"]))
            return
        }
        let fileURL = resBase.appendingPathComponent(relative)
        guard let data = try? Data(contentsOf: fileURL) else {
            debugLog("[samples] NOT FOUND: \(fileURL.path)")
            urlSchemeTask.didFailWithError(NSError(domain: "SampleSchemeHandler", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Not found: \(relative)"]))
            return
        }
        debugLog("[samples] OK: \(relative) (\(data.count) bytes)")
        let mime: String
        if fileURL.pathExtension == "mp3" { mime = "audio/mpeg" }
        else if fileURL.pathExtension == "json" { mime = "application/json" }
        else { mime = "application/octet-stream" }
        let resp = HTTPURLResponse(url: reqURL, statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mime,
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*",
            ])!
        urlSchemeTask.didReceive(resp)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

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
    /// Records notes during a video take for "Learn to play". Set by the engine.
    var noteCapture: PerformanceNoteCapture?
    private var webView: WKWebView!
    @Published var isReady = false

    var onBeat: ((Int) -> Void)?
    var onLog: ((String) -> Void)?
    var onNoteStarted: (() -> Void)?

    override init() {
        super.init()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Register a custom URL scheme so the JS can fetch bundled instrument
        // samples without running into WebKit's file:// origin restrictions.
        // `app://samples/...` resolves to files inside the app's Resources.
        config.setURLSchemeHandler(SampleSchemeHandler(), forURLScheme: "app-samples")

        let contentController = WKUserContentController()
        contentController.add(self, name: "strudelBridge")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-real-web-audio") {
            let holdRemoteDrums = """
            const fetchResource = window.fetch.bind(window);
            window.fetch = (input, options) => String(input).includes('raw.githubusercontent.com/tidalcycles/Dirt-Samples/')
              ? new Promise(() => {}) : fetchResource(input, options);
            """
            contentController.addUserScript(WKUserScript(source: holdRemoteDrums, injectionTime: .atDocumentStart,
                                                         forMainFrameOnly: true))
        }
        #endif
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

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
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        debugLog("page FAILED to load: \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        debugLog("page FAILED provisional navigation: \(error)")
    }

    var view: WKWebView { webView }

    func initialize() async throws {
        guard !isReady else { return }
        // A cancelled Swift session can leave JavaScript initialization in flight.
        // Keep one promise per document and wait on its actual result on retry.
        let script = """
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
        """
        do {
            try await Self.waitForWebAudio { (try? await self.webView.evaluateJavaScript(script)) as? String }
            isReady = true
        } catch let error as NSError {
            if error.domain == "StrudelBridge", error.code == 2 {
                _ = try? await webView.evaluateJavaScript("delete window._handStrudelInitState")
            }
            throw error
        }
    }

    static func waitForWebAudio(timeout: TimeInterval = 20, pollNanoseconds: UInt64 = 150_000_000,
                                readState: () async -> String?) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline {
            try Task.checkCancellation()
            let state = await readState()
            try Task.checkCancellation()
            if state == "ready" { return }
            if state == "failed" {
                throw NSError(domain: "StrudelBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "The web audio engine couldn't start."])
            }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }
        throw NSError(domain: "StrudelBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "The web audio engine took too long to load."])
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

    private(set) var tempoScale: Double = 1

    func setTempoScale(_ scale: Double, bpm: Double) {
        tempoScale = scale
        updateTempo(bpm)
    }

    func updateTempo(_ bpm: Double) {
        webView.evaluateJavaScript("__hp._cpm=\(String(format: "%.2f", bpm / 4 * tempoScale))", completionHandler: nil)
    }

    func updateParams(_ params: MusicParams, config: MappingConfig) {
        let ni = max(0, min(NOTES.count - 1, Int((params["noteIdx"] ?? 10).rounded())))
        let midi = MIDI_NOTES[ni]
        let cpm = (params["bpm"] ?? 120) / 4 * tempoScale

        var parts = ["__hp._midi=\(midi)", "__hp._cpm=\(String(format: "%.2f", cpm))"]
        for id in extraParamIds(config) {
            guard let def = PARAM_MAP[id] else { continue }
            let val = params[id] ?? def.defaultValue
            parts.append("__hp.\(id)=\(String(format: "%.4f", val))")
        }
        webView.evaluateJavaScript(parts.joined(separator: ";"), completionHandler: nil)
    }

    func updateScaleParams(_ params: MusicParams, config: MappingConfig, midi: Int) {
        let cpm = (params["bpm"] ?? 120) / 4 * tempoScale
        var parts = ["__hp._midi=\(midi)", "__hp._cpm=\(String(format: "%.2f", cpm))"]
        for id in extraParamIds(config) {
            guard let def = PARAM_MAP[id] else { continue }
            parts.append("__hp.\(id)=\(String(format: "%.4f", params[id] ?? def.defaultValue))")
        }
        webView.evaluateJavaScript(parts.joined(separator: ";"), completionHandler: nil)
    }

    func updateChordParams(_ params: MusicParams, config: MappingConfig, chordMidi: [Int]) {
        let cpm = (params["bpm"] ?? 120) / 4 * tempoScale
        var parts = ["__hp._cpm=\(String(format: "%.2f", cpm))", "__hp._midi=\(chordMidi.first ?? 60)"]
        for i in 0..<3 {
            let midi = i < chordMidi.count ? chordMidi[i] : (chordMidi.first ?? 60)
            parts.append("__hp._cm\(i)=\(midi)")
        }
        for id in extraParamIds(config) {
            guard let def = PARAM_MAP[id] else { continue }
            parts.append("__hp.\(id)=\(String(format: "%.4f", params[id] ?? def.defaultValue))")
        }

        webView.evaluateJavaScript(parts.joined(separator: ";"), completionHandler: nil)
    }

    func playHit(_ type: String) {
        webView.evaluateJavaScript("playHit('\(type)')", completionHandler: nil)
    }

    func updateDrumParams(intensity: Double, complexity: Double) {
        webView.evaluateJavaScript("_drumIntensity=\(String(format: "%.2f", intensity));_drumComplexity=\(String(format: "%.2f", complexity))", completionHandler: nil)
    }

    func noteOn(hand: String, midi: Int, waveform: String = "sawtooth", velocity: Double = 0.6) {
        let safeMidi = max(0, min(127, midi))
        let safeVel = max(0, min(1, velocity))
        webView.evaluateJavaScript("noteOn('\(hand)',\(safeMidi),'\(waveform)',\(String(format: "%.2f", safeVel)))", completionHandler: nil)
        if isReady, !hand.hasPrefix("jam-") { onNoteStarted?() }
        noteCapture?.noteOn(voice: hand, midi: safeMidi, role: PerformanceNoteCapture.role(forVoice: hand))
    }

    func noteOff(hand: String) {
        webView.evaluateJavaScript("noteOff('\(hand)')", completionHandler: nil)
        noteCapture?.noteOff(voice: hand)
    }

    func noteSlide(hand: String, midi: Int) {
        webView.evaluateJavaScript("noteSlide('\(hand)',\(midi))", completionHandler: nil)
        noteCapture?.slide(voice: hand, midi: max(0, min(127, midi)))
    }

    /// Set a single synth-side parameter on the global `__hp` object that the
    /// Strudel patterns and noteOn voices read from (e.g. lpf, hpf, reverb).
    func setSynthParam(_ id: String, value: Double) {
        webView.evaluateJavaScript("__hp.\(id)=\(String(format: "%.4f", value))", completionHandler: nil)
    }

    func playNote(midi: Int, waveform: String = "sawtooth", velocity: Double = 0.6, duration: Double = 0.3,
                  capture role: NoteCaptureRole = .melody) {
        let safeMidi = max(0, min(127, midi))
        webView.evaluateJavaScript("playNote(\(safeMidi),'\(waveform)',\(String(format: "%.2f", velocity)),\(String(format: "%.2f", duration)))", completionHandler: nil)
        noteCapture?.oneShot(midi: safeMidi, duration: duration, role: role)
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
