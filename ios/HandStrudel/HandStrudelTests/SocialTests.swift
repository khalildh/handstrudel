import AVFoundation
import XCTest
@testable import HandStrudel

final class SocialTests: XCTestCase {
    func testUsernameValidation() {
        XCTAssertTrue(Profile.isValidUsername("hand_strudel1"))
        XCTAssertFalse(Profile.isValidUsername("ab"))                 // too short
        XCTAssertFalse(Profile.isValidUsername("UpperCase"))          // must be lowercase
        XCTAssertFalse(Profile.isValidUsername("has space"))
        XCTAssertFalse(Profile.isValidUsername(String(repeating: "a", count: 21)))
    }

    func testUsernameNormalization() {
        XCTAssertEqual(Profile.normalizeUsername("Hand Strudel!"), "handstrudel")
        XCTAssertEqual(Profile.normalizeUsername("héllo_wörld"), "hllo_wrld")
        XCTAssertEqual(Profile.normalizeUsername(String(repeating: "x", count: 30)).count, 20)
    }

    func testRenderSizeKeepsAspectAndEvenHeight() {
        // iPhone 16e-sized portrait screen recording.
        let size = VideoUploader.renderSize(for: CGSize(width: 1170, height: 2532))
        XCTAssertEqual(size.width, 720)
        XCTAssertEqual(Int(size.height) % 2, 0)
        XCTAssertEqual(size.height / size.width, 2532.0 / 1170.0, accuracy: 0.01)
    }

    func testFeedVideoDecodes() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","user_id":"00000000-0000-0000-0000-00000000000a",
         "video_key":"videos/a/v.mp4","thumb_key":"thumbs/a/v.jpg","caption":"hi","instrument":"Piano",
         "mode":"scale","duration_s":7.0,"width":720,"height":1558,"like_count":3,"hidden":false,
         "created_at":"2026-11-13T05:00:00Z","username":"alice","liked_by_me":true}
        """
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let v = try dec.decode(Video.self, from: Data(json.utf8))
        XCTAssertEqual(v.likeCount, 3)
        XCTAssertEqual(v.username, "alice")
        XCTAssertEqual(v.likedByMe, true)
        XCTAssertTrue(v.videoURL.absoluteString.hasSuffix("videos/a/v.mp4"))
    }

    /// Runs the real transcode on a generated 2 s portrait clip at iPhone screen size.
    @MainActor
    func testPrepareTranscodesTo720WideWithThumbnail() async throws {
        let src = try await Self.makeClip(width: 1170, height: 2532, seconds: 2)
        let prepared = try await VideoUploader.prepare(src)
        XCTAssertEqual(prepared.width, 720)
        XCTAssertEqual(prepared.height, 1558)
        XCTAssertEqual(prepared.duration, 2, accuracy: 0.2)
        XCTAssertGreaterThan(prepared.thumb.count, 1000)

        let track = try await AVURLAsset(url: prepared.videoURL).loadTracks(withMediaType: .video).first
        let size = try await track?.load(.naturalSize)
        XCTAssertEqual(size?.width, 720)
        XCTAssertEqual(size?.height, 1558)
        XCTAssertLessThan(try VideoUploader.fileSize(prepared.videoURL), 15 * 1024 * 1024)
        let rate = try await track?.load(.estimatedDataRate) ?? 0
        XCTAssertLessThan(rate, 3_000_000, "video bitrate should be ~2.5 Mbps, got \(Int(rate))")
    }

    private static func makeClip(width: Int, height: Int, seconds: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("src_\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<(seconds * 30) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            guard let buffer else { continue }
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), Int32(frame * 4 % 255),
                   CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }

    func testNewVideoEncodesSnakeCase() throws {
        let row = NewVideo(id: UUID(), userId: UUID(), videoKey: "videos/u/x.mp4", thumbKey: "thumbs/u/x.jpg",
                           caption: "c", instrument: nil, mode: "scale", durationS: 7, width: 720, height: 1558)
        let obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any]
        XCTAssertNotNil(obj?["user_id"])
        XCTAssertNotNil(obj?["video_key"])
        XCTAssertNil(obj?["videoKey"])
    }
}
