import Foundation

final class SaveGestureDetector {
    private var armed = [String: Bool]()
    private var lastSaveTime: TimeInterval = 0

    func reset() {
        armed.removeAll()
        lastSaveTime = 0
    }

    func check(hands: HandsState, config: MappingConfig, currentTime: TimeInterval) -> Bool {
        let saveAxes = HandMapper.getSaveAxes(config)
        var triggered = false

        for (side, axisKey) in saveAxes {
            let hand = side == "left" ? hands.left : hands.right
            guard let hand, let raw = hand.value(for: axisKey) else { continue }

            let armKey = "\(side):\(axisKey)"
            let isArmed = armed[armKey] ?? true

            if raw > 0.8 && isArmed && currentTime - lastSaveTime > 1.0 {
                armed[armKey] = false
                lastSaveTime = currentTime
                triggered = true
            } else if raw < 0.3 {
                armed[armKey] = true
            }
        }

        return triggered
    }
}
