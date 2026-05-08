import AVFoundation

final class AudioExporter {
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

    /// Save to camera roll
    static func saveToPhotos(url: URL) async throws {
        // For audio files, we save to the Files app instead
        // The URL can be shared via UIActivityViewController
    }
}
