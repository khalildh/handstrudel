import SwiftUI
import UIKit

/// Draws and plays any format 2 instrument (`InstrumentLayout`): every zone
/// from `InstrumentSurfaceGeometry`, lit while touched, pinched or latched,
/// with the instrument's named palette, shape, effect and label style. A
/// multitouch layer on top feeds touches to `InstrumentSurfacePlayer`; hand
/// tracking feeds it through `InstrumentSurfaceModeController`.
struct InstrumentSurfaceView: View {
    @ObservedObject var player: InstrumentSurfacePlayer
    var enabled: Bool
    @Environment(\.studioPalette) private var palette

    var body: some View {
        ZStack {
            if let layout = player.layout {
                TimelineView(.animation(paused: !Self.animates(layout))) { _ in
                    Canvas { context, _ in
                        draw(layout, in: &context, time: player.clock())
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            InstrumentTouchLayer(player: player, enabled: enabled)
        }
    }

    static func animates(_ layout: InstrumentLayout) -> Bool {
        layout.surface.type == .orbs || layout.visuals.effect == .particles || layout.visuals.effect == .ripple
    }

    // MARK: Drawing

    private func draw(_ layout: InstrumentLayout, in context: inout GraphicsContext, time: Double) {
        let geometry = InstrumentSurfaceGeometry(layout: layout, rect: player.playRect)
        guard player.playRect.width > 0 else { return }
        let colors = InstrumentPalette.colors(layout.visuals.palette, studio: palette)
        for index in layout.zones.indices {
            let zone = layout.zones[index]
            let shape = geometry.shape(of: index, time: time)
            let path = Self.path(for: shape, inset: 3)
            let color = colors[InstrumentPalette.colorIndex(for: zone, index: index) % colors.count]
            let since = player.activeZones[index]
            let active = since != nil
            let latched = player.latchedZones.contains(index)

            if active, layout.visuals.effect == .glow {
                context.drawLayer { glow in
                    glow.addFilter(.shadow(color: color.opacity(0.9), radius: 18))
                    glow.fill(path, with: .color(color.opacity(0.7)))
                }
            }
            context.fill(path, with: .color(color.opacity(active ? 0.78 : 0.30)))
            context.stroke(path, with: .color(color.opacity(active ? 1 : 0.7)),
                           style: StrokeStyle(lineWidth: latched ? 4 : (active ? 2.5 : 1.5), dash: latched ? [6, 4] : []))
            if zone.hasOctaveBands { drawBands(shape, in: &context, color: .white.opacity(0.35)) }
            if let since, layout.visuals.effect == .ripple { drawRipple(shape, since: since, time: time, color: color, in: &context) }
            if let since, layout.visuals.effect == .particles { drawParticles(shape, since: since, time: time, color: color, in: &context) }
            if zone.role == .expression { drawExpressionHint(shape, zone: zone, in: &context) }

            let label = InstrumentMusic.label(for: zone, style: layout.visuals.labels,
                                              heldChordDegree: player.heldChordDegree, player.context)
            if !label.isEmpty {
                let size: CGFloat = min(20, max(11, shape.minimumSide * 0.28))
                let text = Text(label).font(.system(size: size, weight: .bold, design: .rounded)).foregroundColor(.white)
                context.drawLayer { labelLayer in
                    labelLayer.addFilter(.shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1))
                    labelLayer.draw(text, at: shape.anchor)
                }
            }
        }
        for (_, point) in player.handCursors {
            let ring = Path(ellipseIn: CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28))
            context.stroke(ring, with: .color(.white.opacity(0.9)), lineWidth: 2.5)
        }
    }

    static func path(for shape: ZoneShape, inset: CGFloat) -> Path {
        switch shape {
        case .rect(let rect, let corner):
            let box = rect.insetBy(dx: min(inset, rect.width / 4), dy: min(inset, rect.height / 4))
            return Path(roundedRect: box, cornerRadius: min(corner, min(box.width, box.height) / 2))
        case .circle(let center, let radius):
            let r = max(1, radius - inset)
            return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        case .wedge(let center, let inner, let outer, let start, let end):
            return wedgePath(center: center, inner: inner + inset, outer: outer - inset,
                             start: start + Double(inset / max(1, outer)), end: end - Double(inset / max(1, outer)))
        }
    }

    private static func wedgePath(center: CGPoint, inner: CGFloat, outer: CGFloat, start: Double, end: Double) -> Path {
        // ZoneShape angles run clockwise from up; SwiftUI's from +x.
        let from = Angle(radians: start - .pi / 2), to = Angle(radians: end - .pi / 2)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: from, endAngle: to, clockwise: false)
        path.addArc(center: center, radius: max(0, inner), startAngle: to, endAngle: from, clockwise: true)
        path.closeSubpath()
        return path
    }

    private func drawBands(_ shape: ZoneShape, in context: inout GraphicsContext, color: Color) {
        let fraction = InstrumentSurfaceGeometry.bandFraction
        var lines = Path()
        switch shape {
        case .rect, .circle:
            let box = shape.bounds
            for y in [box.minY + box.height * fraction, box.maxY - box.height * fraction] {
                lines.move(to: CGPoint(x: box.minX + 8, y: y))
                lines.addLine(to: CGPoint(x: box.maxX - 8, y: y))
            }
        case .wedge(let center, let inner, let outer, let start, let end):
            for radius in [inner + (outer - inner) * fraction, outer - (outer - inner) * fraction] {
                lines.addArc(center: center, radius: radius, startAngle: .radians(start - .pi / 2 + 0.03),
                             endAngle: .radians(end - .pi / 2 - 0.03), clockwise: false)
                lines.move(to: ZoneShape.point(center, outer - (outer - inner) * fraction, end))
            }
        }
        context.stroke(lines, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
    }

    private func drawRipple(_ shape: ZoneShape, since: Double, time: Double, color: Color, in context: inout GraphicsContext) {
        let progress = CGFloat((time - since).truncatingRemainder(dividingBy: 1.1) / 1.1)
        let radius = 10 + progress * shape.minimumSide * 0.7
        let anchor = shape.anchor
        let ring = Path(ellipseIn: CGRect(x: anchor.x - radius, y: anchor.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(ring, with: .color(color.opacity(Double(1 - progress))), lineWidth: 3)
    }

    private func drawParticles(_ shape: ZoneShape, since: Double, time: Double, color: Color, in context: inout GraphicsContext) {
        let anchor = shape.anchor
        let reach = shape.minimumSide * 0.6
        for particle in 0..<10 {
            let seed = Double(particle) * 0.618
            let life = ((time - since) * 0.9 + seed).truncatingRemainder(dividingBy: 1)
            let angle = seed * 2 * .pi * 1.7 + since
            let distance = CGFloat(life) * reach
            let point = CGPoint(x: anchor.x + distance * CGFloat(cos(angle)), y: anchor.y + distance * CGFloat(sin(angle)))
            let size = 3 + 3 * CGFloat(1 - life)
            context.fill(Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)),
                         with: .color(color.opacity(1 - life)))
        }
    }

    private func drawExpressionHint(_ shape: ZoneShape, zone: InstrumentLayout.Zone, in context: inout GraphicsContext) {
        let box = shape.bounds
        let axis = zone.axis ?? (box.width >= box.height ? .x : .y)
        var arrow = Path()
        if axis == .x {
            arrow.move(to: CGPoint(x: box.minX + 12, y: box.maxY - 12))
            arrow.addLine(to: CGPoint(x: box.maxX - 12, y: box.maxY - 12))
        } else {
            arrow.move(to: CGPoint(x: box.maxX - 12, y: box.maxY - 12))
            arrow.addLine(to: CGPoint(x: box.maxX - 12, y: box.minY + 12))
        }
        context.stroke(arrow, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
    }
}

// MARK: - Named palettes

/// The fixed palettes an instrument can name. Zones draw as tinted glass with
/// white labels over the camera, so each palette reads in every studio theme;
/// `theme` takes the studio theme's own accents.
enum InstrumentPalette {
    static func colors(_ palette: InstrumentLayout.Visuals.Palette, studio: StudioPalette) -> [Color] {
        switch palette {
        case .theme: return [studio.accent, studio.overtone, studio.mediaAccent, studio.ink]
        case .aurora: return ([0x7CF5C8, 0x5EC8FF, 0xA88BFF, 0xFF8BD8, 0x9DFF8B] as [UInt32]).map(hex)
        case .ember: return ([0xFF8A3D, 0xFF5A5F, 0xFFC857, 0xE84A7F, 0xFFA07A] as [UInt32]).map(hex)
        case .ocean: return ([0x3DA5FF, 0x2EE6D6, 0x6C7BFF, 0x8FE3FF, 0x4FD1A5] as [UInt32]).map(hex)
        case .candy: return ([0xFF7AC6, 0xFFD36E, 0x7AE7FF, 0xB7FF7A, 0xC79BFF] as [UInt32]).map(hex)
        case .mono: return ([0xF2F2F2, 0xC8C8C8] as [UInt32]).map(hex)
        }
    }

    private static func hex(_ rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    /// Notes colour by scale degree and chords by progression slot, so the
    /// same musical role looks the same on every surface.
    static func colorIndex(for zone: InstrumentLayout.Zone, index: Int) -> Int {
        switch zone.role {
        case .note: return zone.degree ?? index
        case .chord: return zone.slot ?? index
        case .chordTone: return zone.tone ?? index
        case .drum: return InstrumentLayout.Drum.allCases.firstIndex(of: zone.drum ?? .kick) ?? index
        case .expression: return index
        }
    }
}

// MARK: - Touch

struct InstrumentTouchLayer: UIViewRepresentable {
    let player: InstrumentSurfacePlayer
    let enabled: Bool

    func makeUIView(context: Context) -> InstrumentTouchView {
        let view = InstrumentTouchView()
        view.player = player
        return view
    }

    func updateUIView(_ view: InstrumentTouchView, context: Context) {
        view.player = player
        view.enabled = enabled
        if !enabled { view.liftAll() }
        view.updatePlayRect()
    }
}

/// Multitouch: each finger is a contact that plays the zone under it and
/// re-plays when it slides into another zone.
final class InstrumentTouchView: UIView {
    weak var player: InstrumentSurfacePlayer?
    var enabled = true
    private var touchIDs: [ObjectIdentifier: String] = [:]
    private var nextTouch = 0
    private var zoneElements: [InstrumentZoneElement] = []
    private var elementsKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The play area: the screen minus the studio's top bar, its status line
    /// ("Camera off") and the bottom controls.
    static func playRect(bounds: CGRect, safeArea: UIEdgeInsets) -> CGRect {
        bounds.inset(by: UIEdgeInsets(top: safeArea.top + 96, left: 14, bottom: safeArea.bottom + 140, right: 14))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePlayRect()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updatePlayRect()
    }

    func updatePlayRect() {
        guard let player, bounds.width > 0 else { return }
        let rect = Self.playRect(bounds: bounds, safeArea: window?.safeAreaInsets ?? safeAreaInsets)
        guard player.playRect != rect else { return }
        DispatchQueue.main.async { player.playRect = rect }
    }

    /// Only the play area takes touches, so the studio's controls keep theirs.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let player, player.layout != nil else { return false }
        return player.playRect.contains(point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard enabled, let player else { return }
        for touch in touches {
            nextTouch += 1
            let id = "touch\(nextTouch)"
            touchIDs[ObjectIdentifier(touch)] = id
            player.begin(id, at: touch.location(in: self))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let player else { return }
        for touch in touches {
            guard let id = touchIDs[ObjectIdentifier(touch)] else { continue }
            player.move(id, to: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }

    private func lift(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let id = touchIDs.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            player?.end(id)
        }
    }

    func liftAll() {
        for id in touchIDs.values { player?.end(id) }
        touchIDs = [:]
    }

    // MARK: Accessibility: one element per zone, for VoiceOver and UI tests.

    override var isAccessibilityElement: Bool { get { false } set {} }

    override var accessibilityElements: [Any]? {
        get {
            guard let player, let instrument = player.instrument, let layout = player.layout else { return [] }
            let key = "\(instrument.id)-\(layout.zones.count)"
            if key != elementsKey {
                elementsKey = key
                zoneElements = layout.zones.indices.map { InstrumentZoneElement(container: self, index: $0) }
            }
            return zoneElements
        }
        set {}
    }

    fileprivate func zoneInfo(_ index: Int) -> (frame: CGRect, label: String, value: String)? {
        guard let player, let layout = player.layout, let geometry = player.geometry,
              layout.zones.indices.contains(index) else { return nil }
        let zone = layout.zones[index]
        let shape = geometry.shape(of: index, time: player.clock())
        let side = min(44, shape.minimumSide * 0.6)
        let anchor = shape.anchor
        let box = CGRect(x: anchor.x - side / 2, y: anchor.y - side / 2, width: side, height: side)
        var label = InstrumentMusic.label(for: zone, style: .notes, heldChordDegree: player.heldChordDegree, player.context)
        if label.isEmpty { label = zone.role.rawValue }
        let value = InstrumentMusic.soundDescription(for: zone, heldChordDegree: player.heldChordDegree, player.context)
        return (UIAccessibility.convertToScreenCoordinates(box, in: self), label, value)
    }
}

/// A zone as an accessibility element; its frame follows moving orbs.
private final class InstrumentZoneElement: UIAccessibilityElement {
    private weak var view: InstrumentTouchView?
    private let index: Int

    init(container: InstrumentTouchView, index: Int) {
        view = container
        self.index = index
        super.init(accessibilityContainer: container)
        accessibilityIdentifier = "surface-zone-\(index)"
        accessibilityTraits = .button
    }

    override var accessibilityFrame: CGRect {
        get { view?.zoneInfo(index)?.frame ?? .zero }
        set {}
    }

    override var accessibilityLabel: String? {
        get { view?.zoneInfo(index)?.label }
        set {}
    }

    override var accessibilityValue: String? {
        get { view?.zoneInfo(index)?.value }
        set {}
    }
}

#if DEBUG
/// UI tests read the notes and hits sent to the engine here (`--uitesting` only).
struct EngineNoteLogProbe: View {
    @ObservedObject private var log = EngineNoteLog.shared

    var body: some View {
        if EngineNoteLog.enabled {
            Text(" ")
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("engine-note-log")
                .accessibilityLabel(log.entries.joined(separator: " "))
                .allowsHitTesting(false)
        }
    }
}
#endif
