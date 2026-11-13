import AVFoundation
import Supabase
import UIKit

/// Turns a ReplayKit clip into a feed post: transcode to 720-wide H.264,
/// grab a thumbnail, upload both to R2 via presigned URLs, insert the row.
@MainActor
final class VideoUploader: ObservableObject {
    enum Phase: Equatable { case idle, preparing, uploading(Double), done, failed(String) }
    @Published private(set) var phase: Phase = .idle

    struct Prepared {
        let videoURL: URL
        let thumb: Data
        let width: Int
        let height: Int
        let duration: Double
    }

    /// Output width for posted clips; height keeps the recording's aspect.
    nonisolated static let outputWidth = 720

    func post(clip: URL, caption: String, instrument: String?, mode: String?, userId: UUID) async -> Bool {
        do {
            phase = .preparing
            let prepared = try await Self.prepare(clip)
            phase = .uploading(0)
            let signed: SignUploadResponse = try await supabase.functions.invoke(
                "sign-upload",
                options: FunctionInvokeOptions(body: SignUploadRequest(
                    videoBytes: try Self.fileSize(prepared.videoURL),
                    thumbBytes: prepared.thumb.count)))
            try await Self.put(fileURL: prepared.videoURL, to: signed.videoUploadUrl, type: "video/mp4")
            phase = .uploading(0.9)
            try await Self.put(data: prepared.thumb, to: signed.thumbUploadUrl, type: "image/jpeg")
            try await supabase.from("videos").insert(NewVideo(
                id: signed.id, userId: userId, videoKey: signed.videoKey, thumbKey: signed.thumbKey,
                caption: String(caption.prefix(150)), instrument: instrument, mode: mode,
                durationS: prepared.duration, width: prepared.width, height: prepared.height)).execute()
            try? FileManager.default.removeItem(at: prepared.videoURL)
            phase = .done
            return true
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
    }

    // MARK: Transcode + thumbnail

    nonisolated static func renderSize(for natural: CGSize) -> CGSize {
        let w = CGFloat(outputWidth)
        let h = (natural.height / max(natural.width, 1) * w / 2).rounded() * 2  // even height
        return CGSize(width: w, height: h)
    }

    static func prepare(_ clip: URL) async throws -> Prepared {
        let asset = AVURLAsset(url: clip)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw SocialError.message("The recording has no video.")
        }
        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let upright = natural.applying(transform)
        let source = CGSize(width: abs(upright.width), height: abs(upright.height))
        let size = renderSize(for: source)
        let duration = try await asset.load(.duration).seconds

        let composition = AVMutableVideoComposition()
        composition.renderSize = size
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let scale = size.width / source.width
        layer.setTransform(transform.concatenating(CGAffineTransform(scaleX: scale, y: scale)), at: .zero)
        instruction.layerInstructions = [layer]
        composition.instructions = [instruction]

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("post_\(UUID().uuidString).mp4")
        try await encode(asset: asset, composition: composition, size: size, to: out)

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: out))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        let at = CMTime(seconds: min(1, duration / 2), preferredTimescale: 600)
        let cg = try generator.copyCGImage(at: at, actualTime: nil)
        guard let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.75) else {
            throw SocialError.message("Couldn't make a thumbnail.")
        }
        return Prepared(videoURL: out, thumb: jpeg, width: Int(size.width), height: Int(size.height),
                        duration: duration)
    }

    /// Feed bitrate: ~2.2 MB per 7 s clip. Export presets can't set a bitrate
    /// (HighestQuality ran ~6 Mbps; Medium shrank to 320 wide), so encode directly.
    static let videoBitrate = 2_500_000
    static let audioBitrate = 128_000

    /// Reader (through the scaling composition) → writer at a fixed bitrate.
    private static func encode(asset: AVAsset, composition: AVVideoComposition, size: CGSize,
                               to out: URL) async throws {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        let reader = try AVAssetReader(asset: asset)
        let videoOut = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
        videoOut.videoComposition = composition
        reader.add(videoOut)
        var audioOut: AVAssetReaderAudioMixOutput?
        if !audioTracks.isEmpty {
            let a = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM])
            reader.add(a)
            audioOut = a
        }

        let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let videoIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 60,
            ],
        ])
        videoIn.expectsMediaDataInRealTime = false
        writer.add(videoIn)
        var audioIn: AVAssetWriterInput?
        if audioOut != nil {
            let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44_100, AVEncoderBitRateKey: audioBitrate])
            a.expectsMediaDataInRealTime = false
            writer.add(a)
            audioIn = a
        }

        guard reader.startReading(), writer.startWriting() else {
            throw reader.error ?? writer.error ?? SocialError.message("Couldn't prepare the video.")
        }
        writer.startSession(atSourceTime: .zero)

        // Pump each track on its own queue until its reader output runs dry.
        func pump(_ output: AVAssetReaderOutput, into input: AVAssetWriterInput, label: String) async {
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                let queue = DispatchQueue(label: "handstrudel.encode.\(label)")
                input.requestMediaDataWhenReady(on: queue) {
                    while input.isReadyForMoreMediaData {
                        guard let sample = output.copyNextSampleBuffer() else {
                            input.markAsFinished()
                            done.resume()
                            return
                        }
                        if !input.append(sample) {
                            input.markAsFinished()
                            done.resume()
                            return
                        }
                    }
                }
            }
        }
        async let videoDone: Void = pump(videoOut, into: videoIn, label: "video")
        if let audioOut, let audioIn { await pump(audioOut, into: audioIn, label: "audio") }
        await videoDone

        if reader.status == .failed { writer.cancelWriting(); throw reader.error ?? SocialError.message("Couldn't read the video.") }
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? SocialError.message("Video export failed.")
        }
    }

    // MARK: Upload

    static func fileSize(_ url: URL) throws -> Int {
        (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    private static func request(_ url: URL, type: String, length: Int) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = "PUT"
        r.setValue(type, forHTTPHeaderField: "Content-Type")
        r.setValue(String(length), forHTTPHeaderField: "Content-Length")
        return r
    }

    private static func put(fileURL: URL, to url: URL, type: String) async throws {
        let (_, res) = try await URLSession.shared.upload(
            for: request(url, type: type, length: try fileSize(fileURL)), fromFile: fileURL)
        try check(res)
    }

    private static func put(data: Data, to url: URL, type: String) async throws {
        let (_, res) = try await URLSession.shared.upload(
            for: request(url, type: type, length: data.count), from: data)
        try check(res)
    }

    private static func check(_ res: URLResponse) throws {
        guard let http = res as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SocialError.message("Upload failed (\((res as? HTTPURLResponse)?.statusCode ?? 0)).")
        }
    }
}
