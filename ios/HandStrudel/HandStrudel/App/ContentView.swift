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
    @AppStorage("hideSkeletonWhenRecording") private var hideSkeletonWhenRecording = true
    @State private var filterName: String = ""
    @State private var showFilterName = false
    @State private var showJamAlert = false
    @State private var watermarkView: UIView?
    @State private var showRandomizedToast = false
    @State private var showSongResults = false

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
        .onReceive(NotificationCenter.default.publisher(for: .siriStartPreset)) { notification in
            guard !engine.isRunning, let presetId = notification.object as? String else { return }
            if let preset = PRESETS.first(where: { $0.id == presetId }) {
                engine.start(config: preset.mapping, hydraConfig: preset.hydraMapping, advanced: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .siriStartMode)) { notification in
            guard let mode = notification.object as? String else { return }
            if !engine.isRunning {
                // Start with default preset first
                engine.start(config: DEFAULT_MAPPING, hydraConfig: DEFAULT_HYDRA_MAPPING, advanced: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                switch mode {
                case "grid": engine.gridModeEnabled = true; engine.drumModeEnabled = false
                case "drums": engine.drumModeEnabled = true; engine.gridModeEnabled = false
                default: break
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleLoopRecording)) { _ in
            guard engine.isRunning else { return }
            if engine.isLoopRecording {
                engine.stopLoopRecording()
            } else {
                engine.startLoopRecording()
            }
        }
    }

    // MARK: - Performance View

    private func randomizeSettings() {
        let allKeys = MusicKey.allCases
        let allScales = Scale.allCases
        let waveformIds = WAVEFORMS.map(\.id)

        engine.selectedKey = allKeys.randomElement() ?? .C
        engine.selectedScale = allScales.randomElement() ?? .pentatonic
        engine.selectedWaveform = waveformIds.randomElement() ?? "sawtooth"
        engine.manualBPM = Double(Int.random(in: 80...160))
        engine.recomputeScaleNotes()

        withAnimation(.easeOut(duration: 0.2)) { showRandomizedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { showRandomizedToast = false }
        }
    }

    private var performanceView: some View {
        ZStack {
            // Shake-to-randomize detector
            ShakeDetectorView { randomizeSettings() }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)

            // Full-screen camera with filter
            ZStack {
                CameraView(handTracker: engine.handTracker)

                // Filter overlay
                if let color = engine.selectedFilter.overlayColor {
                    color.opacity(engine.selectedFilter.overlayOpacity)
                        .blendMode(engine.selectedFilter.blendMode)
                }
            }
            .saturation(engine.selectedFilter.saturation)
            .contrast(engine.selectedFilter.contrast)
            .brightness(engine.selectedFilter.brightness)
            .hueRotation(.degrees(engine.selectedFilter.hueRotation))
            .ignoresSafeArea()

            // Hand skeleton overlay with glow (aspect-corrected)
            HandOverlayView(
                handsState: engine.handsState,
                videoAspect: engine.handTracker.videoWidth / engine.handTracker.videoHeight
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(isRecording && hideSkeletonWhenRecording ? 0 : 1)

            // Grid mode note lanes overlay (tappable for one-hand play)
            if engine.gridModeEnabled {
                noteGridOverlay
                    .ignoresSafeArea()
            }

            // Song mode falling notes overlay
            if engine.songPlayer.isPlaying {
                songOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Song results overlay
            if showSongResults {
                songResultsOverlay
            }

            // Drum zone overlay (tappable pads)
            if engine.drumModeEnabled {
                drumZoneOverlay
                    .ignoresSafeArea()
            }

            // Floating UI overlays
            VStack {
                // Top bar: close button + beat dots
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Logo
                if !engine.drumModeEnabled {
                    logoMark
                        .padding(.top, 2)
                }

                // Drum XY pad (top area, out of the way of drum pads)
                if engine.drumModeEnabled {
                    drumXYPad
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                }

                // Jam session indicator
                if engine.jamSession.isActive && !engine.jamSession.lastReceivedEvent.isEmpty {
                    Text(engine.jamSession.lastReceivedEvent)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.cyan.opacity(0.1)))
                }

                // Floating code pill — hide in grid/drum mode
                if !engine.gridModeEnabled && !engine.drumModeEnabled {
                    codePill
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                }

                Spacer()

                // Note badge — hide in grid/drum mode (grid has lane labels, drums have pad labels)
                if !engine.gridModeEnabled && !engine.drumModeEnabled {
                    noteBadge

                    beatRing
                        .padding(.bottom, 8)
                }

                // Grid quick controls (range + octave)
                if engine.gridModeEnabled {
                    gridQuickBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Filter name toast
                if showFilterName {
                    Text(engine.selectedFilter.emoji + " " + engine.selectedFilter.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .transition(.opacity)
                }

                // Shake-to-randomize toast
                if showRandomizedToast {
                    Text("\u{1F3B2} Randomized!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.purple.opacity(0.6)))
                        .transition(.opacity)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Only handle horizontal swipes (not vertical scrolls or taps near buttons)
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let filters = CAMERA_FILTERS.filter { !$0.isPremium || storeManager.isUnlocked($0.packId ?? "") }
                        guard let currentIdx = filters.firstIndex(where: { $0.id == engine.selectedFilter.id }) else { return }

                        let newIdx: Int
                        if value.translation.width < 0 {
                            // Swipe left → next filter
                            newIdx = (currentIdx + 1) % filters.count
                        } else {
                            // Swipe right → previous filter
                            newIdx = (currentIdx - 1 + filters.count) % filters.count
                        }
                        engine.selectedFilter = filters[newIdx]

                        // Show filter name briefly
                        withAnimation(.easeOut(duration: 0.2)) { showFilterName = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeOut(duration: 0.3)) { showFilterName = false }
                        }
                    }
            )
        }
        .onChange(of: engine.songPlayer.isPlaying) { playing in
            if !playing && engine.songPlayer.totalNotes > 0 {
                showSongResults = true
            }
        }
        .alert("Jam Session", isPresented: $showJamAlert) {
            Button("Got it") {}
        } message: {
            Text("Start a FaceTime call, then tap the people icon again. Everyone on the call who has HandStrudel can join the jam!")
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
            ControlSheet(engine: engine, storeManager: storeManager, hideSkeletonWhenRecording: $hideSkeletonWhenRecording)
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
                        .frame(width: 7, height: 7)
                        .scaleEffect(i == engine.currentBeat ? 1.5 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: engine.currentBeat)
                }
            }

            Spacer()

            // Jam session button
            Button(action: {
                if engine.jamSession.isActive {
                    engine.jamSession.leaveSession()
                } else {
                    engine.jamSession.startSession()
                    showJamAlert = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: engine.jamSession.isActive ? "person.2.fill" : "person.2")
                        .font(.system(size: 12, weight: .bold))
                    if engine.jamSession.isActive {
                        Text("\(engine.jamSession.participants.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(engine.jamSession.isActive ? .green : .white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(engine.jamSession.isActive ? Color.green.opacity(0.2) : Color.black.opacity(0.3))
                )
            }

            // Close button
            Button(action: { engine.stop() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
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
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Text("strudel")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(Color(hue: strudelHue, saturation: 0.8, brightness: 1.0))
                .animation(.easeInOut(duration: 0.3), value: strudelHue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .background(Capsule().fill(.ultraThinMaterial).opacity(0.3))
        )
        .clipShape(Capsule())
        .shadow(color: Color(hue: strudelHue, saturation: 0.6, brightness: 0.8).opacity(0.5), radius: 10, x: 0, y: 2)
    }

    // MARK: - Code Pill

    private var codePill: some View {
        Group {
            if !engine.codeDisplay.isEmpty {
                Text(engine.codeDisplay.components(separatedBy: "\n").prefix(3).joined(separator: "\n"))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
                    .lineLimit(3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.green.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: Color.green.opacity(0.25), radius: 8, x: 0, y: 0)
            }
        }
    }

    // MARK: - Note Badge

    private var noteBadge: some View {
        Text(engine.noteDisplay)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hue: strudelHue, saturation: 0.6, brightness: 0.3).opacity(0.5))
                    .overlay(
                        Capsule()
                            .stroke(Color(hue: strudelHue, saturation: 0.8, brightness: 1.0).opacity(0.6), lineWidth: 2)
                    )
            )
            .shadow(color: Color(hue: strudelHue, saturation: 0.8, brightness: 1.0).opacity(0.5), radius: 12, x: 0, y: 0)
            .scaleEffect(engine.currentBeat == 0 ? 1.1 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: engine.currentBeat)
    }

    // MARK: - Beat Ring

    private var beatRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 1.5)
                .frame(width: 50, height: 50)

            Circle()
                .stroke(
                    engine.currentBeat % 2 == 0 ? Color.green.opacity(0.6) : Color.pink.opacity(0.6),
                    lineWidth: 1.5
                )
                .frame(width: 50, height: 50)
                .scaleEffect(engine.currentBeat == 0 ? 1.15 : 1.0)
                .opacity(engine.currentBeat == 0 ? 0.4 : 0.8)
                .animation(.easeOut(duration: 0.3), value: engine.currentBeat)

            Text("\(Int(engine.bpm.rounded()))")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Drum XY Pad

    private var drumXYPad: some View {
        GeometryReader { geo in
            let dotX = engine.drumComplexity * geo.size.width
            let dotY = (1 - engine.drumIntensity) * geo.size.height

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Quadrant labels
                VStack {
                    HStack {
                        Text("SOFT")
                            .foregroundColor(.white.opacity(0.15))
                        Spacer()
                        Text("LOUD")
                            .foregroundColor(.white.opacity(0.15))
                    }
                    Spacer()
                    HStack {
                        Text("SIMPLE")
                            .foregroundColor(.white.opacity(0.15))
                        Spacer()
                        Text("COMPLEX")
                            .foregroundColor(.white.opacity(0.15))
                    }
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(8)

                // Crosshair lines
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Position dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .shadow(color: .green.opacity(0.5), radius: 8)
                    .position(x: dotX, y: dotY)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let cx: Double = value.location.x / geo.size.width
                        let cy: Double = 1.0 - value.location.y / geo.size.height
                        engine.drumComplexity = max(0, min(1, cx))
                        engine.drumIntensity = max(0, min(1, cy))
                    }
            )
        }
        .frame(height: 80)
    }

    // MARK: - Grid Quick Bar

    private var gridQuickBar: some View {
        HStack(spacing: 12) {
            // Octave down/up
            HStack(spacing: 6) {
                Button(action: { if engine.gridBaseOctave > 1 { engine.gridBaseOctave -= 1 } }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                Text("Oct \(engine.gridBaseOctave)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Button(action: { if engine.gridBaseOctave < 6 { engine.gridBaseOctave += 1 } }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }

            Spacer()

            // Range pills
            ForEach([1, 2, 3], id: \.self) { range in
                Button(action: { engine.gridOctaveRange = range }) {
                    Text("\(range)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(engine.gridOctaveRange == range ? .black : .white.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(engine.gridOctaveRange == range ? Color.green : Color.white.opacity(0.1))
                        )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.black.opacity(0.5))
        )
    }

    // MARK: - Note Grid Overlay

    @State private var touchedLane: Int? = nil  // legacy, kept for compat
    @State private var touchActiveLanes: Set<Int> = []

    private var noteGridOverlay: some View {
        GeometryReader { geo in
            let notes = scaleNotes(key: engine.selectedKey, scale: engine.selectedScale, baseOctave: engine.gridBaseOctave, octaveRange: engine.gridOctaveRange)
            let count = notes.count
            // Pad top/bottom 15% to avoid dead zones where camera can't see hands
            let topPad = geo.size.height * 0.15
            let bottomPad = geo.size.height * 0.2  // more bottom padding for UI controls
            let usableHeight = geo.size.height - topPad - bottomPad
            let laneHeight = usableHeight / CGFloat(max(1, count))

            // Apply same aspect fill correction as HandOverlayView
            let vidAspect = engine.handTracker.videoWidth / engine.handTracker.videoHeight
            let scrAspect = geo.size.width / geo.size.height

            let correctedY: (Double) -> CGFloat = { vy in
                if vidAspect > scrAspect {
                    return CGFloat(vy) * geo.size.height
                } else {
                    let vis = vidAspect / scrAspect
                    let off = (1 - vis) / 2
                    return (CGFloat(vy) - off) / vis * geo.size.height
                }
            }

            let leftVisualLane: Int? = engine.handsState.left.map { hand in
                let screenY = correctedY(hand.pinchY) - topPad
                return max(0, min(count - 1, Int(screenY / laneHeight)))
            }
            let rightVisualLane: Int? = engine.handsState.right.map { hand in
                let screenY = correctedY(hand.pinchY) - topPad
                return max(0, min(count - 1, Int(screenY / laneHeight)))
            }

            VStack(spacing: 0) {
                Spacer().frame(height: topPad)
                ForEach(0..<count, id: \.self) { i in
                    let noteIdx = count - 1 - i
                    let midi = notes[noteIdx]
                    let name = midiNoteName(midi)
                    let leftActive = leftVisualLane == i
                    let rightActive = rightVisualLane == i
                    let isEven = i % 2 == 0
                    let isTouchActive = touchActiveLanes.contains(i)

                    ZStack {
                        // Lane background — split left/right + touch highlight
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(isTouchActive ? Color.cyan.opacity(0.3)
                                      : leftActive ? Color.green.opacity(engine.gridModeManager.isLeftPinching ? 0.25 : 0.1)
                                      : Color.white.opacity(isEven ? 0.03 : 0.0))
                            Rectangle()
                                .fill(isTouchActive ? Color.cyan.opacity(0.3)
                                      : rightActive ? Color.pink.opacity(engine.gridModeManager.isRightPinching ? 0.25 : 0.1)
                                      : Color.white.opacity(isEven ? 0.03 : 0.0))
                        }

                        // Left label
                        HStack {
                            Text(name)
                                .font(.system(size: (leftActive || isTouchActive) ? 14 : 11, weight: (leftActive || isTouchActive) ? .black : .medium, design: .monospaced))
                                .foregroundColor(isTouchActive ? .cyan : leftActive ? .green : .white.opacity(0.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill((leftActive || isTouchActive) ? Color.green.opacity(0.2) : Color.black.opacity(0.3)))
                            Spacer()
                            // Right label
                            Text(name)
                                .font(.system(size: (rightActive || isTouchActive) ? 14 : 11, weight: (rightActive || isTouchActive) ? .black : .medium, design: .monospaced))
                                .foregroundColor(isTouchActive ? .cyan : rightActive ? .pink : .white.opacity(0.3))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill((rightActive || isTouchActive) ? Color.pink.opacity(0.2) : Color.black.opacity(0.2)))
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: laneHeight)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(leftActive || rightActive || isTouchActive ? 0.2 : 0.06))
                            .frame(height: 1)
                    }
                }
                Spacer()
            }

            // Multitouch layer on top for two-finger play
            GridTouchOverlay(
                noteCount: count,
                topPad: topPad,
                bottomPad: bottomPad,
                notes: notes,
                waveform: engine.selectedWaveform,
                onNoteOn: { voice, midi, name in
                    engine.strudelBridge.noteOn(hand: voice, midi: midi, waveform: engine.selectedWaveform, velocity: 0.7)
                    engine.haptics.noteTrigger()
                    engine.lastGridNote = name
                    let elapsed = engine.startTime.map { Date().timeIntervalSince($0) } ?? 0
                    engine.loopRecorder.recordEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: 0.7), currentTime: elapsed)
                },
                onNoteOff: { voice in
                    engine.strudelBridge.noteOff(hand: voice)
                },
                onNoteSlide: { voice, midi, name in
                    engine.strudelBridge.noteSlide(hand: voice, midi: midi)
                    engine.lastGridNote = name
                    engine.haptics.lightTap()
                },
                onHaptic: { },
                activeLanes: $touchActiveLanes
            )

        }
    }

    // MARK: - Drum Zone Overlay

    @State private var flashingPad: String? = nil

    private var drumZoneOverlay: some View {
        VStack(spacing: 0) {
            // Hand zone labels at top
            HStack {
                Text("L hand")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.green.opacity(0.5))
                Spacer()
                Text("R hand")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.pink.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Tap-to-play drum pad grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1)
            ], spacing: 1) {
                let allZones = DrumModeManager.leftZones + DrumModeManager.rightZones
                ForEach(Array(allZones.enumerated()), id: \.offset) { idx, zone in
                    Button(action: {
                        engine.strudelBridge.playHit(zone.hitType)
                        flashingPad = zone.name
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if flashingPad == zone.name { flashingPad = nil }
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(padEmoji(for: zone.name))
                                .font(.system(size: 24))
                            Text(zone.name)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: flashingPad == zone.name
                                            ? [Color.green.opacity(0.5), Color.green.opacity(0.2)]
                                            : [Color.white.opacity(0.1), Color.white.opacity(0.04)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .scaleEffect(flashingPad == zone.name ? 0.9 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: flashingPad)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120) // space for bottom controls
        }
    }

    private func padEmoji(for name: String) -> String {
        switch name {
        case "Crash": return "💥"
        case "Hi-Hat": return "🔔"
        case "Kick": return "🦶"
        case "Ride": return "🛎️"
        case "Snare": return "🥁"
        case "Tom": return "🪘"
        default: return "🎵"
        }
    }

    // MARK: - Song Overlay (Falling Notes)

    private var songOverlay: some View {
        GeometryReader { geo in
            let notes = scaleNotes(
                key: engine.selectedKey,
                scale: engine.selectedScale,
                baseOctave: engine.gridBaseOctave,
                octaveRange: engine.gridOctaveRange
            )
            let laneCount = max(1, notes.count)
            let topPad = geo.size.height * 0.15
            let bottomPad = geo.size.height * 0.2
            let usableHeight = geo.size.height - topPad - bottomPad
            let laneHeight = usableHeight / CGFloat(laneCount)
            let lookAhead: Double = 2.5

            // Notes scroll from RIGHT to LEFT — tap the lane when the note reaches the left edge
            let hitLineX = geo.size.width * 0.15

            ZStack {
                // Score and combo
                VStack {
                    HStack {
                        // Score
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(engine.songPlayer.score)")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            if engine.songPlayer.combo > 1 {
                                Text("\(engine.songPlayer.combo)x")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.yellow)
                            }
                        }
                        Spacer()
                        // Progress
                        Text("\(engine.songPlayer.hitNotes)/\(engine.songPlayer.totalNotes)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                    Spacer()
                }

                // Hit line (vertical, on the left)
                Rectangle()
                    .fill(Color.green.opacity(0.4))
                    .frame(width: 3)
                    .position(x: hitLineX, y: geo.size.height / 2)

                // Lane labels + tap targets on the left
                VStack(spacing: 0) {
                    Spacer().frame(height: topPad)
                    ForEach(0..<laneCount, id: \.self) { i in
                        let noteIdx = laneCount - 1 - i
                        let midi = noteIdx < notes.count ? notes[noteIdx] : 60
                        let name = midiNoteName(midi)

                        Text(name)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Tap to hit — play the note and check score
                                engine.strudelBridge.playNote(midi: midi, waveform: engine.selectedWaveform, velocity: 0.7, duration: 0.3)
                                engine.haptics.noteTrigger()
                                let hit = engine.songPlayer.checkHit(midi: midi)
                                if hit {
                                    engine.haptics.drumHit() // extra feedback for hits
                                }
                            }
                    }
                    Spacer()
                }

                // Scrolling note indicators (right to left)
                ForEach(engine.songPlayer.visibleNotes(lookAhead: lookAhead), id: \.index) { entry in
                    let relativeTime = entry.note.time - engine.songPlayer.songTime
                    // Notes scroll from right to left
                    let xProgress = 1.0 - (relativeTime / lookAhead)
                    let noteX: CGFloat = hitLineX + CGFloat(xProgress) * (geo.size.width - hitLineX)

                    // Find which row this note belongs to
                    let noteIdx = notes.firstIndex(of: entry.note.midi) ?? 0
                    let rowIdx = laneCount - 1 - noteIdx // invert: high notes at top
                    let noteY: CGFloat = topPad + CGFloat(rowIdx) * laneHeight + laneHeight / 2

                    let noteColor: Color = {
                        if entry.isHit { return .green }
                        if relativeTime < -0.3 { return .red.opacity(0.5) }
                        return .cyan
                    }()

                    let noteWidth = max(20, CGFloat(entry.note.duration / lookAhead) * (geo.size.width - hitLineX))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(noteColor.opacity(entry.isHit ? 0.2 : 0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(noteColor, lineWidth: entry.isHit ? 0.5 : 1.5)
                        )
                        .frame(width: noteWidth, height: laneHeight * 0.7)
                        .shadow(color: noteColor.opacity(0.4), radius: entry.isHit ? 0 : 4)
                        .position(x: noteX, y: noteY)
                        .opacity(entry.isHit ? 0.3 : 1.0)
                }
            }
        }
    }

    // MARK: - Song Results Overlay

    private var songResultsOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Grade
                Text(engine.songPlayer.grade)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(gradeColor(engine.songPlayer.grade))
                    .shadow(color: gradeColor(engine.songPlayer.grade).opacity(0.6), radius: 20)

                if let song = engine.songPlayer.currentSong {
                    Text(song.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Stats
                VStack(spacing: 12) {
                    statRow(label: "Score", value: "\(engine.songPlayer.score)")
                    statRow(label: "Notes Hit", value: "\(engine.songPlayer.hitNotes) / \(engine.songPlayer.totalNotes)")
                    statRow(label: "Max Combo", value: "\(engine.songPlayer.maxCombo)x")
                    statRow(label: "Accuracy", value: "\(Int(engine.songPlayer.progress * 100))%")
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                )

                // Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        showSongResults = false
                    }) {
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 120, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }

                    Button(action: {
                        showSongResults = false
                        if let song = engine.songPlayer.currentSong ?? BUILT_IN_SONGS.first {
                            engine.songPlayer.startSong(song)
                        }
                    }) {
                        Text("Play Again")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(width: 120, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                    }
                }
            }
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "S": return .yellow
        case "A": return .green
        case "B": return .cyan
        case "C": return .orange
        case "D": return .red
        default: return .gray
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Loop record button
            loopRecordButton

            Spacer()

            // Video record button
            recordButton

            Spacer()

            // Settings button
            Button(action: { showSheet = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
        }
    }

    @State private var showLoopSaved = false
    @State private var loopMessage = ""

    private var loopRecordButton: some View {
        Button(action: {
            if engine.isLoopRecording {
                let hadEvents = engine.stopLoopRecording()
                if hadEvents {
                    loopMessage = "Loop saved & playing"
                } else {
                    loopMessage = "No notes recorded"
                }
                withAnimation { showLoopSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showLoopSaved = false }
                }
            } else {
                if !engine.gridModeEnabled && !engine.drumModeEnabled {
                    loopMessage = "Switch to Grid or Drums mode first"
                    withAnimation { showLoopSaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showLoopSaved = false }
                    }
                } else {
                    engine.startLoopRecording()
                }
            }
        }) {
            ZStack {
                Circle()
                    .stroke(engine.isLoopRecording ? Color.red : Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 44, height: 44)

                if engine.isLoopRecording {
                    Circle()
                        .trim(from: 0, to: engine.loopRecordingProgress)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(Color.red)
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 18, height: 18)
                }

                // Loop count badge
                if !engine.savedLoops.isEmpty && !engine.isLoopRecording {
                    Text("\(engine.savedLoops.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.green))
                        .offset(x: 16, y: -16)
                }
            }
        }
        .overlay(alignment: .top) {
            if showLoopSaved {
                HStack(spacing: 6) {
                    Image(systemName: loopMessage.contains("saved") ? "checkmark.circle.fill" : "info.circle.fill")
                        .font(.system(size: 12))
                    Text(loopMessage)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(loopMessage.contains("saved") ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule().stroke(
                                loopMessage.contains("saved") ? Color.green.opacity(0.3) : Color.orange.opacity(0.3),
                                lineWidth: 1
                            )
                        )
                )
                .offset(y: -40)
                .transition(.opacity)
            }
        }
    }

    private var recordButton: some View {
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
                                        lineWidth: 3
                                    )
                                    .frame(width: 56, height: 56)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 20))
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

        // Add watermark overlay for branding in recording
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.windows.first {
            let wm = WatermarkManager.createWatermarkView(frame: window.bounds)
            window.addSubview(wm)
            watermarkView = wm
        }

        recorder.startRecording { error in
            if let error {
                debugPrint("Recording failed:", error)
                DispatchQueue.main.async {
                    isRecording = false
                    watermarkView?.removeFromSuperview()
                    watermarkView = nil
                }
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
                // Remove watermark
                watermarkView?.removeFromSuperview()
                watermarkView = nil
                if let error {
                    debugPrint("Stop recording failed:", error)
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
    @Binding var hideSkeletonWhenRecording: Bool
    @State private var showStore = false
    @State private var paywallPackId: String?
    @State private var showAudioExport = false
    @State private var exportedAudioURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with store button
                HStack {
                    Spacer()
                    Button(action: { showStore = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("Store")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    }
                }

                modeSection

                sectionDivider
                songsSection

                sectionDivider
                harmonySection

                sectionDivider
                soundSection

                sectionDivider
                bpmSection

                sectionDivider
                paramsSection

                sectionDivider
                drumTrackSection(
                    label: "DRUMS 1",
                    loop: $engine.selectedDrumLoop,
                    volume: $engine.drumVolume,
                    bpm: $engine.drumBPM
                )

                sectionDivider
                drumTrackSection(
                    label: "DRUMS 2",
                    loop: $engine.selectedDrumLoop2,
                    volume: $engine.drumVolume2,
                    bpm: $engine.drumBPM2
                )

                sectionDivider
                filterSection

                if !engine.savedLoops.isEmpty {
                    sectionDivider
                    loopsSection
                }

                sectionDivider
                recordingSection

                if !engine.savedSnippets.isEmpty {
                    sectionDivider
                    snippetsSection
                }

                if !engine.track.slots.isEmpty {
                    sectionDivider
                    trackSection
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showStore) {
            StoreView(storeManager: storeManager)
        }
        .sheet(isPresented: $showAudioExport) {
            if let url = exportedAudioURL {
                ShareSheet(activityItems: [url])
            }
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

    // MARK: - Helpers

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.green.opacity(0.6))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.5)
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

    // MARK: - Mode

    private enum AppMode: String { case melodic, grid, drums }
    private var currentMode: AppMode {
        if engine.gridModeEnabled { return .grid }
        if engine.drumModeEnabled { return .drums }
        return .melodic
    }

    private func setMode(_ mode: AppMode) {
        engine.gridModeEnabled = mode == .grid
        engine.drumModeEnabled = mode == .drums
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("MODE", icon: "gamecontroller")

            HStack(spacing: 8) {
                modeButton("Melodic", icon: "pianokeys", mode: .melodic)
                modeButton("Grid", icon: "square.grid.3x3", mode: .grid)
                modeButton("Drums", icon: "drum.fill", mode: .drums)
            }

            if currentMode == .grid {
                Text("Pinch to play notes. Move hand up/down to change pitch.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                // Octave range controls
                HStack(spacing: 12) {
                    // Octave range
                    HStack(spacing: 6) {
                        Text("Range")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        ForEach([1, 2, 3], id: \.self) { range in
                            Button(action: { engine.gridOctaveRange = range }) {
                                Text("\(range)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(engine.gridOctaveRange == range ? .green : .secondary)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(engine.gridOctaveRange == range ? Color.green.opacity(0.15) : Color.primary.opacity(0.04)))
                            }
                        }
                    }

                    Spacer()

                    // Base octave
                    HStack(spacing: 4) {
                        Text("Oct")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Button(action: { if engine.gridBaseOctave > 1 { engine.gridBaseOctave -= 1 } }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                                .foregroundColor(.secondary)
                        }
                        Text("\(engine.gridBaseOctave)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Button(action: { if engine.gridBaseOctave < 6 { engine.gridBaseOctave += 1 } }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func modeButton(_ label: String, icon: String, mode: AppMode) -> some View {
        let isActive = currentMode == mode
        return Button(action: { setMode(mode) }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isActive ? .green : .primary.opacity(0.5))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? .green : .primary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive
                        ? LinearGradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.green.opacity(0.5) : Color.white.opacity(0.06), lineWidth: isActive ? 1.5 : 0.5)
            )
        }
    }

    // MARK: - Songs

    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SONGS", icon: "music.note.list")

            ForEach(BUILT_IN_SONGS) { song in
                HStack(spacing: 12) {
                    Button(action: {
                        // Switch to grid mode with song's key/scale
                        engine.gridModeEnabled = true
                        engine.drumModeEnabled = false
                        if let key = MusicKey(rawValue: song.key) {
                            engine.selectedKey = key
                        }
                        if let scale = Scale(rawValue: song.scale) {
                            engine.selectedScale = scale
                        }
                        engine.recomputeScaleNotes()
                        engine.songPlayer.startSong(song)
                    }) {
                        Image(systemName: engine.songPlayer.isPlaying && engine.songPlayer.currentSong?.id == song.id
                              ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(engine.songPlayer.isPlaying && engine.songPlayer.currentSong?.id == song.id
                                             ? .orange : .green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(song.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            if song.isPremium {
                                Text("Premium")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundColor(.yellow.opacity(0.9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.yellow.opacity(0.15)))
                            }
                        }
                        Text("\(song.artist) \u{2022} \(song.key) \(song.scale) \u{2022} \(Int(song.bpm)) BPM")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(song.notes.count) notes")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            if engine.songPlayer.isPlaying {
                Button(action: { engine.songPlayer.stopSong() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("Stop Song")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
                }
            }
        }
    }

    // MARK: - Harmony

    private var harmonySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("HARMONY", icon: "music.note")

            // Key picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MusicKey.allCases) { key in
                        Button(action: {
                            engine.selectedKey = key
                            engine.recomputeScaleNotes()
                        }) {
                            Text(key.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(engine.selectedKey == key ? .green : .primary.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(engine.selectedKey == key ? Color.green.opacity(0.15) : Color.primary.opacity(0.04))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(engine.selectedKey == key ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                        }
                    }
                }
            }

            // Scale picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Scale.allCases) { scale in
                        Button(action: {
                            engine.selectedScale = scale
                            engine.recomputeScaleNotes()
                        }) {
                            Text(scale.rawValue)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(engine.selectedScale == scale ? .green : .primary.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(engine.selectedScale == scale ? Color.green.opacity(0.15) : Color.primary.opacity(0.04))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(engine.selectedScale == scale ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                        }
                    }
                }
            }

            // Toggles - pill style
            HStack(spacing: 12) {
                pillToggle("Chords", icon: "music.note.list", isOn: $engine.chordMode)
                pillToggle("Circle of 5ths", icon: "circle.circle", isOn: $engine.circleOfFifthsEnabled)
            }
        }
    }

    private func pillToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(isOn.wrappedValue ? .green : .primary.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isOn.wrappedValue ? Color.green.opacity(0.15) : Color.primary.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .stroke(isOn.wrappedValue ? Color.green.opacity(0.4) : Color.white.opacity(0.06), lineWidth: isOn.wrappedValue ? 1.5 : 0.5)
            )
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SOUND", icon: "waveform")

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
                        VStack(spacing: 5) {
                            Text(wf.emoji)
                                .font(.system(size: 20))
                            Text(wf.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(engine.selectedWaveform == wf.id ? .green : .primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(engine.selectedWaveform == wf.id
                                    ? LinearGradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(engine.selectedWaveform == wf.id ? Color.green.opacity(0.5) : Color.white.opacity(0.06), lineWidth: engine.selectedWaveform == wf.id ? 1.5 : 0.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Text("PRO")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.ultraThinMaterial))
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

    private func drumTrackSection(label: String, loop: Binding<DrumLoop>, volume: Binding<Double>, bpm: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label, icon: "drum")

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
                        VStack(spacing: 5) {
                            Text(drumLoop.emoji)
                                .font(.system(size: 22))
                            Text(drumLoop.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(loop.wrappedValue.id == drumLoop.id ? .green : .primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(loop.wrappedValue.id == drumLoop.id
                                    ? LinearGradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(loop.wrappedValue.id == drumLoop.id ? Color.green.opacity(0.5) : Color.white.opacity(0.06), lineWidth: loop.wrappedValue.id == drumLoop.id ? 1.5 : 0.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Text("PRO")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .padding(5)
                            }
                        }
                        .opacity(locked ? 0.5 : 1.0)
                    }
                }
            }

            if loop.wrappedValue.id != "none" {
                HStack(spacing: 8) {
                    Text("VOL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28)
                    Slider(value: volume, in: 0.2...2.0)
                        .tint(.green)
                    Text(String(format: "%.0f%%", volume.wrappedValue * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    Text("BPM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28)
                    Slider(value: bpm, in: 40...240, step: 1)
                        .tint(.green)
                    Text("\(Int(bpm.wrappedValue.rounded()))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - BPM

    private var bpmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("BPM", icon: "metronome")

            HStack {
                Spacer()
                Text("\(Int(engine.manualBPM.rounded()))")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
            }

            if engine.bpmIsMapped {
                Text("Controlled by hand")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 10) {
                    Button(action: { engine.manualBPM = max(50, engine.manualBPM - 1) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }

                    Slider(value: Binding(
                        get: { engine.manualBPM },
                        set: { engine.manualBPM = $0 }
                    ), in: 50...205, step: 1)
                    .tint(.green)

                    Button(action: { engine.manualBPM = min(205, engine.manualBPM + 1) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                }
            }
        }
    }

    // MARK: - Params

    private var paramsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PARAMETERS", icon: "slider.horizontal.3")

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
                // Lock toggle with filled circle background
                Button(action: { engine.toggleLock(def.id) }) {
                    ZStack {
                        Circle()
                            .fill(isLocked ? Color.orange.opacity(0.2) : Color.clear)
                            .frame(width: 24, height: 24)
                        Image(systemName: isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 11))
                            .foregroundColor(isLocked ? .orange : .secondary.opacity(0.4))
                    }
                }
                .frame(width: 24)

                Text(def.label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(isLocked ? .orange : .primary)
                    .frame(width: 55, alignment: .leading)

                if isLocked {
                    Slider(value: Binding(
                        get: { engine.manualValues[def.id] ?? def.defaultValue },
                        set: { engine.setManualValue(def.id, value: $0) }
                    ), in: def.min...def.max)
                    .tint(.orange)
                } else {
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
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .frame(minHeight: 32)
    }

    // MARK: - Recording Settings

    // MARK: - Filters

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("FILTERS", icon: "camera.filters")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(CAMERA_FILTERS) { filter in
                    let locked = filter.isPremium && !storeManager.isUnlocked(filter.packId ?? "")
                    let isSelected = engine.selectedFilter.id == filter.id
                    Button(action: {
                        if locked, let packId = filter.packId {
                            paywallPackId = packId
                        } else {
                            engine.selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 2) {
                            Text(filter.emoji)
                                .font(.system(size: 18))
                            Text(filter.name)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? .green : .primary.opacity(0.6))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Text("PRO")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.15)))
                                    .padding(4)
                            }
                        }
                        .opacity(locked ? 0.5 : 1.0)
                    }
                }
            }
        }
    }

    // MARK: - Loops

    private var loopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("LOOPS", icon: "waveform.circle")
                Spacer()
                if !engine.playingLoopIds.isEmpty {
                    Button(action: engine.stopAllLoops) {
                        Text("Stop All")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }

            Text("Tap the red circle button to record a loop. Loops auto-play and layer on top of each other.")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)

            // Bar length picker
            HStack(spacing: 6) {
                Text("Length")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                ForEach(LoopRecorder.barOptions, id: \.self) { bars in
                    Button(action: { engine.loopRecorder.selectedBars = bars }) {
                        Text("\(bars) bars")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(engine.loopRecorder.selectedBars == bars ? .green : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(engine.loopRecorder.selectedBars == bars ? Color.green.opacity(0.15) : Color.primary.opacity(0.04))
                            )
                    }
                }
            }

            // Saved loops
            ForEach(engine.savedLoops) { loop in
                HStack(spacing: 10) {
                    // Play/stop toggle
                    Button(action: { engine.toggleLoopPlayback(loop.id) }) {
                        Image(systemName: engine.playingLoopIds.contains(loop.id) ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(engine.playingLoopIds.contains(loop.id) ? .orange : .green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(loop.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        HStack(spacing: 6) {
                            Text(loop.mode)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.15)))
                            Text("\(loop.events.count) events")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", loop.duration))s")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Export audio
                    Button(action: {
                        Task {
                            if let url = try? await AudioExporter.exportLoop(loop) {
                                await MainActor.run {
                                    exportedAudioURL = url
                                    showAudioExport = true
                                }
                            }
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(.green.opacity(0.6))
                    }

                    // Delete
                    Button(action: { engine.deleteLoop(loop.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RECORDING", icon: "video")

            pillToggle("Hide hand tracking in recordings", icon: "hand.raised.slash", isOn: $hideSkeletonWhenRecording)
        }
    }

    // MARK: - Snippets

    private var snippetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("SAVED SNIPPETS", icon: "bookmark")

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
                sectionHeader("TRACK", icon: "list.bullet.rectangle")
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

// MARK: - Shake Detector

struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    class ShakeVC: UIViewController {
        var onShake: (() -> Void)?
        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { onShake?() }
            super.motionEnded(motion, with: event)
        }
        override var canBecomeFirstResponder: Bool { true }
    }

    func makeUIViewController(context: Context) -> ShakeVC {
        let vc = ShakeVC()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ vc: ShakeVC, context: Context) {
        vc.onShake = onShake
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
