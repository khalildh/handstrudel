import CoreMotion
import AVFoundation

final class SpatialAudioManager: ObservableObject {
    private let headphoneMotion = CMHeadphoneMotionManager()

    @Published var isAvailable = false
    @Published var isActive = false
    @Published var headYaw: Double = 0    // -1 (left) to 1 (right)
    @Published var headPitch: Double = 0  // -1 (down) to 1 (up)

    init() {
        isAvailable = headphoneMotion.isDeviceMotionAvailable
    }

    func start() {
        guard isAvailable, !isActive else { return }
        headphoneMotion.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }
            // Yaw: head rotation left/right, normalized to -1...1
            self.headYaw = max(-1, min(1, motion.attitude.yaw / (.pi / 3)))
            // Pitch: head tilt up/down
            self.headPitch = max(-1, min(1, motion.attitude.pitch / (.pi / 4)))
        }
        isActive = true
    }

    func stop() {
        headphoneMotion.stopDeviceMotionUpdates()
        isActive = false
    }

    /// Map head yaw to stereo pan value (0 = left, 0.5 = center, 1 = right)
    var panValue: Double {
        (headYaw + 1) / 2  // convert -1...1 to 0...1
    }
}
