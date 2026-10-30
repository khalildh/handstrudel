import AVFoundation

/// Speeds a slow-mo recording back up to real time.
///
/// In slow-mo the music runs at half tempo while the user performs, so the
/// raw clip is twice as long as the final one. Compressing it doubles the
/// speed of everything on screen while the music returns to normal tempo.
/// The audio is time-stretched rather than resampled, so the notes keep the
/// pitch they were played at.
enum SlowMoExporter {
    enum ExportError: LocalizedError {
        case noExportSession
        case failed(Error?)

        var errorDescription: String? {
            switch self {
            case .noExportSession: return "Couldn't create an export session."
            case .failed(let error): return error?.localizedDescription ?? "Export failed."
            }
        }
    }

    static func speedUp(_ url: URL, by factor: Double) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let composition = AVMutableComposition()

        for mediaType in [AVMediaType.video, .audio] {
            for track in try await asset.loadTracks(withMediaType: mediaType) {
                guard let compTrack = composition.addMutableTrack(
                    withMediaType: mediaType, preferredTrackID: kCMPersistentTrackID_Invalid
                ) else { continue }
                let range = try await track.load(.timeRange)
                try compTrack.insertTimeRange(range, of: track, at: range.start)
                if mediaType == .video {
                    compTrack.preferredTransform = try await track.load(.preferredTransform)
                }
            }
        }

        let fullRange = CMTimeRange(start: .zero, duration: composition.duration)
        composition.scaleTimeRange(
            fullRange, toDuration: CMTimeMultiplyByFloat64(composition.duration, multiplier: 1 / factor))

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.noExportSession
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("handstrudel_\(Int(Date().timeIntervalSince1970))_fast.mp4")
        try? FileManager.default.removeItem(at: outputURL)
        export.outputURL = outputURL
        export.outputFileType = .mp4
        // Keep pitch when compressing the audio.
        export.audioTimePitchAlgorithm = .spectral
        await export.export()
        guard export.status == .completed else { throw ExportError.failed(export.error) }
        return outputURL
    }
}
