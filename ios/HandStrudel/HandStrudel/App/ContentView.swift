import SwiftUI

struct ContentView: View {
    @StateObject private var engine = EngineController()
    @State private var showSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                performanceView
            } else {
                StartOverlayView(
                    status: engine.status,
                    onStart: { cfg, hCfg, adv in
                        engine.start(config: cfg, hydraConfig: hCfg, advanced: adv)
                    }
                )
            }

            // Hidden WebView for audio (must be in view hierarchy)
            WebViewContainer(webView: engine.strudelBridge.view)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .statusBarHidden(engine.isRunning)
    }

    // MARK: - Performance View

    private var performanceView: some View {
        ZStack {
            // Full-screen camera
            CameraView(handTracker: engine.handTracker)
                .ignoresSafeArea()

            // Hydra visuals overlay
            if engine.hydraEnabled {
                WebViewContainer(webView: engine.strudelBridge.view)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(0.5)
            }

            // Hand skeleton overlay with glow (aspect-corrected)
            HandOverlayView(
                handsState: engine.handsState,
                videoAspect: engine.handTracker.videoWidth / engine.handTracker.videoHeight
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Floating UI overlays
            VStack {
                // Top bar: close button + beat dots
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Floating code pill
                codePill
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                Spacer()

                // Note badge
                noteBadge

                // Beat pulse ring
                beatRing
                    .padding(.bottom, 8)

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showSheet) {
            ControlSheet(engine: engine)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Beat dots
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == engine.currentBeat
                              ? (i % 2 == 0 ? Color.green : Color.pink)
                              : Color.white.opacity(0.15))
                        .frame(width: 6, height: 6)
                        .scaleEffect(i == engine.currentBeat ? 1.5 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: engine.currentBeat)
                }
            }

            Spacer()

            // Close button
            Button(action: { /* TODO: stop and go back */ }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Code Pill

    private var codePill: some View {
        Group {
            if !engine.codeDisplay.isEmpty {
                Text(engine.codeDisplay.components(separatedBy: "\n").prefix(3).joined(separator: "\n"))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
                    .lineLimit(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.5))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.15), lineWidth: 1)
                            )
                    )
            }
        }
    }

    // MARK: - Note Badge

    private var noteBadge: some View {
        Text(engine.noteDisplay)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.3))
                    .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
            )
            .scaleEffect(engine.currentBeat == 0 ? 1.1 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: engine.currentBeat)
    }

    // MARK: - Beat Ring

    private var beatRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 2)
                .frame(width: 50, height: 50)

            Circle()
                .stroke(
                    engine.currentBeat % 2 == 0 ? Color.green.opacity(0.6) : Color.pink.opacity(0.6),
                    lineWidth: 3
                )
                .frame(width: 50, height: 50)
                .scaleEffect(engine.currentBeat == 0 ? 1.3 : 1.0)
                .opacity(engine.currentBeat == 0 ? 0.3 : 0.8)
                .animation(.easeOut(duration: 0.3), value: engine.currentBeat)

            Text("\(Int(engine.bpm.rounded()))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Hydra toggle
            if hasHydraMapping(engine.hydraConfig) {
                Button(action: engine.toggleHydra) {
                    Image(systemName: engine.hydraEnabled ? "sparkles" : "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(engine.hydraEnabled ? .purple : .white.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(engine.hydraEnabled ? Color.purple.opacity(0.2) : Color.black.opacity(0.3))
                        )
                }
            }

            Spacer()

            // Saved count badge
            if !engine.savedSnippets.isEmpty {
                Button(action: { showSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 14))
                        Text("\(engine.savedSnippets.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                    )
                }
            }

            // Controls sheet button
            Button(action: { showSheet = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                    )
            }
        }
    }
}

// MARK: - Control Sheet

struct ControlSheet: View {
    @ObservedObject var engine: EngineController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Params section
                VStack(alignment: .leading, spacing: 8) {
                    Text("PARAMETERS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.5)

                    ForEach(PARAM_DEFS) { def in
                        let isActive = engine.config.left.values.contains(def.id) ||
                                       engine.config.right.values.contains(def.id)
                        if isActive {
                            paramRow(def: def, value: engine.smoothedParams[def.id] ?? def.defaultValue)
                        }
                    }
                }

                // Snippets section
                if !engine.savedSnippets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SAVED SNIPPETS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(1.5)

                        ForEach(Array(engine.savedSnippets.enumerated()), id: \.offset) { idx, snippet in
                            HStack {
                                Button(action: { engine.toggleSnippet(idx) }) {
                                    Image(systemName: engine.playingSet.contains(idx) ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(engine.playingSet.contains(idx) ? .orange : .green)
                                }

                                VStack(alignment: .leading) {
                                    Text("Snippet #\(idx + 1)")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    Text("\(snippet.bpm) bpm")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: { engine.addToTrack(idx) }) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Track section
                if !engine.track.slots.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TRACK")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(1.5)

                            Spacer()

                            Button(action: engine.toggleTrackPlay) {
                                Image(systemName: engine.trackPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(engine.trackPlaying ? .orange : .green)
                            }
                        }

                        // Speed pills
                        HStack(spacing: 6) {
                            ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { speed in
                                Button(action: { engine.setTrackSpeed(speed) }) {
                                    Text("\(speed == Double(Int(speed)) ? "\(Int(speed))" : String(format: "%.1f", speed))x")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(engine.track.speed == speed ? .green : .secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(engine.track.speed == speed ? Color.green.opacity(0.15) : Color.clear)
                                        )
                                }
                            }
                        }

                        ForEach(Array(engine.track.slots.enumerated()), id: \.offset) { slotIdx, snippetIdx in
                            HStack {
                                Text("\(slotIdx + 1).")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("Snippet #\(snippetIdx + 1)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Spacer()
                                Button(action: { engine.removeFromTrack(slotIdx) }) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func paramRow(def: ParamDef, value: Double) -> some View {
        let normalized = (value - def.min) / (def.max - def.min)
        return HStack(spacing: 10) {
            Text(def.label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 55, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.green.opacity(0.5))
                        .frame(width: geo.size.width * max(0, min(1, normalized)))
                }
            }
            .frame(height: 8)

            Text(def.format(value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
        }
        .frame(height: 20)
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
