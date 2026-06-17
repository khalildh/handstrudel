import SwiftUI

/// Split chord+melody overlay — one centered circle cut into two semicircles.
/// The chord hand fans across one half (left by default, right when swapped),
/// the melody hand fans across the other.
///
/// Geometry mirrors `ChordMelodyModeManager`'s `.split` layout: wedges fan
/// from the top of each arc going counter-clockwise (chord side) / clockwise
/// (melody side) down to the bottom, with a center rest hole. Reaching across
/// to the other half is treated as resting on both sides, so a player can't
/// accidentally poach the other voice.
struct SplitChordMelodyOverlayView: View {
    /// Scale degrees per chord wedge — used only for the per-degree colors.
    let zoneDegrees: [Int]
    /// Lettered chord names per wedge (e.g. "Cmaj", "Am").
    let chordNames: [String]
    /// Currently hovered chord wedge (0..<chordNames.count).
    let currentChordZone: Int?
    /// Whether the chord hand is pinching (chord actively struck).
    let chordHandPinching: Bool
    /// Chord hand is in the center rest zone (or strayed across the divider).
    let chordResting: Bool
    /// Chord display name shown in the wheel's center.
    let currentChordName: String
    /// Active octave shift for the chord hand (-1, 0, +1) — drives which outer
    /// sub-zone lights up when the hand reaches into the octave band.
    let chordOctaveShift: Int
    /// Lettered note names per melody wedge.
    let melodyNames: [String]
    /// Melody hand's current wedge (0..<melodyNames.count).
    let melodyLane: Int?
    /// Whether the melody hand is pinching.
    let melodyHandPinching: Bool
    /// Melody hand is in the center rest zone.
    let melodyResting: Bool
    /// When true, chord = right semicircle, melody = left (lefty users).
    let swapHands: Bool
    /// Chord sub-zones currently held by a touch (separate from hand state).
    /// Lights them up the same way as the hand-driven active zone.
    var touchedChordSubzones: Set<ChordSubzone> = []
    /// Melody lanes currently held by a touch.
    var touchedMelodyLanes: Set<Int> = []
    /// Lane indices that are *chord tones* of the currently-held chord —
    /// drawn with the chord's accent color so the player can see which
    /// scale notes are consonant landing targets. Only set in Scale mode;
    /// empty in Split (where every melody lane is already a chord tone).
    var chordToneLanes: Set<Int> = []
    /// Melody-side octave shift driven by the outer radial band (Scale mode).
    /// 0 in Split since the melody side doesn't have an octave band.
    var melodyOctaveShift: Int = 0

    /// In Scale mode the melody half gets the same inner-band + outer-octave
    /// treatment as the chord side. Detected by the presence of either
    /// chord-tone lanes or a non-zero octave shift.
    private var isScaleMode: Bool { !chordToneLanes.isEmpty || melodyOctaveShift != 0 }

    private var zoneCount: Int { max(1, chordNames.count) }
    private var melodyCount: Int { max(1, melodyNames.count) }

    // Geometry mirrors ChordMelodyModeManager so the drawn wheel lines up with
    // the angle/radius math that selects wedges.
    private let radiusFraction = CGFloat(ChordMelodyModeManager.splitRadiusFraction)
    private let deadzoneFraction = CGFloat(ChordMelodyModeManager.splitDeadzone)
    private let octaveBandFraction = CGFloat(ChordMelodyModeManager.splitOctaveBandThreshold)

    /// Which side (left or right semicircle) the chord half occupies.
    private var chordIsRightHalf: Bool { swapHands }

    var body: some View {
        GeometryReader { geo in
            let outerR = min(geo.size.width, geo.size.height) / 2 * radiusFraction
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let deadR = outerR * deadzoneFraction
            let octaveR = outerR * octaveBandFraction

            ZStack {
                chordHalf(center: center, innerR: deadR, outerR: outerR, octaveR: octaveR)
                if isScaleMode {
                    melodyHalfWithOctaveBand(center: center, innerR: deadR, outerR: outerR, octaveR: octaveR)
                } else {
                    melodyHalf(center: center, innerR: deadR, outerR: outerR)
                }
                divider(center: center, innerR: deadR, outerR: outerR)
                restHole(center: center, radius: deadR)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Chord half

    @ViewBuilder
    private func chordHalf(center: CGPoint, innerR: CGFloat, outerR: CGFloat, octaveR: CGFloat) -> some View {
        let wedge = 180.0 / Double(zoneCount)
        ZStack {
            ForEach(0..<zoneCount, id: \.self) { i in
                chordWedge(index: i, wedge: wedge,
                           center: center, innerR: innerR, outerR: outerR, octaveR: octaveR)
            }
        }
    }

    @ViewBuilder
    private func chordWedge(index i: Int, wedge: Double,
                            center: CGPoint, innerR: CGFloat, outerR: CGFloat, octaveR: CGFloat) -> some View {
        let degree = degreeForZone(i)
        let color = colorForDegree(degree)
        let isCurrent = currentChordZone == i && !chordResting
        let isHeld = isCurrent && chordHandPinching
        let centerAngle = chordCenterAngle(forIndex: i, wedge: wedge)
        let start = Angle(degrees: centerAngle - wedge / 2)
        let end = Angle(degrees: centerAngle + wedge / 2)
        // Hand-driven AND touch-driven highlights for each sub-zone.
        let baseActive = (isCurrent && chordOctaveShift == 0) || touchedChordSubzones.contains(ChordSubzone(wedge: i, octave: 0))
        let baseHeld = isHeld && chordOctaveShift == 0
        let upActive = (isCurrent && chordOctaveShift == 1) || touchedChordSubzones.contains(ChordSubzone(wedge: i, octave: 1))
        let upHeld = isHeld && chordOctaveShift == 1
        let downActive = (isCurrent && chordOctaveShift == -1) || touchedChordSubzones.contains(ChordSubzone(wedge: i, octave: -1))
        let downHeld = isHeld && chordOctaveShift == -1

        // Inner band (deadzone → octaveR): base octave.
        wedgeShape(center: center, innerR: innerR, outerR: octaveR, start: start, end: end)
            .fill(fillStyle(color: color, isCurrent: baseActive, isHeld: baseHeld))
            .overlay(
                wedgeShape(center: center, innerR: innerR, outerR: octaveR, start: start, end: end)
                    .stroke(
                        baseHeld ? color.opacity(0.95) :
                        baseActive ? color.opacity(0.6) :
                        Color.white.opacity(0.1),
                        lineWidth: baseHeld ? 2.5 : (baseActive ? 1.5 : 1)
                    )
            )
            .shadow(color: baseHeld ? color.opacity(0.5) : .clear, radius: 12)

        // Outer band, split into two angular halves for octave shift. The
        // closer-to-top-of-arc half = +1 octave; the closer-to-bottom = −1.
        // On the right arc that half is BEFORE centerAngle; on the left arc
        // it's AFTER. We split the wedge accordingly.
        let upRange = octaveUpRange(start: start, end: end, centerAngle: centerAngle)
        let downRange = octaveDownRange(start: start, end: end, centerAngle: centerAngle)
        octaveSubzone(center: center, innerR: octaveR, outerR: outerR,
                      start: upRange.0, end: upRange.1,
                      color: color,
                      isCurrent: upActive,
                      isHeld: upHeld)
        octaveSubzone(center: center, innerR: octaveR, outerR: outerR,
                      start: downRange.0, end: downRange.1,
                      color: color,
                      isCurrent: downActive,
                      isHeld: downHeld)

        let labelActive = baseActive || upActive || downActive
        Text(chordLabel(i))
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundColor(labelActive ? .white : .white.opacity(0.7))
            .shadow(color: .black.opacity(0.6), radius: 3)
            .position(polar(center: center, angleDeg: centerAngle, radius: (innerR + octaveR) / 2))

        Text("↑")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(upActive ? .white : .white.opacity(0.35))
            .shadow(color: .black.opacity(0.6), radius: 2)
            .position(polar(center: center,
                            angleDeg: chordSubzoneAngle(centerAngle: centerAngle, wedge: wedge, upper: true),
                            radius: (octaveR + outerR) / 2))
        Text("↓")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(downActive ? .white : .white.opacity(0.35))
            .shadow(color: .black.opacity(0.6), radius: 2)
            .position(polar(center: center,
                            angleDeg: chordSubzoneAngle(centerAngle: centerAngle, wedge: wedge, upper: false),
                            radius: (octaveR + outerR) / 2))
    }

    /// Render one of the two angular sub-zones in a chord wedge's outer band.
    @ViewBuilder
    private func octaveSubzone(center: CGPoint, innerR: CGFloat, outerR: CGFloat,
                               start: Angle, end: Angle,
                               color: Color, isCurrent: Bool, isHeld: Bool) -> some View {
        wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
            .fill(fillStyle(color: color, isCurrent: isCurrent, isHeld: isHeld))
            .overlay(
                wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
                    .stroke(
                        isHeld ? color.opacity(0.95) :
                        isCurrent ? color.opacity(0.6) :
                        Color.white.opacity(0.08),
                        lineWidth: isHeld ? 2.5 : (isCurrent ? 1.5 : 0.5)
                    )
            )
            .shadow(color: isHeld ? color.opacity(0.5) : .clear, radius: 10)
    }

    /// Angular range covering the +1-octave sub-zone of a chord wedge.
    private func octaveUpRange(start: Angle, end: Angle, centerAngle: Double) -> (Angle, Angle) {
        let mid = Angle(degrees: centerAngle)
        return chordIsRightHalf ? (start, mid) : (mid, end)
    }

    /// Angular range covering the −1-octave sub-zone of a chord wedge.
    private func octaveDownRange(start: Angle, end: Angle, centerAngle: Double) -> (Angle, Angle) {
        let mid = Angle(degrees: centerAngle)
        return chordIsRightHalf ? (mid, end) : (start, mid)
    }

    /// Center angle of one of the two octave sub-zones in a chord wedge.
    /// `upper == true` returns the midpoint of the +1-octave half (the half
    /// whose angles sit closer to the top of the arc). The closer-to-top half
    /// is BEFORE centerAngle on the right arc, AFTER centerAngle on the left.
    private func chordSubzoneAngle(centerAngle: Double, wedge: Double, upper: Bool) -> Double {
        let sign: Double = chordIsRightHalf ? -1 : 1
        let delta = sign * (upper ? wedge / 4 : -wedge / 4)
        var a = centerAngle + delta
        if a < 0 { a += 360 }
        if a >= 360 { a -= 360 }
        return a
    }

    // MARK: - Melody half

    @ViewBuilder
    private func melodyHalf(center: CGPoint, innerR: CGFloat, outerR: CGFloat) -> some View {
        let arcDegrees = 180.0
        let wedge = arcDegrees / Double(melodyCount)
        ZStack {
            ForEach(0..<melodyCount, id: \.self) { i in
                // `i` is lane index — 0 = lowest pitch (bottom of arc),
                // melodyCount-1 = highest (top of arc).
                let handActive = melodyLane == i && !melodyResting
                let isCurrent = handActive || touchedMelodyLanes.contains(i)
                let isHeld = handActive && melodyHandPinching
                let centerAngle = melodyCenterAngle(forLane: i, wedge: wedge)
                let start = Angle(degrees: centerAngle - wedge / 2)
                let end = Angle(degrees: centerAngle + wedge / 2)

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
                    .position(polar(center: center, angleDeg: centerAngle, radius: (innerR + outerR) / 2))
            }
        }
    }

    // MARK: - Scale-mode melody half (inner band + octave shift outer band)

    @ViewBuilder
    private func melodyHalfWithOctaveBand(center: CGPoint, innerR: CGFloat, outerR: CGFloat, octaveR: CGFloat) -> some View {
        let wedge = 180.0 / Double(melodyCount)
        ZStack {
            ForEach(0..<melodyCount, id: \.self) { i in
                scaleMelodyWedge(lane: i, wedge: wedge,
                                 center: center, innerR: innerR, outerR: outerR, octaveR: octaveR)
            }
        }
    }

    /// One melody wedge in Scale mode: inner band = base octave at that scale
    /// degree, outer band split angularly into ±1 octave halves (same pattern
    /// as a chord wedge). Chord-tone lanes get the chord's accent color so
    /// the player can see consonant landing targets at a glance.
    @ViewBuilder
    private func scaleMelodyWedge(lane i: Int, wedge: Double,
                                  center: CGPoint, innerR: CGFloat, outerR: CGFloat, octaveR: CGFloat) -> some View {
        let isChordTone = chordToneLanes.contains(i)
        let toneColor: Color = isChordTone ? Color.green : Color.cyan
        let handActive = melodyLane == i && !melodyResting
        let isCurrent = handActive || touchedMelodyLanes.contains(i)
        let isHeld = handActive && melodyHandPinching

        // The melody side mirrors the chord side: index 0 sits at the bottom
        // (lowest pitch) — same `melodyCenterAngle` math as Split.
        let centerAngle = melodyCenterAngle(forLane: i, wedge: wedge)
        let start = Angle(degrees: centerAngle - wedge / 2)
        let end = Angle(degrees: centerAngle + wedge / 2)

        let baseActive = isCurrent && melodyOctaveShift == 0
        let baseHeld = isHeld && melodyOctaveShift == 0

        // Inner band — base octave. Resting fill is bumped + we stack a black
        // outline behind the color stroke so the wedge reads cleanly against
        // the live camera feed.
        wedgeShape(center: center, innerR: innerR, outerR: octaveR, start: start, end: end)
            .fill(
                baseHeld ? toneColor.opacity(0.6) :
                baseActive ? toneColor.opacity(0.4) :
                isChordTone ? toneColor.opacity(0.30) : Color.cyan.opacity(0.16)
            )
            .overlay(
                wedgeShape(center: center, innerR: innerR, outerR: octaveR, start: start, end: end)
                    .stroke(Color.black.opacity(0.65), lineWidth: 2.5)
            )
            .overlay(
                wedgeShape(center: center, innerR: innerR, outerR: octaveR, start: start, end: end)
                    .stroke(
                        baseHeld ? toneColor :
                        baseActive ? toneColor.opacity(0.9) :
                        isChordTone ? toneColor.opacity(0.85) : Color.cyan.opacity(0.55),
                        lineWidth: baseHeld ? 2.5 : (baseActive ? 1.8 : 1.2)
                    )
            )
            .shadow(color: baseHeld ? toneColor.opacity(0.6) : .clear, radius: 10)

        // Outer ±1 octave sub-zones. The "closer-to-top-of-arc" half is +1.
        // Melody side's chordIsRightHalf is the opposite of the chord side
        // (different semicircle), so up/down map the other way.
        let melodyIsRightHalf = !chordIsRightHalf
        let mid = Angle(degrees: centerAngle)
        let upRange: (Angle, Angle) = melodyIsRightHalf ? (start, mid) : (mid, end)
        let downRange: (Angle, Angle) = melodyIsRightHalf ? (mid, end) : (start, mid)

        scaleMelodyOctaveSubzone(center: center, innerR: octaveR, outerR: outerR,
                                 start: upRange.0, end: upRange.1, toneColor: toneColor,
                                 isCurrent: isCurrent && melodyOctaveShift == 1,
                                 isHeld: isHeld && melodyOctaveShift == 1,
                                 isChordTone: isChordTone)
        scaleMelodyOctaveSubzone(center: center, innerR: octaveR, outerR: outerR,
                                 start: downRange.0, end: downRange.1, toneColor: toneColor,
                                 isCurrent: isCurrent && melodyOctaveShift == -1,
                                 isHeld: isHeld && melodyOctaveShift == -1,
                                 isChordTone: isChordTone)

        Text(melodyLabel(i))
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.85), radius: 3)
            .position(polar(center: center, angleDeg: centerAngle, radius: (innerR + octaveR) / 2))

        // ±1 octave hint arrows near the rim.
        let upMidpoint = melodyIsRightHalf ? (centerAngle - wedge / 4) : (centerAngle + wedge / 4)
        let downMidpoint = melodyIsRightHalf ? (centerAngle + wedge / 4) : (centerAngle - wedge / 4)
        Text("↑")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(isCurrent && melodyOctaveShift == 1 ? .white : toneColor.opacity(0.35))
            .position(polar(center: center, angleDeg: wrappedAngle(upMidpoint), radius: (octaveR + outerR) / 2))
        Text("↓")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(isCurrent && melodyOctaveShift == -1 ? .white : toneColor.opacity(0.35))
            .position(polar(center: center, angleDeg: wrappedAngle(downMidpoint), radius: (octaveR + outerR) / 2))
    }

    private func wrappedAngle(_ a: Double) -> Double {
        var x = a
        if x < 0 { x += 360 }
        if x >= 360 { x -= 360 }
        return x
    }

    /// One outer-band sub-zone in the Scale-mode melody half — black backing
    /// stroke for contrast against the camera feed, then a colored stroke and
    /// fill that brightens when active.
    @ViewBuilder
    private func scaleMelodyOctaveSubzone(
        center: CGPoint, innerR: CGFloat, outerR: CGFloat,
        start: Angle, end: Angle,
        toneColor: Color,
        isCurrent: Bool, isHeld: Bool, isChordTone: Bool
    ) -> some View {
        let fillOpacity: Double = isCurrent ? (isHeld ? 0.55 : 0.35) : (isChordTone ? 0.16 : 0.10)
        let strokeOpacity: Double = isCurrent ? 0.95 : (isChordTone ? 0.55 : 0.35)
        wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
            .fill(toneColor.opacity(fillOpacity))
            .overlay(
                wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
                    .stroke(Color.black.opacity(0.65), lineWidth: 2)
            )
            .overlay(
                wedgeShape(center: center, innerR: innerR, outerR: outerR, start: start, end: end)
                    .stroke(toneColor.opacity(strokeOpacity), lineWidth: isCurrent ? 1.8 : 1)
            )
    }

    // MARK: - Divider line

    /// A vertical separator across the wheel to make the halves visually obvious.
    private func divider(center: CGPoint, innerR: CGFloat, outerR: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: center.x, y: center.y - outerR))
            p.addLine(to: CGPoint(x: center.x, y: center.y - innerR))
            p.move(to: CGPoint(x: center.x, y: center.y + innerR))
            p.addLine(to: CGPoint(x: center.x, y: center.y + outerR))
        }
        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }

    // MARK: - Center

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

    // MARK: - Angle math

    /// Center angle of chord wedge `i` (0 at top of arc → count-1 at bottom),
    /// measured clockwise from 12 o'clock. The chord arc fans counter-clockwise
    /// from the top down on the left half (or clockwise on the right half when
    /// swapped) so the indices read "top to bottom".
    private func chordCenterAngle(forIndex i: Int, wedge: Double) -> Double {
        let offset = (Double(i) + 0.5) * wedge   // 0..180 along the arc
        if chordIsRightHalf {
            return offset   // top (0°) → bottom (180°) clockwise
        }
        var a = 360.0 - offset   // top (360°) → bottom (180°) counter-clockwise
        if a >= 360 { a -= 360 }
        return a
    }

    /// Center angle of melody lane `i` (0 = lowest pitch at bottom of arc,
    /// count-1 = highest at top), measured clockwise from 12 o'clock.
    private func melodyCenterAngle(forLane lane: Int, wedge: Double) -> Double {
        // Invert lane → wedge index from the top.
        let wedgeFromTop = Double(melodyCount - 1 - lane)
        let offset = (wedgeFromTop + 0.5) * wedge
        if chordIsRightHalf {
            // Melody is on the LEFT half when swapped.
            var a = 360.0 - offset
            if a >= 360 { a -= 360 }
            return a
        }
        return offset   // top → bottom clockwise (right half)
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

    private func wedgeShape(center: CGPoint, innerR: CGFloat, outerR: CGFloat, start: Angle, end: Angle) -> SplitWedge {
        SplitWedge(center: center, innerRadius: innerR, outerRadius: outerR, startAngle: start, endAngle: end)
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

/// Annular wedge — identical math to `RadialWedge` but kept separate so the
/// split overlay is self-contained.
private struct SplitWedge: Shape {
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
