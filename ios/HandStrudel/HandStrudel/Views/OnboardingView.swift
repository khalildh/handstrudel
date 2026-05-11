import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 32) {
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

                // Tips
                VStack(spacing: 20) {
                    tipRow(
                        icon: "arrow.up.arrow.down",
                        title: "Move your hands up & down",
                        subtitle: "Controls pitch & volume"
                    )
                    tipRow(
                        icon: "hand.raised.fingers.spread",
                        title: "Spread your fingers",
                        subtitle: "Adds reverb, filter & effects"
                    )
                    tipRow(
                        icon: "video.circle",
                        title: "Tap the record button",
                        subtitle: "Share to Instagram"
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
                    Text("GOT IT!")
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
