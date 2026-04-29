import SwiftUI
import UIKit

/// Multitouch grid view — supports two simultaneous fingers for playing notes
struct GridTouchOverlay: UIViewRepresentable {
    let noteCount: Int
    let topPad: CGFloat
    let bottomPad: CGFloat
    let notes: [Int]
    let waveform: String
    let onNoteOn: (String, Int, String) -> Void
    let onNoteOff: (String) -> Void
    let onNoteSlide: (String, Int, String) -> Void
    let onHaptic: () -> Void
    @Binding var activeLanes: Set<Int>

    func makeUIView(context: Context) -> GridTouchUIView {
        let view = GridTouchUIView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: GridTouchUIView, context: Context) {
        uiView.noteCount = noteCount
        uiView.topPad = topPad
        uiView.bottomPad = bottomPad
        uiView.notes = notes
        uiView.waveform = waveform
        uiView.onNoteOn = onNoteOn
        uiView.onNoteOff = onNoteOff
        uiView.onNoteSlide = onNoteSlide
        uiView.onHaptic = onHaptic
        uiView.onActiveLanesChanged = { lanes in
            DispatchQueue.main.async { self.activeLanes = lanes }
        }
    }
}

class GridTouchUIView: UIView {
    var noteCount: Int = 10
    var topPad: CGFloat = 0
    var bottomPad: CGFloat = 0
    var notes: [Int] = []
    var waveform: String = "sawtooth"
    var onNoteOn: ((String, Int, String) -> Void)?
    var onNoteOff: ((String) -> Void)?
    var onNoteSlide: ((String, Int, String) -> Void)?
    var onHaptic: (() -> Void)?

    // Track which lane each touch is on, keyed by touch pointer
    private var touchLanes: [UITouch: Int] = [:]
    // Map touches to voices: first touch = "touch1", second = "touch2"
    private var touchVoices: [UITouch: String] = [:]
    // Track active lanes for visual callback
    var activeLanes: Set<Int> = []
    var onActiveLanesChanged: ((Set<Int>) -> Void)?

    private func laneForTouch(_ touch: UITouch) -> Int? {
        let y = touch.location(in: self).y
        let usableHeight = bounds.height - topPad - bottomPad
        guard usableHeight > 0, noteCount > 0 else { return nil }
        let laneHeight = usableHeight / CGFloat(noteCount)
        let lane = Int((y - topPad) / laneHeight)
        return max(0, min(noteCount - 1, lane))
    }

    private func voiceForTouch(_ touch: UITouch) -> String {
        if let existing = touchVoices[touch] { return existing }
        let voice = touchVoices.values.contains("touch1") ? "touch2" : "touch1"
        touchVoices[touch] = voice
        return voice
    }

    private func noteInfo(for lane: Int) -> (midi: Int, name: String)? {
        let noteIdx = noteCount - 1 - lane
        guard noteIdx >= 0, noteIdx < notes.count else { return nil }
        let midi = notes[noteIdx]
        return (midi: midi, name: midiNoteName(midi))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let lane = laneForTouch(touch),
                  let info = noteInfo(for: lane) else { continue }
            let voice = voiceForTouch(touch)
            touchLanes[touch] = lane
            activeLanes.insert(lane)
            onNoteOn?(voice, info.midi, info.name)
            onHaptic?()
        }
        onActiveLanesChanged?(activeLanes)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let lane = laneForTouch(touch),
                  let info = noteInfo(for: lane),
                  let voice = touchVoices[touch] else { continue }
            let prevLane = touchLanes[touch]
            if lane != prevLane {
                if let prev = prevLane { activeLanes.remove(prev) }
                touchLanes[touch] = lane
                activeLanes.insert(lane)
                onNoteSlide?(voice, info.midi, info.name)
                onHaptic?()
            }
        }
        onActiveLanesChanged?(activeLanes)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let voice = touchVoices[touch] {
                onNoteOff?(voice)
            }
            if let lane = touchLanes[touch] { activeLanes.remove(lane) }
            touchLanes.removeValue(forKey: touch)
            touchVoices.removeValue(forKey: touch)
        }
        onActiveLanesChanged?(activeLanes)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}
