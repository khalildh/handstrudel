import XCTest
@testable import HandStrudel

final class CameraFilterTests: XCTestCase {

    // MARK: - Unique IDs

    func testCameraFilters_allHaveUniqueIds() {
        let ids = CAMERA_FILTERS.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "All camera filter IDs should be unique")
    }

    // MARK: - Premium vs Free

    func testCameraFilters_premiumFilters_haveNonNilPackId() {
        let premiumFilters = CAMERA_FILTERS.filter { $0.isPremium }
        XCTAssertGreaterThan(premiumFilters.count, 0, "Should have at least one premium filter")
        for filter in premiumFilters {
            XCTAssertNotNil(filter.packId, "Premium filter '\(filter.id)' should have a packId")
            XCTAssertFalse(filter.packId!.isEmpty, "Premium filter '\(filter.id)' packId should not be empty")
        }
    }

    func testCameraFilters_freeFilters_haveNilPackId() {
        let freeFilters = CAMERA_FILTERS.filter { !$0.isPremium }
        XCTAssertGreaterThan(freeFilters.count, 0, "Should have at least one free filter")
        for filter in freeFilters {
            XCTAssertNil(filter.packId, "Free filter '\(filter.id)' should have nil packId")
        }
    }

    // MARK: - Saturation range (0-3)

    func testCameraFilters_saturation_withinReasonableRange() {
        for filter in CAMERA_FILTERS {
            XCTAssertTrue(filter.saturation >= 0,
                          "Filter '\(filter.id)' saturation \(filter.saturation) should be >= 0")
            XCTAssertTrue(filter.saturation <= 3,
                          "Filter '\(filter.id)' saturation \(filter.saturation) should be <= 3")
        }
    }

    // MARK: - Contrast range (0-2)

    func testCameraFilters_contrast_withinReasonableRange() {
        for filter in CAMERA_FILTERS {
            XCTAssertTrue(filter.contrast >= 0,
                          "Filter '\(filter.id)' contrast \(filter.contrast) should be >= 0")
            XCTAssertTrue(filter.contrast <= 2,
                          "Filter '\(filter.id)' contrast \(filter.contrast) should be <= 2")
        }
    }

    // MARK: - Brightness range (-0.1 to 0.1)

    func testCameraFilters_brightness_withinReasonableRange() {
        for filter in CAMERA_FILTERS {
            XCTAssertTrue(filter.brightness >= -0.1,
                          "Filter '\(filter.id)' brightness \(filter.brightness) should be >= -0.1")
            XCTAssertTrue(filter.brightness <= 0.1,
                          "Filter '\(filter.id)' brightness \(filter.brightness) should be <= 0.1")
        }
    }

    // MARK: - Hue rotation range (0-360)

    func testCameraFilters_hueRotation_withinReasonableRange() {
        for filter in CAMERA_FILTERS {
            XCTAssertTrue(filter.hueRotation >= 0,
                          "Filter '\(filter.id)' hueRotation \(filter.hueRotation) should be >= 0")
            XCTAssertTrue(filter.hueRotation <= 360,
                          "Filter '\(filter.id)' hueRotation \(filter.hueRotation) should be <= 360")
        }
    }

    // MARK: - Overlay opacity range

    func testCameraFilters_overlayOpacity_withinZeroToOne() {
        for filter in CAMERA_FILTERS {
            XCTAssertTrue(filter.overlayOpacity >= 0,
                          "Filter '\(filter.id)' overlayOpacity \(filter.overlayOpacity) should be >= 0")
            XCTAssertTrue(filter.overlayOpacity <= 1,
                          "Filter '\(filter.id)' overlayOpacity \(filter.overlayOpacity) should be <= 1")
        }
    }

    // MARK: - Non-empty metadata

    func testCameraFilters_allHaveNonEmptyNames() {
        for filter in CAMERA_FILTERS {
            XCTAssertFalse(filter.name.isEmpty, "Filter '\(filter.id)' should have a non-empty name")
        }
    }

    func testCameraFilters_allHaveNonEmptyEmoji() {
        for filter in CAMERA_FILTERS {
            XCTAssertFalse(filter.emoji.isEmpty, "Filter '\(filter.id)' should have a non-empty emoji")
        }
    }

    // MARK: - "None" filter

    func testCameraFilters_noneFilter_hasIdentityValues() {
        let noneFilter = CAMERA_FILTERS.first { $0.id == "none" }
        XCTAssertNotNil(noneFilter)
        guard let f = noneFilter else { return }

        XCTAssertEqual(f.saturation, 1.0, "None filter saturation should be 1 (identity)")
        XCTAssertEqual(f.contrast, 1.0, "None filter contrast should be 1 (identity)")
        XCTAssertEqual(f.brightness, 0.0, "None filter brightness should be 0 (identity)")
        XCTAssertEqual(f.hueRotation, 0.0, "None filter hue should be 0 (identity)")
        XCTAssertNil(f.overlayColor, "None filter should have no overlay color")
        XCTAssertEqual(f.overlayOpacity, 0.0, "None filter overlay opacity should be 0")
    }

    func testCameraFilters_noneFilter_isFree() {
        let noneFilter = CAMERA_FILTERS.first { $0.id == "none" }
        XCTAssertNotNil(noneFilter)
        XCTAssertFalse(noneFilter!.isPremium)
        XCTAssertNil(noneFilter!.packId)
    }

    // MARK: - Total count

    func testCameraFilters_hasFreeFilters() {
        let freeCount = CAMERA_FILTERS.filter { !$0.isPremium }.count
        XCTAssertGreaterThanOrEqual(freeCount, 5, "Should have at least 5 free filters")
    }

    func testCameraFilters_hasPremiumFilters() {
        let premiumCount = CAMERA_FILTERS.filter { $0.isPremium }.count
        XCTAssertGreaterThan(premiumCount, 0, "Should have premium filters")
    }

    // MARK: - Premium pack consistency

    func testCameraFilters_premiumFilters_allHaveSamePackId() {
        let premiumFilters = CAMERA_FILTERS.filter { $0.isPremium }
        let packIds = Set(premiumFilters.compactMap(\.packId))
        // All premium camera filters should use "filter_pack"
        XCTAssertEqual(packIds.count, 1, "All premium filters should use the same packId")
        XCTAssertEqual(packIds.first, "filter_pack")
    }

    // MARK: - Noir filter specifics

    func testCameraFilters_noirFilter_hasZeroSaturation() {
        let noir = CAMERA_FILTERS.first { $0.id == "noir" }
        XCTAssertNotNil(noir)
        XCTAssertEqual(noir!.saturation, 0, "Noir should be fully desaturated")
    }
}
