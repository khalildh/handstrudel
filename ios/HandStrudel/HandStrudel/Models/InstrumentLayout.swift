import Foundation

/// A format 2 instrument surface other than the split wheel: where its zones
/// sit, what musical role each zone plays, which hand gestures shape the
/// sound, and how it looks. Mirrors `shared/instruments/schema.json`.
///
/// Zones say *which* scale degree, progression chord, chord tone or drum they
/// play; the player's key, scale, progression, voicing and sound decide the
/// actual pitches. Everything is drawn and played by `InstrumentSurfaceView`
/// and `InstrumentSurfacePlayer`; nothing in the file is executed.
struct InstrumentLayout: Codable, Equatable {
    var surface: Surface
    var zones: [Zone]
    var gestures: Gestures
    var visuals: Visuals

    enum CodingKeys: String, CodingKey { case surface, zones, gestures, visuals }

    init(surface: Surface, zones: [Zone], gestures: Gestures = Gestures(), visuals: Visuals = Visuals()) {
        self.surface = surface
        self.zones = zones
        self.gestures = gestures
        self.visuals = visuals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        surface = try container.decode(Surface.self, forKey: .surface)
        zones = try container.decode([Zone].self, forKey: .zones)
        gestures = try container.decodeIfPresent(Gestures.self, forKey: .gestures) ?? Gestures()
        visuals = try container.decodeIfPresent(Visuals.self, forKey: .visuals) ?? Visuals()
    }

    // MARK: Surface

    /// How zones are placed. Laid-out surfaces (radial, grid, keys, strips,
    /// arc) place zones in order; free surfaces (pads, orbs) use each zone's
    /// `frame`. Coordinates are fractions of the play area (x right, y down).
    struct Surface: Codable, Equatable {
        enum Kind: String, Codable, CaseIterable {
            case radial, grid, keys, strips, pads, arc, orbs
            var isFree: Bool { self == .pads || self == .orbs }
        }
        enum Orientation: String, Codable { case horizontal, vertical }
        enum Motion: String, Codable { case drift, pulse }

        var type: Kind
        /// grid
        var rows: Int?
        var columns: Int?
        /// keys, strips
        var orientation: Orientation?
        /// radial, arc: fractions of the surface radius.
        var innerRadius: Double?
        var outerRadius: Double?
        /// arc: degrees clockwise from straight up.
        var startAngle: Double?
        var endAngle: Double?
        /// orbs
        var motion: Motion?
        /// orbs: how far they drift (fraction of the play area) or swell (fraction of their size).
        var amount: Double?
        /// orbs: seconds per drift or pulse cycle. Visual only, not tempo.
        var period: Double?

        enum CodingKeys: String, CodingKey {
            case type, rows, columns, orientation, innerRadius = "inner_radius", outerRadius = "outer_radius",
                 startAngle = "start_angle", endAngle = "end_angle", motion, amount, period
        }

        init(type: Kind, rows: Int? = nil, columns: Int? = nil, orientation: Orientation? = nil,
             innerRadius: Double? = nil, outerRadius: Double? = nil, startAngle: Double? = nil, endAngle: Double? = nil,
             motion: Motion? = nil, amount: Double? = nil, period: Double? = nil) {
            self.type = type
            self.rows = rows
            self.columns = columns
            self.orientation = orientation
            self.innerRadius = innerRadius
            self.outerRadius = outerRadius
            self.startAngle = startAngle
            self.endAngle = endAngle
            self.motion = motion
            self.amount = amount
            self.period = period
        }

        static let rowsRange = 1...8
        static let columnsRange = 1...6
        static let innerRadiusRange = 0.2...0.6
        static let outerRadiusRange = 0.6...1.0
        /// Ring depth (outer − inner) that keeps a wedge deep enough to land in.
        static let minimumRingDepth = 0.3
        static let angleRange = -100.0...100.0
        static let minimumArcSpan = 60.0
        static let amountRange = 0.0...0.06
        static let periodRange = 2.0...20.0
    }

    // MARK: Zones

    struct Frame: Codable, Equatable {
        var x: Double
        var y: Double
        var w: Double
        var h: Double
    }

    enum Hand: String, Codable { case left, right, any }
    enum Behavior: String, Codable { case hold, latch, retrigger }
    enum Axis: String, Codable { case x, y }
    enum PadShape: String, Codable { case round, rounded }

    /// Drum kit slots: whatever kit the player's sound uses.
    enum Drum: String, Codable, CaseIterable {
        case kick, snare, hihat, crash, ride, tom
        var title: String {
            switch self {
            case .kick: return "Kick"
            case .snare: return "Snare"
            case .hihat: return "Hi-hat"
            case .crash: return "Crash"
            case .ride: return "Ride"
            case .tom: return "Tom"
            }
        }
    }

    /// Expression parameters a zone or gesture can shape, from a fixed list.
    /// Each maps to an engine synth parameter (`PARAM_MAP`).
    enum Expression: String, Codable, CaseIterable {
        case filter, hipass, reverb, delay, volume, pan, drive, crush
        var paramID: String {
            switch self {
            case .filter: return "lpf"
            case .hipass: return "hpf"
            case .reverb: return "reverb"
            case .delay: return "delay"
            case .volume: return "gain"
            case .pan: return "pan"
            case .drive: return "shape"
            case .crush: return "crush"
            }
        }
        var title: String {
            switch self {
            case .filter: return "Filter"
            case .hipass: return "Hi-pass"
            case .reverb: return "Reverb"
            case .delay: return "Delay"
            case .volume: return "Volume"
            case .pan: return "Pan"
            case .drive: return "Drive"
            case .crush: return "Crush"
            }
        }
    }

    /// One playable area. `role` picks which of the role fields apply:
    /// note → `degree` (+`octave`), chord → `slot` (+`octave`), chord_tone →
    /// `tone` (+`octave`), drum → `drum`, expression → `parameter` (+`axis`).
    struct Zone: Codable, Equatable {
        enum Role: String, Codable { case note, chord, chordTone = "chord_tone", drum, expression }

        var role: Role
        /// note: scale degree from the root (0 = root). Past the scale's size it climbs octaves.
        var degree: Int?
        /// note, chord, chord_tone: octaves up or down.
        var octave: Int?
        /// chord: which chord of the player's progression (wraps around).
        var slot: Int?
        /// chord_tone: 0 root, 1 third, 2 fifth, 3 seventh of the held chord.
        var tone: Int?
        var drum: Drum?
        var parameter: Expression?
        /// expression: the zone's axis that sets the value.
        var axis: Axis?
        /// Which tracked hand can play it. Touch plays every zone.
        var hand: Hand?
        var behavior: Behavior?
        /// Top/outer band plays an octave up, bottom/inner band an octave down.
        var octaveBands: Bool?
        /// pads, orbs
        var frame: Frame?
        var shape: PadShape?
        /// Replaces the computed label. Short text only.
        var label: String?

        enum CodingKeys: String, CodingKey {
            case role, degree, octave, slot, tone, drum, parameter, axis, hand, behavior,
                 octaveBands = "octave_bands", frame, shape, label
        }

        init(role: Role, degree: Int? = nil, octave: Int? = nil, slot: Int? = nil, tone: Int? = nil,
             drum: Drum? = nil, parameter: Expression? = nil, axis: Axis? = nil, hand: Hand? = nil,
             behavior: Behavior? = nil, octaveBands: Bool? = nil, frame: Frame? = nil, shape: PadShape? = nil,
             label: String? = nil) {
            self.role = role
            self.degree = degree
            self.octave = octave
            self.slot = slot
            self.tone = tone
            self.drum = drum
            self.parameter = parameter
            self.axis = axis
            self.hand = hand
            self.behavior = behavior
            self.octaveBands = octaveBands
            self.frame = frame
            self.shape = shape
            self.label = label
        }

        var isPitched: Bool { role == .note || role == .chord || role == .chordTone }
        var resolvedHand: Hand { hand ?? .any }
        var resolvedBehavior: Behavior { isPitched ? (behavior ?? .hold) : .retrigger }
        var hasOctaveBands: Bool { isPitched && (octaveBands ?? false) }

        static let degreeRange = 0...20
        static let octaveRange = -2...2
        static let slotRange = 0...7
        static let toneRange = 0...3
        static let labelLimit = 12
    }

    // MARK: Gestures

    /// Which hand gesture plays a zone, and which hand inputs shape the sound.
    struct Gestures: Codable, Equatable {
        enum Play: String, Codable {
            /// Pinch inside a zone to play it.
            case pinch
            /// A hand's pinch point inside a zone plays it.
            case hover
        }
        var play: Play
        var expressions: [GestureExpression]

        init(play: Play = .pinch, expressions: [GestureExpression] = []) {
            self.play = play
            self.expressions = expressions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            play = try container.decodeIfPresent(Play.self, forKey: .play) ?? .pinch
            expressions = try container.decodeIfPresent([GestureExpression].self, forKey: .expressions) ?? []
        }

        static let expressionLimit = 6
    }

    /// One hand input (a `MappingConfig` axis) driving one expression parameter.
    struct GestureExpression: Codable, Equatable {
        enum Side: String, Codable { case left, right }
        /// The hand-pipeline axes (`AXIS_DEFS` keys).
        enum Input: String, Codable, CaseIterable {
            case x, y, spread, pinch, fist, rotation, thumbCurl, indexCurl, middleCurl, ringCurl, pinkyCurl
        }
        var hand: Side
        var input: Input
        var parameter: Expression
        var invert: Bool?
    }

    // MARK: Visuals

    /// Named styles only; each draws legibly over the camera in every `StudioTheme`.
    struct Visuals: Codable, Equatable {
        enum Palette: String, Codable, CaseIterable { case theme, aurora, ember, ocean, candy, mono }
        enum Shape: String, Codable { case rounded, round, square }
        enum Effect: String, Codable { case none, glow, particles, ripple }
        enum Labels: String, Codable { case notes, degrees, none }

        var palette: Palette
        var shape: Shape
        var effect: Effect
        var labels: Labels

        init(palette: Palette = .theme, shape: Shape = .rounded, effect: Effect = .glow, labels: Labels = .notes) {
            self.palette = palette
            self.shape = shape
            self.effect = effect
            self.labels = labels
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            palette = try container.decodeIfPresent(Palette.self, forKey: .palette) ?? .theme
            shape = try container.decodeIfPresent(Shape.self, forKey: .shape) ?? .rounded
            effect = try container.decodeIfPresent(Effect.self, forKey: .effect) ?? .glow
            labels = try container.decodeIfPresent(Labels.self, forKey: .labels) ?? .notes
        }
    }

    /// Zones a tracked hand can aim at comfortably.
    static let maximumZonesPerHand = 16
}

// MARK: - Playability rules

extension InstrumentLayout {
    enum Validation: Equatable {
        case accepted(InstrumentLayout, [InstrumentIssue])
        case rejected(InstrumentIssue)
    }

    /// Check and repair a layout so it is playable on every screen. Rules
    /// (see `shared/instruments/README.md`), in this order:
    /// 1. At least one zone, and each zone has its role's fields (else reject).
    /// 2. Surface values into range (`surface_clamped`).
    /// 3. Role values and labels into range (`zone_clamped`, `label_trimmed`).
    /// 4. Free zones inside the play area (`zone_moved`) and at least the
    ///    minimum size (`zone_resized`).
    /// 5. No more than 16 zones per hand, and no more zones than the surface
    ///    fits at the minimum size (`zones_dropped`).
    /// 6. Octave bands only where both bands are big enough (`octave_bands_removed`).
    /// 7. Free zones must not overlap, including orb motion (reject `zones_overlap`).
    /// 8. One expression per gesture, none on the play gesture, one control per
    ///    parameter, at most six (`gesture_dropped`).
    func validated() -> Validation {
        var layout = self
        var issues: [InstrumentIssue] = []
        func note(_ issue: InstrumentIssue) { if !issues.contains(issue) { issues.append(issue) } }

        // 1. Zones exist and are complete.
        guard !zones.isEmpty else { return .rejected(.zonesMissing) }
        for zone in zones where !zone.isComplete(on: surface.type) { return .rejected(.zoneInvalid) }

        // 2. Surface.
        if layout.surface.normalize() { note(.surfaceClamped) }

        // 3. Roles and labels.
        var clamped = false, trimmed = false
        for index in layout.zones.indices {
            let changes = layout.zones[index].normalize(on: layout.surface.type)
            clamped = clamped || changes.clamped
            trimmed = trimmed || changes.labelTrimmed
        }
        if clamped { note(.zoneClamped) }
        if trimmed { note(.labelTrimmed) }

        // 4. Free zones in bounds and big enough.
        if layout.surface.type.isFree {
            for index in layout.zones.indices {
                guard var frame = layout.zones[index].frame else { continue }
                if frame.clampIntoPlayArea() { note(.zoneMoved) }
                let round = layout.zones[index].resolvedShape(layout.visuals) == .round
                if frame.growToMinimum(round: round) { note(.zoneResized) }
                layout.zones[index].frame = frame
            }
        }

        // 5. Zone counts.
        var perHand: [Hand: Int] = [.left: 0, .right: 0]
        var kept: [Zone] = []
        for zone in layout.zones {
            let hands: [Hand] = zone.resolvedHand == .any ? [.left, .right] : [zone.resolvedHand]
            guard hands.allSatisfy({ perHand[$0, default: 0] < Self.maximumZonesPerHand }) else { continue }
            hands.forEach { perHand[$0, default: 0] += 1 }
            kept.append(zone)
        }
        let capacity = InstrumentSurfaceGeometry.capacity(of: layout.surface)
        if kept.count > capacity { kept = Array(kept.prefix(capacity)) }
        if kept.count != layout.zones.count { note(.zonesDropped) }
        layout.zones = kept

        // 6. Octave bands.
        let reference = InstrumentSurfaceGeometry(layout: layout, rect: InstrumentSurfaceGeometry.referenceRect)
        for index in layout.zones.indices where layout.zones[index].octaveBands != nil {
            let zone = layout.zones[index]
            let fits = zone.isPitched && (reference.bandedExtent(of: index) ?? 0)
                >= 2 * InstrumentSurfaceGeometry.minimumZoneSide - 0.001
            if zone.octaveBands == true && !fits { note(.octaveBandsRemoved) }
            layout.zones[index].octaveBands = (zone.octaveBands == true && fits) ? true : nil
        }

        // 7. Overlaps.
        if layout.surface.type.isFree && reference.hasOverlappingZones() { return .rejected(.zonesOverlap) }

        // 8. Gestures.
        var usedInputs = Set<String>()
        var usedParameters = Set(layout.zones.compactMap(\.parameter))
        var gestures: [GestureExpression] = []
        for gesture in layout.gestures.expressions {
            let input = "\(gesture.hand.rawValue).\(gesture.input.rawValue)"
            let playGesture = layout.gestures.play == .pinch && gesture.input == .pinch
            guard gestures.count < Gestures.expressionLimit, !playGesture,
                  !usedInputs.contains(input), !usedParameters.contains(gesture.parameter) else { continue }
            usedInputs.insert(input)
            usedParameters.insert(gesture.parameter)
            gestures.append(gesture)
        }
        if gestures.count != layout.gestures.expressions.count { note(.gestureDropped) }
        layout.gestures.expressions = gestures

        return .accepted(layout, issues)
    }
}

private extension InstrumentLayout.Surface {
    /// Fill defaults, clear fields other surfaces use, and clamp. True when a
    /// value had to change (a missing value taking its default doesn't count).
    mutating func normalize() -> Bool {
        var changed = false
        func clamp<T: Comparable>(_ value: T?, _ range: ClosedRange<T>, default fallback: T) -> T {
            guard let value else { return fallback }
            let result = min(range.upperBound, max(range.lowerBound, value))
            if result != value { changed = true }
            return result
        }
        let original = self
        self = .init(type: type)
        switch type {
        case .grid:
            rows = clamp(original.rows, Self.rowsRange, default: 3)
            columns = clamp(original.columns, Self.columnsRange, default: 4)
        case .keys, .strips:
            orientation = original.orientation ?? .horizontal
        case .radial, .arc:
            let outer = clamp(original.outerRadius, Self.outerRadiusRange, default: 1.0)
            let innerMax = InstrumentSpec.rounded(min(Self.innerRadiusRange.upperBound, outer - Self.minimumRingDepth))
            outerRadius = outer
            innerRadius = clamp(original.innerRadius, Self.innerRadiusRange.lowerBound...innerMax,
                                default: min(type == .arc ? 0.45 : 0.35, innerMax))
            if type == .arc {
                let start = clamp(original.startAngle, Self.angleRange.lowerBound...(Self.angleRange.upperBound - Self.minimumArcSpan),
                                  default: -70)
                startAngle = start
                endAngle = clamp(original.endAngle, (start + Self.minimumArcSpan)...Self.angleRange.upperBound,
                                 default: max(70, start + Self.minimumArcSpan))
            }
        case .orbs:
            motion = original.motion ?? .drift
            amount = clamp(original.amount, Self.amountRange, default: 0.02)
            period = clamp(original.period, Self.periodRange, default: 8)
        case .pads:
            break
        }
        return changed
    }
}

private extension InstrumentLayout.Zone {
    func isComplete(on surface: InstrumentLayout.Surface.Kind) -> Bool {
        if surface.isFree && frame == nil { return false }
        switch role {
        case .note: return degree != nil
        case .chord: return slot != nil
        case .chordTone: return tone != nil
        case .drum: return drum != nil
        case .expression: return parameter != nil
        }
    }

    func resolvedShape(_ visuals: InstrumentLayout.Visuals) -> InstrumentLayout.PadShape {
        shape ?? (visuals.shape == .round ? .round : .rounded)
    }

    /// Keep only this role's fields, fill defaults and clamp.
    mutating func normalize(on surface: InstrumentLayout.Surface.Kind) -> (clamped: Bool, labelTrimmed: Bool) {
        var clamped = false
        func clamp(_ value: Int?, _ range: ClosedRange<Int>) -> Int? {
            guard let value else { return nil }
            let result = min(range.upperBound, max(range.lowerBound, value))
            if result != value { clamped = true }
            return result
        }
        let original = self
        self = .init(role: role, hand: original.hand == .any ? nil : original.hand)
        switch role {
        case .note:
            degree = clamp(original.degree, Self.degreeRange)
            octave = clamp(original.octave, Self.octaveRange)
        case .chord:
            slot = clamp(original.slot, Self.slotRange)
            octave = clamp(original.octave, Self.octaveRange)
        case .chordTone:
            tone = clamp(original.tone, Self.toneRange)
            octave = clamp(original.octave, Self.octaveRange)
        case .drum:
            drum = original.drum
        case .expression:
            parameter = original.parameter
            axis = original.axis
        }
        if isPitched {
            behavior = original.behavior == .hold ? nil : original.behavior
            octaveBands = original.octaveBands
            if octave == 0 { octave = nil }
        }
        if surface.isFree {
            frame = original.frame
            shape = original.shape
        }
        var labelTrimmed = false
        if let label = original.label {
            let trimmed = InstrumentSpec.trim(label, limit: Self.labelLimit)
            labelTrimmed = trimmed != label
            self.label = trimmed.isEmpty ? nil : trimmed
        }
        return (clamped, labelTrimmed)
    }
}

private extension InstrumentLayout.Frame {
    /// Size at most the play area, then move inside it.
    mutating func clampIntoPlayArea() -> Bool {
        let original = self
        w = min(1, max(0, w))
        h = min(1, max(0, h))
        x = InstrumentSpec.rounded(min(1 - w, max(0, x)))
        y = InstrumentSpec.rounded(min(1 - h, max(0, y)))
        return self != original
    }

    /// Grow around the centre to the minimum zone size on the reference play
    /// area, then move back inside it.
    mutating func growToMinimum(round: Bool) -> Bool {
        let reference = InstrumentSurfaceGeometry.referenceRect.size
        let side = Double(InstrumentSurfaceGeometry.minimumZoneSide)
        let minW = side / reference.width
        let minH = side / reference.height
        let original = self
        let centerX = x + w / 2
        let centerY = y + h / 2
        // A round pad is the circle inscribed in its frame, so for both shapes
        // each side must reach the minimum.
        _ = round
        w = max(w, minW)
        h = max(h, minH)
        guard self != original else { return false }
        // Round sizes up so a repaired pad stays at the minimum when reloaded.
        w = (w * 1_000_000).rounded(.up) / 1_000_000
        h = (h * 1_000_000).rounded(.up) / 1_000_000
        x = InstrumentSpec.rounded(centerX - w / 2)
        y = InstrumentSpec.rounded(centerY - h / 2)
        _ = clampIntoPlayArea()
        return true
    }
}
