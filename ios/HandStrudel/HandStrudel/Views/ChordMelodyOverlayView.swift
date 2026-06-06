import SwiftUI

/// Two-hand chord+melody mode overlay.
///
/// The chord hand selects one of 7 diatonic chord zones on its half of the
/// screen. The melody hand picks a note from the current chord's tones on the
/// other half. Visual feedback is critical here — without seeing the zones,
/// the player can't reliably hit them.
struct ChordMelodyOverlayView: View {
    /// Scale degrees assigned to each zone — drives both zone count and the
    /// Roman numeral label per zone. `[0, 4, 5, 3]` = a 4-zone Pop layout
    /// labeled "I V vi IV"; `[0,1,2,3,4,5,6]` = the original 7-zone Free mode.
    let zoneDegrees: [Int]
    /// Currently hovered chord zone (0..<zoneDegrees.count).
    let currentChordZone: Int?
    /// Whether the chord hand is pinching (chord actively held).
    let chordHandPinching: Bool
    /// Current octave shift from chord hand Y: -1 (low), 0 (mid), +1 (high).
    let currentOctaveShift: Int
    /// Current chord display name (e.g. "Cmaj", "Am") shown in the center.
    let currentChordName: String
    /// Melody hand's current lane (used for highlight on the melody half).
    let melodyLane: Int?
    /// Whether the melody hand is pinching.
    let melodyHandPinching: Bool
    /// Number of melody lanes (chord tones expanded across octaves).
    let melodyLaneCount: Int
    /// `true` = chord hand on the right side, melody on the left (swap mode).
    let swapHands: Bool

    private var zoneCount: Int { max(1, zoneDegrees.count) }

    private var chordsOnLeft: Bool { !swapHands }

    /// Octave shifts displayed top-to-bottom (high → mid → low).
    private let octaves: [Int] = [1, 0, -1]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ---- chord hand half ----
                ZStack {
                    HStack(spacing: 4) {
                        ForEach(0..<zoneCount, id: \.self) { i in
                            chordZone(index: i)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: geo.size.width / 2, height: geo.size.height)
                .position(
                    x: chordsOnLeft ? geo.size.width / 4 : 3 * geo.size.width / 4,
                    y: geo.size.height / 2
                )

                // ---- melody hand half ----
                ZStack(alignment: chordsOnLeft ? .trailing : .leading) {
                    VStack(spacing: 2) {
                        ForEach(0..<melodyLaneCount, id: \.self) { i in
                            melodyLaneStrip(index: i, total: melodyLaneCount)
                        }
                    }
                    .padding(.vertical, geo.size.height * 0.15)
                    .padding(.horizontal, 6)
                }
                .frame(width: geo.size.width / 2, height: geo.size.height)
                .position(
                    x: chordsOnLeft ? 3 * geo.size.width / 4 : geo.size.width / 4,
                    y: geo.size.height / 2
                )

                // ---- chord name display ----
                if !currentChordName.isEmpty {
                    Text(currentChordName)
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: chordHandPinching ? [.green, .cyan] : [.white.opacity(0.5), .white.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .black.opacity(0.6), radius: 8)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.18)
                        .animation(.easeOut(duration: 0.15), value: currentChordName)
                        .animation(.easeOut(duration: 0.15), value: chordHandPinching)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Zone components

    private func chordZone(index: Int) -> some View {
        let isCurrentZone = currentChordZone == index
        let degree = degreeForZone(index)
        let degreeColor = colorForDegree(degree)
        return VStack(spacing: 2) {
            ForEach(octaves, id: \.self) { oct in
                octaveCell(degree: degree, octave: oct, degreeColor: degreeColor, isCurrentZone: isCurrentZone)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func degreeForZone(_ index: Int) -> Int {
        guard !zoneDegrees.isEmpty else { return 0 }
        let safe = max(0, min(zoneDegrees.count - 1, index))
        return zoneDegrees[safe]
    }

    private func octaveCell(degree: Int, octave: Int, degreeColor: Color, isCurrentZone: Bool) -> some View {
        let isActiveCell = isCurrentZone && octave == currentOctaveShift
        let isHeld = isActiveCell && chordHandPinching
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellFill(degreeColor: degreeColor, isCurrentZone: isCurrentZone, isActive: isActiveCell, isHeld: isHeld))

            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isHeld ? degreeColor.opacity(0.95) :
                    isActiveCell ? degreeColor.opacity(0.6) :
                    isCurrentZone ? degreeColor.opacity(0.25) :
                    Color.white.opacity(0.07),
                    lineWidth: isHeld ? 2 : (isActiveCell ? 1.5 : 1)
                )

            // Only the middle octave row gets the degree label — keeps the
            // strip readable without repeating the same Roman numeral 3 times.
            if octave == 0 {
                VStack(spacing: 4) {
                    Text(romanNumeral(degree: degree))
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(isCurrentZone ? .white : .white.opacity(0.55))
                    Text(degreeLabel(degree: degree))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(isCurrentZone ? 0.7 : 0.4))
                }
            } else {
                // Tiny octave indicator (+ for high, − for low) on outer rows.
                Text(octave > 0 ? "+8va" : "−8va")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(isActiveCell ? 0.85 : 0.3))
            }
        }
        .shadow(color: isHeld ? degreeColor.opacity(0.5) : .clear, radius: 12)
    }

    private func cellFill(degreeColor: Color, isCurrentZone: Bool, isActive: Bool, isHeld: Bool) -> some ShapeStyle {
        if isHeld {
            return AnyShapeStyle(degreeColor.opacity(0.45))
        }
        if isActive {
            return AnyShapeStyle(degreeColor.opacity(0.28))
        }
        if isCurrentZone {
            return AnyShapeStyle(degreeColor.opacity(0.1))
        }
        return AnyShapeStyle(Color.white.opacity(0.04))
    }

    private func melodyLaneStrip(index: Int, total: Int) -> some View {
        // Higher lane index in our state = lower on screen, but we want top of
        // the screen to be the highest pitch, so we invert here.
        let pitchPos = total - 1 - index
        let isCurrent = melodyLane == pitchPos
        let isHeld = isCurrent && melodyHandPinching
        return RoundedRectangle(cornerRadius: 6)
            .fill(
                isHeld ? Color.cyan.opacity(0.4) :
                isCurrent ? Color.cyan.opacity(0.18) :
                Color.white.opacity(0.04)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isHeld ? Color.cyan.opacity(0.8) :
                        isCurrent ? Color.cyan.opacity(0.4) :
                        Color.white.opacity(0.05),
                        lineWidth: isHeld ? 2 : 1
                    )
            )
            .frame(maxWidth: .infinity)
            .shadow(color: isHeld ? .cyan.opacity(0.4) : .clear, radius: 6)
    }

    // MARK: - Labels & colors

    /// Diatonic Roman numerals 1..7 for a major scale layout.
    /// (The actual chord quality is reflected in chordDisplayName; the labels
    /// here are just zone markers so the player can find the chord.)
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

    /// Each degree gets a hue so the player can spot zones by color, not just
    /// position. Tonic/sub/dom emphasized with brighter shades.
    private func colorForDegree(_ degree: Int) -> Color {
        switch degree {
        case 0: return .green        // I — tonic
        case 1: return Color(red: 0.6, green: 0.5, blue: 0.9) // ii
        case 2: return Color(red: 0.7, green: 0.6, blue: 0.9) // iii
        case 3: return Color(red: 0.4, green: 0.8, blue: 0.9) // IV — subdominant
        case 4: return .pink         // V — dominant
        case 5: return Color(red: 0.9, green: 0.6, blue: 0.4) // vi
        case 6: return Color(red: 0.9, green: 0.4, blue: 0.4) // vii°
        default: return .gray
        }
    }
}
