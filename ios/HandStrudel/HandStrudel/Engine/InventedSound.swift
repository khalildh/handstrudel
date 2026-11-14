#if DEBUG
import AVFoundation
import AudioToolbox
import Foundation

struct InventedSound: Identifiable {
    let id: UUID
    let name: String
    let caf: Data

    private static var library: URL {
        URL.applicationSupportDirectory.appendingPathComponent("InventedSounds", isDirectory: true)
    }

    static func saved() -> [Self] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: library, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "caf" }.prefix(24).compactMap {
            let parts = $0.deletingPathExtension().lastPathComponent.split(separator: "_", maxSplits: 1)
            guard parts.count == 2, let id = UUID(uuidString: String(parts[0])),
                  let data = try? Data(contentsOf: $0) else { return nil }
            return Self(id: id, name: String(parts[1]), caf: data)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var savedURL: URL {
        Self.library.appendingPathComponent("\(id.uuidString)_\(name).caf")
    }

    func save() throws {
        try FileManager.default.createDirectory(at: Self.library, withIntermediateDirectories: true)
        guard Self.saved().count < 24 else { throw SampleError.libraryFull }
        try caf.write(to: savedURL, options: .atomic)
    }

    func delete() throws { try FileManager.default.removeItem(at: savedURL) }

    static func variants(for prompt: String) throws -> [Self] {
        let words = Set(prompt.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        let bright = !words.isDisjoint(with: ["glass", "bright", "crystal", "sparkly", "metallic"])
        let bell = !words.isDisjoint(with: ["bell", "bells", "chime", "chimes"])
        let soft = !words.isDisjoint(with: ["warm", "soft", "wood", "wooden", "mellow"])
        let short = !words.isDisjoint(with: ["short", "pluck", "plucked", "knock", "mallet", "kalimba"])
        let color = prompt.lowercased().utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
        let name = title(prompt)
        return try (0..<2).map { variation in
            let shimmer = (bright ? 0.32 : 0.13) + Double((color >> 8) % 11) / 100 + Double(variation) * 0.12
            let decay = (short ? 3.9 : 2.6) + Double(color % 11) / 10 + Double(variation) * 0.5
            let second = bell ? 2.76 : 2.0
            let count = Int(sampleRate * 1.45)
            let root = frequency(midi: 60)
            let samples = (0..<count).map { index -> Float in
                let t = Double(index) / sampleRate
                let angle = 2 * Double.pi * t * root
                let attack = min(1, t / (soft ? 0.022 : 0.005))
                let fade = min(1, Double(count - index - 1) / (sampleRate * 0.055))
                let base = sin(angle) * exp(-t * decay)
                let overtone = sin(angle * second) * shimmer * exp(-t * (decay + 5))
                let strike = sin(angle * 5) * (soft ? 0.04 : 0.14) * exp(-t * 85)
                return Float((base + overtone + strike) * attack * fade * 0.56)
            }
            return Self(id: UUID(), name: "\(name) \(variation == 0 ? "I" : "II")", caf: try makeCAF(samples))
        }
    }

    static func imported(from url: URL) throws -> Self {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try sample(from: url, name: url.deletingPathExtension().lastPathComponent)
    }

    #if targetEnvironment(simulator)
    enum AudioProvider: String, Decodable {
        case local = "stable-audio-local"
        case cloud = "stable-audio-cloud"

        static func available() async -> Self? {
            struct Status: Decodable { let provider: AudioProvider }
            let request = URLRequest(url: URL(string: "http://127.0.0.1:54339/status")!, timeoutInterval: 3)
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try? JSONDecoder().decode(Status.self, from: data).provider
        }
    }

    static func generatedByStability(prompt: String, provider: AudioProvider) async throws -> Self {
        do { return try await requestGeneratedSample(prompt: prompt, provider: provider) }
        catch SampleError.pitch where provider == .local {
            // The model sometimes returns an unpitched or drifting sound.
            try Task.checkCancellation()
            return try await requestGeneratedSample(prompt: prompt, provider: provider)
        }
    }

    private static func requestGeneratedSample(prompt: String, provider: AudioProvider) async throws -> Self {
        let url = URL(string: "http://127.0.0.1:54339/generate")!
        var request = URLRequest(url: url, timeoutInterval: 95)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(provider.rawValue, forHTTPHeaderField: "X-HandStrudel-Audio-Provider")
        request.httpBody = try JSONEncoder().encode(["prompt": prompt])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let reason = String(data: data.prefix(150), encoding: .utf8) ?? ""
            throw SampleError.provider(reason)
        }
        try Task.checkCancellation()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary)
        return try sample(from: temporary, name: prompt)
    }
    #endif

    private static func sample(from url: URL, name: String) throws -> Self {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 4_000_000 else { throw SampleError.format }
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let rate = format.sampleRate
        guard (16_000...96_000).contains(rate), (1...2).contains(format.channelCount),
              file.length >= Int64(rate * 0.25), file.length <= Int64(rate * 4),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))
        else { throw SampleError.format }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else { throw SampleError.format }
        return Self(id: UUID(), name: title(name),
                    caf: try makeCAF(tuned(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))), rate: rate)))
    }

    static let sampleRate = 24_000.0
    static func frequency(midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    static func tuned(_ source: [Float], rate: Double) throws -> [Float] {
        guard source.allSatisfy(\.isFinite), let peak = source.map({ abs($0) }).max(), peak > 0.015,
              let onset = source.firstIndex(where: { abs($0) > peak * 0.04 }) else { throw SampleError.pitch }
        let start = max(0, onset - Int(rate * 0.002))
        let samples = Array(source[start...])
        guard let pitch = detectedPitch(samples, rate: rate, offset: 0.06),
              let laterPitch = detectedPitch(samples, rate: rate, offset: 0.15),
              abs(log2(laterPitch / pitch) * 1200) < 45 else { throw SampleError.pitch }
        let step = rate / sampleRate * frequency(midi: 60) / pitch
        let count = min(Int(Double(samples.count - 1) / step), Int(sampleRate * 2))
        return (0..<count).map { index in
            let position = Double(index) * step
            let frame = Int(position)
            let ratio = Float(position - Double(frame))
            let fade = Float(min(1, Double(index) / 48, Double(count - index - 1) / 480))
            return (samples[frame] * (1 - ratio) + samples[frame + 1] * ratio) * (0.63 / peak) * fade
        }
    }

    static func detectedPitch(_ samples: [Float], rate: Double, offset: Double = 0) -> Double? {
        let strideBy = max(1, Int(rate / 12_000))
        let start = Int(rate * offset)
        guard samples.count > start + Int(rate * 0.09) else { return nil }
        let window = stride(from: start, to: start + Int(rate * 0.09), by: strideBy).map { Double(samples[$0]) }
        let subsampledRate = rate / Double(strideBy)
        let minLag = Int(subsampledRate / 390)
        let maxLag = Int(subsampledRate / 170)
        let count = window.count - maxLag - 1
        guard count > 0 else { return nil }
        let mean = window.reduce(0, +) / Double(window.count)
        let centered = window.map { $0 - mean }
        var scores = Array(repeating: 0.0, count: maxLag + 2)
        for lag in (minLag - 1)...(maxLag + 1) {
            var dot = 0.0, a = 0.0, b = 0.0
            for i in 0..<count {
                let x = centered[i], y = centered[i + lag]
                dot += x * y
                a += x * x
                b += y * y
            }
            if min(a,b) > 0.0001 { scores[lag] = dot / sqrt(a * b) }
        }
        let candidates = (minLag...maxLag).filter { scores[$0] >= scores[$0 - 1] && scores[$0] >= scores[$0 + 1] }
        guard let best = candidates.map({ scores[$0] }).max(), best >= 0.82,
              let lag = candidates.first(where: { scores[$0] >= best - 0.025 }) else { return nil }
        let a = scores[lag - 1], b = scores[lag], c = scores[lag + 1]
        let correction = a + c == 2 * b ? 0 : 0.5 * (a - c) / (a - 2 * b + c)
        return subsampledRate / (Double(lag) + correction)
    }

    private static func title(_ text: String) -> String {
        let clean = String(text.filter { $0.isLetter || $0.isNumber || $0 == " " }.prefix(42))
            .trimmingCharacters(in: .whitespaces)
        return clean.isEmpty ? "Invented sound" : clean
    }

    private static func makeCAF(_ samples: [Float]) throws -> Data {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let count = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count), let channel = buffer.floatChannelData?[0]
        else { throw SampleError.format }
        buffer.frameLength = count
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { channel.update(from: base, count: samples.count) }
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        var fileID: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readWritePermission, 0, &fileID) == noErr, let fileID
        else { throw SampleError.format }
        // CAF instrument metadata stores the float root note and integers big-endian.
        var chunk = CAFInstrumentChunk(mBaseNote: Float32(bitPattern: Float32(60).bitPattern.bigEndian),
                                       mMIDILowNote: 0, mMIDIHighNote: 127, mMIDILowVelocity: 1, mMIDIHighVelocity: 127,
                                       mdBGain: 0, mStartRegionID: 0, mSustainRegionID: 0, mReleaseRegionID: 0, mInstrumentID: 0)
        let result = withUnsafeBytes(of: &chunk) {
            AudioFileSetUserData(fileID, kCAF_InstrumentChunkID, 0, UInt32($0.count), $0.baseAddress!)
        }
        AudioFileClose(fileID)
        guard result == noErr else { throw SampleError.format }
        return try Data(contentsOf: url)
    }

    enum SampleError: LocalizedError {
        case format, pitch, libraryFull, provider(String)
        var errorDescription: String? {
            switch self {
            case .format: return "Use a short WAV (0.25–4 seconds, up to 4 MB)."
            case .pitch: return "Couldn't find a stable note. Try one clean note near middle C, without a chord or pitch bend."
            case .libraryFull: return "Your sound library is full. Delete a sound to save another."
            case .provider(let reason): return "Couldn't generate a sample. \(reason)"
            }
        }
    }
}
#endif
