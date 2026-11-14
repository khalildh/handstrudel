import AVFoundation

final class AudioExporter {
    static func capturedURL(_ id: UUID) -> URL {
        URL.applicationSupportDirectory.appending(path: "AudioLoops", directoryHint: .isDirectory)
            .appending(path: "\(id).wav")
    }

    static func shareCaptured(_ loop: RecordedLoop) throws -> URL {
        let output = FileManager.default.temporaryDirectory.appending(path: "HandStrudel-\(UUID()).wav")
        try FileManager.default.copyItem(at: capturedURL(loop.id), to: output)
        return output
    }
    /// Render a loop to an M4A file and return the URL
    static func exportLoop(_ loop: RecordedLoop, waveform: String = "sawtooth") async throws -> URL {
        let sampleRate: Double = 44100
        let duration = loop.duration
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(loop.name)_\(Int(Date().timeIntervalSince1970)).m4a")

        // Create a buffer for the entire loop
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }
        buffer.frameLength = frameCount

        // Synthesize events into the buffer
        let leftChannel = buffer.floatChannelData![0]
        let rightChannel = buffer.floatChannelData![1]

        for event in loop.events {
            let startSample = Int(event.timestamp * sampleRate)
            guard startSample >= 0 && startSample < Int(frameCount) else { continue }

            switch event.type {
            case .noteOn(let midi, _, let velocity):
                // Synthesize a note (simple sine wave)
                let freq = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
                let noteDuration = 0.3 // seconds
                let noteSamples = min(Int(noteDuration * sampleRate), Int(frameCount) - startSample)

                for i in 0..<noteSamples {
                    let t = Double(i) / sampleRate
                    let envelope = Float(max(0, 1 - t / noteDuration)) // linear decay
                    let sample = Float(sin(2.0 * .pi * freq * t)) * envelope * Float(velocity) * 0.3
                    let idx = startSample + i
                    if idx < Int(frameCount) {
                        leftChannel[idx] += sample
                        rightChannel[idx] += sample
                    }
                }

            case .drumHit(let hitType):
                // Synthesize drum hit
                let noteSamples = min(Int(0.2 * sampleRate), Int(frameCount) - startSample)
                for i in 0..<noteSamples {
                    let t = Double(i) / sampleRate
                    let envelope = Float(max(0, 1 - t / 0.2))
                    var sample: Float = 0

                    switch hitType {
                    case "kick":
                        let freq = 150 * pow(0.1, t / 0.15)
                        sample = Float(sin(2.0 * .pi * freq * t)) * envelope * 0.8
                    case "snare":
                        sample = Float.random(in: -1...1) * envelope * 0.5
                    case "hihat":
                        sample = Float.random(in: -1...1) * Float(max(0, 1 - t / 0.03)) * 0.3
                    default:
                        sample = Float.random(in: -1...1) * envelope * 0.4
                    }

                    let idx = startSample + i
                    if idx < Int(frameCount) {
                        leftChannel[idx] += sample
                        rightChannel[idx] += sample
                    }
                }

            case .noteOff:
                break
            case .codeSnapshot:
                break // code snapshots are for live playback, not audio export
            }
        }

        // Normalize to prevent clipping
        var maxSample: Float = 0
        for i in 0..<Int(frameCount) {
            maxSample = max(maxSample, abs(leftChannel[i]), abs(rightChannel[i]))
        }
        if maxSample > 1.0 {
            let scale = 0.9 / maxSample
            for i in 0..<Int(frameCount) {
                leftChannel[i] *= scale
                rightChannel[i] *= scale
            }
        }

        // Write to file
        let audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        try audioFile.write(from: buffer)

        return outputURL
    }

}

// ReplayKit delivers app audio on a background callback. Serialize file writes and finalization.
final class CapturedLoopFile: @unchecked Sendable {
    let id: UUID
    private let lock = NSLock()
    private let url: URL
    private var file: AVAudioFile?
    private var format: AVAudioFormat?
    private var frameCount: AVAudioFramePosition = 0
    private var firstTimestamp: CMTime?
    private var failure: Error?
    private var closed = false

    init(id: UUID = UUID(), url: URL? = nil) {
        self.id = id
        self.url = url ?? AudioExporter.capturedURL(id)
    }

    func append(_ sample: CMSampleBuffer) {
        lock.withLock {
            guard !closed, failure == nil, sample.numSamples > 0 else { return }
            guard let description = sample.formatDescription,
                  let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description),
                  let incoming = AVAudioFormat(streamDescription: stream),
                  incoming.sampleRate.isFinite, (8_000...192_000).contains(incoming.sampleRate),
                  sample.numSamples <= 192_000,
                  let buffer = AVAudioPCMBuffer(pcmFormat: incoming, frameCapacity: AVAudioFrameCount(sample.numSamples))
            else { failure = SocialError.message("The captured audio format isn't supported."); return }
            let timestamp = sample.presentationTimeStamp
            var start = frameCount
            if timestamp.isNumeric {
                let origin = firstTimestamp ?? (timestamp - CMTime(seconds: Double(frameCount) / incoming.sampleRate,
                                                                   preferredTimescale: 1_000_000))
                firstTimestamp = origin
                let position = (timestamp - origin).seconds * incoming.sampleRate
                if position.isFinite && abs(position) < incoming.sampleRate * 120 {
                    let aligned = AVAudioFramePosition(position.rounded())
                    if abs(aligned - frameCount) > 1 { start = aligned }
                } else {
                    failure = SocialError.message("The captured audio timing changed unexpectedly.")
                    return
                }
            }
            let skipped = Int(max(0, frameCount - start))
            guard skipped < sample.numSamples else { return }
            buffer.frameLength = AVAudioFrameCount(sample.numSamples - skipped)
            do {
                try sample.copyPCMData(fromRange: skipped..<sample.numSamples, into: buffer.mutableAudioBufferList)
            } catch {
                failure = SocialError.message("Couldn't read the captured audio.")
                return
            }
            write(buffer, gap: max(0, start - frameCount))
        }
    }

    #if DEBUG
    func appendPCM(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            guard !closed, failure == nil, buffer.frameLength > 0 else { return }
            write(buffer)
        }
    }
    #endif

    private func write(_ buffer: AVAudioPCMBuffer, gap: AVAudioFramePosition = 0) {
        do {
            if file == nil {
                let incoming = buffer.format
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                var settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: incoming.sampleRate,
                    AVNumberOfChannelsKey: incoming.channelCount, AVLinearPCMBitDepthKey: 24,
                    AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                if let layout = incoming.settings[AVChannelLayoutKey] { settings[AVChannelLayoutKey] = layout }
                file = try AVAudioFile(forWriting: url, settings: settings,
                                       commonFormat: incoming.commonFormat, interleaved: incoming.isInterleaved)
                format = incoming
            }
            guard format == buffer.format, let file else {
                throw SocialError.message("The audio route changed during the recording. Try a new loop.")
            }
            if gap > 0 {
                guard gap <= AVAudioFramePosition(buffer.format.sampleRate * 2),
                      let silence = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(gap))
                else { throw SocialError.message("The captured audio stopped unexpectedly.") }
                silence.frameLength = AVAudioFrameCount(gap)
                for channel in UnsafeMutableAudioBufferListPointer(silence.mutableAudioBufferList) {
                    if let data = channel.mData { memset(data, 0, Int(channel.mDataByteSize)) }
                }
                try file.write(from: silence)
                frameCount += gap
            }
            try file.write(from: buffer)
            frameCount += AVAudioFramePosition(buffer.frameLength)
        } catch { failure = error }
    }

    func fail(_ error: Error) { lock.withLock { failure = error } }

    func finish() throws -> Double {
        try lock.withLock {
            closed = true
            file = nil
            if let failure { throw failure }
            guard let format, frameCount > 0 else { throw SocialError.message("No app audio was captured.") }
            return Double(frameCount) / format.sampleRate
        }
    }

    func discard() {
        lock.withLock {
            closed = true
            file = nil
            try? FileManager.default.removeItem(at: url)
        }
    }
}
