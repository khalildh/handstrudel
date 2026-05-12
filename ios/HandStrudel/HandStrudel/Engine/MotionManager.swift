import CoreMotion
import Foundation

final class MotionManager: ObservableObject {
    private let motion = CMMotionManager()

    @Published var pitch: Double = 0  // forward/back tilt (-1 to 1)
    @Published var roll: Double = 0   // left/right tilt (-1 to 1)
    @Published var isActive = false

    func start() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0  // 30fps
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            // Pitch: -1 (tilted toward you) to 1 (tilted away)
            self.pitch = max(-1, min(1, data.attitude.pitch / (.pi / 4)))
            // Roll: -1 (tilted left) to 1 (tilted right)
            self.roll = max(-1, min(1, data.attitude.roll / (.pi / 4)))
        }
        isActive = true
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        isActive = false
    }
}
