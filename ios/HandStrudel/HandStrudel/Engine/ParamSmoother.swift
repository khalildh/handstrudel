import Foundation

final class ParamSmoother {
    static let alpha = 0.35

    static func smooth(target: MusicParams, smoothed: inout MusicParams) {
        for (k, v) in target {
            if let current = smoothed[k] {
                smoothed[k] = current + (v - current) * alpha
            } else {
                smoothed[k] = v
            }
        }
    }
}
