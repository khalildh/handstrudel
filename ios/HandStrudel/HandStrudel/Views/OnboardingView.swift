import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    let noteName: String
    let melodyLaneCount: Int
    let swapHands: Bool
    let playFirstNote: () -> Void
    @State private var played = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // This layer keeps the first touch on the highlighted note.
                Color.black.opacity(0.16)
                    .contentShape(Rectangle())
                    .onTapGesture {}
                    .allowsHitTesting(!played)

                if !played {
                    Button {
                        playFirstNote()
                        withAnimation(.easeOut(duration: 0.2)) { played = true }
                    } label: {
                        Text(noteName)
                            .font(.title3.bold())
                            .foregroundStyle(StudioStyle.background)
                            .frame(width: 53, height: 53)
                            .background(StudioStyle.accent, in: Circle())
                            .overlay { Circle().strokeBorder(.white.opacity(0.6)) }
                    }
                    .buttonStyle(.plain)
                    .position(target(in: geometry.size))
                    .accessibilityLabel("Play your first note")
                    .accessibilityIdentifier("onboarding-first-note")
                }

                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 9) {
                        Text(played ? "Now try a pinch" : "Play your first note")
                            .font(.system(.title2, design: .serif))
                            .accessibilityAddTraits(.isHeader)
                        Text(played
                             ? "Hold your hand over a note and pinch your thumb and index finger. You can also tap or drag on the wheel."
                             : "Tap the highlighted note on the wheel.")
                            .font(.subheadline)
                            .foregroundStyle(StudioStyle.muted)
                        Button(played ? "Keep playing" : "Skip") { hasSeenOnboarding = true }
                            .buttonStyle(.bordered)
                            .tint(StudioStyle.accent)
                            .accessibilityIdentifier("onboarding-got-it")
                    }
                    .frame(maxWidth: 430, alignment: .leading)
                    .padding(17)
                    .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private func target(in size: CGSize) -> CGPoint {
        let count = max(1, melodyLaneCount)
        let lane = count / 2
        let theta = (Double(count - 1 - lane) + 0.5) * .pi / Double(count)
        let radius = min(size.width, size.height) * 0.31
        return CGPoint(x: size.width / 2 + sin(theta) * radius * (swapHands ? -1 : 1),
                       y: size.height / 2 - cos(theta) * radius)
    }
}
