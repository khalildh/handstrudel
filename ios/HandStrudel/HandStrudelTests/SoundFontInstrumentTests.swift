import XCTest
@testable import HandStrudel

final class SoundFontInstrumentTests: XCTestCase {

    func testInstrumentListNonEmpty() {
        XCTAssertFalse(SOUNDFONT_INSTRUMENTS.isEmpty)
    }

    func testIdsAreUnique() {
        let ids = SOUNDFONT_INSTRUMENTS.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "instrument ids must be unique")
    }

    func testProgramsAreValidGM() {
        for inst in SOUNDFONT_INSTRUMENTS {
            XCTAssertTrue((0...127).contains(Int(inst.program)),
                          "\(inst.id) program \(inst.program) out of GM range")
        }
    }

    func testDefaultIsFirst() {
        XCTAssertEqual(DEFAULT_SOUNDFONT_INSTRUMENT.id, SOUNDFONT_INSTRUMENTS.first?.id)
    }

    func testLookupReturnsMatch() {
        let target = SOUNDFONT_INSTRUMENTS[3]
        XCTAssertEqual(soundFontInstrument(id: target.id), target)
    }

    func testLookupFallsBackToDefault() {
        XCTAssertEqual(soundFontInstrument(id: "does-not-exist"), DEFAULT_SOUNDFONT_INSTRUMENT)
    }

    func testDisplayNameIncludesEmojiAndName() {
        let inst = DEFAULT_SOUNDFONT_INSTRUMENT
        XCTAssertTrue(inst.displayName.contains(inst.name))
        XCTAssertTrue(inst.displayName.contains(inst.emoji))
    }
}
