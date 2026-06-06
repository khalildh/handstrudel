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
    @State private var showLearnPicker = false
    @State private var watermarkView: UIView?
    @State private var showRandomizedToast = false
    // Song mode removed

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
                    onStart: { cfg, adv in
                        engine.start(config: cfg, advanced: adv)
                    }
                )
            }

            // Hidden WebView for audio (must be in view hierarchy)
            WebViewContainer(webView: engine.strudelBridge.view)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
                hasSeenOnboarding = false
            }
        }
        .statusBarHidden(engine.isRunning)
        .onReceive(NotificationCenter.default.publisher(for: .siriStartPreset)) { notification in
            guard !engine.isRunning, let presetId = notification.object as? String else { return }
            if let preset = PRESETS.first(where: { $0.id == presetId }) {
                engine.start(config: preset.mapping, advanced: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .siriStartMode)) { notification in
            guard let mode = notification.object as? String else { return }
            if !engine.isRunning {
                // Start with default preset first
                engine.start(config: DEFAULT_MAPPING, advanced: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                switch mode {
                case "grid": engine.switchMode(grid: true, drums: false, learn: false)
                case "drums": engine.switchMode(grid: false, drums: true, learn: false)
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
                videoAspect: engine.handTracker.videoWidth / engine.handTracker.videoHeight,
                theme: engine.selectedHandTheme
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(isRecording && hideSkeletonWhenRecording ? 0 : 1)

            // Grid mode note lanes overlay (tappable for one-hand play)
            if engine.gridModeEnabled {
                noteGridOverlay
                    .ignoresSafeArea()
            }

            // Drum zone overlay (tappable pads)
            if engine.drumModeEnabled {
                drumZoneOverlay
                    .ignoresSafeArea()
            }

            // Chord+Melody / SoundFont mode overlay (chord zones + melody lanes).
            // Both modes share the same two-hand interaction and chordMelody*
            // UI state, so they render the same overlay.
            if engine.chordMelodyModeEnabled || engine.soundFontModeEnabled {
                ChordMelodyOverlayView(
                    zoneDegrees: engine.chordMelodyModeManager.zoneDegrees,
                    currentChordZone: engine.chordMelodyChordHandLane,
                    chordHandPinching: engine.chordMelodyModeManager.isChordHandPinching,
                    currentOctaveShift: engine.chordMelodyOctaveShift,
                    currentChordName: engine.chordMelodyCurrentChordName,
                    melodyLane: engine.chordMelodyMelodyLane,
                    melodyHandPinching: engine.chordMelodyModeManager.isMelodyHandPinching,
                    melodyLaneCount: 9,
                    swapHands: engine.chordMelodySwapHands
                )
                .ignoresSafeArea()
            }

            // Learn mode overlay (Guitar Hero scrolling notes)
            if engine.learnModeEnabled {
                let gridNotes = scaleNotes(key: engine.selectedKey, scale: engine.selectedScale,
                                          baseOctave: engine.gridBaseOctave, octaveRange: engine.gridOctaveRange)
                LearnOverlayView(
                    noteCount: gridNotes.count,
                    scaleNotes: gridNotes,
                    visibleNotes: engine.learnVisibleNotes,
                    hitEffects: engine.learnHitEffects,
                    score: engine.learnScore,
                    songComplete: engine.learnSongComplete,
                    songName: engine.currentLearnSong?.name ?? "",
                    leftPinchX: engine.handsState.left?.pinchX,
                    leftPinchY: engine.handsState.left?.pinchY,
                    rightPinchX: engine.handsState.right?.pinchX,
                    rightPinchY: engine.handsState.right?.pinchY,
                    leftPinching: (engine.handsState.left?.pinch ?? 0) > 0.8,
                    rightPinching: (engine.handsState.right?.pinch ?? 0) > 0.8,
                    videoAspect: engine.handTracker.videoWidth / engine.handTracker.videoHeight,
                    countdownValue: engine.learnModeManager.countdownValue,
                    isCountingDown: engine.learnModeManager.isCountingDown,
                    onPlayAgain: {
                        if let song = engine.currentLearnSong { engine.loadLearnSong(song) }
                    },
                    onPickSong: { showLearnPicker = true }
                )
                .ignoresSafeArea()
            }

            // Floating UI overlays
            VStack {
                // Top bar: close button + beat dots
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Logo
                logoMark
                    .padding(.top, 2)

                // Jam session indicator
                if engine.jamSession.isActive {
                    let text = engine.jamSession.lastReceivedEvent.isEmpty
                        ? engine.jamSession.statusMessage
                        : engine.jamSession.lastReceivedEvent
                    if !text.isEmpty {
                        Text(text)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.cyan.opacity(0.1)))
                    }
                }

                // Floating code pill — hide in grid/drum/learn/chord/soundfont mode
                if !engine.gridModeEnabled && !engine.drumModeEnabled && !engine.learnModeEnabled && !engine.chordMelodyModeEnabled && !engine.soundFontModeEnabled {
                    codePill
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                }

                Spacer()

                // Note badge — hide in grid/drum/learn/chord/soundfont mode
                if !engine.gridModeEnabled && !engine.drumModeEnabled && !engine.learnModeEnabled && !engine.chordMelodyModeEnabled && !engine.soundFontModeEnabled {
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

                // Drum XY pad (bottom area, below drum lanes)
                if engine.drumModeEnabled {
                    drumXYPad
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
                        // Don't swipe filters while using drum XY pad or grid
                        guard !engine.drumModeEnabled && !engine.gridModeEnabled else { return }
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
        .sheet(isPresented: $showLearnPicker) {
            LearnSongPicker { song in
                engine.loadLearnSong(song)
                showLearnPicker = false
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
                .onAppear { engine.pause() }
                .onDisappear { engine.resume() }
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
            .accessibilityIdentifier("close-button")
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
        HStack(spacing: 10) {
            // Finger count indicator (when finger octave is enabled)
            if engine.fingerOctaveEnabled {
                HStack(spacing: 3) {
                    // Show finger count visually
                    ForEach(1...5, id: \.self) { i in
                        Circle()
                            .fill(i <= engine.currentFingerCount ? Color.green : Color.white.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Octave display
            Text("Oct \(engine.gridBaseOctave)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.green)

            // Manual octave controls (when finger control is off)
            if !engine.fingerOctaveEnabled {
                Button(action: { if engine.gridBaseOctave > 1 { engine.gridBaseOctave -= 1 } }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                Button(action: { if engine.gridBaseOctave < 6 { engine.gridBaseOctave += 1 } }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }

            Spacer()

            // Sync-to-beat (quantize) toggle
            Button(action: { engine.quantizeEnabled.toggle() }) {
                Image(systemName: engine.quantizeEnabled ? "metronome.fill" : "metronome")
                    .font(.system(size: 12))
                    .foregroundColor(engine.quantizeEnabled ? .green : .white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(engine.quantizeEnabled ? Color.green.opacity(0.15) : Color.white.opacity(0.1)))
            }

            // Finger octave toggle
            Button(action: { engine.fingerOctaveEnabled.toggle() }) {
                Image(systemName: engine.fingerOctaveEnabled ? "hand.raised.fingers.spread" : "hand.raised.slash")
                    .font(.system(size: 12))
                    .foregroundColor(engine.fingerOctaveEnabled ? .green : .white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(engine.fingerOctaveEnabled ? Color.green.opacity(0.15) : Color.white.opacity(0.1)))
            }

            // Range pills
            ForEach([1, 2, 3], id: \.self) { range in
                Button(action: { engine.gridOctaveRange = range }) {
                    Text("\(range)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(engine.gridOctaveRange == range ? .black : .white.opacity(0.6))
                        .frame(width: 26, height: 26)
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

    // MARK: - Drum Lane Overlay

    @State private var activeDrumLanes = Set<String>()

    private struct DrumLane: Identifiable {
        let id: String
        let name: String
        let hitType: String
        let emoji: String
        let color: Color
    }

    private let drumLanes: [DrumLane] = [
        DrumLane(id: "crash", name: "CRASH", hitType: "crash", emoji: "💥", color: .yellow),
        DrumLane(id: "hihat", name: "HI-HAT", hitType: "hihat", emoji: "🔔", color: .cyan),
        DrumLane(id: "snare", name: "SNARE", hitType: "snare", emoji: "🥁", color: .orange),
        DrumLane(id: "ride", name: "RIDE", hitType: "ride", emoji: "🛎️", color: .pink),
        DrumLane(id: "tom", name: "TOM", hitType: "tom", emoji: "🪘", color: .purple),
        DrumLane(id: "kick", name: "KICK", hitType: "kick", emoji: "🦶", color: .red),
    ]

    private var drumZoneOverlay: some View {
        GeometryReader { geo in
            let topPad = geo.size.height * 0.15
            let bottomPad = geo.size.height * 0.20
            let usableHeight = geo.size.height - topPad - bottomPad
            let laneHeight = usableHeight / CGFloat(drumLanes.count)

        VStack(spacing: 0) {
            Spacer().frame(height: topPad)

            ForEach(Array(drumLanes.enumerated()), id: \.element.id) { idx, lane in
                let leftTouched = activeDrumLanes.contains("L_\(lane.id)")
                let rightTouched = activeDrumLanes.contains("R_\(lane.id)")
                let leftHand = engine.drumLeftLane == idx
                let rightHand = engine.drumRightLane == idx
                let leftPinch = leftHand && engine.drumModeManager.isLeftPinching
                let rightPinch = rightHand && engine.drumModeManager.isRightPinching
                let leftActive = leftTouched || leftPinch
                let rightActive = rightTouched || rightPinch

                HStack(spacing: 0) {
                    // Left hand pad
                    ZStack {
                        Rectangle()
                            .fill(leftActive ? lane.color.opacity(0.35)
                                  : leftHand ? lane.color.opacity(0.1)
                                  : Color.white.opacity(0.03))

                        HStack(spacing: 6) {
                            Text(lane.emoji)
                                .font(.system(size: 20))
                            Text(lane.name)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(leftActive ? lane.color : .white.opacity(0.4))
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                let key = "L_\(lane.id)"
                                if !activeDrumLanes.contains(key) {
                                    activeDrumLanes.insert(key)
                                    engine.strudelBridge.playHit(lane.hitType)
                                    engine.haptics.drumHit()
                                }
                            }
                            .onEnded { _ in
                                activeDrumLanes.remove("L_\(lane.id)")
                            }
                    )

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)

                    // Right hand pad
                    ZStack {
                        Rectangle()
                            .fill(rightActive ? lane.color.opacity(0.35)
                                  : rightHand ? lane.color.opacity(0.1)
                                  : Color.white.opacity(0.0))

                        HStack(spacing: 6) {
                            Text(lane.name)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(rightActive ? lane.color : .white.opacity(0.4))
                            Text(lane.emoji)
                                .font(.system(size: 20))
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                let key = "R_\(lane.id)"
                                if !activeDrumLanes.contains(key) {
                                    activeDrumLanes.insert(key)
                                    engine.strudelBridge.playHit(lane.hitType)
                                    engine.haptics.drumHit()
                                }
                            }
                            .onEnded { _ in
                                activeDrumLanes.remove("R_\(lane.id)")
                            }
                    )
                }
                .frame(height: laneHeight)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(leftActive || rightActive ? 0.15 : 0.04))
                        .frame(height: 1)
                }
                .animation(.easeOut(duration: 0.08), value: leftActive)
                .animation(.easeOut(duration: 0.08), value: rightActive)
            }

            Spacer()
        }
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
            .accessibilityIdentifier("settings-button")
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
                engine.startLoopRecording()
                let modeHint = engine.gridModeEnabled ? "play notes" : engine.drumModeEnabled ? "play drums" : "move your hands"
                loopMessage = "Recording loop — \(modeHint), tap again to stop"
                withAnimation { showLoopSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showLoopSaved = false }
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
                    Image(systemName: loopMessage.contains("saved") ? "checkmark.circle.fill" : loopMessage.contains("Recording") ? "record.circle" : "info.circle.fill")
                        .font(.system(size: 12))
                    Text(loopMessage)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(loopMessage.contains("saved") ? .green : loopMessage.contains("Recording") ? .red : .orange)
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
            .accessibilityIdentifier("record-button")
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
