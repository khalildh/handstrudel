import SwiftUI
import UIKit

/// Multitouch / drag overlay for the Split chord+melody wheel. Mirrors
/// `GridTouchOverlay`'s shape: a UIKit-backed view that tracks every active
/// finger, computes which zone it sits over (chord sub-zone or melody wedge),
/// fires a one-shot when a touch enters a new zone, and reports the set of
/// currently-touched zones back so the visual overlay can light them up.
///
/// Geometry constants come from `ChordMelodyModeManager`, so the touch math
/// stays aligned with the rendering / hand-tracking math.
struct SplitTouchOverlay: UIViewRepresentable {
    let zoneCount: Int
    let melodyCount: Int
    /// Maps a wedge index → scale degree via the active progression. Provided
    /// by the caller so this view doesn't need to know about progressions.
    let degreeForZone: (Int) -> Int
    let swapHands: Bool

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
    private var deadR: CGFloat  { outerR * CGFloat(ChordMelodyModeManager.splitDeadzone) }
    private var octaveR: CGFloat { outerR * CGFloat(ChordMelodyModeManager.splitOctaveBandThreshold) }
    private var wheelCenter: CGPoint { CGPoint(x: bounds.width / 2, y: bounds.height / 2) }

    /// Per-touch state: (current voice ID, current zone). When a touch is
    /// inside the rest hole the voice ID is nil but the touch is still
    /// tracked so a drag back out can spawn a new voice.
    private struct TouchState {
        var voice: String?
        var zone: SplitTouchZone?
    }
    private var states: [UITouch: TouchState] = [:]
    private var nextVoiceCounter: Int = 0

    private var activeChord: Set<ChordSubzone> = []
    private var activeMelody: Set<Int> = []

    private func allocVoice() -> String {
        nextVoiceCounter &+= 1
        return "splittouch-\(nextVoiceCounter)"
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
        let probe = ChordMelodyModeManager()
        probe.zoneDegrees = Array(0..<max(1, zoneCount))   // dummy; we only use the side wedge math

        // Chord side?
        if let wedge = probe.splitWedgeIndex(side: chordSide, angle: deg, count: zoneCount) {
            let oct = probe.splitOctaveShift(side: chordSide, angle: deg, radius: radius, wedgeIndex: wedge)
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
                applyEnterHighlight(z)
                onZoneEnter?(voice, z)
            }
            states[touch] = st
        }
        emit()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            var st = states[touch] ?? TouchState()
            let z = zoneForTouch(touch)
            if z == st.zone { continue }
            // Release the old voice (and highlight) before starting a new one.
            if let prev = st.zone { applyLeaveHighlight(prev) }
            if let v = st.voice { onZoneExit?(v); st.voice = nil }
            if let z {
                let voice = allocVoice()
                st.voice = voice
                applyEnterHighlight(z)
                onZoneEnter?(voice, z)
            }
            st.zone = z
            states[touch] = st
        }
        emit()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let st = states[touch] {
                if let prev = st.zone { applyLeaveHighlight(prev) }
                if let v = st.voice { onZoneExit?(v) }
            }
            states.removeValue(forKey: touch)
        }
        emit()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func applyEnterHighlight(_ z: SplitTouchZone) {
        switch z {
        case .chord(let sub): activeChord.insert(sub)
        case .melody(let lane): activeMelody.insert(lane)
        }
    }

    private func applyLeaveHighlight(_ z: SplitTouchZone) {
        switch z {
        case .chord(let sub): activeChord.remove(sub)
        case .melody(let lane): activeMelody.remove(lane)
        }
    }

    private func emit() {
        onActiveChordChanged?(activeChord)
        onActiveMelodyChanged?(activeMelody)
    }
}
