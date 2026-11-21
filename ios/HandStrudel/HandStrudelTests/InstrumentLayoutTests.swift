import XCTest
@testable import HandStrudel

/// Format 2 instruments: the starter library, hit-testing on every surface at
/// real screen coordinates, the playability rules, and what zones send to the
/// engine with the player's music.
@MainActor
final class InstrumentLayoutTests: XCTestCase {
    /// A phone-sized play area (the hit-test expectations below are computed from it).
    private let rect = CGRect(x: 14, y: 100, width: 362, height: 600)

    private func starter(_ id: String) throws -> InstrumentSpec {
        try XCTUnwrap(InstrumentLibrary.builtIn("builtin.\(id)"), id)
    }

    private func geometry(_ id: String) throws -> InstrumentSurfaceGeometry {
        InstrumentSurfaceGeometry(layout: try XCTUnwrap(starter(id).layout), rect: rect)
    }

    /// A point at `degrees` clockwise from up and `radius` points from `center`.
    private func polar(_ center: CGPoint, _ degrees: Double, _ radius: CGFloat) -> CGPoint {
        let angle = degrees * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(sin(angle)), y: center.y - radius * CGFloat(cos(angle)))
    }

    // MARK: Starter library

    func testStarterLibraryCoversEverySurfaceAndEveryZoneIsPlayable() throws {
        let surfaces = Set(InstrumentLibrary.all.map(\.surfaceType))
        let expected = Set(InstrumentLayout.Surface.Kind.allCases.map(\.rawValue) + ["split_wheel"])
        XCTAssertEqual(surfaces, expected)
        let starters = InstrumentLibrary.all.filter(\.isSurfaceInstrument)
        XCTAssertGreaterThanOrEqual(starters.count, 10)

        for spec in starters {
            let layout = try XCTUnwrap(spec.layout)
            XCTAssertEqual(spec.formatVersion, 2, spec.id)
            for area in [InstrumentSurfaceGeometry.referenceRect, rect] {
                let geometry = InstrumentSurfaceGeometry(layout: layout, rect: area)
                for index in layout.zones.indices {
                    let shape = geometry.shape(of: index)
                    // Every zone is big enough and reachable at its centre.
                    XCTAssertGreaterThanOrEqual(shape.minimumSide, InstrumentSurfaceGeometry.minimumZoneSide - 0.01,
                                                "\(spec.id) zone \(index)")
                    XCTAssertEqual(geometry.hit(shape.anchor)?.zone, index, "\(spec.id) zone \(index)")
                    XCTAssertEqual(geometry.hit(shape.anchor)?.octave, 0, "\(spec.id) zone \(index) middle band")
                }
            }
        }
    }

    func testStarterInstrumentsNeverCarryMusicSettings() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("shared/instruments/library")
        let banned = ["key", "scale", "tempo", "bpm", "sound", "instrument", "voicing", "midi", "notes_override", "progression"]
        for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        where file.pathExtension == "json" {
            let text = try String(contentsOf: file)
            for word in banned { XCTAssertFalse(text.contains("\"\(word)\""), "\(file.lastPathComponent) has \(word)") }
        }
    }

    // MARK: Hit-testing at real coordinates

    func testGridHitTesting() throws {
        let grid = try geometry("note-grid") // 3×3, cells 120.67×200, top row first
        XCTAssertEqual(grid.hit(CGPoint(x: 74, y: 200))?.zone, 0)
        XCTAssertEqual(grid.hit(CGPoint(x: 195, y: 400))?.zone, 4)
        XCTAssertEqual(grid.hit(CGPoint(x: 366, y: 690))?.zone, 8)
        XCTAssertEqual(grid.hit(CGPoint(x: 140, y: 650))?.zone, 7)
        XCTAssertNil(grid.hit(CGPoint(x: 10, y: 400)), "left of the play area")
        XCTAssertNil(grid.hit(CGPoint(x: 195, y: 705)), "below the play area")
    }

    func testKeysHitTestingWithOctaveBands() throws {
        let keys = try geometry("scale-keys") // 7 keys of 51.7 points, bands in the top and bottom 28%
        XCTAssertEqual(keys.hit(CGPoint(x: 143, y: 400)), InstrumentHit(zone: 2, octave: 0))
        XCTAssertEqual(keys.hit(CGPoint(x: 143, y: 120)), InstrumentHit(zone: 2, octave: 1))
        XCTAssertEqual(keys.hit(CGPoint(x: 143, y: 690)), InstrumentHit(zone: 2, octave: -1))
        XCTAssertEqual(keys.hit(CGPoint(x: 20, y: 400))?.zone, 0)
        XCTAssertEqual(keys.hit(CGPoint(x: 370, y: 400))?.zone, 6)
    }

    func testVerticalStripsAreLowToHighAndRespectHands() throws {
        let strips = try geometry("strum-ladder") // 10 strips of 60 points, bottom up; 0–3 left hand, 4–9 right
        let bottom = CGPoint(x: 195, y: 690), top = CGPoint(x: 195, y: 105)
        XCTAssertEqual(strips.hit(bottom)?.zone, 0)
        XCTAssertEqual(strips.hit(top)?.zone, 9)
        XCTAssertEqual(strips.hit(CGPoint(x: 195, y: 470))?.zone, 3)
        XCTAssertEqual(strips.hit(bottom, hand: .left)?.zone, 0)
        XCTAssertNil(strips.hit(bottom, hand: .right), "a chord rung belongs to the left hand")
        XCTAssertEqual(strips.hit(top, hand: .right)?.zone, 9)
    }

    func testRadialHitTesting() throws {
        let halo = try geometry("halo") // 7 wedges of 51.4°, ring 54.3–181 points round (195, 400)
        let center = CGPoint(x: 195, y: 400)
        XCTAssertEqual(halo.hit(polar(center, 10, 118)), InstrumentHit(zone: 0, octave: 0))
        XCTAssertEqual(halo.hit(polar(center, 10, 172)), InstrumentHit(zone: 0, octave: 1))
        XCTAssertEqual(halo.hit(polar(center, 10, 60)), InstrumentHit(zone: 0, octave: -1))
        XCTAssertEqual(halo.hit(polar(center, 100, 118))?.zone, 1)
        XCTAssertEqual(halo.hit(polar(center, 200, 118))?.zone, 3)
        XCTAssertEqual(halo.hit(polar(center, 350, 118))?.zone, 6)
        XCTAssertNil(halo.hit(center), "the centre rests")
        XCTAssertNil(halo.hit(polar(center, 10, 185)), "outside the ring")
    }

    func testArcHitTesting() throws {
        let arc = try geometry("rainbow-arc") // 7 wedges over −90…90°, radius 181 from (195, 700)
        let center = CGPoint(x: 195, y: 700)
        XCTAssertEqual(arc.hit(polar(center, -80, 125))?.zone, 0)
        XCTAssertEqual(arc.hit(polar(center, 0, 125))?.zone, 3)
        XCTAssertEqual(arc.hit(polar(center, 85, 125))?.zone, 6)
        XCTAssertNil(arc.hit(polar(center, 0, 40)), "inside the arc's hole")
        XCTAssertNil(arc.hit(polar(center, -120, 125)), "past the arc's start")
    }

    func testPadsHitTesting() throws {
        let pads = try geometry("drum-pads") // round pads inscribed in their frames
        XCTAssertEqual(pads.hit(CGPoint(x: 108, y: 202))?.zone, 0, "crash")
        XCTAssertNil(pads.hit(CGPoint(x: 34, y: 126)), "frame corner is outside the round pad")
        XCTAssertEqual(pads.hit(CGPoint(x: 108, y: 598))?.zone, 4, "kick")
        XCTAssertEqual(pads.hit(CGPoint(x: 282, y: 598))?.zone, 5, "snare")
        XCTAssertNil(pads.hit(CGPoint(x: 195, y: 400)), "between pads")
    }

    func testOrbsAreHitWhereTheyHaveMoved() throws {
        // Drift: orb 0 rests centred at (104.5, 205), r 54.3, drifting up to 9.05 points.
        let drift = try geometry("floating-orbs")
        XCTAssertEqual(drift.hit(CGPoint(x: 104.5, y: 264), time: 0)?.zone, 0)
        XCTAssertNil(drift.hit(CGPoint(x: 104.5, y: 155), time: 0), "the orb has drifted down at t=0")
        let right = CGPoint(x: 163.5, y: 207.4)
        XCTAssertNil(drift.hit(right, time: 0))
        XCTAssertEqual(drift.hit(right, time: 2.25)?.zone, 0, "a quarter period later it has drifted right")

        // Pulse: orb 0 centred at (108.1, 235), r 72.4, swelling by up to 10.9 points.
        let pulse = try geometry("pulse-chords")
        let rim = CGPoint(x: 108.1 + 78, y: 235)
        XCTAssertNil(pulse.hit(rim, time: 0))
        XCTAssertEqual(pulse.hit(rim, time: 1)?.zone, 0, "swollen at a quarter period")
    }

    // MARK: Playability rules

    private func load(_ surface: InstrumentLayout.Surface, _ zones: [InstrumentLayout.Zone],
                      gestures: InstrumentLayout.Gestures = .init()) -> InstrumentLoadResult {
        let spec = InstrumentSpec(format: InstrumentSpec.formatName, formatVersion: 2, id: "community.test", name: "Test",
                                  description: nil, surface: InstrumentSpec.unusedWheel, chords: .init(side: .left),
                                  notes: .init(source: .scaleOneOctave, octaveBand: false, highlightChordTones: nil),
                                  layout: InstrumentLayout(surface: surface, zones: zones, gestures: gestures))
        return spec.validated()
    }

    func testMinimumZoneSizeIsEnforcedOnEverySurface() throws {
        let note = InstrumentLayout.Zone(role: .note, degree: 0)
        // Keys: 7 across, 12 up.
        XCTAssertEqual(load(.init(type: .keys), Array(repeating: note, count: 8)).spec?.layout?.zones.count, 7)
        XCTAssertEqual(load(.init(type: .keys, orientation: .vertical), Array(repeating: note, count: 13)).spec?.layout?.zones.count, 10)
        // Radial and arc capacity follows the ring.
        let radial = load(.init(type: .radial, innerRadius: 0.2, outerRadius: 0.6), Array(repeating: note, count: 16))
        XCTAssertEqual(radial.issues, [.zonesDropped])
        let ring = try XCTUnwrap(radial.spec?.layout)
        let geometry = InstrumentSurfaceGeometry(layout: ring, rect: InstrumentSurfaceGeometry.referenceRect)
        for index in ring.zones.indices {
            XCTAssertGreaterThanOrEqual(geometry.shape(of: index).minimumSide, 44)
        }
        // Pads grow.
        let tiny = InstrumentLayout.Zone(role: .note, degree: 0, frame: .init(x: 0.4, y: 0.4, w: 0.01, h: 0.01))
        let grown = try XCTUnwrap(load(.init(type: .pads), [tiny]).spec?.layout)
        let pad = InstrumentSurfaceGeometry(layout: grown, rect: InstrumentSurfaceGeometry.referenceRect).shape(of: 0)
        XCTAssertGreaterThanOrEqual(pad.minimumSide, 44 - 0.01)
    }

    func testZoneCountPerHand() {
        let any = InstrumentLayout.Zone(role: .note, degree: 0)
        XCTAssertEqual(load(.init(type: .grid, rows: 4, columns: 5), Array(repeating: any, count: 20)).spec?.layout?.zones.count, 16)
        var left = any; left.hand = .left
        var right = any; right.hand = .right
        let split = load(.init(type: .grid, rows: 6, columns: 6), Array(repeating: left, count: 17) + Array(repeating: right, count: 3))
        XCTAssertEqual(split.spec?.layout?.zones.filter { $0.hand == .left }.count, 16)
        XCTAssertEqual(split.spec?.layout?.zones.filter { $0.hand == .right }.count, 3)
    }

    func testOverlappingZonesAreRejected() {
        func pad(_ x: Double, _ y: Double) -> InstrumentLayout.Zone {
            .init(role: .note, degree: 0, frame: .init(x: x, y: y, w: 0.3, h: 0.2), shape: .rounded)
        }
        XCTAssertEqual(load(.init(type: .pads), [pad(0.1, 0.1), pad(0.35, 0.2)]).issues, [.zonesOverlap])
        XCTAssertEqual(load(.init(type: .pads), [pad(0.1, 0.1), pad(0.4, 0.1)]).issues, [], "touching edges are fine")
        // Orbs apart at rest overlap once their drift is counted.
        XCTAssertEqual(load(.init(type: .orbs, motion: .drift, amount: 0, period: 8), [pad(0.1, 0.1), pad(0.42, 0.1)]).issues, [])
        XCTAssertEqual(load(.init(type: .orbs, motion: .drift, amount: 0.05, period: 8), [pad(0.1, 0.1), pad(0.42, 0.1)]).issues,
                       [.zonesOverlap])
    }

    func testOneExpressionPerGesture() throws {
        typealias G = InstrumentLayout.GestureExpression
        let result = load(.init(type: .keys), [.init(role: .note, degree: 0)], gestures: .init(play: .pinch, expressions: [
            G(hand: .right, input: .rotation, parameter: .filter),
            G(hand: .right, input: .rotation, parameter: .reverb),   // same gesture
            G(hand: .left, input: .pinch, parameter: .delay),        // the play gesture
            G(hand: .left, input: .y, parameter: .filter),           // filter already driven
            G(hand: .left, input: .y, parameter: .reverb),
        ]))
        XCTAssertEqual(result.issues, [.gestureDropped])
        XCTAssertEqual(try XCTUnwrap(result.spec?.layout).gestures.expressions.map(\.parameter), [.filter, .reverb])
        // With hover play, pinch is free to shape the sound.
        let hover = load(.init(type: .keys), [.init(role: .note, degree: 0)], gestures: .init(play: .hover, expressions: [
            G(hand: .left, input: .pinch, parameter: .delay),
        ]))
        XCTAssertEqual(hover.issues, [])
    }

    func testV1FilesStillLoadAndWheelsKeepTheirFields() throws {
        XCTAssertEqual(InstrumentLibrary.scaleWheel.formatVersion, 1)
        XCTAssertNil(InstrumentLibrary.scaleWheel.layout)
        XCTAssertFalse(InstrumentLibrary.scaleWheel.isSurfaceInstrument)
        let encoded = try JSONEncoder().encode(InstrumentLibrary.scaleWheel)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(object["zones"], "wheels encode exactly as format 1")
        XCTAssertNotNil(object["chords"])
        let grid = try starter("note-grid")
        let gridObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(grid)) as? [String: Any])
        XCTAssertNil(gridObject["chords"], "surfaces encode without wheel fields")
        XCTAssertEqual(InstrumentSpec.load(try JSONEncoder().encode(grid)).spec, grid)
    }

    // MARK: Playing: zones resolve against the player's music

    private final class RecordingSink: InstrumentSoundSink {
        var events: [String] = []
        func instrumentNoteOn(voice: String, midi: Int, velocity: Double) { events.append("on:\(midi)") }
        func instrumentNoteOff(voice: String) { events.append("off:\(voice)") }
        func instrumentOneShot(midis: [Int], velocity: Double, duration: Double) {
            events.append("play:" + midis.map(String.init).joined(separator: ","))
        }
        func instrumentDrum(_ drum: InstrumentLayout.Drum) { events.append("hit:\(drum.rawValue)") }
        func instrumentExpression(_ parameter: InstrumentLayout.Expression, value: Double) {
            events.append("fx:\(parameter.rawValue)=\(String(format: "%.2f", value))")
        }
        var notes: [String] { events.filter { $0.hasPrefix("on:") || $0.hasPrefix("play:") } }
    }

    private func player(_ id: String, key: MusicKey = .C, scale: Scale = .major) throws -> (InstrumentSurfacePlayer, RecordingSink) {
        let player = InstrumentSurfacePlayer()
        let sink = RecordingSink()
        player.sink = sink
        player.clock = { 0 }
        player.playRect = rect
        player.context = InstrumentMusicContext(key: key, scale: scale, progression: [0, 4, 5, 3])
        player.load(try starter(id))
        return (player, sink)
    }

    private func center(_ player: InstrumentSurfacePlayer, _ zone: Int) -> CGPoint {
        player.geometry!.shape(of: zone).anchor
    }

    func testNotesFollowThePlayersKeyAndScale() throws {
        let (player, sink) = try self.player("note-grid")
        player.begin("t1", at: center(player, 6)) // degree 0, bottom left
        player.end("t1")
        player.begin("t2", at: center(player, 2)) // degree 8 = second degree, an octave up
        player.end("t2")
        XCTAssertEqual(sink.notes, ["on:60", "on:74"])
        XCTAssertEqual(sink.events.filter { $0.hasPrefix("off:") }.count, 2, "hold releases on lift")

        // Same instrument, different player settings: different notes.
        let (pentatonic, other) = try self.player("note-grid", key: .D, scale: .pentatonic)
        pentatonic.begin("t1", at: center(pentatonic, 6))
        pentatonic.begin("t2", at: center(pentatonic, 2)) // degree 8 of 5 = 4th degree up an octave
        XCTAssertEqual(other.notes, ["on:62", "on:81"])
    }

    func testChordsFollowTheProgressionAndChordTonesFollowTheHeldChord() throws {
        let (player, sink) = try self.player("strum-ladder")
        player.begin("tone", at: center(player, 4), hand: nil) // root of the resting chord (I = C)
        player.end("tone")
        player.begin("chord", at: center(player, 1)) // progression slot 1 = V = G
        player.begin("tone", at: center(player, 5)) // third of G
        XCTAssertEqual(sink.notes, ["play:60", "on:55", "on:59", "on:62", "play:71"])
        XCTAssertEqual(player.heldChordDegree, 4)
        player.end("chord")
        XCTAssertEqual(player.heldChordDegree, 4, "chord tones keep following the last chord")

        // A tracked right hand can't play the left hand's chord rungs.
        player.begin("hand-right", at: center(player, 0), hand: .right)
        XCTAssertEqual(sink.notes.count, 5)
    }

    func testDraggingAcrossKeysReplaysAndOctaveBandsShift() throws {
        let (player, sink) = try self.player("scale-keys")
        let first = center(player, 0)
        player.begin("t", at: first)
        player.move("t", to: CGPoint(x: first.x, y: first.y + 10)) // same zone, same band: nothing new
        player.move("t", to: center(player, 1))
        player.move("t", to: CGPoint(x: center(player, 1).x, y: rect.minY + 10)) // top band
        player.end("t")
        XCTAssertEqual(sink.notes, ["on:60", "on:62", "on:74"])
        XCTAssertEqual(sink.events.filter { $0.hasPrefix("off:") }.count, 3)
    }

    func testLatchKeepsChordsUntilTappedAgain() throws {
        let (player, sink) = try self.player("chord-ring")
        player.begin("t", at: center(player, 2))
        player.end("t")
        XCTAssertEqual(sink.notes, ["on:57", "on:60", "on:64"], "slot 2 = vi = A minor")
        XCTAssertFalse(sink.events.contains { $0.hasPrefix("off:") }, "still sounding after lift")
        XCTAssertEqual(player.latchedZones, [2])
        player.begin("t", at: center(player, 2))
        player.end("t")
        XCTAssertEqual(sink.events.filter { $0.hasPrefix("off:") }.count, 3)
        XCTAssertEqual(player.latchedZones, [])
    }

    func testDrumsAndBassAndExpressionZones() throws {
        let (drums, drumSink) = try player("beat-box")
        drums.begin("a", at: center(drums, 2))
        drums.begin("b", at: center(drums, 5))
        XCTAssertEqual(drumSink.events.first, "hit:kick")
        XCTAssertEqual(drumSink.notes, ["on:48"], "bass root an octave down")

        let (synth, sink) = try player("synth-pads")
        let strip = synth.geometry!.shape(of: 5).bounds
        synth.begin("f", at: CGPoint(x: strip.minX + 1, y: strip.midY))
        synth.move("f", to: CGPoint(x: strip.maxX + 40, y: strip.minY - 80)) // captured: keeps controlling
        XCTAssertEqual(sink.events, ["fx:filter=0.00", "fx:filter=1.00"])
    }

    func testLatchedOrbsPlayAtEveryMomentOfTheirPulse() throws {
        let (player, sink) = try self.player("pulse-chords")
        player.playRect = CGRect(x: 14, y: 158, width: 374, height: 542) // iPhone 17 Pro, as the app lays it out
        for step in 0..<16 {
            let time = Double(step) * 0.25
            player.clock = { time }
            let geometry = try XCTUnwrap(player.geometry)
            for zone in 0..<4 {
                XCTAssertEqual(geometry.hit(geometry.shape(of: zone, time: time).anchor, time: time)?.zone, zone, "t=\(time)")
            }
        }
        player.begin("a", at: center(player, 0)); player.end("a")
        player.begin("b", at: center(player, 3)); player.end("b")
        XCTAssertEqual(sink.notes.count, 6, "\(sink.events)")
    }

    func testEngineSwitchesToAndFromASurfaceInstrument() throws {
        let engine = EngineController()
        engine.selectedKey = .E
        engine.playInstrument(try starter("halo"))
        XCTAssertEqual(engine.surfaceInstrument?.id, "builtin.halo")
        XCTAssertEqual(engine.instrumentSurface.instrument?.id, "builtin.halo")
        XCTAssertFalse(engine.scaleChordMelodyModeEnabled || engine.splitChordMelodyModeEnabled)
        XCTAssertEqual(engine.selectedKey, .E, "the instrument doesn't touch the music")
        XCTAssertEqual(engine.instrumentSurface.context.key, .E)

        engine.playInstrument(InstrumentLibrary.scaleWheel)
        XCTAssertNil(engine.surfaceInstrument)
        XCTAssertNil(engine.instrumentSurface.instrument)
        XCTAssertTrue(engine.scaleChordMelodyModeEnabled)
    }
}
