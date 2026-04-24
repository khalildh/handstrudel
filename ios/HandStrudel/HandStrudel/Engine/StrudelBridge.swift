import WebKit
import Combine

final class StrudelBridge: NSObject, ObservableObject {
    private var webView: WKWebView!
    @Published var isReady = false
    @Published var hydraEnabled = false

    var onBeat: ((Int) -> Void)?

    override init() {
        super.init()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Allow JS message handler for callbacks from Strudel
        let contentController = WKUserContentController()
        contentController.add(self, name: "strudelBridge")
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        // Load the HTML engine
        if let htmlURL = Bundle.main.url(forResource: "strudel-engine", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
    }

    /// Get the hidden WebView (needed to add to view hierarchy for audio to work)
    var view: WKWebView { webView }

    /// Initialize Strudel audio engine (call after user interaction)
    func initialize() async throws {
        try await webView.evaluateJavaScript("initStrudel()")
        await MainActor.run { isReady = true }
    }

    /// Evaluate Strudel code
    func evaluate(_ code: String) {
        let escaped = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        webView.evaluateJavaScript("strudelEval(`\(escaped)`)") { _, error in
            if let error { print("strudel eval error:", error) }
        }
    }

    /// Evaluate Hydra visual code
    func evalHydra(_ code: String) {
        let escaped = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        webView.evaluateJavaScript("hydraEval(`\(escaped)`)") { _, error in
            if let error { print("hydra eval error:", error) }
        }
    }

    /// Update signal params (called at 60fps)
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

    /// Batch update all params in a single JS call (more efficient for 60fps)
    func updateParamsBatch(_ jsUpdate: String) {
        webView.evaluateJavaScript(jsUpdate, completionHandler: nil)
    }

    /// Toggle Hydra visuals
    func setHydraEnabled(_ enabled: Bool) {
        hydraEnabled = enabled
        let js = enabled ? "showHydra()" : "hideHydra()"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Stop all audio
    func stop() {
        webView.evaluateJavaScript("strudelStop()") { _, error in
            if let error { print("strudel stop error:", error) }
        }
    }

    /// Get a snapshot of the Hydra canvas for native display
    func captureHydraFrame(completion: @escaping (UIImage?) -> Void) {
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, _ in
            completion(image)
        }
    }
}

extension StrudelBridge: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        if let beat = body["beat"] as? Int {
            onBeat?(beat)
        }
    }
}
