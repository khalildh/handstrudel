import AVFoundation

/// Records the app's audio output and plays it back as a loop.
/// Works in all modes (melodic, grid, drums) since it captures actual audio, not events.
final class AudioLooper {
    private let engine = AVAudioEngine()
    private var recordBuffer: AVAudioPCMBuffer?
    private var recordFramePosition: AVAudioFrameCount = 0
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 44100
    private let channels: AVAudioChannelCount = 2

    private(set) var isRecording = false
    private(set) var isPlaying = false

    // Multiple loops layered
    private var loops: [(id: UUID, player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer)] = []

    static let barOptions = [2, 4, 8, 16]
    var selectedBars: Int = 4

    /// Duration in seconds based on BPM
    func loopDuration(bpm: Double) -> Double {
        return Double(selectedBars) * 4.0 * 60.0 / bpm
    }

    /// Start capturing system audio
    func startRecording(bpm: Double) {
        guard !isRecording else { return }

        let duration = loopDuration(bpm: bpm)
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = 0

        recordBuffer = buffer
        recordFramePosition = 0

        // Install tap on main mixer to capture all audio output
        let mainMixer = engine.mainMixerNode
        let mixerFormat = mainMixer.outputFormat(forBus: 0)

        // Start engine if not running
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                debugPrint("[AudioLooper] Engine start failed: \(error)")
                return
            }
        }

        mainMixer.installTap(onBus: 0, bufferSize: 1024, format: mixerFormat) { [weak self] tapBuffer, _ in
            guard let self, self.isRecording, let recBuf = self.recordBuffer else { return }

            let framesToCopy = min(tapBuffer.frameLength, recBuf.frameCapacity - self.recordFramePosition)
            if framesToCopy == 0 { return }

            // Convert if needed and copy samples
            guard let srcLeft = tapBuffer.floatChannelData?[0],
                  let dstLeft = recBuf.floatChannelData?[0] else { return }

            let offset = Int(self.recordFramePosition)
            for i in 0..<Int(framesToCopy) {
                dstLeft[offset + i] = srcLeft[i]
            }

            if tapBuffer.format.channelCount >= 2, recBuf.format.channelCount >= 2,
               let srcRight = tapBuffer.floatChannelData?[1],
               let dstRight = recBuf.floatChannelData?[1] {
                for i in 0..<Int(framesToCopy) {
                    dstRight[offset + i] = srcRight[i]
                }
            }

            self.recordFramePosition += framesToCopy
            recBuf.frameLength = self.recordFramePosition

            // Auto-stop when buffer is full
            if self.recordFramePosition >= recBuf.frameCapacity {
                DispatchQueue.main.async { self.stopRecording() }
            }
        }

        isRecording = true
    }

    /// Stop recording and return the loop
    @discardableResult
    func stopRecording() -> AudioLoop? {
        guard isRecording else { return nil }
        isRecording = false

        let mainMixer = engine.mainMixerNode
        mainMixer.removeTap(onBus: 0)

        guard let buffer = recordBuffer, buffer.frameLength > 0 else { return nil }

        // Normalize
        normalizeBuffer(buffer)

        let loop = AudioLoop(
            id: UUID(),
            buffer: buffer,
            duration: Double(buffer.frameLength) / sampleRate,
            name: "Loop \(loops.count + 1)"
        )

        // Auto-play
        playLoop(loop)

        return loop
    }

    /// Recording progress 0-1
    func recordingProgress(bpm: Double) -> Double {
        guard isRecording, let buf = recordBuffer else { return 0 }
        return Double(recordFramePosition) / Double(buf.frameCapacity)
    }

    /// Play a loop on repeat
    func playLoop(_ loop: AudioLoop) {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: loop.buffer.format)

        if !engine.isRunning {
            try? engine.start()
        }

        // Schedule looping playback
        player.scheduleBuffer(loop.buffer, at: nil, options: .loops)
        player.play()

        loops.append((id: loop.id, player: player, buffer: loop.buffer))
        isPlaying = true
    }

    /// Stop and remove a specific loop
    func removeLoop(_ loopId: UUID) {
        if let idx = loops.firstIndex(where: { $0.id == loopId }) {
            let entry = loops[idx]
            entry.player.stop()
            engine.detach(entry.player)
            loops.remove(at: idx)
        }
        if loops.isEmpty { isPlaying = false }
    }

    /// Stop all loops
    func stopAll() {
        for entry in loops {
            entry.player.stop()
            engine.detach(entry.player)
        }
        loops.removeAll()
        isPlaying = false
    }

    var activeLoopIds: Set<UUID> {
        Set(loops.map { $0.id })
    }

    private func normalizeBuffer(_ buffer: AVAudioPCMBuffer) {
        var maxSample: Float = 0
        let count = Int(buffer.frameLength)
        for ch in 0..<Int(buffer.format.channelCount) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<count {
                maxSample = max(maxSample, abs(data[i]))
            }
        }
        if maxSample > 0.01 {
            let scale = min(1.0, 0.9 / maxSample)
            if scale < 1.0 {
                for ch in 0..<Int(buffer.format.channelCount) {
                    guard let data = buffer.floatChannelData?[ch] else { continue }
                    for i in 0..<count { data[i] *= scale }
                }
            }
        }
    }
}

struct AudioLoop: Identifiable {
    let id: UUID
    let buffer: AVAudioPCMBuffer
    let duration: Double
    let name: String
}
