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

    // Pinch detection — drums use a lighter touch (0.7/0.4) than melodic modes
    // so percussive hits feel responsive.
    private var leftPinch = PinchDetector(on: 0.7, off: 0.4)
    private var rightPinch = PinchDetector(on: 0.7, off: 0.4)

    // Track which drum each hand last triggered (prevent re-trigger)
    private var leftLastDrum: String? = nil
    private var rightLastDrum: String? = nil

    // Published lane indices for UI highlighting
    var leftLane: Int? = nil
    var rightLane: Int? = nil
    var isLeftPinching: Bool { leftPinch.isPinching }
    var isRightPinching: Bool { rightPinch.isPinching }

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

        // Left hand — use pinchY (midpoint of thumb+index) for position
        if let left = hands.left {
            let drumIdx = yToDrumIndex(y: left.pinchY)
            leftLane = drumIdx
            let drum = Self.allDrums[drumIdx]

            switch leftPinch.update(pinch: left.pinch) {
            case .began:
                leftLastDrum = drum.hitType
                hits.append(DrumHit(hand: "left", hitType: drum.hitType))
            case .held:
                // Still pinching — retrigger if moved to new drum
                if drum.hitType != leftLastDrum {
                    leftLastDrum = drum.hitType
                    hits.append(DrumHit(hand: "left", hitType: drum.hitType))
                }
            case .ended:
                leftLastDrum = nil
            case .idle:
                break
            }
        } else {
            leftPinch.release()
            leftLastDrum = nil
            leftLane = nil
        }

        // Right hand — use pinchY
        if let right = hands.right {
            let drumIdx = yToDrumIndex(y: right.pinchY)
            rightLane = drumIdx
            let drum = Self.allDrums[drumIdx]

            switch rightPinch.update(pinch: right.pinch) {
            case .began:
                rightLastDrum = drum.hitType
                hits.append(DrumHit(hand: "right", hitType: drum.hitType))
            case .held:
                if drum.hitType != rightLastDrum {
                    rightLastDrum = drum.hitType
                    hits.append(DrumHit(hand: "right", hitType: drum.hitType))
                }
            case .ended:
                rightLastDrum = nil
            case .idle:
                break
            }
        } else {
            rightPinch.release()
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
