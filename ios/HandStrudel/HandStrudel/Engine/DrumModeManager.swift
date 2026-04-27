import Foundation

struct DrumZone {
    let name: String
    let code: String
    let color: String
}

final class DrumModeManager {
    // Zones for each hand (Y ranges: 0-0.33 = high, 0.33-0.66 = mid, 0.66-1.0 = low)
    static let leftZones: [DrumZone] = [
        DrumZone(name: "Crash", code: "note(\"c6\").s(\"white\").decay(0.15).sustain(0).gain(0.4).hpf(6000)", color: "yellow"),
        DrumZone(name: "Hi-Hat", code: "note(\"a5\").s(\"white\").decay(0.025).sustain(0).gain(0.35).hpf(8000)", color: "cyan"),
        DrumZone(name: "Kick", code: "note(\"c1\").s(\"sine\").decay(0.3).sustain(0).gain(1.4).lpf(120)", color: "red"),
    ]

    static let rightZones: [DrumZone] = [
        DrumZone(name: "Ride", code: "note(\"e6\").s(\"pink\").decay(0.1).sustain(0).gain(0.3).hpf(5000)", color: "gold"),
        DrumZone(name: "Snare", code: "stack(note(\"c4\").s(\"white\").decay(0.12).sustain(0).gain(0.7).hpf(1000).lpf(6000), note(\"e3\").s(\"triangle\").decay(0.08).sustain(0).gain(0.5).lpf(3000))", color: "orange"),
        DrumZone(name: "Tom", code: "note(\"g2\").s(\"sine\").decay(0.2).sustain(0).gain(0.9).lpf(400)", color: "purple"),
    ]

    // Track previous Y positions to detect velocity
    private var prevLeftY: Double = 0.5
    private var prevRightY: Double = 0.5
    private var leftCooldown: TimeInterval = 0
    private var rightCooldown: TimeInterval = 0
    private let cooldownDuration: TimeInterval = 0.1

    // Returns Strudel code to evaluate if a hit was detected, nil otherwise
    func checkHits(hands: HandsState, currentTime: TimeInterval) -> [String] {
        var hits: [String] = []

        if let left = hands.left {
            let velocity = abs(left.y - prevLeftY)
            if velocity > 0.04 && currentTime > leftCooldown {
                let zoneIdx = min(2, Int(left.y * 3))
                hits.append(Self.leftZones[zoneIdx].code)
                leftCooldown = currentTime + cooldownDuration
            }
            prevLeftY = left.y
        }

        if let right = hands.right {
            let velocity = abs(right.y - prevRightY)
            if velocity > 0.04 && currentTime > rightCooldown {
                let zoneIdx = min(2, Int(right.y * 3))
                hits.append(Self.rightZones[zoneIdx].code)
                rightCooldown = currentTime + cooldownDuration
            }
            prevRightY = right.y
        }

        return hits
    }

    // Get current zone names for display
    func currentZones(hands: HandsState) -> (left: String?, right: String?) {
        let leftZone = hands.left.map { min(2, Int($0.y * 3)) }.map { Self.leftZones[$0].name }
        let rightZone = hands.right.map { min(2, Int($0.y * 3)) }.map { Self.rightZones[$0].name }
        return (leftZone, rightZone)
    }
}
