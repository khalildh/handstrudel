import CoreGraphics
import Foundation

/// The area one zone covers on screen. Angles are radians clockwise from
/// straight up.
enum ZoneShape: Equatable {
    case rect(CGRect, corner: CGFloat)
    case circle(center: CGPoint, radius: CGFloat)
    case wedge(center: CGPoint, inner: CGFloat, outer: CGFloat, start: Double, end: Double)

    func contains(_ point: CGPoint) -> Bool {
        switch self {
        case .rect(let rect, _):
            return rect.contains(point)
        case .circle(let center, let radius):
            return hypot(point.x - center.x, point.y - center.y) <= radius
        case .wedge(let center, let inner, let outer, let start, let end):
            let dx = point.x - center.x, dy = point.y - center.y
            let distance = hypot(dx, dy)
            guard distance >= inner, distance <= outer else { return false }
            return Self.angleOffset(Self.angle(dx: dx, dy: dy), from: start) <= end - start
        }
    }

    var bounds: CGRect {
        switch self {
        case .rect(let rect, _):
            return rect
        case .circle(let center, let radius):
            return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case .wedge(let center, let inner, let outer, let start, let end):
            var points = [Self.point(center, outer, start), Self.point(center, outer, end),
                          Self.point(center, inner, start), Self.point(center, inner, end)]
            // Include the extreme points the arc sweeps past.
            for quarter in stride(from: 0.0, through: 2 * .pi, by: .pi / 2)
            where Self.angleOffset(quarter, from: start) <= end - start {
                points.append(Self.point(center, outer, quarter))
            }
            let xs = points.map(\.x), ys = points.map(\.y)
            return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        }
    }

    /// Where the label goes; always inside the zone, in its middle band.
    var anchor: CGPoint {
        switch self {
        case .rect(let rect, _): return CGPoint(x: rect.midX, y: rect.midY)
        case .circle(let center, _): return center
        case .wedge(let center, let inner, let outer, let start, let end):
            return Self.point(center, (inner + outer) / 2, (start + end) / 2)
        }
    }

    /// The smallest dimension a finger has to land in.
    var minimumSide: CGFloat {
        switch self {
        case .rect(let rect, _): return min(rect.width, rect.height)
        case .circle(_, let radius): return radius * 2
        case .wedge(_, let inner, let outer, let start, let end):
            return min(outer - inner, (inner + outer) / 2 * CGFloat(end - start))
        }
    }

    /// The length octave bands split: height for rects and circles, ring depth for wedges.
    var bandedExtent: CGFloat {
        switch self {
        case .rect(let rect, _): return rect.height
        case .circle(_, let radius): return radius * 2
        case .wedge(_, let inner, let outer, _, _): return outer - inner
        }
    }

    /// Octave band at a point inside the zone: +1 in the top (outer) band,
    /// −1 in the bottom (inner) band, 0 in the middle.
    func octaveBand(at point: CGPoint) -> Int {
        let fraction: CGFloat
        switch self {
        case .rect, .circle:
            let box = bounds
            fraction = box.height > 0 ? 1 - (point.y - box.minY) / box.height : 0.5
        case .wedge(let center, let inner, let outer, _, _):
            fraction = (hypot(point.x - center.x, point.y - center.y) - inner) / max(1, outer - inner)
        }
        if fraction >= 1 - InstrumentSurfaceGeometry.bandFraction { return 1 }
        if fraction < InstrumentSurfaceGeometry.bandFraction { return -1 }
        return 0
    }

    /// Value 0…1 along an axis of the zone (x: left → right, y: bottom → top).
    func value(at point: CGPoint, axis: InstrumentLayout.Axis) -> Double {
        let box = bounds
        switch axis {
        case .x: return box.width > 0 ? Double(min(1, max(0, (point.x - box.minX) / box.width))) : 0.5
        case .y: return box.height > 0 ? Double(min(1, max(0, (box.maxY - point.y) / box.height))) : 0.5
        }
    }

    /// The shape grown by `amount` points on every side.
    func expanded(by amount: CGFloat) -> ZoneShape {
        switch self {
        case .rect(let rect, let corner): return .rect(rect.insetBy(dx: -amount, dy: -amount), corner: corner)
        case .circle(let center, let radius): return .circle(center: center, radius: radius + amount)
        case .wedge: return self
        }
    }

    /// True when the two shapes share area (touching edges don't count).
    func overlaps(_ other: ZoneShape) -> Bool {
        let tolerance: CGFloat = 0.5
        switch (self, other) {
        case (.rect(let a, _), .rect(let b, _)):
            let common = a.intersection(b)
            return !common.isNull && common.width > tolerance && common.height > tolerance
        case (.circle(let a, let ra), .circle(let b, let rb)):
            return hypot(a.x - b.x, a.y - b.y) < ra + rb - tolerance
        case (.circle(let center, let radius), .rect(let rect, _)), (.rect(let rect, _), .circle(let center, let radius)):
            let nearest = CGPoint(x: min(rect.maxX, max(rect.minX, center.x)), y: min(rect.maxY, max(rect.minY, center.y)))
            return hypot(nearest.x - center.x, nearest.y - center.y) < radius - tolerance
        default:
            return bounds.intersection(other.bounds).width > tolerance
        }
    }

    static func angle(dx: CGFloat, dy: CGFloat) -> Double { Double(atan2(dx, -dy)) }

    static func angleOffset(_ angle: Double, from start: Double) -> Double {
        let turn = 2 * Double.pi
        let offset = (angle - start).truncatingRemainder(dividingBy: turn)
        return offset < 0 ? offset + turn : offset
    }

    static func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(sin(angle)), y: center.y - radius * CGFloat(cos(angle)))
    }
}

/// A zone under a point, with the octave band it was hit in.
struct InstrumentHit: Equatable, Hashable {
    let zone: Int
    let octave: Int
}

/// Where every zone of a layout sits inside a play area, at a moment in time
/// (orbs move). Touch, hand tracking, drawing and the loader's playability
/// rules all use this one geometry.
struct InstrumentSurfaceGeometry {
    /// The smallest play area the rules are checked against (an iPhone mini in
    /// portrait, minus the studio's top bar, status line and controls), in points.
    static let referenceRect = CGRect(x: 0, y: 0, width: 340, height: 480)
    /// Apple's minimum comfortable touch target.
    static let minimumZoneSide: CGFloat = 44
    /// Share of a banded zone that plays an octave up (top) or down (bottom).
    static let bandFraction: CGFloat = 0.28

    let layout: InstrumentLayout
    let rect: CGRect

    var surface: InstrumentLayout.Surface { layout.surface }

    func shapes(time: Double = 0) -> [ZoneShape] {
        layout.zones.indices.map { shape(of: $0, time: time) }
    }

    func shape(of index: Int, time: Double = 0) -> ZoneShape {
        let count = layout.zones.count
        let corner = cornerRadius
        switch surface.type {
        case .grid:
            let columns = max(1, surface.columns ?? 4), rows = max(1, surface.rows ?? 3)
            let width = rect.width / CGFloat(columns), height = rect.height / CGFloat(rows)
            let cell = CGRect(x: rect.minX + CGFloat(index % columns) * width,
                              y: rect.minY + CGFloat(index / columns) * height, width: width, height: height)
            return layout.visuals.shape == .round
                ? .circle(center: CGPoint(x: cell.midX, y: cell.midY), radius: min(width, height) / 2)
                : .rect(cell, corner: corner)
        case .keys, .strips:
            if surface.orientation == .vertical {
                // Low to high from the bottom.
                let height = rect.height / CGFloat(count)
                return .rect(CGRect(x: rect.minX, y: rect.maxY - CGFloat(index + 1) * height,
                                    width: rect.width, height: height), corner: corner)
            }
            let width = rect.width / CGFloat(count)
            return .rect(CGRect(x: rect.minX + CGFloat(index) * width, y: rect.minY,
                                width: width, height: rect.height), corner: corner)
        case .radial:
            let radius: CGFloat = min(rect.width, rect.height) / 2
            let span: Double = 2 * Double.pi / Double(count)
            let inner: CGFloat = radius * CGFloat(surface.innerRadius ?? 0.35)
            let outer: CGFloat = radius * CGFloat(surface.outerRadius ?? 1)
            let start: Double = Double(index) * span
            return .wedge(center: CGPoint(x: rect.midX, y: rect.midY), inner: inner, outer: outer,
                          start: start, end: start + span)
        case .arc:
            let radius: CGFloat = Self.arcRadius(in: rect)
            let first: Double = (surface.startAngle ?? -70) * Double.pi / 180
            let last: Double = (surface.endAngle ?? 70) * Double.pi / 180
            let span: Double = (last - first) / Double(count)
            let inner: CGFloat = radius * CGFloat(surface.innerRadius ?? 0.45)
            let outer: CGFloat = radius * CGFloat(surface.outerRadius ?? 1)
            let start: Double = first + Double(index) * span
            return .wedge(center: CGPoint(x: rect.midX, y: rect.maxY), inner: inner, outer: outer,
                          start: start, end: start + span)
        case .pads, .orbs:
            let zone = layout.zones[index]
            let frame = zone.frame ?? .init(x: 0, y: 0, w: 0, h: 0)
            var box = CGRect(x: rect.minX + CGFloat(frame.x) * rect.width, y: rect.minY + CGFloat(frame.y) * rect.height,
                             width: CGFloat(frame.w) * rect.width, height: CGFloat(frame.h) * rect.height)
            if surface.type == .orbs {
                let motion = orbMotion(index: index, time: time)
                box = box.offsetBy(dx: motion.offset.x, dy: motion.offset.y).insetBy(dx: -motion.swell, dy: -motion.swell)
            }
            let round = (zone.shape ?? (layout.visuals.shape == .round || surface.type == .orbs ? .round : .rounded)) == .round
            return round
                ? .circle(center: CGPoint(x: box.midX, y: box.midY), radius: min(box.width, box.height) / 2)
                : .rect(box, corner: corner)
        }
    }

    /// The zone under a point, if any. A tracked hand only plays zones meant
    /// for it (or for either hand); touch passes no hand and plays them all.
    func hit(_ point: CGPoint, time: Double = 0, hand: InstrumentLayout.Hand? = nil) -> InstrumentHit? {
        for index in layout.zones.indices.reversed() {
            let zone = layout.zones[index]
            if let hand, zone.resolvedHand != .any, zone.resolvedHand != hand { continue }
            let shape = shape(of: index, time: time)
            guard shape.contains(point) else { continue }
            return InstrumentHit(zone: index, octave: zone.hasOctaveBands ? shape.octaveBand(at: point) : 0)
        }
        return nil
    }

    // MARK: Orb motion

    /// How far an orb has drifted (points) and swelled (points per side) at `time`.
    func orbMotion(index: Int, time: Double) -> (offset: CGPoint, swell: CGFloat) {
        let reach = CGFloat(surface.amount ?? 0) * min(rect.width, rect.height)
        let period = max(0.5, surface.period ?? 8)
        let phase = 2 * Double.pi * time / period + Double(index) * 2.399
        switch surface.motion ?? .drift {
        case .drift:
            return (CGPoint(x: reach * CGFloat(sin(phase)), y: reach * CGFloat(cos(phase * 0.83))), 0)
        case .pulse:
            return (.zero, reach * CGFloat(sin(phase)))
        }
    }

    /// Every place an orb can reach while it moves.
    func envelope(of index: Int) -> ZoneShape {
        guard surface.type == .orbs else { return shape(of: index) }
        let resting = withoutMotion.shape(of: index)
        let reach = CGFloat(surface.amount ?? 0) * min(rect.width, rect.height)
        let grow: CGFloat
        switch surface.motion ?? .drift {
        case .drift: grow = reach * 1.415
        case .pulse: grow = reach
        }
        return resting.expanded(by: grow)
    }

    private var withoutMotion: InstrumentSurfaceGeometry {
        var still = layout
        still.surface.amount = 0
        return InstrumentSurfaceGeometry(layout: still, rect: rect)
    }

    // MARK: Playability checks (on the reference play area)

    func hasOverlappingZones() -> Bool {
        let envelopes = layout.zones.indices.map { envelope(of: $0) }
        for i in envelopes.indices {
            for j in envelopes.indices where j > i && envelopes[i].overlaps(envelopes[j]) { return true }
        }
        return false
    }

    func bandedExtent(of index: Int) -> CGFloat? {
        guard layout.zones.indices.contains(index) else { return nil }
        return withoutMotion.shape(of: index).bandedExtent
    }

    /// How many zones a laid-out surface holds before they shrink below the
    /// minimum size on the reference play area. Free surfaces aren't limited here.
    static func capacity(of surface: InstrumentLayout.Surface) -> Int {
        let rect = referenceRect
        let side = Double(minimumZoneSide)
        switch surface.type {
        case .grid:
            return (surface.rows ?? 3) * (surface.columns ?? 4)
        case .keys, .strips:
            let length = surface.orientation == .vertical ? rect.height : rect.width
            return Int(Double(length) / side)
        case .radial:
            let radius = Double(min(rect.width, rect.height) / 2)
            let middle = ((surface.innerRadius ?? 0.35) + (surface.outerRadius ?? 1)) / 2 * radius
            return max(1, Int(2 * .pi * middle / side))
        case .arc:
            let radius = Double(arcRadius(in: rect))
            let middle = ((surface.innerRadius ?? 0.45) + (surface.outerRadius ?? 1)) / 2 * radius
            let span = ((surface.endAngle ?? 70) - (surface.startAngle ?? -70)) * .pi / 180
            return max(1, Int(span * middle / side))
        case .pads, .orbs:
            return Int.max
        }
    }

    /// An arc fans up from the bottom centre of the play area.
    static func arcRadius(in rect: CGRect) -> CGFloat { min(rect.width / 2, rect.height) }

    private var cornerRadius: CGFloat {
        switch layout.visuals.shape {
        case .square: return 4
        case .rounded, .round: return 14
        }
    }
}
