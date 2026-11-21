import SwiftUI

extension View {
    /// Fetches remote config and the instrument catalog at launch and on
    /// foreground (throttled), and shows the update banner or blocker the
    /// config asks for. `showsBanner` hides the soft banner mid-performance;
    /// the blocker always shows.
    func remoteUpdates(showsBanner: Bool) -> some View {
        modifier(RemoteUpdatesModifier(showsBanner: showsBanner))
    }
}

private struct RemoteUpdatesModifier: ViewModifier {
    let showsBanner: Bool
    @ObservedObject private var config = RemoteConfig.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("remoteUpdateDismissedVersion") private var dismissedVersion = ""

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showsBanner, case .recommended(let version) = config.updateRequirement, dismissedVersion != version {
                    UpdateBanner(message: config.updateMessage, url: config.appStoreURL) { dismissedVersion = version }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                if case .required = config.updateRequirement {
                    UpdateRequiredView(message: config.updateMessage, url: config.appStoreURL)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: config.updateRequirement)
            .task { await refresh() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await refresh() } }
            }
    }

    private func refresh() async {
        await RemoteConfig.shared.refreshIfNeeded()
        await InstrumentCatalog.shared.refreshIfNeeded()
    }
}

/// Soft prompt: a newer version is recommended.
struct UpdateBanner: View {
    let message: String?
    let url: URL
    let onDismiss: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.studioPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.app.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Update available").font(.subheadline.bold())
                Text(message ?? "A new version of HandStrudel is ready.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button { openURL(url) } label: { Text("Update").foregroundStyle(palette.onAccent) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("update-banner-open")
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.footnote.bold()).foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier("update-banner-dismiss")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("update-banner")
    }
}

/// Hard block: this version is no longer supported.
struct UpdateRequiredView: View {
    let message: String?
    let url: URL
    @Environment(\.openURL) private var openURL
    @Environment(\.studioPalette) private var palette

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Update required").font(.title2.bold()).foregroundStyle(palette.ink)
                Text(message ?? "This version of HandStrudel is no longer supported. Update to keep playing.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    openURL(url)
                } label: {
                    Text("Update on the App Store").foregroundStyle(palette.onAccent).frame(maxWidth: 320)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("update-required-open")
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("update-required")
        .accessibilityAddTraits(.isModal)
    }
}
