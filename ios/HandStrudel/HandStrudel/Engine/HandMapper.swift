import Foundation

final class HandMapper {
    static func scaleAxis(raw: Double, paramId: String, invert: Bool) -> Double {
        guard let def = PARAM_MAP[paramId] else { return 0 }
        let t = invert ? 1 - raw : raw
        return def.min + t * (def.max - def.min)
    }

    static func mapHandsToParams(_ hands: HandsState, params: inout MusicParams, config: MappingConfig) {
        for side in ["left", "right"] {
            let hand = side == "left" ? hands.left : hands.right
            guard let hand else { continue }
            let sideConfig = side == "left" ? config.left : config.right
            for (axisKey, paramId) in sideConfig {
                guard paramId != "none" && paramId != "save" else { continue }
                guard let axisDef = AXIS_MAP[axisKey] else { continue }
                guard let raw = hand.value(for: axisKey) else { continue }
                params[paramId] = scaleAxis(raw: raw, paramId: paramId, invert: axisDef.invert)
            }
        }
    }

    static func getSaveAxes(_ config: MappingConfig) -> [(side: String, axisKey: String)] {
        var result = [(side: String, axisKey: String)]()
        for side in ["left", "right"] {
            let sideConfig = side == "left" ? config.left : config.right
            for (axisKey, paramId) in sideConfig where paramId == "save" {
                result.append((side: side, axisKey: axisKey))
            }
        }
        return result
    }
}
