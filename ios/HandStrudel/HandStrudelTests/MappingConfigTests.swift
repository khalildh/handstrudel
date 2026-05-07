import XCTest
@testable import HandStrudel

final class MappingConfigTests: XCTestCase {

    // MARK: - DEFAULT_MAPPING

    func testDefaultMapping_leftHasValidParamIds() {
        for (_, paramId) in DEFAULT_MAPPING.left {
            XCTAssertTrue(
                PARAM_MAP[paramId] != nil || paramId == "none" || paramId == "save",
                "DEFAULT_MAPPING left param '\(paramId)' should be in PARAM_MAP or be none/save"
            )
        }
    }

    func testDefaultMapping_rightHasValidParamIds() {
        for (_, paramId) in DEFAULT_MAPPING.right {
            XCTAssertTrue(
                PARAM_MAP[paramId] != nil || paramId == "none" || paramId == "save",
                "DEFAULT_MAPPING right param '\(paramId)' should be in PARAM_MAP or be none/save"
            )
        }
    }

    func testDefaultMapping_leftHasExpectedMappings() {
        XCTAssertEqual(DEFAULT_MAPPING.left["y"], "noteIdx")
        XCTAssertEqual(DEFAULT_MAPPING.left["x"], "lpf")
        XCTAssertEqual(DEFAULT_MAPPING.left["spread"], "reverb")
    }

    func testDefaultMapping_rightHasExpectedMappings() {
        XCTAssertEqual(DEFAULT_MAPPING.right["y"], "gain")
        XCTAssertEqual(DEFAULT_MAPPING.right["x"], "bpm")
        XCTAssertEqual(DEFAULT_MAPPING.right["spread"], "delay")
    }

    // MARK: - PRESETS validation

    func testPresets_allHaveUniqueIds() {
        let ids = PRESETS.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "All preset IDs should be unique")
    }

    func testPresets_allHaveValidParamIdsInLeftMapping() {
        for preset in PRESETS {
            for (_, paramId) in preset.mapping.left {
                XCTAssertTrue(
                    PARAM_MAP[paramId] != nil || paramId == "none" || paramId == "save",
                    "Preset '\(preset.id)' left param '\(paramId)' should be in PARAM_MAP or be none/save"
                )
            }
        }
    }

    func testPresets_allHaveValidParamIdsInRightMapping() {
        for preset in PRESETS {
            for (_, paramId) in preset.mapping.right {
                XCTAssertTrue(
                    PARAM_MAP[paramId] != nil || paramId == "none" || paramId == "save",
                    "Preset '\(preset.id)' right param '\(paramId)' should be in PARAM_MAP or be none/save"
                )
            }
        }
    }

    func testPresets_premiumPresetsHaveNonNilPackId() {
        let premiumPresets = PRESETS.filter { $0.isPremium }
        XCTAssertGreaterThan(premiumPresets.count, 0, "Should have at least one premium preset")
        for preset in premiumPresets {
            XCTAssertNotNil(preset.packId, "Premium preset '\(preset.id)' should have a packId")
            XCTAssertFalse(preset.packId!.isEmpty, "Premium preset '\(preset.id)' packId should not be empty")
        }
    }

    func testPresets_freePresetsHaveNilPackId() {
        let freePresets = PRESETS.filter { !$0.isPremium }
        XCTAssertGreaterThan(freePresets.count, 0, "Should have at least one free preset")
        for preset in freePresets {
            XCTAssertNil(preset.packId, "Free preset '\(preset.id)' should have nil packId")
        }
    }

    func testPresets_allHaveNonEmptyLeftMapping() {
        for preset in PRESETS {
            XCTAssertFalse(preset.mapping.left.isEmpty, "Preset '\(preset.id)' left mapping should not be empty")
        }
    }

    func testPresets_allHaveNonEmptyRightMapping() {
        for preset in PRESETS {
            XCTAssertFalse(preset.mapping.right.isEmpty, "Preset '\(preset.id)' right mapping should not be empty")
        }
    }

    func testPresets_allHaveNonEmptyNames() {
        for preset in PRESETS {
            XCTAssertFalse(preset.name.isEmpty, "Preset '\(preset.id)' should have a name")
        }
    }

    func testPresets_allHaveNonEmptyEmoji() {
        for preset in PRESETS {
            XCTAssertFalse(preset.emoji.isEmpty, "Preset '\(preset.id)' should have an emoji")
        }
    }

    func testPresets_allHaveNonEmptyDescription() {
        for preset in PRESETS {
            XCTAssertFalse(preset.description.isEmpty, "Preset '\(preset.id)' should have a description")
        }
    }

    func testPresets_colorsAreValidRGB() {
        for preset in PRESETS {
            let (r, g, b) = preset.color
            XCTAssertTrue(r >= 0 && r <= 1, "Preset '\(preset.id)' red \(r) out of [0,1]")
            XCTAssertTrue(g >= 0 && g <= 1, "Preset '\(preset.id)' green \(g) out of [0,1]")
            XCTAssertTrue(b >= 0 && b <= 1, "Preset '\(preset.id)' blue \(b) out of [0,1]")
        }
    }

    func testPresets_freeCount() {
        let freePresets = PRESETS.filter { !$0.isPremium }
        XCTAssertEqual(freePresets.count, 4, "Should have 4 free presets")
    }

    // MARK: - AXIS_DEFS

    func testAxisDefs_hasExpectedCount() {
        XCTAssertEqual(AXIS_DEFS.count, 11)
    }

    func testAxisDefs_allKeysAreUnique() {
        let keys = AXIS_DEFS.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "All axis keys should be unique")
    }

    func testAxisDefs_containsExpectedBasicAxes() {
        let basicKeys = AXIS_DEFS.filter(\.basic).map(\.key)
        XCTAssertTrue(basicKeys.contains("y"))
        XCTAssertTrue(basicKeys.contains("x"))
        XCTAssertTrue(basicKeys.contains("spread"))
    }

    func testAxisDefs_basicAxesCount() {
        let basicAxes = AXIS_DEFS.filter(\.basic)
        XCTAssertEqual(basicAxes.count, 3)
    }

    func testAxisDefs_advancedAxesCount() {
        let advancedAxes = AXIS_DEFS.filter { !$0.basic }
        XCTAssertEqual(advancedAxes.count, 8)
    }

    func testAxisDefs_containsExpectedAdvancedAxes() {
        let advancedKeys = AXIS_DEFS.filter { !$0.basic }.map(\.key)
        XCTAssertTrue(advancedKeys.contains("pinch"))
        XCTAssertTrue(advancedKeys.contains("fist"))
        XCTAssertTrue(advancedKeys.contains("rotation"))
        XCTAssertTrue(advancedKeys.contains("thumbCurl"))
        XCTAssertTrue(advancedKeys.contains("indexCurl"))
        XCTAssertTrue(advancedKeys.contains("middleCurl"))
        XCTAssertTrue(advancedKeys.contains("ringCurl"))
        XCTAssertTrue(advancedKeys.contains("pinkyCurl"))
    }

    func testAxisDefs_yAndX_areInverted() {
        let yAxis = AXIS_DEFS.first { $0.key == "y" }!
        let xAxis = AXIS_DEFS.first { $0.key == "x" }!
        XCTAssertTrue(yAxis.invert)
        XCTAssertTrue(xAxis.invert)
    }

    func testAxisDefs_spread_isNotInverted() {
        let spreadAxis = AXIS_DEFS.first { $0.key == "spread" }!
        XCTAssertFalse(spreadAxis.invert)
    }

    func testAxisDefs_advancedAxes_areNotInverted() {
        let advancedAxes = AXIS_DEFS.filter { !$0.basic }
        for axis in advancedAxes {
            XCTAssertFalse(axis.invert, "Advanced axis '\(axis.key)' should not be inverted")
        }
    }

    func testAxisDefs_allHaveNonEmptyLabels() {
        for axis in AXIS_DEFS {
            XCTAssertFalse(axis.label.isEmpty, "Axis '\(axis.key)' should have a non-empty label")
        }
    }

    func testAxisDefs_allHaveNonEmptyIcons() {
        for axis in AXIS_DEFS {
            XCTAssertFalse(axis.icon.isEmpty, "Axis '\(axis.key)' should have a non-empty icon")
        }
    }

    // MARK: - AXIS_MAP

    func testAxisMap_containsAllAxisDefs() {
        for axis in AXIS_DEFS {
            XCTAssertNotNil(AXIS_MAP[axis.key], "AXIS_MAP should contain key '\(axis.key)'")
        }
    }

    func testAxisMap_sameCountAsAxisDefs() {
        XCTAssertEqual(AXIS_MAP.count, AXIS_DEFS.count)
    }

    // MARK: - DEFAULT_ADVANCED_MAPPING

    func testDefaultAdvancedMapping_leftHasAllAxes() {
        XCTAssertEqual(DEFAULT_ADVANCED_MAPPING.left.count, 11)
    }

    func testDefaultAdvancedMapping_rightHasAllAxes() {
        XCTAssertEqual(DEFAULT_ADVANCED_MAPPING.right.count, 11)
    }

    func testDefaultAdvancedMapping_hasValidParamIds() {
        for (_, paramId) in DEFAULT_ADVANCED_MAPPING.left {
            XCTAssertTrue(
                PARAM_MAP[paramId] != nil || paramId == "none" || paramId == "save",
                "DEFAULT_ADVANCED_MAPPING left param '\(paramId)' should be valid"
            )
        }
        for (_, paramId) in DEFAULT_ADVANCED_MAPPING.right {
            XCTAssertTrue(
                PARAM_MAP[paramId] != nil || paramId == "none" || paramId == "save",
                "DEFAULT_ADVANCED_MAPPING right param '\(paramId)' should be valid"
            )
        }
    }

    // MARK: - DEFAULT_HYDRA_MAPPING

    func testDefaultHydraMapping_allNone() {
        for (_, paramId) in DEFAULT_HYDRA_MAPPING.left {
            XCTAssertEqual(paramId, "none")
        }
        for (_, paramId) in DEFAULT_HYDRA_MAPPING.right {
            XCTAssertEqual(paramId, "none")
        }
    }

    // MARK: - Preset mapping axis keys reference valid AXIS_DEFS

    func testPresets_mappingAxisKeysAreValidAxisDefs() {
        let validKeys = Set(AXIS_DEFS.map(\.key))
        for preset in PRESETS {
            for key in preset.mapping.left.keys {
                XCTAssertTrue(validKeys.contains(key),
                              "Preset '\(preset.id)' left key '\(key)' not in AXIS_DEFS")
            }
            for key in preset.mapping.right.keys {
                XCTAssertTrue(validKeys.contains(key),
                              "Preset '\(preset.id)' right key '\(key)' not in AXIS_DEFS")
            }
        }
    }
}
