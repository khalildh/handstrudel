import Foundation

struct DrumZone {
    let name: String
    let hitType: String  // matches playHit() JS function parameter
    let color: String
}

final class DrumModeManager {
    static let leftZones: [DrumZone] = [
        DrumZone(name: "Crash", hitType: "crash", color: "yellow"),
        DrumZone(name: "Hi-Hat", hitType: "hihat", color: "cyan"),
        DrumZone(name: "Kick", hitType: "kick", color: "red"),
    ]

    static let rightZones: [DrumZone] = [
        DrumZone(name: "Ride", hitType: "ride", color: "gold"),
        DrumZone(name: "Snare", hitType: "snare", color: "orange"),
        DrumZone(name: "Tom", hitType: "tom", color: "purple"),
    ]

    // Track previous Y positions to detect velocity
    private var prevLeftY: Double = 0.5
    private var prevRightY: Double = 0.5
    private var leftCooldown: TimeInterval = 0
    private var rightCooldown: TimeInterval = 0
    private let cooldownDuration: TimeInterval = 0.1

    // Returns hit type strings for playHit() JS function
    func checkHits(hands: HandsState, currentTime: TimeInterval) -> [String] {
        var hits: [String] = []

        if let left = hands.left {
            let velocity = abs(left.y - prevLeftY)
            if velocity > 0.04 && currentTime > leftCooldown {
                let zoneIdx = min(2, Int(left.y * 3))
                hits.append(Self.leftZones[zoneIdx].hitType)
                leftCooldown = currentTime + cooldownDuration
            }
            prevLeftY = left.y
        }

        if let right = hands.right {
            let velocity = abs(right.y - prevRightY)
            if velocity > 0.04 && currentTime > rightCooldown {
                let zoneIdx = min(2, Int(right.y * 3))
                hits.append(Self.rightZones[zoneIdx].hitType)
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
