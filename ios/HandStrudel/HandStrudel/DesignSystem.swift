import SwiftUI

// MARK: - HandStrudel Design System
//
// One source of truth for the app's visual language. Direction: clean,
// Apple-native (SF Pro, system Materials, generous whitespace, restrained
// neutrals) with a single expressive element — a music-reactive accent hue.
//
// Rules of thumb:
//  • Color is meaningful, not constant. Neutrals carry structure; the accent
//    marks the live/active/primary thing only.
//  • Surfaces use system Materials for depth instead of flat opacity fills.
//  • Geometry snaps to an 8pt spacing grid and a small radius set.
//  • Type uses SF Pro; monospace is reserved for code + live numerics.

enum DS {

    // MARK: Spacing (8pt grid)
    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner radius
    enum Radius {
        static let chip:    CGFloat = 12
        static let control: CGFloat = 16
        static let card:    CGFloat = 22
        static let sheet:   CGFloat = 28
        static let pill:    CGFloat = 999
    }

    // MARK: Neutrals (dark-only surface system)
    static let textPrimary    = Color.white
    static let textSecondary  = Color.white.opacity(0.60)
    static let textTertiary   = Color.white.opacity(0.38)
    static let textQuaternary = Color.white.opacity(0.22)

    static let separator  = Color.white.opacity(0.10)
    static let hairline   = Color.white.opacity(0.07)
    static let fill       = Color.white.opacity(0.06)   // resting control fill
    static let fillStrong = Color.white.opacity(0.12)

    static let background = Color.black

    // MARK: Reactive accent
    /// Calibrated accent for a given hue (0...1). Saturation/brightness are held
    /// constant so the color stays legible on black at any hue.
    static func accent(_ hue: Double, sat: Double = 0.68, bright: Double = 1.0) -> Color {
        let h = hue.truncatingRemainder(dividingBy: 1.0)
        return Color(hue: h < 0 ? h + 1 : h, saturation: sat, brightness: bright)
    }

    /// Resting hue in the green→cyan region — the brand's "home" color, used
    /// when no music is driving the accent.
    static let signatureHue: Double = 0.43
    static var signature: Color { accent(signatureHue) }
}

// MARK: - Typography (SF Pro)

extension Font {
    static let dsLargeTitle  = Font.system(size: 34, weight: .bold)
    static let dsTitle       = Font.system(size: 26, weight: .bold)
    static let dsTitle2      = Font.system(size: 22, weight: .semibold)
    static let dsTitle3      = Font.system(size: 19, weight: .semibold)
    static let dsHeadline    = Font.system(size: 17, weight: .semibold)
    static let dsBody        = Font.system(size: 15, weight: .regular)
    static let dsCallout     = Font.system(size: 14, weight: .medium)
    static let dsSubheadline = Font.system(size: 13, weight: .medium)
    static let dsFootnote    = Font.system(size: 12, weight: .medium)
    static let dsCaption     = Font.system(size: 11, weight: .medium)
    static let dsCaption2    = Font.system(size: 10, weight: .semibold)

    /// Monospace — code and live numeric readouts only.
    static func dsMono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Surfaces

private struct DSCard: ViewModifier {
    var radius: CGFloat = DS.Radius.card
    var selected: Bool = false
    var accent: Color = DS.signature

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(selected ? accent.opacity(0.14) : Color.white.opacity(0.025))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        selected ? accent.opacity(0.65) : Color.white.opacity(0.08),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    /// Standard elevated card surface (Material + subtle stroke).
    func dsCard(radius: CGFloat = DS.Radius.card,
                selected: Bool = false,
                accent: Color = DS.signature) -> some View {
        modifier(DSCard(radius: radius, selected: selected, accent: accent))
    }
}

// MARK: - Section header (Settings-style)

struct DSSectionHeader: View {
    let title: String
    var accessory: AnyView? = nil

    init(_ title: String) { self.title = title; self.accessory = nil }
    init<A: View>(_ title: String, @ViewBuilder accessory: () -> A) {
        self.title = title
        self.accessory = AnyView(accessory())
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.dsFootnote)
                .tracking(0.6)
                .foregroundColor(DS.textTertiary)
                .textCase(.uppercase)
            Spacer(minLength: 0)
            if let accessory { accessory }
        }
    }
}

// MARK: - Pro badge

struct ProBadge: View {
    var compact: Bool = false
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: compact ? 7 : 8, weight: .bold))
            if !compact {
                Text("PRO")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
            }
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 3 : 3)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
    }
}

// MARK: - Icon tile (App Store / Settings style)
// Elevates an emoji or SF Symbol into an intentional rounded, tinted tile.

struct IconTile: View {
    var emoji: String? = nil
    var symbol: String? = nil
    var tint: Color = DS.signature
    var size: CGFloat = 44
    var glyphSize: CGFloat? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tint.opacity(0.18))
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            if let emoji {
                Text(emoji).font(.system(size: glyphSize ?? size * 0.5))
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: glyphSize ?? size * 0.42, weight: .semibold))
                    .foregroundColor(tint)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Buttons

/// Primary call-to-action — solid accent, dark label.
struct DSPrimaryButtonStyle: ButtonStyle {
    var accent: Color = DS.signature
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsHeadline)
            .foregroundColor(enabled ? .black : DS.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                    .fill(enabled ? accent : Color.white.opacity(0.07))
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary — translucent neutral fill, light label.
struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsCallout)
            .foregroundColor(DS.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Selectable chip (keys, scales, segmented options)

struct DSChip: View {
    let title: String
    let selected: Bool
    var accent: Color = DS.signature
    var locked: Bool = false
    var monospaced: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(monospaced ? .dsMono(13, .semibold) : .system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .black : DS.textSecondary)
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(selected ? accent : Color.white.opacity(0.06))
                )
                .overlay(alignment: .topTrailing) {
                    if locked { ProBadge(compact: true).scaleEffect(0.8).offset(x: 4, y: -6) }
                }
                .opacity(locked ? 0.6 : 1)
        }
    }
}

// MARK: - Ambient reactive accent
// Drives a slow drift through the spectrum on idle screens so the brand stays
// alive without distracting. Wrap only the accent-bearing chrome (title, CTA)
// — not whole scroll views — to keep re-renders cheap.

struct AmbientAccent<Content: View>: View {
    var period: Double = 26   // seconds per full spectrum cycle
    var sat: Double = 0.66
    var bright: Double = 1.0
    @ViewBuilder var content: (Color, Double) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let hue = (t / period).truncatingRemainder(dividingBy: 1.0)
            content(DS.accent(hue, sat: sat, bright: bright), hue)
        }
    }
}

// MARK: - Sheet grabber + scrim helpers

extension View {
    /// Full-bleed black backdrop used by overlays/sheets.
    func dsScreenBackground() -> some View {
        background(DS.background.ignoresSafeArea())
    }
}
