import SwiftUI

struct StartOverlayView: View {
    let status: String
    let onStart: (MappingConfig, MappingConfig, Bool) -> Void

    @State private var selectedPreset: Preset? = nil
    @State private var starting = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color(white: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
                .padding(.bottom, 40)

                // Preset cards
                Text("pick a vibe")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .textCase(.uppercase)
                    .tracking(2)
                    .padding(.bottom, 12)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(PRESETS) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: selectedPreset?.id == preset.id
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
                    }
                    .disabled(selectedPreset == nil)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                    .onChange(of: selectedPreset?.id) { _ in
                        startPulse()
                    }
                }
            }
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
