import XCTest
@testable import HandStrudel

/// Instrument files (`shared/instruments/`): loading rules, the bundled
/// library, and the wheel playing from a file.
final class InstrumentSpecTests: XCTestCase {
    private static let instrumentsFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // HandStrudelTests
        .deletingLastPathComponent()      // HandStrudel (project)
        .deletingLastPathComponent()      // ios
        .deletingLastPathComponent()      // repo root
        .appendingPathComponent("shared/instruments")

    // MARK: Shared fixtures

    /// Every case in `shared/instruments/fixtures/`. Another implementation
    /// of the format (the web app) must pass the same files.
    func testSharedFixtures() throws {
        let folder = Self.instrumentsFolder.appendingPathComponent("fixtures")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertGreaterThanOrEqual(files.count, 30)

        for file in files {
            let name = file.lastPathComponent
            let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any], name)
            let input = try JSONSerialization.data(withJSONObject: XCTUnwrap(fixture["input"], name))
            let expect = try XCTUnwrap(fixture["expect"] as? [String: Any], name)
            let result = InstrumentSpec.load(input)

            XCTAssertEqual(result.accepted, expect["accepted"] as? Bool, name)
            XCTAssertEqual(result.issues.map(\.rawValue), expect["issues"] as? [String], name)
            guard let spec = result.spec else { continue }
            if let surface = expect["surface"] as? [String: Double] {
                XCTAssertEqual(spec.surface.radius, surface["radius"], name)
                XCTAssertEqual(spec.surface.restRadius, surface["rest_radius"], name)
                XCTAssertEqual(spec.surface.octaveBandRadius, surface["octave_band_radius"], name)
            }
            if let expectedName = expect["name"] as? String { XCTAssertEqual(spec.name, expectedName, name) }
            if let count = expect["zone_count"] as? Int { XCTAssertEqual(spec.layout?.zones.count, count, name) }
            if let values = expect["values"] as? [String: Any] {
                let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(spec)) as? [String: Any])
                for (path, expected) in values {
                    let actual = Self.value(at: path, in: encoded)
                    if let number = expected as? Double, !(expected is Bool) {
                        XCTAssertEqual((actual as? Double) ?? .nan, number, accuracy: 0.000001, "\(name): \(path)")
                    } else {
                        XCTAssertEqual(actual.map { "\($0)" }, "\(expected)", "\(name): \(path)")
                    }
                }
            }
            // A repaired instrument loads cleanly the second time.
            XCTAssertEqual(InstrumentSpec.load(try JSONEncoder().encode(spec)).issues, [], name)
        }
    }

    /// `zones.0.frame.w` style paths into decoded JSON.
    private static func value(at path: String, in object: Any) -> Any? {
        path.split(separator: ".").reduce(Optional(object)) { current, key in
            if let array = current as? [Any], let index = Int(key) { return array.indices.contains(index) ? array[index] : nil }
            return (current as? [String: Any])?[String(key)]
        }
    }

    func testOversizedAndNonJSONFilesAreRejected() {
        XCTAssertEqual(InstrumentSpec.load(Data(repeating: 32, count: InstrumentSpec.byteLimit + 1)).issues, [.tooLarge])
        XCTAssertEqual(InstrumentSpec.load(Data("not json".utf8)).issues, [.malformed])
        XCTAssertEqual(InstrumentSpec.load(Data("[]".utf8)).issues, [.malformed])
    }

    // MARK: Bundled library

    func testBundledLibraryLoadsEveryFileCleanly() throws {
        let folder = Self.instrumentsFolder.appendingPathComponent("library")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        for file in files {
            XCTAssertEqual(InstrumentSpec.load(try Data(contentsOf: file)).issues, [], file.lastPathComponent)
        }
        let ids = InstrumentLibrary.all.map(\.id)
        XCTAssertEqual(ids.count, files.count, "Every library file is in the app bundle.")
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Array(ids.prefix(2)).sorted(), [InstrumentLibrary.scaleWheelID, InstrumentLibrary.splitWheelID])
        XCTAssertTrue(ids.contains("demo.wide-wheel"))
    }

    /// The built-in wheels now come from files; they must describe exactly the
    /// behaviour that used to be hard-coded.
    func testBuiltInWheelFilesMatchTheOriginalWheels() {
        let scale = InstrumentLibrary.scaleWheel.rules
        XCTAssertEqual(scale, WheelRules(geometry: .standard, chordsOnRight: false, voicing: .seventh,
                                         noteSource: .scaleOneOctave, notesOctaveBand: true, highlightChordTones: true))
        let split = InstrumentLibrary.splitWheel.rules
        XCTAssertEqual(split, WheelRules(geometry: .standard, chordsOnRight: false, voicing: .triad,
                                         noteSource: .chordTonesThreeOctaves, notesOctaveBand: false,
                                         highlightChordTones: false))
        XCTAssertEqual(WheelGeometry.standard, WheelGeometry(radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.80))

        for (key, mode) in [(MusicKey.C, Scale.major), (.D, .minor), (.Eb, .pentatonic)] {
            for degree in 0..<7 {
                XCTAssertEqual(scale.chordTones(key: key, scale: mode, degree: degree),
                               chordNotesWithSeventh(key: key, scale: mode, degree: degree))
                XCTAssertEqual(scale.noteLanes(key: key, scale: mode, chordDegree: degree),
                               scaleNotesOneOctave(key: key, scale: mode))
                let triad = chordNotes(key: key, scale: mode, degree: degree)
                XCTAssertEqual(split.chordTones(key: key, scale: mode, degree: degree), triad)
                XCTAssertEqual(split.noteLanes(key: key, scale: mode, chordDegree: degree),
                               (0..<3).flatMap { octave in triad.map { $0 + octave * 12 } }.sorted())
            }
        }
        XCTAssertEqual(scale.chordNameSuffix, "⁷")
        XCTAssertEqual(split.chordNameSuffix, "")
    }

    func testChordToneHighlightFollowsTheInstrument() {
        let scale = InstrumentLibrary.scaleWheel.rules
        let lanes = scale.noteLanes(key: .C, scale: .major, chordDegree: 0)  // C D E F G A B
        XCTAssertEqual(scale.chordToneLanes(key: .C, scale: .major, chordDegree: 0, lanes: lanes), [0, 2, 4, 6])
        XCTAssertEqual(InstrumentLibrary.splitWheel.rules.chordToneLanes(key: .C, scale: .major, chordDegree: 0, lanes: lanes), [])
    }

    func testChordSideIsMirroredBySwapHands() {
        var rightHanded = InstrumentLibrary.scaleWheel.rules
        XCTAssertFalse(rightHanded.swapHands(playerSwap: false))
        XCTAssertTrue(rightHanded.swapHands(playerSwap: true))
        rightHanded.chordsOnRight = true
        XCTAssertTrue(rightHanded.swapHands(playerSwap: false))
        XCTAssertFalse(rightHanded.swapHands(playerSwap: true))
    }

    // MARK: Playing a file

    /// An instrument changes the wheel, never the sound: it adapts to the
    /// player's key, scale and progression.
    @MainActor
    func testPlayingAnInstrumentKeepsThePlayersSoundAndAdaptsToIt() throws {
        let engine = EngineController()
        engine.selectedKey = .D
        engine.selectedScale = .pentatonic
        engine.manualBPM = 97
        let progression = engine.chordMelodyProgression
        let soundFont = engine.selectedSoundFontInstrument
        let wide = try XCTUnwrap(InstrumentLibrary.builtIn("demo.wide-wheel"))

        engine.playInstrument(wide)
        XCTAssertTrue(engine.scaleChordMelodyModeEnabled)
        XCTAssertEqual(engine.customInstrument, wide)
        XCTAssertEqual(engine.wheelInstrument.id, wide.id)
        XCTAssertEqual(engine.selectedKey, .D)
        XCTAssertEqual(engine.selectedScale, .pentatonic)
        XCTAssertEqual(engine.manualBPM, 97)
        XCTAssertEqual(engine.chordMelodyProgression.id, progression.id)
        XCTAssertEqual(engine.selectedSoundFontInstrument, soundFont)

        engine.configureWheelManager()
        let manager = engine.chordMelodyModeManager
        XCTAssertEqual(manager.layout, .scale)
        XCTAssertEqual(manager.geometry, WheelGeometry(radius: 1.0, restRadius: 0.26, octaveBandRadius: 0.7))
        let tones = engine.chordMelodyTones(key: engine.selectedKey, scale: engine.selectedScale)
        XCTAssertEqual(tones.melody(0).count, 5, "One wedge per note of the player's pentatonic scale.")
        XCTAssertEqual(tones.chord(0), chordNotesWithSeventh(key: .D, scale: .pentatonic, degree: 0),
                       "Chords keep the Scale wheel's voicing; the instrument doesn't choose it.")

        // Changing the player's scale reshapes the same instrument.
        engine.selectedScale = .major
        XCTAssertEqual(engine.chordMelodyTones(key: .D, scale: engine.selectedScale).melody(0).count, 7)
        XCTAssertEqual(engine.customInstrument, wide)

        engine.switchMode(grid: false, drums: false, learn: false, scaleChordMelody: true)
        XCTAssertNil(engine.customInstrument)
        XCTAssertEqual(engine.wheelInstrument.id, InstrumentLibrary.scaleWheelID)
    }

    @MainActor
    func testPlayingABuiltInWheelFileSwitchesMode() {
        let engine = EngineController()
        engine.selectedKey = .A
        engine.playInstrument(InstrumentLibrary.splitWheel)
        XCTAssertTrue(engine.splitChordMelodyModeEnabled)
        XCTAssertFalse(engine.scaleChordMelodyModeEnabled)
        XCTAssertNil(engine.customInstrument)
        XCTAssertEqual(engine.selectedKey, .A)
        engine.configureWheelManager()
        XCTAssertEqual(engine.chordMelodyModeManager.layout, .split)
        XCTAssertEqual(engine.chordMelodyModeManager.geometry, .standard)
    }

    // MARK: Geometry reaches touch and hand tracking

    @MainActor
    func testTouchUsesTheInstrumentsRestHoleAndOctaveRim() {
        let wheel = SplitTouchUIView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        wheel.zoneCount = 4
        wheel.melodyCount = 5
        wheel.melodyOctaveBand = true
        let center = CGPoint(x: 200, y: 200)
        func point(_ degrees: Double, _ fraction: Double, radius: Double) -> CGPoint {
            let a = degrees * .pi / 180
            return CGPoint(x: center.x + sin(a) * 200 * radius * fraction, y: center.y - cos(a) * 200 * radius * fraction)
        }
        let wedge = 180.0 / 5
        // Standard wheel: 0.32 of the radius is still the rest hole.
        XCTAssertNil(wheel.zone(at: point(0.5 * wedge, 0.32, radius: 1)))

        wheel.geometry = WheelGeometry(radius: 0.94, restRadius: 0.28, octaveBandRadius: 0.74)
        XCTAssertEqual(wheel.zone(at: point(0.5 * wedge, 0.32, radius: 0.94)), .melody(MelodySubzone(lane: 4, octave: 0)))
        XCTAssertEqual(wheel.zone(at: point(0.25 * wedge, 0.77, radius: 0.94)), .melody(MelodySubzone(lane: 4, octave: 1)))
        XCTAssertEqual(wheel.zone(at: point(0.75 * wedge, 0.77, radius: 0.94)), .melody(MelodySubzone(lane: 4, octave: -1)))
        XCTAssertNil(wheel.zone(at: point(0.5 * wedge, 0.25, radius: 0.94)))
    }

    func testHandTrackedOctaveRimFollowsTheInstrumentGeometry() {
        let manager = ChordMelodyModeManager()
        manager.layout = .scale
        XCTAssertEqual(manager.splitOctaveShift(side: .right, angle: 5, radius: 0.85, wedgeIndex: 0, count: 7), 1)
        manager.geometry = WheelGeometry(radius: 1, restRadius: 0.3, octaveBandRadius: 0.9)
        XCTAssertEqual(manager.splitOctaveShift(side: .right, angle: 5, radius: 0.85, wedgeIndex: 0, count: 7), 0,
                       "The rim starts where the instrument says.")
    }
}
