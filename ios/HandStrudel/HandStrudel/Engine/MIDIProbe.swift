import Foundation

#if DEBUG
/// UI tests only (`--uitesting`): counts notes the engines actually started,
/// so a test can assert that touching a zone sent MIDI, not just that a
/// button exists. Shown as the `debug-midi-probe` element.
@MainActor
final class MIDIProbe: ObservableObject {
    static let shared = MIDIProbe()
    nonisolated static let isEnabled = ProcessInfo.processInfo.arguments.contains("--uitesting")

    @Published private(set) var count = 0
    @Published private(set) var last: Int?

    nonisolated static func record(_ midi: Int) {
        guard isEnabled else { return }
        Task { @MainActor in
            shared.count += 1
            shared.last = midi
        }
    }

    var summary: String { "notes \(count) last \(last.map(String.init) ?? "none")" }
}
#endif
