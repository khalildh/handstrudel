import UIKit

// MARK: - Music: what a zone plays with the player's settings

/// The player's music an instrument resolves its zones against. None of it
/// comes from the instrument file.
struct InstrumentMusicContext: Equatable {
    var key: MusicKey
    var scale: Scale
    /// Scale degrees of the player's progression, one per chord.
    var progression: [Int]
    var voicing: ChordVoicing = .triad
}

/// What a zone sounds like right now.
enum InstrumentZoneSound: Equatable {
    case notes([Int])
    case drum(InstrumentLayout.Drum)
    case expression(InstrumentLayout.Expression)
}

/// Resolves zone roles (scale degree, progression slot, chord tone, drum
/// slot) into notes using only the player's key, scale, progression and voicing.
enum InstrumentMusic {
    typealias Zone = InstrumentLayout.Zone

    static func chordDegree(slot: Int, _ context: InstrumentMusicContext) -> Int {
        guard !context.progression.isEmpty else { return 0 }
        return context.progression[((slot % context.progression.count) + context.progression.count) % context.progression.count]
    }

    /// The chord the chord-tone zones follow when nothing is held: the first of the progression.
    static func restingChordDegree(_ context: InstrumentMusicContext) -> Int { chordDegree(slot: 0, context) }

    static func sound(for zone: Zone, band: Int = 0, heldChordDegree: Int?, _ context: InstrumentMusicContext) -> InstrumentZoneSound {
        let shift = 12 * ((zone.octave ?? 0) + band)
        switch zone.role {
        case .note:
            let lanes = scaleNotesOneOctave(key: context.key, scale: context.scale)
            guard !lanes.isEmpty else { return .notes([60 + shift]) }
            let degree = zone.degree ?? 0
            return .notes([lanes[degree % lanes.count] + 12 * (degree / lanes.count) + shift])
        case .chord:
            let degree = chordDegree(slot: zone.slot ?? 0, context)
            return .notes(chordTones(degree: degree, context).map { $0 + shift })
        case .chordTone:
            let degree = heldChordDegree ?? restingChordDegree(context)
            // One octave above the chord zones, root to seventh.
            let tones = chordNotesWithSeventh(key: context.key, scale: context.scale, degree: degree).map { $0 + 12 }
            return .notes([tones[min(tones.count - 1, max(0, zone.tone ?? 0))] + shift])
        case .drum:
            return .drum(zone.drum ?? .kick)
        case .expression:
            return .expression(zone.parameter ?? .filter)
        }
    }

    static func chordTones(degree: Int, _ context: InstrumentMusicContext) -> [Int] {
        switch context.voicing {
        case .triad: return chordNotes(key: context.key, scale: context.scale, degree: degree)
        case .seventh: return chordNotesWithSeventh(key: context.key, scale: context.scale, degree: degree)
        }
    }

    /// The zone's on-screen label in a label style.
    static func label(for zone: Zone, style: InstrumentLayout.Visuals.Labels, heldChordDegree: Int?,
                      _ context: InstrumentMusicContext) -> String {
        if let custom = zone.label { return custom }
        switch zone.role {
        case .drum: return style == .none ? "" : (zone.drum ?? .kick).title
        case .expression: return style == .none ? "" : (zone.parameter ?? .filter).title
        default: break
        }
        switch style {
        case .none:
            return ""
        case .notes:
            if zone.role == .chord {
                let degree = chordDegree(slot: zone.slot ?? 0, context)
                return chordDisplayName(key: context.key, scale: context.scale, degree: degree)
                    + (context.voicing == .seventh ? "⁷" : "")
            }
            guard case .notes(let notes) = sound(for: zone, heldChordDegree: heldChordDegree, context),
                  let first = notes.first else { return "" }
            return pitchClassName(first)
        case .degrees:
            switch zone.role {
            case .note:
                let size = max(1, context.scale.intervals.count)
                return "\((zone.degree ?? 0) % size + 1)"
            case .chord:
                return romanNumeral(chordDegree(slot: zone.slot ?? 0, context) + 1)
            case .chordTone:
                return ["R", "3", "5", "7"][min(3, max(0, zone.tone ?? 0))]
            default:
                return ""
            }
        }
    }

    /// What a zone sends to the engine, for accessibility and tests: note
    /// names with octave, a drum slot, or a parameter.
    static func soundDescription(for zone: Zone, heldChordDegree: Int?, _ context: InstrumentMusicContext) -> String {
        switch sound(for: zone, heldChordDegree: heldChordDegree, context) {
        case .notes(let notes): return notes.map(midiNoteName).joined(separator: " ")
        case .drum(let drum): return drum.rawValue
        case .expression(let parameter): return parameter.paramID
        }
    }

    private static func romanNumeral(_ number: Int) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
        return numerals[min(numerals.count - 1, max(0, number - 1))]
    }
}

// MARK: - Engine output

/// Where a played instrument sends sound. `EngineInstrumentSink` routes it
/// through the engine's existing synth, SoundFont, drum, jam and loop paths.
@MainActor
protocol InstrumentSoundSink: AnyObject {
    func instrumentNoteOn(voice: String, midi: Int, velocity: Double)
    func instrumentNoteOff(voice: String)
    func instrumentOneShot(midis: [Int], velocity: Double, duration: Double)
    func instrumentDrum(_ drum: InstrumentLayout.Drum)
    func instrumentExpression(_ parameter: InstrumentLayout.Expression, value: Double)
}

// MARK: - Player

/// Plays a format 2 instrument from contacts — touches and tracked hands —
/// at screen points. Hit-tests with `InstrumentSurfaceGeometry`, applies each
/// zone's behaviour (hold, latch, retrigger), and sends notes to the sink.
@MainActor
final class InstrumentSurfacePlayer: ObservableObject {
    typealias Hand = InstrumentLayout.Hand

    @Published private(set) var instrument: InstrumentSpec?
    /// Zones being played (by a contact or a latch), with when each lit up.
    @Published private(set) var activeZones: [Int: Double] = [:]
    @Published private(set) var latchedZones: Set<Int> = []
    /// The chord chord-tone zones follow: the held chord, else the last one played.
    @Published private(set) var heldChordDegree: Int?
    @Published var handCursors: [Hand: CGPoint] = [:]
    /// The play area in the instrument view's (full-screen) coordinates.
    @Published var playRect: CGRect = .zero
    @Published var context = InstrumentMusicContext(key: .C, scale: .major, progression: [0, 4, 5, 3])

    weak var sink: InstrumentSoundSink?
    var clock: () -> Double = { CACurrentMediaTime() }

    private struct Contact {
        var hand: Hand?
        var hit: InstrumentHit?
        var voices: [String] = []
    }
    private var contacts: [String: Contact] = [:]
    private var contactOrder: [String] = []
    private var latchVoices: [Int: [String]] = [:]
    private var chordHolds: [(owner: String, degree: Int)] = []
    private var lastChordDegree: Int?
    private var lastExpressionValues: [InstrumentLayout.Expression: Double] = [:]

    var layout: InstrumentLayout? { instrument?.layout }

    var geometry: InstrumentSurfaceGeometry? {
        layout.map { InstrumentSurfaceGeometry(layout: $0, rect: playRect) }
    }

    /// Show and play an instrument (nil to stop). Stops everything sounding.
    func load(_ instrument: InstrumentSpec?) {
        releaseAll()
        lastChordDegree = nil
        heldChordDegree = nil
        lastExpressionValues = [:]
        self.instrument = instrument?.layout == nil ? nil : instrument
    }

    func isActive(_ contact: String) -> Bool { contacts[contact] != nil }

    // MARK: Contacts

    func begin(_ id: String, at point: CGPoint, hand: Hand? = nil) {
        if contacts[id] != nil { end(id) }
        contacts[id] = Contact(hand: hand)
        contactOrder.append(id)
        if let hit = geometry?.hit(point, time: clock(), hand: hand) {
            enter(id, hit: hit, at: point, began: true)
        }
        publishActive()
    }

    func move(_ id: String, to point: CGPoint) {
        guard let contact = contacts[id], let geometry else { return }
        // An expression zone keeps the contact until it lifts.
        if let hit = contact.hit, layout?.zones[hit.zone].role == .expression {
            updateExpression(zone: hit.zone, at: point, geometry: geometry)
            return
        }
        let hit = geometry.hit(point, time: clock(), hand: contact.hand)
        guard hit != contact.hit else { return }
        exit(id)
        if let hit { enter(id, hit: hit, at: point, began: false) }
        publishActive()
    }

    func end(_ id: String) {
        guard contacts[id] != nil else { return }
        exit(id)
        contacts.removeValue(forKey: id)
        contactOrder.removeAll { $0 == id }
        publishActive()
    }

    /// Lift every contact and release every latch.
    func releaseAll() {
        for id in contactOrder { exit(id) }
        contacts = [:]
        contactOrder = []
        for (_, voices) in latchVoices { voices.forEach { sink?.instrumentNoteOff(voice: $0) } }
        latchVoices = [:]
        latchedZones = []
        chordHolds = []
        publishActive()
    }

    /// A hand gesture's value (0…1) for an expression parameter.
    func setExpression(_ parameter: InstrumentLayout.Expression, value: Double) {
        let value = min(1, max(0, value))
        if let last = lastExpressionValues[parameter], abs(last - value) < 0.005 { return }
        lastExpressionValues[parameter] = value
        sink?.instrumentExpression(parameter, value: value)
    }

    // MARK: Zone behaviour

    private func enter(_ id: String, hit: InstrumentHit, at point: CGPoint, began: Bool) {
        guard let layout, layout.zones.indices.contains(hit.zone), let geometry else { return }
        let zone = layout.zones[hit.zone]
        contacts[id]?.hit = hit
        switch zone.role {
        case .expression:
            updateExpression(zone: hit.zone, at: point, geometry: geometry)
            return
        case .drum:
            sink?.instrumentDrum(zone.drum ?? .kick)
            return
        case .note, .chord, .chordTone:
            break
        }
        guard case .notes(let notes) = InstrumentMusic.sound(for: zone, band: hit.octave,
                                                             heldChordDegree: heldChordDegree, context) else { return }
        let chordDegree = zone.role == .chord ? InstrumentMusic.chordDegree(slot: zone.slot ?? 0, context) : nil
        switch zone.resolvedBehavior {
        case .hold:
            let voices = notes.indices.map { "inst-\(id)-\($0)" }
            for (voice, midi) in zip(voices, notes) {
                sink?.instrumentNoteOn(voice: voice, midi: midi, velocity: zone.role == .chord ? 0.6 : 0.75)
            }
            contacts[id]?.voices = voices
            if let chordDegree { chordHolds.append((id, chordDegree)) }
        case .retrigger:
            sink?.instrumentOneShot(midis: notes, velocity: zone.role == .chord ? 0.6 : 0.75, duration: 0.5)
        case .latch:
            guard began else { break }
            if let voices = latchVoices.removeValue(forKey: hit.zone) {
                voices.forEach { sink?.instrumentNoteOff(voice: $0) }
                latchedZones.remove(hit.zone)
                chordHolds.removeAll { $0.owner == "latch-\(hit.zone)" }
            } else {
                let voices = notes.indices.map { "inst-latch-\(hit.zone)-\($0)" }
                for (voice, midi) in zip(voices, notes) {
                    sink?.instrumentNoteOn(voice: voice, midi: midi, velocity: zone.role == .chord ? 0.6 : 0.75)
                }
                latchVoices[hit.zone] = voices
                latchedZones.insert(hit.zone)
                if let chordDegree { chordHolds.append(("latch-\(hit.zone)", chordDegree)) }
            }
        }
        if let chordDegree { lastChordDegree = chordDegree }
        updateHeldChord()
    }

    private func exit(_ id: String) {
        guard let contact = contacts[id] else { return }
        contact.voices.forEach { sink?.instrumentNoteOff(voice: $0) }
        contacts[id]?.voices = []
        contacts[id]?.hit = nil
        if chordHolds.contains(where: { $0.owner == id }) {
            chordHolds.removeAll { $0.owner == id }
            updateHeldChord()
        }
    }

    private func updateExpression(zone index: Int, at point: CGPoint, geometry: InstrumentSurfaceGeometry) {
        guard let zone = layout?.zones[index], let parameter = zone.parameter else { return }
        let shape = geometry.shape(of: index, time: clock())
        let box = shape.bounds
        let axis = zone.axis ?? (box.width >= box.height ? .x : .y)
        setExpression(parameter, value: shape.value(at: point, axis: axis))
    }

    private func updateHeldChord() {
        let degree = chordHolds.last?.degree ?? lastChordDegree
        if degree != heldChordDegree { heldChordDegree = degree }
    }

    private func publishActive() {
        var active: [Int: Double] = [:]
        let now = clock()
        for contact in contacts.values {
            if let zone = contact.hit?.zone { active[zone] = activeZones[zone] ?? now }
        }
        for zone in latchedZones { active[zone] = activeZones[zone] ?? now }
        if active != activeZones { activeZones = active }
    }
}

// MARK: - Engine sink

/// Sends a played instrument through the engine's existing paths: the
/// Strudel synth (or the native SoundFont when the player picked it for
/// Scale mode), the drum voices, jam sessions and the loop recorder.
@MainActor
final class EngineInstrumentSink: InstrumentSoundSink {
    private weak var engine: EngineController?
    private var nativeVoices = Set<String>()
    private var oneShotCount = 0

    init(engine: EngineController) { self.engine = engine }

    private var elapsed: Double { engine?.startTime.map { Date().timeIntervalSince($0) } ?? 0 }

    private var usesSoundFont: Bool {
        guard let engine, engine.scaleUseSoundFont else { return false }
        return engine.soundFontEngine.startIfNeeded(program: engine.selectedSoundFontInstrument.program)
    }

    func instrumentNoteOn(voice: String, midi: Int, velocity: Double) {
        guard let engine else { return }
        let native = usesSoundFont
        if native {
            nativeVoices.insert(voice)
            engine.soundFontEngine.noteOn(voice: voice, midi: midi, velocity: velocity)
        } else {
            engine.strudelBridge.noteOn(hand: voice, midi: midi, waveform: engine.selectedWaveform, velocity: velocity)
        }
        engine.holdJamVoice(voice, pitches: [midi], velocity: velocity, native: native)
        engine.loopRecorder.recordEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: velocity),
                                        currentTime: elapsed)
        engine.lastGridNote = midiNoteName(midi)
        engine.haptics.noteTrigger()
    }

    func instrumentNoteOff(voice: String) {
        guard let engine else { return }
        if nativeVoices.remove(voice) != nil {
            engine.soundFontEngine.releaseTemporaryVoice(voice)
        } else {
            engine.strudelBridge.noteOff(hand: voice)
        }
        engine.releaseJamVoice(voice)
        engine.loopRecorder.recordEvent(.noteOff(hand: voice), currentTime: elapsed)
    }

    func instrumentOneShot(midis: [Int], velocity: Double, duration: Double) {
        guard let engine else { return }
        if usesSoundFont {
            for midi in midis {
                oneShotCount += 1
                let voice = "inst-shot-\(oneShotCount)"
                engine.soundFontEngine.noteOn(voice: voice, midi: midi, velocity: velocity)
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak engine] in
                    engine?.soundFontEngine.releaseTemporaryVoice(voice)
                }
            }
        } else {
            for midi in midis {
                engine.strudelBridge.playNote(midi: midi, waveform: engine.selectedWaveform, velocity: velocity,
                                              duration: duration)
            }
        }
        for midi in midis {
            engine.loopRecorder.recordEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: velocity),
                                            currentTime: elapsed)
        }
        engine.shareJamNotes(midis, velocity: velocity, duration: duration)
        engine.lastGridNote = midis.first.map(midiNoteName) ?? engine.lastGridNote
        engine.haptics.noteTrigger()
    }

    func instrumentDrum(_ drum: InstrumentLayout.Drum) {
        guard let engine else { return }
        engine.strudelBridge.playHit(drum.rawValue)
        engine.haptics.drumHit()
        engine.lastDrumHit = drum.rawValue
        engine.loopRecorder.recordEvent(.drumHit(hitType: drum.rawValue), currentTime: elapsed)
        engine.jamSession.sendEvent(.drumHit(hitType: drum.rawValue))
    }

    func instrumentExpression(_ parameter: InstrumentLayout.Expression, value: Double) {
        guard let engine, let def = PARAM_MAP[parameter.paramID] else { return }
        let mapped = def.min + value * (def.max - def.min)
        engine.smoothed[def.id] = mapped
        engine.strudelBridge.setSynthParam(def.id, value: mapped)
        #if DEBUG
        EngineNoteLog.record("fx:\(def.id)")
        #endif
    }
}

// MARK: - Hand tracking

/// Runs a format 2 instrument from the camera: each hand's pinch point is a
/// cursor on screen; pinching (or hovering, per the instrument) inside a zone
/// plays it, and the instrument's gestures drive its expression parameters.
@MainActor
final class InstrumentSurfaceModeController: ModeController {
    private var leftPinch = PinchDetector()
    private var rightPinch = PinchDetector()

    func tick(_ engine: EngineController) {
        let player = engine.instrumentSurface
        guard let layout = player.layout else { return }
        let context = engine.instrumentMusicContext
        if player.context != context { player.context = context }

        let screen = UIScreen.main.bounds.size
        let videoAspect = engine.handTracker.videoWidth / max(1, engine.handTracker.videoHeight)
        var cursors: [InstrumentLayout.Hand: CGPoint] = [:]
        for side in [InstrumentLayout.Hand.left, .right] {
            let id = "hand-\(side.rawValue)"
            let data = side == .left ? engine.currentHands.left : engine.currentHands.right
            guard let hand = data else {
                if side == .left { leftPinch.release() } else { rightPinch.release() }
                player.end(id)
                continue
            }
            let point = Self.screenPoint(x: hand.pinchX, y: hand.pinchY, screen: screen, videoAspect: videoAspect)
            cursors[side] = point
            switch layout.gestures.play {
            case .pinch:
                let phase = side == .left ? leftPinch.update(pinch: hand.pinch) : rightPinch.update(pinch: hand.pinch)
                switch phase {
                case .began: player.begin(id, at: point, hand: side)
                case .held: player.move(id, to: point)
                case .ended: player.end(id)
                case .idle: break
                }
            case .hover:
                if player.isActive(id) { player.move(id, to: point) } else { player.begin(id, at: point, hand: side) }
            }
            for gesture in layout.gestures.expressions where gesture.hand.rawValue == side.rawValue {
                let raw = min(1, max(0, hand.value(for: gesture.input.rawValue) ?? 0))
                player.setExpression(gesture.parameter, value: gesture.invert == true ? 1 - raw : raw)
            }
        }
        if cursors != player.handCursors { player.handCursors = cursors }
        engine.evaluateDrumLoopsIfChanged(modePrefix: "instrument")
    }

    /// Camera coordinates (0…1, as `HandOverlayView` draws them) to screen
    /// points, with the video aspect-filled to the screen.
    static func screenPoint(x: Double, y: Double, screen: CGSize, videoAspect: CGFloat) -> CGPoint {
        let width = screen.width, height = screen.height
        guard width > 0, height > 0 else { return .zero }
        let screenAspect = width / height
        if videoAspect > screenAspect {
            let visible = screenAspect / videoAspect
            let offset = (1 - visible) / 2
            return CGPoint(x: (CGFloat(x) - offset) / visible * width, y: CGFloat(y) * height)
        }
        let visible = videoAspect / screenAspect
        let offset = (1 - visible) / 2
        return CGPoint(x: CGFloat(x) * width, y: (CGFloat(y) - offset) / visible * height)
    }
}

// MARK: - UI test probe

#if DEBUG
/// Notes and hits sent to the engine, readable by UI tests through the
/// `engine-note-log` element. Only records under `--uitesting`.
final class EngineNoteLog: ObservableObject {
    static let shared = EngineNoteLog()
    static let enabled = ProcessInfo.processInfo.arguments.contains("--uitesting")

    @Published private(set) var entries: [String] = []

    static func record(_ entry: String) {
        guard enabled else { return }
        DispatchQueue.main.async {
            shared.entries.append(entry)
            if shared.entries.count > 80 { shared.entries.removeFirst(shared.entries.count - 80) }
        }
    }

    static func clear() {
        guard enabled else { return }
        DispatchQueue.main.async { shared.entries = [] }
    }
}
#endif
