import SwiftUI

/// Radial chord+melody overlay — a single wheel centered on screen, sized to
/// be easy to read on a phone.
///
/// Both hands share one wheel: the **outer ring** is the harmony (chord hand)
/// and the **inner ring** is the melody (melody hand), with a rest zone in the
/// hole at the center. Each hand selects by *angle* — rest in the middle, then
/// reach out toward any wedge — so any chord/note is one direct move away. Keys
/// are lettered (chord names on the outside, note names on the inside).
///
/// All highlights are driven by state the manager publishes (`currentChordZone`,
/// `melodyLane`, resting), so the wheel always agrees with the audio.
struct RadialChordMelodyOverlayView: View {
    /// Scale degrees per chord wedge — used only for the per-degree colors.
    let zoneDegrees: [Int]
    /// Lettered chord names per wedge (e.g. "Cmaj", "Am"), length == zoneDegrees.
    let chordNames: [String]
    /// Currently hovered chord wedge (0..<chordNames.count).
    let currentChordZone: Int?
    /// Whether the chord hand is pinching (chord actively struck).
    let chordHandPinching: Bool
    /// Chord hand is in the center rest zone (holding, not selecting).
    let chordResting: Bool
    /// Chord display name shown in the wheel's center.
    let currentChordName: String
    /// Lettered note names per melody wedge (e.g. "C", "E", "G").
    let melodyNames: [String]
    /// Melody hand's current wedge (0..<melodyNames.count).
    let melodyLane: Int?
    /// Whether the melody hand is pinching.
    let melodyHandPinching: Bool
    /// Melody hand is in the center rest zone.
    let melodyResting: Bool

    private var zoneCount: Int { max(1, chordNames.count) }
    private var melodyCount: Int { max(1, melodyNames.count) }

    // Geometry mirrors ChordMelodyModeManager so the drawn wheel lines up with
    // the angle/radius math that selects wedges.
    private let radiusFraction = CGFloat(ChordMelodyModeManager.radialRadiusFraction)
    private let deadzoneFraction = CGFloat(ChordMelodyModeManager.radialDeadzone)
    /// Boundary between the inner melody ring and the outer chord ring.
    private let ringSplitFraction: CGFloat = 0.60

    var body: some View {
        GeometryReader { geo in
            let outerR = min(geo.size.width, geo.size.height) / 2 * radiusFraction
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let deadR = outerR * deadzoneFraction
            let splitR = outerR * ringSplitFraction

            ZStack {
                melodyRing(center: center, innerR: deadR, outerR: splitR)
                chordRing(center: center, innerR: splitR, outerR: outerR)
                restHole(center: center, radius: deadR)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Chord (outer) ring

    @ViewBuilder
    private func chordRing(center: CGPoint, innerR: CGFloat, outerR: CGFloat) -> some View {
        let wedge = 360.0 / Double(zoneCount)
        ZStack {
            ForEach(0..<zoneCount, id: \.self) { i in
                let degree = degreeForZone(i)
                let color = colorForDegree(degree)
                let isCurrent = currentChordZone == i && !chordResting
                let isHeld = isCurrent && chordHandPinching
                let start = Angle(degrees: Double(i) * wedge - wedge / 2)
                let end = Angle(degrees: Double(i) * wedge + wedge / 2)

                wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
                    .fill(fillStyle(color: color, isCurrent: isCurrent, isHeld: isHeld))
                    .overlay(
                        wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
                            .stroke(
                                isHeld ? color.opacity(0.95) :
                                isCurrent ? color.opacity(0.6) :
                                Color.white.opacity(0.1),
                                lineWidth: isHeld ? 2.5 : (isCurrent ? 1.5 : 1)
                            )
                    )
                    .shadow(color: isHeld ? color.opacity(0.5) : .clear, radius: 12)

                Text(chordLabel(i))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(isCurrent ? .white : .white.opacity(0.7))
                    .shadow(color: .black.opacity(0.6), radius: 3)
                    .position(polar(center: center, angleDeg: Double(i) * wedge, radius: (innerR + outerR) / 2))
            }
        }
    }

    // MARK: - Melody (inner) ring

    @ViewBuilder
    private func melodyRing(center: CGPoint, innerR: CGFloat, outerR: CGFloat) -> some View {
        let wedge = 360.0 / Double(melodyCount)
        ZStack {
            ForEach(0..<melodyCount, id: \.self) { i in
                let isCurrent = melodyLane == i && !melodyResting
                let isHeld = isCurrent && melodyHandPinching
                let start = Angle(degrees: Double(i) * wedge - wedge / 2)
                let end = Angle(degrees: Double(i) * wedge + wedge / 2)

                wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
                    .fill(
                        isHeld ? Color.cyan.opacity(0.45) :
                        isCurrent ? Color.cyan.opacity(0.2) :
                        Color.white.opacity(0.05)
                    )
                    .overlay(
                        wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
                            .stroke(
                                isHeld ? Color.cyan.opacity(0.85) :
                                isCurrent ? Color.cyan.opacity(0.45) :
                                Color.white.opacity(0.08),
                                lineWidth: isHeld ? 2.5 : 1
                            )
                    )
                    .shadow(color: isHeld ? .cyan.opacity(0.4) : .clear, radius: 6)

                Text(melodyLabel(i))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isCurrent ? .white : .cyan.opacity(0.75))
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .position(polar(center: center, angleDeg: Double(i) * wedge, radius: (innerR + outerR) / 2))
            }
        }
    }

    // MARK: - Center

    /// The rest hole: the chord currently sounding, on a disc that brightens
    /// when either hand is parked there (confirming "you're holding, reach out
    /// to pick").
    private func restHole(center: CGPoint, radius: CGFloat) -> some View {
        let resting = chordResting || melodyResting
        return ZStack {
            Circle()
                .fill(resting ? Color.green.opacity(0.16) : Color.black.opacity(0.25))
                .overlay(
                    Circle().stroke(resting ? Color.green.opacity(0.6) : Color.white.opacity(0.15),
                                    lineWidth: resting ? 2 : 1)
                )
            if !currentChordName.isEmpty {
                Text(currentChordName)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: chordHandPinching ? [.green, .cyan] : [.white.opacity(0.8), .white.opacity(0.5)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .position(center)
        .animation(.easeOut(duration: 0.15), value: currentChordName)
    }

    // MARK: - Helpers

    private func chordLabel(_ i: Int) -> String {
        guard i >= 0, i < chordNames.count else { return "" }
        return chordNames[i]
    }

    private func melodyLabel(_ i: Int) -> String {
        guard i >= 0, i < melodyNames.count else { return "" }
        return melodyNames[i]
    }

    private func degreeForZone(_ index: Int) -> Int {
        guard !zoneDegrees.isEmpty else { return 0 }
        let safe = max(0, min(zoneDegrees.count - 1, index))
        return zoneDegrees[safe]
    }

    private func fillStyle(color: Color, isCurrent: Bool, isHeld: Bool) -> some ShapeStyle {
        if isHeld { return AnyShapeStyle(color.opacity(0.5)) }
        if isCurrent { return AnyShapeStyle(color.opacity(0.28)) }
        return AnyShapeStyle(Color.white.opacity(0.05))
    }

    private func wedgeShape(center: CGPoint, innerR: CGFloat, outerR: CGFloat, start: Angle, end: Angle) -> RadialWedge {
        RadialWedge(center: center, innerRadius: innerR, outerRadius: outerR, startAngle: start, endAngle: end)
    }

    private func polar(center: CGPoint, angleDeg: Double, radius: CGFloat) -> CGPoint {
        let r = angleDeg * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(sin(r)),
                       y: center.y - radius * CGFloat(cos(r)))
    }

    private func colorForDegree(_ degree: Int) -> Color {
        switch degree {
        case 0: return .green
        case 1: return Color(red: 0.6, green: 0.5, blue: 0.9)
        case 2: return Color(red: 0.7, green: 0.6, blue: 0.9)
        case 3: return Color(red: 0.4, green: 0.8, blue: 0.9)
        case 4: return .pink
        case 5: return Color(red: 0.9, green: 0.6, blue: 0.4)
        case 6: return Color(red: 0.9, green: 0.4, blue: 0.4)
        default: return .gray
        }
    }
}

/// A ring segment (annular wedge) between two radii and two angles, where
/// angles are measured **clockwise from 12 o'clock** to match
/// `ChordMelodyModeManager`'s radial math. Drawn in absolute coordinates from
/// `center`, so it ignores the layout rect.
private struct RadialWedge: Shape {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 28
        let startDeg = startAngle.degrees
        let endDeg = endAngle.degrees

        func point(_ deg: Double, _ radius: CGFloat) -> CGPoint {
            let r = deg * .pi / 180
            return CGPoint(x: center.x + radius * CGFloat(sin(r)),
                           y: center.y - radius * CGFloat(cos(r)))
        }

        for i in 0...steps {
            let t = startDeg + (endDeg - startDeg) * Double(i) / Double(steps)
            let pt = point(t, outerRadius)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        for i in 0...steps {
            let t = endDeg - (endDeg - startDeg) * Double(i) / Double(steps)
            path.addLine(to: point(t, innerRadius))
        }
        path.closeSubpath()
        return path
    }
}
