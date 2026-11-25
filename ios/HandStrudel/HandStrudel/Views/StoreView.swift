import SwiftUI
import RevenueCat

/// The one place HandStrudel sells anything: Pro (one-time, all the music) and
/// HandStrudel+ (monthly or yearly: everything in Pro plus camera filters and
/// hand themes). Opened from the bag icon, and from any locked item with that
/// item's `highlight` offer, a headline about it, and `unlocks` — the item's
/// pack id — so the sheet closes itself once the item is unlocked.
struct StoreView: View {
    @ObservedObject var storeManager: StoreManager
    var highlight: StoreManager.Offer? = nil
    var headline: String? = nil
    var detail: String? = nil
    var unlocks: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.studioPalette) private var palette
    @State private var plan: Plan = .yearly
    @State private var purchasing: String?
    @State private var errorMessage: String?
    @State private var showManageSubscription = false

    enum Plan: Hashable { case monthly, yearly }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    // Lead with what the player came for, or the plan they're on.
                    if highlight == .plus || (highlight == nil && storeManager.hasSubscription) {
                        plusCard
                        proCard
                    } else {
                        proCard
                        plusCard
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("store-done")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(palette.accent)
        .foregroundStyle(palette.ink)
        .task { await storeManager.loadProducts() }
        .onAppear { Funnel.storeViewed() }
        .onChange(of: isTargetUnlocked) { unlocked in
            if unlocked { dismiss() }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .alert("Purchase didn't go through", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// The locked item that opened the store is now playable.
    private var isTargetUnlocked: Bool {
        guard let unlocks else { return false }
        return storeManager.isUnlocked(unlocks)
    }

    private var background: some View {
        ZStack(alignment: .top) {
            palette.background
            RadialGradient(colors: [palette.glow.opacity(0.9), palette.background.opacity(0)],
                           center: .top, startRadius: 0, endRadius: 420)
                .frame(height: 460)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.14))
                Circle().strokeBorder(palette.accent.opacity(0.35))
                Image(systemName: "waveform")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 60, height: 60)
            .accessibilityHidden(true)
            .padding(.top, 6)

            Text(headline ?? "Play every sound")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("store-headline")
            Text(detail ?? "Own all the music once with Pro, or get it all with HandStrudel+.")
                .font(.body)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Pro

    private var proCard: some View {
        let product = product(StoreManager.pro)
        return OfferCard(featured: highlight == .pro, accessibilityID: "store-pro") {
            cardHeader(title: "Pro", tag: "One-time", price: product?.localizedPriceString)
            features([
                ("pianokeys", "128 instruments"),
                ("music.quarternote.3", "Every scale, from modes to exotic"),
                ("arrow.triangle.2.circlepath", "Every chord progression"),
                ("square.stack.3d.up", "Every preset and drum pack"),
            ])
            if storeManager.ownsPro {
                status("You own Pro", id: "store-pro-owned")
            } else if storeManager.hasProAccess {
                status("Included with HandStrudel+", id: "store-pro-included")
                secondaryButton("Own it forever", price: product?.localizedPriceString,
                                productId: StoreManager.pro, id: "store-buy-pro")
            } else {
                primaryButton("Unlock Pro", price: product?.localizedPriceString,
                              productId: StoreManager.pro, id: "store-buy-pro",
                              prominent: highlight != .plus)
            }
        }
    }

    // MARK: - HandStrudel+

    private var plusCard: some View {
        let monthly = product(StoreManager.plusMonthly)
        let yearly = product(StoreManager.plusYearly)
        let selected = plan == .yearly ? yearly : monthly
        return OfferCard(featured: highlight != .pro, accessibilityID: "store-plus") {
            cardHeader(title: "HandStrudel+", tag: "Everything in Pro, and more", price: nil)
            features([
                ("checkmark.seal", "Everything in Pro"),
                ("camera.filters", "Premium camera filters"),
                ("hand.raised", "Premium hand themes"),
                ("sparkles", "New sounds first"),
            ])
            if storeManager.hasSubscription {
                status("You're a member", id: "store-plus-member")
                Button { showManageSubscription = true } label: {
                    Text("Manage subscription")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("store-manage-subscription")
            } else {
                if storeManager.ownsPro {
                    Label("You already own Pro. HandStrudel+ adds the looks and gets new sounds to you first.",
                          systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("store-plus-pro-note")
                }
                HStack(spacing: 10) {
                    planTile(.yearly, product: yearly, badge: savings(monthly: monthly, yearly: yearly))
                    planTile(.monthly, product: monthly, badge: nil)
                }
                primaryButton(trialText(selected) ?? "Subscribe",
                              price: selected.map { "\($0.localizedPriceString)\(periodSuffix($0))" },
                              productId: plan == .yearly ? StoreManager.plusYearly : StoreManager.plusMonthly,
                              id: "store-subscribe", prominent: highlight != .pro || storeManager.hasProAccess)
                Text("Renews automatically until you cancel. Cancel anytime in Settings at least a day before it renews.")
                    .font(.caption2)
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func planTile(_ option: Plan, product: StoreProduct?, badge: String?) -> some View {
        let isSelected = plan == option
        return Button { plan = option } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(option == .yearly ? "Yearly" : "Monthly")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 2)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? palette.accent : palette.muted)
                        .accessibilityHidden(true)
                }
                Text(product.map { "\($0.localizedPriceString)\(periodSuffix($0))" } ?? "—")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(option == .yearly ? (product?.localizedPricePerMonth.map { "\($0)/mo" } ?? " ") : "Billed monthly")
                    .font(.caption)
                    .foregroundStyle(palette.muted)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(palette.accent, in: Capsule())
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(isSelected ? palette.accent.opacity(0.1) : palette.background.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? palette.accent : palette.border, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option == .yearly ? "store-plan-yearly" : "store-plan-monthly")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            RestorePurchasesButton(storeManager: storeManager, packId: unlocks,
                                   onRestored: unlocks == nil ? nil : { dismiss() })
            HStack(spacing: 18) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://handstrudel.com/privacy")!)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(palette.muted)
            Text("Payment is charged to your Apple Account. Packs you bought before stay unlocked.")
                .font(.caption2)
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Pieces

    private func cardHeader(title: String, tag: String, price: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                Text(tag.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.accent)
            }
            Spacer(minLength: 8)
            if let price {
                Text(price)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
        }
    }

    private func features(_ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.1) { icon, text in
                HStack(spacing: 11) {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 26, height: 26)
                        .background(palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityHidden(true)
                    Text(text).font(.subheadline)
                }
            }
        }
    }

    private func status(_ text: String, id: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier(id)
    }

    private func primaryButton(_ title: String, price: String?, productId: String, id: String,
                               prominent: Bool) -> some View {
        Button { buy(productId) } label: {
            HStack(spacing: 8) {
                if purchasing == productId {
                    ProgressView().tint(prominent ? palette.onAccent : palette.accent)
                } else {
                    Text(title).fontWeight(.semibold)
                    if let price { Text("· \(price)").opacity(0.75) }
                }
            }
            .font(.body)
            .foregroundStyle(prominent ? palette.onAccent : palette.accent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(prominent ? palette.accent : palette.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(purchasing != nil || storeManager.isRestoring || product(productId) == nil)
        .accessibilityIdentifier(id)
    }

    private func secondaryButton(_ title: String, price: String?, productId: String, id: String) -> some View {
        Button { buy(productId) } label: {
            Text([title, price].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(purchasing != nil || product(productId) == nil)
        .accessibilityIdentifier(id)
    }

    // MARK: - Logic

    private func product(_ id: String) -> StoreProduct? {
        storeManager.products.first { $0.productIdentifier == id }
    }

    private func buy(_ productId: String) {
        purchasing = productId
        Task {
            defer { purchasing = nil }
            do {
                try await storeManager.purchase(productId: productId)
            } catch {
                // Backing out of Apple's sheet isn't an error worth showing.
                if (error as NSError).code == ErrorCode.purchaseCancelledError.rawValue { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func periodSuffix(_ product: StoreProduct) -> String {
        switch product.subscriptionPeriod?.unit {
        case .year: return "/yr"
        case .month: return "/mo"
        case .week: return "/wk"
        case .day: return "/day"
        default: return ""
        }
    }

    /// "Save 44%" when a year costs less than twelve months.
    private func savings(monthly: StoreProduct?, yearly: StoreProduct?) -> String? {
        guard let monthly, let yearly, monthly.price > 0 else { return nil }
        // Plain Doubles: NSDecimalNumber.intValue is unreliable for long decimals.
        let full = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
        let yearlyPrice = NSDecimalNumber(decimal: yearly.price).doubleValue
        let percent = Int(((full - yearlyPrice) / full * 100).rounded(.down))
        return percent >= 5 ? "Save \(percent)%" : nil
    }

    private func trialText(_ product: StoreProduct?) -> String? {
        guard let intro = product?.introductoryDiscount, intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        let (count, unit): (Int, String)
        switch period.unit {
        case .day where period.value % 7 == 0: (count, unit) = (period.value / 7, "week")
        case .day: (count, unit) = (period.value, "day")
        case .week: (count, unit) = (period.value, "week")
        case .month: (count, unit) = (period.value, "month")
        case .year: (count, unit) = (period.value, "year")
        @unknown default: return nil
        }
        return "Try \(count) \(unit)\(count == 1 ? "" : "s") free"
    }
}

/// A store card: surface panel; the featured one gets an accent edge and glow.
private struct OfferCard<Content: View>: View {
    @Environment(\.studioPalette) private var palette
    let featured: Bool
    let accessibilityID: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(palette.surface)
                    .overlay {
                        if featured {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(LinearGradient(colors: [palette.glow.opacity(0.55), .clear],
                                                     startPoint: .topLeading, endPoint: .center))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(featured ? palette.accent.opacity(0.7) : palette.border, lineWidth: featured ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(accessibilityID)
    }
}

struct RestorePurchasesButton: View {
    @ObservedObject var storeManager: StoreManager
    var packId: String? = nil
    var onRestoreStarted: (() -> Void)? = nil
    var onRestored: (() -> Void)? = nil

    @Environment(\.studioPalette) private var palette
    @State private var outcome: StoreManager.RestoreOutcome?

    var body: some View {
        Button {
            Funnel.restoreTapped()
            onRestoreStarted?()
            Task {
                guard let result = await storeManager.restorePurchases(for: packId) else { return }
                if result == .accessAvailable, let onRestored {
                    onRestored()
                } else {
                    outcome = result
                }
            }
        } label: {
            HStack {
                if storeManager.isRestoring {
                    ProgressView()
                        .tint(palette.muted)
                        .accessibilityHidden(true)
                    Text("Restoring Purchases…")
                } else {
                    Text("Restore Purchases")
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(palette.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isRestoring)
        .accessibilityIdentifier("store-restore-purchases")
        .alert(item: $outcome) { result in
            Alert(title: Text("Restore Purchases"), message: message(for: result))
        }
    }

    private func message(for result: StoreManager.RestoreOutcome) -> Text {
        switch result {
        case .accessAvailable:
            return Text("Your available purchases are up to date.")
        case .noActivePurchases:
            return Text("No active HandStrudel purchases were found. Check that you’re using the Apple Account you bought them with.")
        case .requestedItemUnavailable:
            return Text("Your available purchases are up to date, but they don’t include this item.")
        case .cancelled:
            return Text("Restore was canceled. You can try again whenever you’re ready.")
        case .failed:
            return Text("We couldn’t restore your purchases. Please try again.")
        }
    }
}
