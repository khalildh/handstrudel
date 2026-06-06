import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        ZStack {
            // Frosted scrim over the live camera — premium, keeps context.
            Rectangle()
                .fill(.regularMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: DS.Space.xl) {
                Spacer()

                VStack(spacing: DS.Space.xs) {
                    Text("WELCOME TO")
                        .font(.dsCaption)
                        .tracking(1.5)
                        .foregroundColor(DS.textTertiary)

                    AmbientAccent(period: 26) { color, _ in
                        HStack(spacing: 0) {
                            Text("hand")
                                .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
                                .foregroundColor(DS.textPrimary)
                            Text("strudel")
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .foregroundColor(color)
                        }
                    }
                    .frame(height: 34)
                }

                VStack(spacing: DS.Space.md) {
                    tipRow(icon: "arrow.up.arrow.down",
                           title: "Move your hands up & down",
                           subtitle: "Controls pitch & volume")
                    tipRow(icon: "hand.raised.fingers.spread",
                           title: "Spread your fingers",
                           subtitle: "Adds reverb, filter & effects")
                    tipRow(icon: "video.fill",
                           title: "Tap record to capture a clip",
                           subtitle: "Share straight to Instagram")
                }
                .padding(.horizontal, DS.Space.lg)

                Spacer()

                AmbientAccent(period: 26) { color, _ in
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) { hasSeenOnboarding = true }
                    }) {
                        Text("Got it")
                    }
                    .buttonStyle(DSPrimaryButtonStyle(accent: color))
                    .accessibilityIdentifier("onboarding-got-it")
                }
                .frame(height: 54)
                .padding(.horizontal, DS.Space.lg)
                .padding(.bottom, DS.Space.xxl)
            }
        }
    }

    private func tipRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: DS.Space.md) {
            IconTile(symbol: icon, tint: DS.signature, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.dsHeadline)
                    .foregroundColor(DS.textPrimary)
                Text(subtitle)
                    .font(.dsFootnote)
                    .foregroundColor(DS.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Space.sm)
        .dsCard()
    }
}
