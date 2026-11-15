import SwiftUI
import UIKit

/// Multitouch / drag overlay for the Split chord+melody wheel. Mirrors
/// `GridTouchOverlay`'s shape: a UIKit-backed view that tracks every active
/// finger, computes which zone it sits over (chord sub-zone or melody wedge),
/// starts a voice when a touch enters a new zone, and reports the set of
/// currently-touched zones back so the visual overlay can light them up.
///
/// Geometry constants come from `ChordMelodyModeManager`, so the touch math
/// stays aligned with the rendering / hand-tracking math.
struct SplitTouchOverlay: UIViewRepresentable {
    let zoneCount: Int
    let melodyCount: Int
    let swapHands: Bool
    let enabled: Bool
    let chordLabels: [String]
    let melodyLabels: [String]

    /// Fired when a touch enters a zone — either on touch-begin or after a
    /// drag crosses into a new zone. The voice ID is unique per touch+zone
    /// so the caller can pair it with the matching `onZoneExit` to start /
    /// stop a sustained note.
    let onZoneEnter: (String, SplitTouchZone) -> Void
    /// Fired when a touch leaves a zone — on touch-end or when a drag crosses
    /// out of it. Caller releases the voice it allocated for that ID.
    let onZoneExit: (String) -> Void

    @Binding var touchedChordSubzones: Set<ChordSubzone>
    @Binding var touchedMelodyLanes: Set<Int>

    func makeUIView(context: Context) -> SplitTouchUIView {
        let v = SplitTouchUIView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: SplitTouchUIView, context: Context) {
        uiView.isUserInteractionEnabled = enabled
        if !enabled { uiView.scheduleRelease() }
        uiView.zoneCount = zoneCount
        uiView.melodyCount = melodyCount
        uiView.swapHands = swapHands
        uiView.onZoneEnter = onZoneEnter
        uiView.onZoneExit = onZoneExit
        uiView.onActiveChordChanged = { zones in
            DispatchQueue.main.async { self.touchedChordSubzones = zones }
        }
        uiView.onActiveMelodyChanged = { lanes in
            DispatchQueue.main.async { self.touchedMelodyLanes = lanes }
        }
        uiView.updateAccessibleNotes(chords: chordLabels, melody: melodyLabels)
    }

    static func dismantleUIView(_ uiView: SplitTouchUIView, coordinator: ()) {
        uiView.scheduleRelease()
    }
}

/// A chord-side sub-zone — used as the unit of "currently touched" tracking on
/// the chord half. Equatable/Hashable so it works in `Set`.
struct ChordSubzone: Hashable {
    let wedge: Int
    let octave: Int   // -1, 0, +1
}

/// The kind of zone a touch is currently over.
enum SplitTouchZone: Hashable {
    case chord(ChordSubzone)
    case melody(Int)   // lane
}

private final class SplitAccessibilityNote: UIAccessibilityElement {
    var play: (() -> Bool)?

    override func accessibilityActivate() -> Bool { play?() ?? false }
}

final class SplitTouchUIView: UIView {
    var zoneCount: Int = 7
    var melodyCount: Int = 9
    var swapHands: Bool = false
    var onZoneEnter: ((String, SplitTouchZone) -> Void)?
    var onZoneExit: ((String) -> Void)?
    var onActiveChordChanged: ((Set<ChordSubzone>) -> Void)?
    var onActiveMelodyChanged: ((Set<Int>) -> Void)?

    // Geometry mirrors the visual overlay: outer radius fits the shorter
    // dimension, deadzone is the rest hole, octaveR is the inner-band rim.
    private var outerR: CGFloat { min(bounds.width, bounds.height) / 2 * CGFloat(ChordMelodyModeManager.splitRadiusFraction) }
    private var wheelCenter: CGPoint { CGPoint(x: bounds.width / 2, y: bounds.height / 2) }

    /// Per-touch state: (current voice ID, current zone). When a touch is
    /// inside the rest hole the voice ID is nil but the touch is still
    /// tracked so a drag back out can spawn a new voice.
    private struct TouchState {
        var voice: String?
        var zone: SplitTouchZone?
    }
    private var states: [UITouch: TouchState] = [:]
    private var previewVoices: [String: SplitTouchZone] = [:]
    private static var nextVoiceCounter: Int = 0
    private var chordLabels: [String] = []
    private var melodyLabels: [String] = []
    private var accessibleNotes: [SplitTouchZone: SplitAccessibilityNote] = [:]

    private let probe = ChordMelodyModeManager()
    private var releaseScheduled = false

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutAccessibleNotes()
    }

    func updateAccessibleNotes(chords: [String], melody: [String]) {
        chordLabels = chords
        melodyLabels = melody
        layoutAccessibleNotes()
    }

    private func layoutAccessibleNotes() {
        guard isUserInteractionEnabled, outerR > 0 else { accessibilityElements = []; return }
        var ordered: [SplitAccessibilityNote] = []
        let radius = outerR * (ChordMelodyModeManager.splitDeadzone + ChordMelodyModeManager.splitOctaveBandThreshold) / 2

        func insert(_ zone: SplitTouchZone, label: String, id: String, wedge: Int, count: Int, right: Bool) {
            let note = accessibleNotes[zone] ?? makeAccessibleNote(zone)
            accessibleNotes[zone] = note
            note.accessibilityLabel = label
            note.accessibilityIdentifier = id
            let angle = Double(wedge) * .pi / Double(count) + .pi / (2 * Double(count))
            let x = wheelCenter.x + sin(angle) * radius * (right ? 1 : -1)
            let y = wheelCenter.y - cos(angle) * radius
            let hitSize = min(44, max(22, .pi * radius / CGFloat(count)))
            note.accessibilityFrameInContainerSpace = CGRect(x: x - hitSize / 2, y: y - hitSize / 2, width: hitSize, height: hitSize)
            ordered.append(note)
        }

        for (index, label) in chordLabels.enumerated() {
            insert(.chord(ChordSubzone(wedge: index, octave: 0)), label: "Chord \(label)", id: "wheel-chord-\(index)",
                   wedge: index, count: chordLabels.count, right: swapHands)
        }
        for (index, label) in melodyLabels.enumerated() {
            insert(.melody(index), label: "Note \(label)", id: "wheel-note-\(index)",
                   wedge: melodyLabels.count - 1 - index, count: melodyLabels.count, right: !swapHands)
        }
        if !(accessibilityElements as? [SplitAccessibilityNote] ?? []).elementsEqual(ordered, by: { $0 === $1 }) {
            accessibilityElements = ordered
        }
    }

    private func makeAccessibleNote(_ zone: SplitTouchZone) -> SplitAccessibilityNote {
        let note = SplitAccessibilityNote(accessibilityContainer: self)
        note.accessibilityTraits = .button
        note.accessibilityHint = "Double-tap to play"
        note.play = { [weak self] in self?.preview(zone) ?? false }
        if case let .chord(subzone) = zone {
            note.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "Play an octave lower") { [weak self] _ in
                    self?.preview(.chord(ChordSubzone(wedge: subzone.wedge, octave: -1))) ?? false
                },
                UIAccessibilityCustomAction(name: "Play an octave higher") { [weak self] _ in
                    self?.preview(.chord(ChordSubzone(wedge: subzone.wedge, octave: 1))) ?? false
                },
            ]
        }
        return note
    }

    private func preview(_ zone: SplitTouchZone) -> Bool {
        guard isUserInteractionEnabled, previewVoices.count < 8, let onZoneEnter else { return false }
        let voice = allocVoice()
        previewVoices[voice] = zone
        onZoneEnter(voice, zone)
        emit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self, self.previewVoices.removeValue(forKey: voice) != nil else { return }
            self.onZoneExit?(voice)
            self.emit()
        }
        return true
    }

    private func allocVoice() -> String {
        Self.nextVoiceCounter &+= 1
        return "splittouch-\(Self.nextVoiceCounter)"
    }

    // MARK: - Touch → zone

    private func zoneForTouch(_ touch: UITouch) -> SplitTouchZone? {
        let p = touch.location(in: self)
        let dx = p.x - wheelCenter.x
        let dy = wheelCenter.y - p.y
        let r = (dx * dx + dy * dy).squareRoot()
        guard outerR > 0 else { return nil }
        let radius = min(1.0, Double(r / outerR))
        // Inside the rest hole — nothing selected, but keep dragging
        guard radius >= Double(ChordMelodyModeManager.splitDeadzone) else { return nil }
        var deg = 90 - atan2(Double(dy), Double(dx)) * 180 / .pi
        deg = deg.truncatingRemainder(dividingBy: 360)
        if deg < 0 { deg += 360 }

        let chordSide: ChordMelodyModeManager.Side = swapHands ? .right : .left
        let melodySide: ChordMelodyModeManager.Side = swapHands ? .left : .right
        // Chord side?
        if let wedge = probe.splitWedgeIndex(side: chordSide, angle: deg, count: zoneCount) {
            let oct = probe.splitOctaveShift(side: chordSide, angle: deg, radius: radius, wedgeIndex: wedge, count: zoneCount)
            return .chord(ChordSubzone(wedge: wedge, octave: oct))
        }
        // Melody side?
        if let wedge = probe.splitWedgeIndex(side: melodySide, angle: deg, count: melodyCount) {
            let lane = melodyCount - 1 - wedge   // invert so top = highest pitch
            return .melody(lane)
        }
        return nil
    }

    // MARK: - UIResponder

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            var st = TouchState()
            if let z = zoneForTouch(touch) {
                let voice = allocVoice()
                st.voice = voice
                st.zone = z
                onZoneEnter?(voice, z)
            }
            states[touch] = st
        }
        emit()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard var st = states[touch] else { continue }
            let z = zoneForTouch(touch)
            if z == st.zone { continue }
            // Release the old voice before starting a new one.
            if let v = st.voice { onZoneExit?(v); st.voice = nil }
            if let z {
                let voice = allocVoice()
                st.voice = voice
                onZoneEnter?(voice, z)
            }
            st.zone = z
            states[touch] = st
        }
        emit()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let voice = states.removeValue(forKey: touch)?.voice { onZoneExit?(voice) }
        }
        emit()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    func scheduleRelease() {
        guard (!states.isEmpty || !previewVoices.isEmpty), !releaseScheduled else { return }
        releaseScheduled = true
        DispatchQueue.main.async {
            self.releaseScheduled = false
            let voices = self.states.values.compactMap(\.voice) + Array(self.previewVoices.keys)
            self.states.removeAll()
            self.previewVoices.removeAll()
            for voice in voices { self.onZoneExit?(voice) }
            self.emit()
        }
    }

    private func emit() {
        var chords: Set<ChordSubzone> = []
        var melody: Set<Int> = []
        for zone in states.values.compactMap(\.zone) + Array(previewVoices.values) {
            switch zone {
            case .chord(let sub): chords.insert(sub)
            case .melody(let lane): melody.insert(lane)
            }
        }
        onActiveChordChanged?(chords)
        onActiveMelodyChanged?(melody)
    }
}
