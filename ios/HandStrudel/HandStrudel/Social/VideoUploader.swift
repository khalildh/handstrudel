import AVFoundation
import Supabase
import UIKit

/// Turns a ReplayKit clip into a feed post: transcode to 720-wide H.264,
/// grab a thumbnail, upload both privately, then wait for the server's publication result.
@MainActor
final class VideoUploader: ObservableObject {
    enum Phase: Equatable { case idle, preparing, uploading(Double), checking, pending(String), done, failed(String) }
    @Published private(set) var phase: Phase = .idle
    private let publish: @MainActor (PublishUploadRequest, UUID) async throws -> PublishUploadResponse
    private let pollTimeout: Duration

    init(pollTimeout: Duration = .seconds(120),
         publish: (@MainActor (PublishUploadRequest, UUID) async throws -> PublishUploadResponse)? = nil) {
        self.pollTimeout = pollTimeout
        self.publish = publish ?? Self.sendPublicationRequest
    }

    var isBusy: Bool {
        switch phase {
        case .preparing, .uploading, .checking: return true
        default: return false
        }
    }

    struct Prepared {
        let videoURL: URL
        let thumb: Data
        let width: Int
        let height: Int
        let duration: Double
    }

    /// Output width for posted clips; height keeps the recording's aspect.
    nonisolated static let outputWidth = 720

    func post(clip: URL, draftID: UUID, accountID: UUID, store: RecordingDrafts,
              caption: String, instrument: String?, mode: String?, soundSetup: SoundSetup?,
              commentsEnabled: Bool, backingEnabled: Bool, backingCredit: BackingCredit?) async -> Bool {
        guard !isBusy else { return false }
        if store.postSubmission(for: draftID, accountID: accountID) != nil {
            return await resume(draftID: draftID, accountID: accountID, store: store)
        }
        do {
            phase = .preparing
            if let backingCredit {
                guard let source = try await FeedService.video(id: backingCredit.videoId), source.backingEnabled == true else {
                    throw SocialError.message("The creator no longer allows new play-along posts. Your private draft is safe.")
                }
            }
            if backingEnabled, try await AVURLAsset(url: clip).loadTracks(withMediaType: .audio).isEmpty {
                throw SocialError.message("This take has no audio to share. Turn off play-along to post it.")
            }
            let prepared = try await Self.prepare(clip)
            defer { try? FileManager.default.removeItem(at: prepared.videoURL) }
            phase = .uploading(0)
            let functions = try await Self.functions(for: accountID)
            let signed: SignUploadResponse = try await functions.invoke(
                "sign-upload",
                options: FunctionInvokeOptions(body: SignUploadRequest(
                    videoBytes: try Self.fileSize(prepared.videoURL),
                    thumbBytes: prepared.thumb.count)))
            try await Self.put(fileURL: prepared.videoURL, to: signed.videoUploadUrl, type: "video/mp4")
            phase = .uploading(0.9)
            try await Self.put(data: prepared.thumb, to: signed.thumbUploadUrl, type: "image/jpeg")
            let fields = VideoPostFields(
                caption: String(caption.prefix(150)), instrument: instrument, mode: mode,
                durationS: prepared.duration, width: prepared.width, height: prepared.height,
                soundSetup: soundSetup, commentsEnabled: commentsEnabled ? nil : false,
                backingEnabled: backingEnabled ? true : nil, sourceVideoId: backingCredit?.videoId)
            let pending = DraftPostSubmission.pending(id: signed.id, fields: fields)
            // Persist before submitting: even a lost HTTP response can mean the server accepted it.
            guard try store.replacePostSubmission(nil, with: pending, draftID: draftID, accountID: accountID) else {
                phase = .idle
                return await resume(draftID: draftID, accountID: accountID, store: store)
            }
            return await track(pending, draftID: draftID, accountID: accountID, store: store,
                               submitImmediately: true, waitForResult: true)
        } catch FunctionsError.httpError(_, let data) {
            let detail = try? JSONDecoder().decode(ErrorResponse.self, from: data).error
            phase = .failed(detail ?? "Couldn't post this video. Your private draft is safe.")
            return false
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
    }

    func resume(draftID: UUID, accountID: UUID, store: RecordingDrafts, waitForResult: Bool = true) async -> Bool {
        guard !isBusy, let submission = store.postSubmission(for: draftID, accountID: accountID) else { return false }
        return await track(submission, draftID: draftID, accountID: accountID, store: store,
                           submitImmediately: false, waitForResult: waitForResult)
    }

    private struct ErrorResponse: Decodable { let error: String }

    private static func functions(for accountID: UUID) async throws -> FunctionsClient {
        let session = try await supabase.auth.session
        guard session.user.id == accountID else {
            throw SocialError.message("Sign back in to the account that started this post.")
        }
        // The shared client attaches the latest session at send time; pin the owner for draft requests.
        return FunctionsClient(url: SocialConfig.supabaseURL.appending(path: "functions/v1"), headers: [
            "apikey": SocialConfig.supabaseAnonKey,
            "Authorization": "Bearer " + session.accessToken,
        ])
    }

    private static func sendPublicationRequest(_ request: PublishUploadRequest,
                                               accountID: UUID) async throws -> PublishUploadResponse {
        let functions = try await functions(for: accountID)
        return try await functions.invoke("publish-upload", options: FunctionInvokeOptions(body: request))
    }

    private func track(_ submission: DraftPostSubmission, draftID: UUID, accountID: UUID, store: RecordingDrafts,
                       submitImmediately: Bool, waitForResult: Bool) async -> Bool {
        guard case .pending(let id, let fields) = submission else {
            phase = .done
            return false
        }
        let statusRequest = PublishUploadRequest(action: "status", id: id)
        let submitRequest = PublishUploadRequest(action: "submit", id: id, fields: fields)
        phase = .checking
        do {
            var status = try await publish(submitImmediately ? submitRequest : statusRequest, accountID).status
            if status == .reserved && !submitImmediately {
                status = try await publish(submitRequest, accountID).status
            }
            if waitForResult {
                let deadline = ContinuousClock.now.advanced(by: pollTimeout)
                while status == .checking, ContinuousClock.now < deadline {
                    try await Task.sleep(for: .seconds(2))
                    status = try await publish(statusRequest, accountID).status
                }
            }
            switch status {
            case .published:
                let changed = try store.replacePostSubmission(submission, with: .published(id: id), draftID: draftID, accountID: accountID)
                if changed { AppAnalytics.shared.record(.recordingPosted) }
                phase = .done
                return changed
            case .held, .failed:
                try store.replacePostSubmission(submission, with: nil, draftID: draftID, accountID: accountID)
                phase = .failed(status == .held
                    ? "This clip didn't pass our public content check. Your private draft is safe."
                    : "We couldn't finish checking this clip. It wasn't posted. Your private draft is safe.")
            case .checking, .reserved:
                phase = .pending("This clip is still being checked. You can check its status in Private drafts.")
            }
        } catch {
            // Only an explicit missing or expired reservation is safe to forget.
            if case FunctionsError.httpError(let code, let data) = error,
               let detail = try? JSONDecoder().decode(ErrorResponse.self, from: data).error,
               (code == 404 && detail == "Upload not found." ||
                code == 409 && detail == "This upload expired. Try again from Private drafts."),
               (try? store.replacePostSubmission(submission, with: nil, draftID: draftID, accountID: accountID)) == true {
                phase = .failed("This upload expired. It wasn't posted. You can post again from Private drafts.")
            } else {
                phase = .pending("We couldn't confirm the post status yet. Check again here or in Private drafts.")
            }
        }
        return false
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
        let sourceDuration = try await asset.load(.duration)
        guard sourceDuration.seconds.isFinite, sourceDuration.seconds > 0, source.width >= 1, size.height >= 2 else {
            throw SocialError.message("The recording could not be read.")
        }
        guard sourceDuration.seconds <= Double(RecordingDrafts.recordingLimit) + 1 else {
            throw SocialError.message("Trim the recording to 60 seconds or less to post it.")
        }
        let capped = CMTime(seconds: Double(RecordingDrafts.recordingLimit), preferredTimescale: 600)
        let assetDuration = CMTimeMinimum(sourceDuration, capped)
        let duration = assetDuration.seconds
        let range = CMTimeRange(start: .zero, duration: assetDuration)

        let composition = AVMutableVideoComposition()
        composition.renderSize = size
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let scale = size.width / source.width
        layer.setTransform(transform.concatenating(CGAffineTransform(scaleX: scale, y: scale)), at: .zero)
        instruction.layerInstructions = [layer]
        composition.instructions = [instruction]

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("post_\(UUID().uuidString).mp4")
        var prepared = false
        defer { if !prepared { try? FileManager.default.removeItem(at: out) } }
        try await encode(asset: asset, composition: composition, size: size, range: range,
                         videoBitrate: targetVideoBitrate(duration: duration), to: out)
        guard try fileSize(out) <= 15 * 1024 * 1024 else {
            throw SocialError.message("This clip is too large to post. Trim it and try again.")
        }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: out))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        let at = CMTime(seconds: min(1, duration / 2), preferredTimescale: 600)
        let cg = try generator.copyCGImage(at: at, actualTime: nil)
        guard let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.75) else {
            throw SocialError.message("Couldn't make a thumbnail.")
        }
        prepared = true
        return Prepared(videoURL: out, thumb: jpeg, width: Int(size.width), height: Int(size.height),
                        duration: duration)
    }

    /// Feed bitrate: ~2.2 MB per 7 s clip. Export presets can't set a bitrate
    /// (HighestQuality ran ~6 Mbps; Medium shrank to 320 wide), so encode directly.
    static let videoBitrate = 2_500_000
    static let audioBitrate = 128_000

    static func targetVideoBitrate(duration: Double) -> Int {
        // Reserve space below the 15 MiB upload limit for AAC, the container and encoder overshoot.
        let available = Double(12 * 1024 * 1024 * 8) / max(duration, 1) - Double(audioBitrate)
        return Int(min(Double(videoBitrate), available))
    }

    private static func encode(asset: AVAsset, composition: AVVideoComposition, size: CGSize,
                               range: CMTimeRange, videoBitrate: Int, to out: URL) async throws {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = range
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
        r.setValue("*", forHTTPHeaderField: "If-None-Match")
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
