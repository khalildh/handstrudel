import Foundation

/// Records performance events and plays them back as loops
final class LoopRecorder {
    // Recording state
    private(set) var isRecording = false
    private var recordStartTime: Double = 0
    private var recordedEvents: [LoopEvent] = []
    private var recordingMode: String = ""

    // Playback state
    private(set) var isPlaying = false
    private var playbackLoops: [(loop: RecordedLoop, startTime: Double, volume: Double)] = []
    private var lastPlaybackCheck: Double = 0

    // Loop duration options (in bars at current BPM)
    static let barOptions = [2, 4, 8, 16, 32]
    var selectedBars: Int = 4

    /// Duration of the loop in seconds based on BPM and bar count
    func loopDuration(bpm: Double) -> Double {
        let beatsPerBar = 4.0
        let secondsPerBeat = 60.0 / bpm
        return Double(selectedBars) * beatsPerBar * secondsPerBeat
    }

    // MARK: - Recording

    func startRecording(currentTime: Double, mode: String) {
        isRecording = true
        recordStartTime = currentTime
        recordedEvents = []
        recordingMode = mode
    }

    func recordEvent(_ event: LoopEvent.EventType, currentTime: Double) {
        guard isRecording else { return }
        let timestamp = currentTime - recordStartTime
        recordedEvents.append(LoopEvent(timestamp: timestamp, type: event))
    }

    func stopRecording(bpm: Double, name: String? = nil) -> RecordedLoop? {
        guard isRecording else { return nil }
        isRecording = false
        let duration = loopDuration(bpm: bpm)
        // Trim events beyond the loop duration
        let trimmed = recordedEvents.filter { $0.timestamp <= duration }
        guard !trimmed.isEmpty else { return nil }
        let loopName = name ?? "Loop \(Int(Date().timeIntervalSince1970) % 1000)"
        return RecordedLoop(
            events: trimmed,
            duration: duration,
            bpm: bpm,
            name: loopName,
            mode: recordingMode
        )
    }

    /// Check if recording should auto-stop (loop duration reached)
    func checkAutoStop(currentTime: Double, bpm: Double) -> Bool {
        guard isRecording else { return false }
        let elapsed = currentTime - recordStartTime
        return elapsed >= loopDuration(bpm: bpm)
    }

    /// Progress of current recording (0-1)
    func recordingProgress(currentTime: Double, bpm: Double) -> Double {
        guard isRecording else { return 0 }
        let elapsed = currentTime - recordStartTime
        return min(1, elapsed / loopDuration(bpm: bpm))
    }

    // MARK: - Playback

    /// Get events that should be triggered at the current time
    func getPlaybackEvents(currentTime: Double) -> [(event: LoopEvent.EventType, volume: Double)] {
        guard isPlaying else { return [] }
        var events: [(event: LoopEvent.EventType, volume: Double)] = []

        for playback in playbackLoops {
            let elapsed = currentTime - playback.startTime
            let loopTime = elapsed.truncatingRemainder(dividingBy: playback.loop.duration)

            // Find events that fall between last check and now
            let dt = currentTime - lastPlaybackCheck
            let prevLoopTime = (elapsed - dt).truncatingRemainder(dividingBy: playback.loop.duration)

            for event in playback.loop.events {
                // Handle wrap-around (when loop restarts)
                let shouldTrigger: Bool
                if prevLoopTime <= loopTime {
                    shouldTrigger = event.timestamp > prevLoopTime && event.timestamp <= loopTime
                } else {
                    // Wrapped around
                    shouldTrigger = event.timestamp > prevLoopTime || event.timestamp <= loopTime
                }

                if shouldTrigger {
                    events.append((event: event.type, volume: playback.volume))
                }
            }
        }

        lastPlaybackCheck = currentTime
        return events
    }

    func addLoop(_ loop: RecordedLoop, startTime: Double, volume: Double = 1.0) {
        playbackLoops.append((loop: loop, startTime: startTime, volume: volume))
        isPlaying = true
        lastPlaybackCheck = startTime
    }

    func removeLoop(_ loopId: UUID) {
        playbackLoops.removeAll { $0.loop.id == loopId }
        if playbackLoops.isEmpty { isPlaying = false }
    }

    func setVolume(_ loopId: UUID, volume: Double) {
        if let idx = playbackLoops.firstIndex(where: { $0.loop.id == loopId }) {
            playbackLoops[idx].volume = volume
        }
    }

    func stopPlayback() {
        playbackLoops.removeAll()
        isPlaying = false
    }

    func reset() {
        isRecording = false
        recordedEvents = []
        stopPlayback()
    }
}
