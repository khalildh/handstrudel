import SwiftUI

struct ContentView: View {
    @StateObject private var engine = EngineController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                // Main app view
                GeometryReader { geo in
                    ZStack {
                        // Camera + hand overlay
                        CameraView(handTracker: engine.handTracker, handsState: engine.handsState)
                            .ignoresSafeArea()

                        // Hydra visuals overlay (from WebView)
                        if engine.hydraEnabled {
                            WebViewContainer(webView: engine.strudelBridge.view)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                                .opacity(0.6)
                        }

                        // Hand skeleton overlay
                        HandOverlayView(handsState: engine.handsState)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)

                        // Sidebar (right side)
                        HStack(spacing: 0) {
                            Spacer()
                            SidebarView(engine: engine)
                                .frame(width: min(280, geo.size.width * 0.35))
                        }

                        // Header
                        VStack {
                            HeaderView(status: engine.status, beat: engine.currentBeat, bpm: engine.bpm)
                            Spacer()
                        }
                    }
                }
            } else {
                // Start overlay
                StartOverlayView(onStart: engine.start)
            }

            // Hidden WebView for audio (must be in view hierarchy)
            WebViewContainer(webView: engine.strudelBridge.view)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .statusBarHidden(engine.isRunning)
    }
}

// Wraps WKWebView for SwiftUI
struct WebViewContainer: UIViewRepresentable {
    let webView: UIView

    func makeUIView(context: Context) -> UIView {
        webView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
