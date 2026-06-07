import SwiftUI

/// Radial chord+melody overlay.
///
/// Instead of the linear half-screen strips of `ChordMelodyOverlayView`, each
/// hand drives a centered *wheel*. The hand rests in the middle (the deadzone
/// hole) and reaches out toward a wedge to pick a chord (chord hand) or a note
/// (melody hand) — so any chord/note is one direct move away, with no need to
/// sweep across every value in between. The chord wheel has two rings: the
/// inner ring is the base octave, the outer ring jumps the chord up an octave.
///
/// All highlights are driven by state the manager publishes (`currentChordZone`,
/// `melodyLane`, octave, resting), so the wheels always agree with the audio.
struct RadialChordMelodyOverlayView: View {
    /// Scale degrees per wedge — drives both the wedge count and the Roman
    /// numeral label, exactly like the grid overlay.
    let zoneDegrees: [Int]
    /// Currently hovered chord wedge (0..<zoneDegrees.count).
    let currentChordZone: Int?
    /// Whether the chord hand is pinching (chord actively struck).
    let chordHandPinching: Bool
    /// Chord hand is in the center rest zone (holding, not selecting).
    let chordResting: Bool
    /// Octave shift from the chord wheel ring: 0 (inner) or +1 (outer).
    let currentOctaveShift: Int
    /// Chord display name (e.g. "Cmaj") shown above the wheels.
    let currentChordName: String
    /// Melody hand's current wedge (0..<melodyLaneCount).
    let melodyLane: Int?
    /// Whether the melody hand is pinching.
    let melodyHandPinching: Bool
    /// Melody hand is in the center rest zone.
    let melodyResting: Bool
    /// Number of melody wedges (chord tones expanded across octaves).
    let melodyLaneCount: Int
    /// `true` = chord wheel on the right, melody on the left (swap mode).
    let swapHands: Bool

    private var zoneCount: Int { max(1, zoneDegrees.count) }
    private var chordsOnLeft: Bool { !swapHands }

    // Geometry mirrors ChordMelodyModeManager so the drawn wheel lines up with
    // the angle/radius math that selects wedges.
    private let radiusFraction = CGFloat(ChordMelodyModeManager.radialRadiusFraction)
    private let deadzoneFraction = CGFloat(ChordMelodyModeManager.radialDeadzone)
    private let octaveRingFraction = CGFloat(ChordMelodyModeManager.radialOctaveRing)

    var body: some View {
        GeometryReader { geo in
            let outerR = (geo.size.width / 2) * radiusFraction
            let chordCenter = CGPoint(
                x: chordsOnLeft ? geo.size.width / 4 : 3 * geo.size.width / 4,
                y: geo.size.height / 2
            )
            let melodyCenter = CGPoint(
                x: chordsOnLeft ? 3 * geo.size.width / 4 : geo.size.width / 4,
                y: geo.size.height / 2
            )

            ZStack {
                chordWheel(center: chordCenter, outerR: outerR)
                melodyWheel(center: melodyCenter, outerR: outerR)

                if !currentChordName.isEmpty {
                    Text(currentChordName)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: chordHandPinching ? [.green, .cyan] : [.white.opacity(0.5), .white.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .black.opacity(0.6), radius: 8)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.1)
                        .animation(.easeOut(duration: 0.15), value: currentChordName)
                        .animation(.easeOut(duration: 0.15), value: chordHandPinching)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Chord wheel

    @ViewBuilder
    private func chordWheel(center: CGPoint, outerR: CGFloat) -> some View {
        let deadR = outerR * deadzoneFraction
        let ringR = outerR * octaveRingFraction
        let wedge = 360.0 / Double(zoneCount)
        let outerRingActive = currentOctaveShift >= 1

        ZStack {
            ForEach(0..<zoneCount, id: \.self) { i in
                let degree = degreeForZone(i)
                let color = colorForDegree(degree)
                let isCurrentZone = currentChordZone == i && !chordResting
                let start = Angle(degrees: Double(i) * wedge - wedge / 2)
                let end = Angle(degrees: Double(i) * wedge + wedge / 2)

                // Inner ring = base octave.
                chordCell(
                    center: center, innerR: deadR, outerR: ringR, start: start, end: end,
                    color: color, isCurrentZone: isCurrentZone,
                    isActive: isCurrentZone && !outerRingActive
                )
                // Outer ring = +1 octave.
                chordCell(
                    center: center, innerR: ringR, outerR: outerR, start: start, end: end,
                    color: color, isCurrentZone: isCurrentZone,
                    isActive: isCurrentZone && outerRingActive
                )

                // Roman numeral on the inner ring's bisector.
                let labelPos = polar(center: center, angleDeg: Double(i) * wedge, radius: (deadR + ringR) / 2)
                VStack(spacing: 1) {
                    Text(romanNumeral(degree: degree))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(isCurrentZone ? .white : .white.opacity(0.55))
                    if !degreeLabel(degree: degree).isEmpty {
                        Text(degreeLabel(degree: degree))
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(isCurrentZone ? 0.7 : 0.4))
                    }
                }
                .position(labelPos)
            }

            restHole(center: center, radius: deadR, active: chordResting, tint: .green)
        }
    }

    private func chordCell(
        center: CGPoint, innerR: CGFloat, outerR: CGFloat, start: Angle, end: Angle,
        color: Color, isCurrentZone: Bool, isActive: Bool
    ) -> some View {
        let isHeld = isActive && chordHandPinching
        return RadialWedge(center: center, innerRadius: innerR, outerRadius: outerR, startAngle: start, endAngle: end)
            .fill(cellFill(color: color, isCurrentZone: isCurrentZone, isActive: isActive, isHeld: isHeld))
            .overlay(
                RadialWedge(center: center, innerRadius: innerR, outerRadius: outerR, startAngle: start, endAngle: end)
                    .stroke(
                        isHeld ? color.opacity(0.95) :
                        isActive ? color.opacity(0.6) :
                        isCurrentZone ? color.opacity(0.25) :
                        Color.white.opacity(0.08),
                        lineWidth: isHeld ? 2.5 : (isActive ? 1.5 : 1)
                    )
            )
            .shadow(color: isHeld ? color.opacity(0.5) : .clear, radius: 12)
    }

    private func cellFill(color: Color, isCurrentZone: Bool, isActive: Bool, isHeld: Bool) -> some ShapeStyle {
        if isHeld { return AnyShapeStyle(color.opacity(0.45)) }
        if isActive { return AnyShapeStyle(color.opacity(0.28)) }
        if isCurrentZone { return AnyShapeStyle(color.opacity(0.12)) }
        return AnyShapeStyle(Color.white.opacity(0.04))
    }

    // MARK: - Melody wheel

    @ViewBuilder
    private func melodyWheel(center: CGPoint, outerR: CGFloat) -> some View {
        let deadR = outerR * deadzoneFraction
        let count = max(1, melodyLaneCount)
        let wedge = 360.0 / Double(count)

        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let isCurrent = melodyLane == i && !melodyResting
                let isHeld = isCurrent && melodyHandPinching
                let start = Angle(degrees: Double(i) * wedge - wedge / 2)
                let end = Angle(degrees: Double(i) * wedge + wedge / 2)
                RadialWedge(center: center, innerRadius: deadR, outerRadius: outerR, startAngle: start, endAngle: end)
                    .fill(
                        isHeld ? Color.cyan.opacity(0.4) :
                        isCurrent ? Color.cyan.opacity(0.18) :
                        Color.white.opacity(0.04)
                    )
                    .overlay(
                        RadialWedge(center: center, innerRadius: deadR, outerRadius: outerR, startAngle: start, endAngle: end)
                            .stroke(
                                isHeld ? Color.cyan.opacity(0.8) :
                                isCurrent ? Color.cyan.opacity(0.4) :
                                Color.white.opacity(0.06),
                                lineWidth: isHeld ? 2.5 : 1
                            )
                    )
                    .shadow(color: isHeld ? .cyan.opacity(0.4) : .clear, radius: 6)
            }

            restHole(center: center, radius: deadR, active: melodyResting, tint: .cyan)
        }
    }

    // MARK: - Shared bits

    /// The center deadzone — a faint disc that brightens while the hand rests
    /// there, confirming "you're parked, reach out to pick".
    private func restHole(center: CGPoint, radius: CGFloat, active: Bool, tint: Color) -> some View {
        Circle()
            .fill(active ? tint.opacity(0.18) : Color.white.opacity(0.03))
            .overlay(
                Circle().stroke(active ? tint.opacity(0.6) : Color.white.opacity(0.12),
                                lineWidth: active ? 2 : 1)
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }

    private func polar(center: CGPoint, angleDeg: Double, radius: CGFloat) -> CGPoint {
        let r = angleDeg * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(sin(r)),
                       y: center.y - radius * CGFloat(cos(r)))
    }

    // MARK: - Labels & colors (shared with the grid overlay)

    private func degreeForZone(_ index: Int) -> Int {
        guard !zoneDegrees.isEmpty else { return 0 }
        let safe = max(0, min(zoneDegrees.count - 1, index))
        return zoneDegrees[safe]
    }

    private func romanNumeral(degree: Int) -> String {
        switch degree {
        case 0: return "I"
        case 1: return "ii"
        case 2: return "iii"
        case 3: return "IV"
        case 4: return "V"
        case 5: return "vi"
        case 6: return "vii°"
        default: return "\(degree + 1)"
        }
    }

    private func degreeLabel(degree: Int) -> String {
        switch degree {
        case 0: return "TONIC"
        case 3: return "SUB"
        case 4: return "DOM"
        default: return ""
        }
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
