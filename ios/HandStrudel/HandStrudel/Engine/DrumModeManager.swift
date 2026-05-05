import Foundation

struct DrumZone {
    let name: String
    let hitType: String
    let color: String
}

final class DrumModeManager {
    // All 6 drums in order from top to bottom (matching the UI lanes)
    static let allDrums: [DrumZone] = [
        DrumZone(name: "Crash", hitType: "crash", color: "yellow"),
        DrumZone(name: "Hi-Hat", hitType: "hihat", color: "cyan"),
        DrumZone(name: "Snare", hitType: "snare", color: "orange"),
        DrumZone(name: "Ride", hitType: "ride", color: "pink"),
        DrumZone(name: "Tom", hitType: "tom", color: "purple"),
        DrumZone(name: "Kick", hitType: "kick", color: "red"),
    ]

    // Keep old statics for backward compat
    static let leftZones = allDrums
    static let rightZones = allDrums

    // Pinch detection (same as GridModeManager)
    private var leftPinching = false
    private var rightPinching = false
    private let pinchThreshold: Double = 0.7
    private let releaseThreshold: Double = 0.4

    // Track which drum each hand last triggered (prevent re-trigger)
    private var leftLastDrum: String? = nil
    private var rightLastDrum: String? = nil

    // Published lane indices for UI highlighting
    var leftLane: Int? = nil
    var rightLane: Int? = nil
    var isLeftPinching: Bool { leftPinching }
    var isRightPinching: Bool { rightPinching }

    struct DrumHit {
        let hand: String
        let hitType: String
    }

    /// Map hand Y to drum index (0 = top/crash, 5 = bottom/kick)
    func yToDrumIndex(y: Double) -> Int {
        let topPad = 0.15
        let bottomPad = 0.20
        let usable = 1.0 - topPad - bottomPad
        let normalized = max(0, min(1, (y - topPad) / usable))
        return max(0, min(Self.allDrums.count - 1, Int(normalized * Double(Self.allDrums.count))))
    }

    /// Check for pinch-based drum hits. Returns list of hits to play.
    func checkHits(hands: HandsState, currentTime: TimeInterval) -> [DrumHit] {
        var hits: [DrumHit] = []

        // Left hand
        if let left = hands.left {
            let drumIdx = yToDrumIndex(y: left.y)
            leftLane = drumIdx
            let drum = Self.allDrums[drumIdx]
            let isPinching = left.pinch > pinchThreshold

            if isPinching && !leftPinching {
                leftPinching = true
                leftLastDrum = drum.hitType
                hits.append(DrumHit(hand: "left", hitType: drum.hitType))
            } else if isPinching && leftPinching {
                // Still pinching — retrigger if moved to new drum
                if drum.hitType != leftLastDrum {
                    leftLastDrum = drum.hitType
                    hits.append(DrumHit(hand: "left", hitType: drum.hitType))
                }
            } else if left.pinch < releaseThreshold {
                leftPinching = false
                leftLastDrum = nil
            }
        } else {
            leftPinching = false
            leftLastDrum = nil
            leftLane = nil
        }

        // Right hand
        if let right = hands.right {
            let drumIdx = yToDrumIndex(y: right.y)
            rightLane = drumIdx
            let drum = Self.allDrums[drumIdx]
            let isPinching = right.pinch > pinchThreshold

            if isPinching && !rightPinching {
                rightPinching = true
                rightLastDrum = drum.hitType
                hits.append(DrumHit(hand: "right", hitType: drum.hitType))
            } else if isPinching && rightPinching {
                if drum.hitType != rightLastDrum {
                    rightLastDrum = drum.hitType
                    hits.append(DrumHit(hand: "right", hitType: drum.hitType))
                }
            } else if right.pinch < releaseThreshold {
                rightPinching = false
                rightLastDrum = nil
            }
        } else {
            rightPinching = false
            rightLastDrum = nil
            rightLane = nil
        }

        return hits
    }

    // Legacy compat
    func currentZones(hands: HandsState) -> (left: String?, right: String?) {
        let leftZone = leftLane.map { Self.allDrums[$0].name }
        let rightZone = rightLane.map { Self.allDrums[$0].name }
        return (leftZone, rightZone)
    }
}
