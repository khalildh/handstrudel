import SwiftUI
import ReplayKit

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    @StateObject private var engine = EngineController()
    @StateObject private var storeManager = StoreManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showSheet = false
    @State private var isRecording = false
    @State private var recordCountdown = 0
    @State private var showShareSheet = false
    @State private var showSharePicker = false
    @State private var recordedVideoURL: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                performanceView
                    .overlay {
                        if !hasSeenOnboarding {
                            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                                .transition(.opacity)
                        }
                    }
            } else {
                StartOverlayView(
                    status: engine.status,
                    storeManager: storeManager,
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

                // Logo
                logoMark
                    .padding(.top, 2)

                // Floating code pill
                codePill
                    .padding(.horizontal, 20)
                    .padding(.top, 2)

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
        .sheet(isPresented: $showShareSheet) {
            if let url = recordedVideoURL {
                ShareSheet(activityItems: [url])
            }
        }
        .confirmationDialog("Share to", isPresented: $showSharePicker, titleVisibility: .visible) {
            Button(action: shareToInstagramStories) {
                Label("Instagram Story", systemImage: "camera.circle")
            }
            Button(action: shareToInstagramReels) {
                Label("Instagram Reels", systemImage: "film")
            }
            Button(action: {
                showSharePicker = false
                showShareSheet = true
            }) {
                Label("Other...", systemImage: "square.and.arrow.up")
            }
            Button("Cancel", role: .cancel) {
                showSharePicker = false
            }
        }
        .sheet(isPresented: $showSheet) {
            ControlSheet(engine: engine, storeManager: storeManager)
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
            Button(action: { engine.stop() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Logo

    private var strudelHue: Double {
        // Map note index (0-17) to hue (0-1), shift with beat for extra life
        let ni = engine.smoothedParams["noteIdx"] ?? 10
        let base = ni / 17.0
        let beatShift = Double(engine.currentBeat) * 0.03
        return (base + beatShift).truncatingRemainder(dividingBy: 1.0)
    }

    private var logoMark: some View {
        HStack(spacing: 0) {
            Text("hand")
                .font(.system(size: 20, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Text("strudel")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(Color(hue: strudelHue, saturation: 0.8, brightness: 1.0))
                .animation(.easeInOut(duration: 0.3), value: strudelHue)
        }
        .shadow(color: Color(hue: strudelHue, saturation: 0.6, brightness: 0.8).opacity(0.5), radius: 10, x: 0, y: 2)
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
            Spacer()

            // Instagram share button
            Button(action: startRecording) {
                ZStack {
                    if isRecording {
                        // Recording indicator with countdown
                        ZStack {
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 3)
                                .frame(width: 62, height: 62)
                            Circle()
                                .trim(from: 0, to: CGFloat(7 - recordCountdown) / 7.0)
                                .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 62, height: 62)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: recordCountdown)
                            Text("\(recordCountdown)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    } else {
                        // Instagram-style share button
                        VStack(spacing: 3) {
                            ZStack {
                                // Instagram gradient ring
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.purple, .pink, .orange, .yellow],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 52, height: 52)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                            Text("7s")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .disabled(isRecording)

            Spacer()

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

    // MARK: - Recording

    private func startRecording() {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable && !isRecording else { return }

        isRecording = true
        recordCountdown = 7

        // Enable microphone to capture Strudel audio from speaker
        // (WebView audio runs in a separate process so ReplayKit can't capture it directly)
        // Audio session is already .playAndRecord so this shouldn't kill playback
        recorder.isMicrophoneEnabled = true

        recorder.startRecording { error in
            if let error {
                print("Recording failed:", error)
                DispatchQueue.main.async { isRecording = false }
                return
            }

            // Countdown timer
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                DispatchQueue.main.async {
                    recordCountdown -= 1
                    if recordCountdown <= 0 {
                        timer.invalidate()
                        stopRecording()
                    }
                }
            }
        }
    }

    private func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("handstrudel_\(Int(Date().timeIntervalSince1970)).mp4")

        recorder.stopRecording(withOutput: outputURL) { error in
            DispatchQueue.main.async {
                isRecording = false
                if let error {
                    print("Stop recording failed:", error)
                    return
                }
                recordedVideoURL = outputURL
                showSharePicker = true
            }
        }
    }

    private func shareToInstagramStories() {
        guard let url = recordedVideoURL,
              let videoData = try? Data(contentsOf: url) else { return }

        if let storiesURL = URL(string: "instagram-stories://share?source_application=com.handstrudel.app"),
           UIApplication.shared.canOpenURL(storiesURL) {
            UIPasteboard.general.setItems([[
                "com.instagram.sharedSticker.backgroundVideo": videoData,
                "com.instagram.sharedSticker.appID": "com.handstrudel.app"
            ]], options: [.expirationDate: Date().addingTimeInterval(300)])
            UIApplication.shared.open(storiesURL)
        } else {
            showShareSheet = true
        }
        showSharePicker = false
    }

    private func shareToInstagramReels() {
        guard let url = recordedVideoURL else { return }

        // Share to Reels via document interaction (video file to Instagram)
        let instagramURL = URL(string: "instagram://library?AssetPath=\(url.absoluteString)")
        if let instagramURL, UIApplication.shared.canOpenURL(instagramURL) {
            UIApplication.shared.open(instagramURL)
        } else {
            // Fallback: open share sheet which shows Instagram as option
            showShareSheet = true
        }
        showSharePicker = false
    }
}

// MARK: - Control Sheet

struct ControlSheet: View {
    @ObservedObject var engine: EngineController
    @ObservedObject var storeManager: StoreManager
    @State private var showStore = false
    @State private var paywallPackId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with store button
                HStack {
                    Spacer()
                    Button(action: { showStore = true }) {
                        Image(systemName: "bag")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                }

                // Sound/waveform section
                soundSection

                // BPM section
                bpmSection

                // Params section
                paramsSection

                // Drum loops + settings
                drumTrackSection(
                    label: "DRUMS 1",
                    loop: $engine.selectedDrumLoop,
                    volume: $engine.drumVolume,
                    speed: $engine.drumSpeed
                )

                drumTrackSection(
                    label: "DRUMS 2",
                    loop: $engine.selectedDrumLoop2,
                    volume: $engine.drumVolume2,
                    speed: $engine.drumSpeed2
                )

                // Snippets
                if !engine.savedSnippets.isEmpty { snippetsSection }

                // Track
                if !engine.track.slots.isEmpty { trackSection }
            }
            .padding(20)
        }
        .sheet(isPresented: $showStore) {
            StoreView(storeManager: storeManager)
        }
        .sheet(item: $paywallPackId) { packId in
            paywallSheet(for: packId)
                .presentationDetents([.medium])
        }
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }
        }
    }

    private func paywallSheet(for packId: String) -> some View {
        let info = packInfo(for: packId)
        let product = storeManager.products.first(where: { $0.id == packId })
        return PaywallOverlay(
            packId: packId,
            packName: info.name,
            packDescription: info.description,
            price: product?.displayPrice ?? "---",
            items: info.items,
            storeManager: storeManager
        )
    }

    private func packInfo(for packId: String) -> (name: String, description: String, items: [String]) {
        switch packId {
        case StoreManager.studioPack: return ("Studio Pack", "Professional studio presets", ["Studio preset", "Cinematic preset"])
        case StoreManager.partyPack: return ("Party Pack", "High-energy party presets", ["Party preset", "Rave preset"])
        case StoreManager.experimentalPack: return ("Experimental Pack", "Experimental sound presets", ["Glitch preset", "Ambient preset"])
        case StoreManager.analogPack: return ("Analog Pack", "Warm analog-style waveforms", ["FM synth", "Supersaw", "Pulse"])
        case StoreManager.texturePack: return ("Texture Pack", "Textural sound sources", ["Noise", "Metallic", "Pad"])
        case StoreManager.vocalPack: return ("Vocal Pack", "Vocal synthesis sounds", ["Choir", "Formant", "Whisper"])
        case StoreManager.kit808: return ("808 Kit", "Classic 808 drum machine", ["808 kick", "808 snare", "808 hat patterns"])
        case StoreManager.kitElectronic: return ("Electronic Kit", "Modern electronic drums", ["Electro kick", "Glitch snare", "Digital hat patterns"])
        case StoreManager.kitWorld: return ("World Kit", "World percussion drums", ["Djembe", "Tabla", "World percussion patterns"])
        default: return ("Pack", "Premium content", [])
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SOUND")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.5)

            HStack(spacing: 8) {
                ForEach(WAVEFORMS) { wf in
                    let locked = wf.isPremium && !storeManager.isUnlocked(wf.packId ?? "")
                    Button(action: {
                        if locked, let packId = wf.packId {
                            paywallPackId = packId
                        } else {
                            engine.selectedWaveform = wf.id
                        }
                    }) {
                        VStack(spacing: 3) {
                            Text(wf.emoji)
                                .font(.system(size: 18))
                            Text(wf.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(engine.selectedWaveform == wf.id ? .green : .primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(engine.selectedWaveform == wf.id ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(engine.selectedWaveform == wf.id ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(5)
                            }
                        }
                        .opacity(locked ? 0.5 : 1.0)
                    }
                }
            }
        }
    }

    // MARK: - Drums

    private func drumTrackSection(label: String, loop: Binding<DrumLoop>, volume: Binding<Double>, speed: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.5)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(DRUM_LOOPS) { drumLoop in
                    let locked = drumLoop.isPremium && !storeManager.isUnlocked(drumLoop.packId ?? "")
                    Button(action: {
                        if locked, let packId = drumLoop.packId {
                            paywallPackId = packId
                        } else {
                            loop.wrappedValue = drumLoop
                        }
                    }) {
                        VStack(spacing: 3) {
                            Text(drumLoop.emoji)
                                .font(.system(size: 20))
                            Text(drumLoop.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(loop.wrappedValue.id == drumLoop.id ? .green : .primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(loop.wrappedValue.id == drumLoop.id ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(loop.wrappedValue.id == drumLoop.id ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(5)
                            }
                        }
                        .opacity(locked ? 0.5 : 1.0)
                    }
                }
            }

            if loop.wrappedValue.id != "none" {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Slider(value: volume, in: 0.2...2.0)
                        .tint(.green)
                    Text(String(format: "%.0f%%", volume.wrappedValue * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    Image(systemName: "metronome")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Slider(value: speed, in: 0.25...4.0, step: 0.25)
                        .tint(.green)
                    Text(String(format: "%.2gx", speed.wrappedValue))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - BPM

    private var bpmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BPM")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
                Spacer()
                Text("\(Int(engine.manualBPM.rounded()))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }

            if engine.bpmIsMapped {
                Text("Controlled by hand")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                Slider(value: Binding(
                    get: { engine.manualBPM },
                    set: { engine.manualBPM = $0 }
                ), in: 50...205, step: 1)
                .tint(.green)
            }
        }
    }

    // MARK: - Params

    private var paramsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PARAMETERS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.5)

            ForEach(PARAM_DEFS) { def in
                let isActive = engine.config.left.values.contains(def.id) ||
                               engine.config.right.values.contains(def.id)
                if isActive {
                    paramRow(def: def)
                }
            }
        }
    }

    private func paramRow(def: ParamDef) -> some View {
        let isLocked = engine.lockedParams.contains(def.id)
        let currentValue = isLocked
            ? (engine.manualValues[def.id] ?? def.defaultValue)
            : (engine.smoothedParams[def.id] ?? def.defaultValue)

        return VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Lock toggle
                Button(action: { engine.toggleLock(def.id) }) {
                    Image(systemName: isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 12))
                        .foregroundColor(isLocked ? .orange : .secondary.opacity(0.4))
                }
                .frame(width: 20)

                Text(def.label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isLocked ? .orange : .primary)
                    .frame(width: 55, alignment: .leading)

                if isLocked {
                    // Slider for manual control
                    Slider(value: Binding(
                        get: { engine.manualValues[def.id] ?? def.defaultValue },
                        set: { engine.setManualValue(def.id, value: $0) }
                    ), in: def.min...def.max)
                    .tint(.orange)
                } else {
                    // Live meter
                    let normalized = (currentValue - def.min) / (def.max - def.min)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(Color.green.opacity(0.5))
                                .frame(width: geo.size.width * max(0, min(1, normalized)))
                        }
                    }
                    .frame(height: 8)
                }

                Text(def.format(currentValue))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .frame(minHeight: 28)
    }

    // MARK: - Snippets

    private var snippetsSection: some View {
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

    // MARK: - Track

    private var trackSection: some View {
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

            HStack(spacing: 6) {
                ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { speed in
                    Button(action: { engine.setTrackSpeed(speed) }) {
                        Text("\(speed == Double(Int(speed)) ? "\(Int(speed))" : String(format: "%.1f", speed))x")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(engine.track.speed == speed ? .green : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(engine.track.speed == speed ? Color.green.opacity(0.15) : Color.clear))
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

// Wraps UIActivityViewController for sharing
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Wraps WKWebView for SwiftUI
struct WebViewContainer: UIViewRepresentable {
    let webView: UIView

    func makeUIView(context: Context) -> UIView {
        webView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
