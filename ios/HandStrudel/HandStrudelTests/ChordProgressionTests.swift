import XCTest
@testable import HandStrudel

final class ChordProgressionTests: XCTestCase {

    // MARK: - Library

    func testLibrary_hasAtLeast100Progressions() {
        XCTAssertGreaterThanOrEqual(CHORD_PROGRESSIONS.count, 100)
    }

    func testLibrary_idsAreUnique() {
        let ids = CHORD_PROGRESSIONS.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Progression ids must be unique")
    }

    func testLibrary_allDegreesAreDiatonic() {
        for prog in CHORD_PROGRESSIONS {
            XCTAssertFalse(prog.degrees.isEmpty, "\(prog.id) has no degrees")
            for d in prog.degrees {
                XCTAssertTrue((0...6).contains(d), "\(prog.id) has out-of-range degree \(d)")
            }
        }
    }

    func testLibrary_keepsFreeAsDefault() {
        let free = CHORD_PROGRESSIONS.first(where: { $0.isFree })
        XCTAssertNotNil(free)
        XCTAssertEqual(free?.degrees, [0, 1, 2, 3, 4, 5, 6])
    }

    // MARK: - Parsing

    func testParse_romanNumerals() {
        XCTAssertEqual(ChordProgression.parse("I V vi IV")?.degrees, [0, 4, 5, 3])
    }

    func testParse_scaleDegreeNumbers() {
        XCTAssertEqual(ChordProgression.parse("1 5 6 4")?.degrees, [0, 4, 5, 3])
    }

    func testParse_acceptsCommonSeparators() {
        XCTAssertEqual(ChordProgression.parse("I-V-vi-IV")?.degrees, [0, 4, 5, 3])
        XCTAssertEqual(ChordProgression.parse("I, V, vi, IV")?.degrees, [0, 4, 5, 3])
        XCTAssertEqual(ChordProgression.parse("I → V → vi → IV")?.degrees, [0, 4, 5, 3])
        XCTAssertEqual(ChordProgression.parse("I/V/vi/IV")?.degrees, [0, 4, 5, 3])
    }

    func testParse_ignoresChordQualitiesAndExtensions() {
        XCTAssertEqual(ChordProgression.parse("Imaj7 V7 vi9 IVadd9")?.degrees, [0, 4, 5, 3])
        XCTAssertEqual(ChordProgression.parse("ii7 V7 Imaj7")?.degrees, [1, 4, 0])
    }

    func testParse_isCaseInsensitive() {
        XCTAssertEqual(ChordProgression.parse("i iv v")?.degrees, [0, 3, 4])
        XCTAssertEqual(ChordProgression.parse("VII")?.degrees, [6])
    }

    func testParse_skipsUnparseableTokensButKeepsValidOnes() {
        XCTAssertEqual(ChordProgression.parse("I foo V bar IV")?.degrees, [0, 4, 3])
        // Out-of-range numbers (0, 8, 9) are dropped.
        XCTAssertEqual(ChordProgression.parse("1 8 5 0 6")?.degrees, [0, 4, 5])
    }

    func testParse_returnsNilForNoParseableContent() {
        XCTAssertNil(ChordProgression.parse(""))
        XCTAssertNil(ChordProgression.parse("   "))
        XCTAssertNil(ChordProgression.parse("hello world"))
    }

    func testParse_marksResultAsCustom() {
        let prog = ChordProgression.parse("I V vi IV")
        XCTAssertEqual(prog?.isCustom, true)
        XCTAssertFalse(prog?.isFree ?? true)
    }
}
