import SwiftUI

/// First-run overlay shown on top of the performance screen. Mirrors how the
/// default mode (Split chord+melody) actually plays: the wheel cuts left and
/// right at the screen divider, hands fall in their own half, and either a
/// pinch or a touch makes sound. Goal is to get a brand-new user from "I
/// opened this" to a sustained chord in under twenty seconds.
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Title
                VStack(spacing: 6) {
                    Text("welcome to")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))

                    HStack(spacing: 0) {
                        Text("hand")
                            .font(.system(size: 28, weight: .thin, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        Text("strudel")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }

                // Tips — each one corresponds directly to a physical thing the
                // player can do as soon as they dismiss this overlay.
                VStack(spacing: 18) {
                    tipRow(
                        icon: "hand.point.left.fill",
                        title: "Left half = chords",
                        subtitle: "Reach toward a wedge to pick a chord"
                    )
                    tipRow(
                        icon: "hand.point.right.fill",
                        title: "Right half = melody",
                        subtitle: "Reach high for high notes, low for low"
                    )
                    tipRow(
                        icon: "hand.tap.fill",
                        title: "Pinch — or just tap",
                        subtitle: "Hold to sustain, drag to slide between zones"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Dismiss button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasSeenOnboarding = true
                    }
                }) {
                    Text("LET'S PLAY")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.green)
                        .cornerRadius(16)
                }
                .accessibilityIdentifier("onboarding-got-it")
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
    }

    private func tipRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.green)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
    }
}
