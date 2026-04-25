import SwiftUI

struct FloatingNote: Identifiable {
    let id = UUID()
    let emoji: String
    let x: CGFloat
    let startY: CGFloat
    let duration: Double
    let delay: Double
    let opacity: Double
    let size: CGFloat
}

struct StartOverlayView: View {
    let status: String
    let onStart: (MappingConfig, MappingConfig, Bool) -> Void

    @State private var selectedPreset: Preset? = nil
    @State private var starting = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var buttonGlow: CGFloat = 0.0
    @State private var cardsAppeared = false
    @State private var titleAppeared = false
    @State private var notesAnimating = false
    @State private var titleGlowPhase: CGFloat = 0.0

    private let floatingNotes: [FloatingNote] = [
        FloatingNote(emoji: "🎵", x: 0.12, startY: 1.1, duration: 8.0, delay: 0.0, opacity: 0.15, size: 20),
        FloatingNote(emoji: "🎶", x: 0.35, startY: 1.2, duration: 10.0, delay: 1.5, opacity: 0.1, size: 16),
        FloatingNote(emoji: "🎵", x: 0.62, startY: 1.15, duration: 9.0, delay: 0.8, opacity: 0.12, size: 22),
        FloatingNote(emoji: "🎶", x: 0.85, startY: 1.25, duration: 11.0, delay: 2.0, opacity: 0.08, size: 18),
        FloatingNote(emoji: "🎵", x: 0.48, startY: 1.3, duration: 12.0, delay: 3.0, opacity: 0.1, size: 14),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color(white: 0.06), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Floating music notes
                ForEach(floatingNotes) { note in
                    Text(note.emoji)
                        .font(.system(size: note.size))
                        .opacity(note.opacity)
                        .position(
                            x: note.x * geo.size.width,
                            y: notesAnimating
                                ? -note.size
                                : note.startY * geo.size.height
                        )
                        .animation(
                            .easeInOut(duration: note.duration)
                            .delay(note.delay)
                            .repeatForever(autoreverses: false),
                            value: notesAnimating
                        )
                }

                VStack(spacing: 0) {
                    Spacer()

                    // App title
                    VStack(spacing: 6) {
                        Text("hand")
                            .font(.system(size: 42, weight: .thin, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        +
                        Text("strudel")
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)

                        Text("make music with your hands")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .shadow(color: .green.opacity(titleGlowPhase * 0.4), radius: 20)
                    .shadow(color: .green.opacity(titleGlowPhase * 0.2), radius: 40)
                    .opacity(titleAppeared ? 1 : 0)
                    .scaleEffect(titleAppeared ? 1 : 0.9)
                    .animation(.easeOut(duration: 0.6), value: titleAppeared)
                    .padding(.bottom, 40)

                    // Preset cards
                    Text("pick a vibe")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .textCase(.uppercase)
                        .tracking(2)
                        .padding(.bottom, 12)
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: cardsAppeared)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(Array(PRESETS.enumerated()), id: \.element.id) { index, preset in
                            PresetCard(
                                preset: preset,
                                isSelected: selectedPreset?.id == preset.id
                            )
                            .opacity(cardsAppeared ? 1 : 0)
                            .scaleEffect(cardsAppeared ? 1 : 0.85)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(0.4 + Double(index) * 0.1),
                                value: cardsAppeared
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedPreset = preset
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Start button or status
                    if starting {
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(.green)
                            Text(status)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.green.opacity(0.7))
                        }
                        .padding(.bottom, 50)
                    } else {
                        Button(action: startTapped) {
                            Text("LET'S GO")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    selectedPreset != nil
                                        ? Color.green
                                        : Color.white.opacity(0.1)
                                )
                                .cornerRadius(16)
                                .scaleEffect(pulseScale)
                                .shadow(
                                    color: .green.opacity(selectedPreset != nil ? buttonGlow * 0.6 : 0),
                                    radius: 16
                                )
                                .shadow(
                                    color: .green.opacity(selectedPreset != nil ? buttonGlow * 0.3 : 0),
                                    radius: 30
                                )
                        }
                        .disabled(selectedPreset == nil)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 50)
                        .onChange(of: selectedPreset?.id) { _ in
                            startPulse()
                            startButtonGlow()
                        }
                    }
                }
            }
        }
        .onAppear {
            titleAppeared = true
            cardsAppeared = true
            notesAnimating = true
            startTitleGlow()
        }
    }

    private func startTapped() {
        guard let preset = selectedPreset else { return }
        starting = true
        onStart(preset.mapping, preset.hydraMapping, false)
    }

    private func startPulse() {
        guard selectedPreset != nil else { return }
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseScale = 1.04
        }
    }

    private func startButtonGlow() {
        guard selectedPreset != nil else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            buttonGlow = 1.0
        }
    }

    private func startTitleGlow() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            titleGlowPhase = 1.0
        }
    }
}

struct PresetCard: View {
    let preset: Preset
    let isSelected: Bool

    var presetColor: Color {
        Color(red: preset.color.0, green: preset.color.1, blue: preset.color.2)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(preset.emoji)
                .font(.system(size: 32))

            Text(preset.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(preset.description)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? presetColor.opacity(0.25) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? presetColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}
