import SwiftUI

struct SidebarView: View {
    @ObservedObject var engine: EngineController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Live code display
                codeSection

                // Parameter meters
                paramSection

                // Hand panels
                handPanelsSection

                // Hydra controls
                hydraSection

                // Saved snippets
                snippetSection

                // Track sequencer
                trackSection
            }
            .padding(10)
        }
        .background(Color(white: 0.08).opacity(0.95))
    }

    // MARK: - Code Display

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STRUDEL")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.green.opacity(0.5))

            Text(engine.codeDisplay)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.green)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
                .cornerRadius(6)

            if engine.hydraEnabled && !engine.hydraCodeDisplay.isEmpty {
                Text("HYDRA")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple.opacity(0.5))
                    .padding(.top, 4)

                Text(engine.hydraCodeDisplay)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.purple)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - Parameters

    private var paramSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PARAMS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))

            ForEach(PARAM_DEFS) { def in
                let isActive = engine.config.left.values.contains(def.id) ||
                               engine.config.right.values.contains(def.id)
                if isActive {
                    paramBar(def: def, value: engine.smoothedParams[def.id] ?? def.defaultValue)
                }
            }
        }
    }

    private func paramBar(def: ParamDef, value: Double) -> some View {
        let normalized = (value - def.min) / (def.max - def.min)
        return HStack(spacing: 4) {
            Text(def.label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 50, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: geo.size.width * max(0, min(1, normalized)))
                }
            }
            .frame(height: 6)
            .cornerRadius(3)

            Text(def.format(value))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 45, alignment: .leading)
        }
        .frame(height: 14)
    }

    // MARK: - Hand Panels

    private var handPanelsSection: some View {
        HStack(spacing: 8) {
            handPanel(side: "L", hand: engine.handsState.left, color: .green,
                      sideConfig: engine.config.left)
            handPanel(side: "R", hand: engine.handsState.right, color: .pink,
                      sideConfig: engine.config.right)
        }
    }

    private func handPanel(side: String, hand: HandData?, color: Color, sideConfig: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(hand != nil ? color : Color.gray)
                    .frame(width: 6, height: 6)
                Text(side)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            let axes = engine.advanced ? AXIS_DEFS : AXIS_DEFS.filter(\.basic)
            ForEach(axes) { axis in
                if let paramId = sideConfig[axis.key], paramId != "none" {
                    let raw = hand?.value(for: axis.key) ?? 0
                    HStack(spacing: 2) {
                        Text(axis.label)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 35, alignment: .trailing)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.08))
                                Rectangle()
                                    .fill(color.opacity(0.5))
                                    .frame(width: geo.size.width * max(0, min(1, raw)))
                            }
                        }
                        .frame(height: 4)
                        .cornerRadius(2)
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    // MARK: - Hydra

    private var hydraSection: some View {
        Group {
            if hasHydraMapping(engine.hydraConfig) {
                Button(action: engine.toggleHydra) {
                    HStack(spacing: 4) {
                        Image(systemName: engine.hydraEnabled ? "eye.fill" : "eye.slash")
                        Text("hydra")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(engine.hydraEnabled ? .purple : .white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(engine.hydraEnabled ? Color.purple.opacity(0.2) : Color.white.opacity(0.05))
                    .cornerRadius(4)
                }
            }
        }
    }

    // MARK: - Snippets

    private var snippetSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !engine.savedSnippets.isEmpty {
                Text("SAVED (\(engine.savedSnippets.count))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))

                ForEach(Array(engine.savedSnippets.enumerated()), id: \.offset) { idx, snippet in
                    HStack(spacing: 4) {
                        Button(action: { engine.toggleSnippet(idx) }) {
                            Image(systemName: engine.playingSet.contains(idx) ? "pause.fill" : "play.fill")
                                .font(.system(size: 10))
                                .foregroundColor(engine.playingSet.contains(idx) ? .orange : .white.opacity(0.5))
                        }

                        Text("#\(idx + 1)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))

                        Text("\(snippet.bpm) bpm")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))

                        Spacer()

                        Button(action: { engine.addToTrack(idx) }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Track

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !engine.track.slots.isEmpty {
                HStack {
                    Text("TRACK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))

                    Spacer()

                    Button(action: engine.toggleTrackPlay) {
                        Image(systemName: engine.trackPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundColor(engine.trackPlaying ? .orange : .green)
                    }
                }

                // Speed control
                HStack(spacing: 4) {
                    Text("speed")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    ForEach([0.25, 0.5, 1.0, 2.0, 4.0], id: \.self) { speed in
                        Button(action: { engine.setTrackSpeed(speed) }) {
                            Text("\(speed == Double(Int(speed)) ? "\(Int(speed))" : String(format: "%.2g", speed))x")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(engine.track.speed == speed ? .green : .white.opacity(0.3))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(engine.track.speed == speed ? Color.green.opacity(0.15) : Color.clear)
                                .cornerRadius(3)
                        }
                    }
                }

                // Track slots
                ForEach(Array(engine.track.slots.enumerated()), id: \.offset) { slotIdx, snippetIdx in
                    HStack(spacing: 4) {
                        Text("\(slotIdx + 1).")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        Text("#\(snippetIdx + 1)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Button(action: { engine.removeFromTrack(slotIdx) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
            }
        }
    }
}
