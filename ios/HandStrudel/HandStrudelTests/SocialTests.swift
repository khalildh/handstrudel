import AVFoundation
import ImageIO
import Supabase
import UIKit
import XCTest
@testable import HandStrudel

final class SocialTests: XCTestCase {
    func testStudioPreviewFollowsSelectedKeyScaleAndChord() throws {
        let free = try XCTUnwrap(CHORD_PROGRESSIONS.first { $0.id == "free" })
        let secondDegree = try XCTUnwrap(ChordProgression.parse("2 5 1"))
        XCTAssertEqual(SoundArtworkVoice.previewNotes(key: .D, scale: .minor, progression: free), [62, 64, 65, 67])
        XCTAssertEqual(SoundArtworkVoice.previewNotes(key: .C, scale: .major, progression: secondDegree), [50, 53, 57, 62])
    }

    func testProfilePhotoIsCenteredSquareBoundedJPEG() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 800))
        let png = renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1600, height: 800))
        }
        let jpeg = try XCTUnwrap(AvatarPhoto.jpeg(from: png))
        XCTAssertEqual(Array(jpeg.prefix(2)), [0xFF, 0xD8])
        let source = try XCTUnwrap(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 512)
        XCTAssertEqual(image.height, 512)
        XCTAssertLessThanOrEqual(jpeg.count, 384 * 1024)
        XCTAssertNil(AvatarPhoto.jpeg(from: Data("not an image".utf8)))
    }

    func testReviewMilestonesOnlyCountDistinctSuccessfulTakes() throws {
        var milestones = CreatorReviewMilestones()
        let first = UUID()
        let now = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertTrue(milestones.record(first))
        XCTAssertFalse(milestones.record(first))
        XCTAssertTrue(milestones.record(UUID()))
        XCTAssertFalse(milestones.canRequest(version: "1.0", now: now))
        XCTAssertTrue(milestones.record(UUID()))
        XCTAssertTrue(milestones.canRequest(version: "1.0", now: now))
        milestones.requested(version: "1.0", now: now)
        milestones = try JSONDecoder().decode(CreatorReviewMilestones.self, from: JSONEncoder().encode(milestones))
        XCTAssertFalse(milestones.record(first))
        for _ in 0..<3 { XCTAssertTrue(milestones.record(UUID())) }
        XCTAssertFalse(milestones.canRequest(version: "1.1", now: now))
        let afterCooldown = now.addingTimeInterval(90 * 24 * 60 * 60)
        XCTAssertFalse(milestones.canRequest(version: "1.0", now: afterCooldown))
        XCTAssertTrue(milestones.canRequest(version: "1.1", now: afterCooldown))
    }

    func testUniversalPerformanceLinksOnlyOpenCanonicalVideoURLs() throws {
        let id = try XCTUnwrap(UUID(uuidString: "52000000-0000-0000-0000-000000000001"))
        func link(_ value: String) throws -> PerformanceLink? {
            PerformanceLink(url: try XCTUnwrap(URL(string: value)))
        }
        XCTAssertEqual(try link("https://handstrudel.com/watch?v=\(id)"), .watch(id))
        XCTAssertEqual(try link("https://handstrudel.com/watch/?v=\(id)&source=share"), .watch(id))
        XCTAssertEqual(try link("handstrudel://comments/\(id)"), .comments(id))
        XCTAssertEqual(try link("handstrudel://watch/\(id)"), .watch(id))
        XCTAssertEqual(try link("handstrudel://sound/\(id)"), .sound(id))
        XCTAssertEqual(try link("handstrudel://play/\(id)"), .playAlong(id))
        XCTAssertNil(try link("https://handstrudel.com/watch"))
        XCTAssertNil(try link("http://handstrudel.com/watch?v=\(id)"))
        XCTAssertNil(try link("https://handstrudel.com.example.org/watch?v=\(id)"))
        XCTAssertNil(try link("https://handstrudel.com/watch?v=\(id)&v=\(id)"))
        XCTAssertNil(try link("https://handstrudel.com/watch?v=bad"))
        XCTAssertNil(try link("https://handstrudel.com/watch/other?v=\(id)"))
    }

    func testJamHoldSurvivesHeartbeatAndEndsOnRelease() throws {
        let chord = JamHeldVoice(pitches: [60, 64, 67, 71], program: 40, waveform: "triangle", velocity: 0.6)
        let held = JamHeldState(sequence: 1, voices: ["pad": chord])
        let wire = try JSONEncoder().encode(held)
        var peer = JamPeerState()
        XCTAssertTrue(peer.accept(try JSONDecoder().decode(JamHeldState.self, from: wire), now: 0))
        for tick in 1...8 {
            // A heartbeat extends the hold without retriggering the audio.
            XCTAssertFalse(peer.accept(JamHeldState(sequence: UInt64(tick + 1), voices: held.voices),
                                       now: Double(tick) * 0.5))
        }
        XCTAssertFalse(peer.expire(now: 6))
        XCTAssertEqual(peer.voices["pad"], chord)
        XCTAssertTrue(peer.accept(JamHeldState(sequence: 10, voices: [:]), now: 6.1))
        XCTAssertFalse(peer.accept(held, now: 6.2))
        XCTAssertTrue(peer.voices.isEmpty)
        let repeatedChord = JamHeldVoice(pitches: chord.pitches, program: chord.program,
                                         waveform: chord.waveform, velocity: chord.velocity)
        XCTAssertTrue(peer.accept(JamHeldState(sequence: 11, voices: ["pad": repeatedChord]), now: 6.3))
        XCTAssertNotEqual(peer.voices["pad"]?.attack, chord.attack)
    }

    func testJamHoldSlidesAndExpiresWhenPeerStopsUpdating() {
        let initial = JamHeldVoice(pitches: [60], program: nil, waveform: "triangle", velocity: 0.7)
        var slide = initial
        slide.pitches = [62]
        var peer = JamPeerState()
        XCTAssertTrue(peer.accept(JamHeldState(sequence: 1, voices: ["right": initial]), now: 0))
        XCTAssertTrue(peer.accept(JamHeldState(sequence: 2, voices: ["right": slide]), now: 1))
        XCTAssertEqual(peer.voices["right"], slide)
        XCTAssertFalse(peer.expire(now: 3))
        XCTAssertTrue(peer.expire(now: 3.5))
        XCTAssertTrue(peer.voices.isEmpty)
        XCTAssertFalse(peer.accept(JamHeldState(sequence: 3, voices: ["invalid voice": initial]), now: 4))
    }

    func testJamCarriesScaleChordAndInstrument() throws {
        let event = JamEvent.notes(pitches: [60, 64, 67, 71], program: 40,
                                   waveform: "triangle", velocity: 0.6, duration: 0.45)
        let decoded = try JSONDecoder().decode(JamEvent.self, from: JSONEncoder().encode(event))
        XCTAssertEqual(decoded, event)
        XCTAssertTrue(decoded.isPlayable)
    }

    func testJamRejectsUnsupportedAudioInputs() {
        XCTAssertFalse(JamEvent.notes(pitches: [128], program: nil,
                                     waveform: "triangle", velocity: 0.6, duration: 0.25).isPlayable)
        XCTAssertFalse(JamEvent.notes(pitches: [60], program: 128,
                                     waveform: "triangle", velocity: 0.6, duration: 0.25).isPlayable)
        XCTAssertFalse(JamEvent.notes(pitches: [60], program: nil,
                                     waveform: "unknown", velocity: 0.6, duration: 0.25).isPlayable)
        XCTAssertTrue(JamEvent.drumHit(hitType: "snare").isPlayable)
        XCTAssertFalse(JamEvent.drumHit(hitType: "unknown").isPlayable)
    }

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
        XCTAssertNil(v.soundSetup)
        XCTAssertNil(v.commentsEnabled, "Clients should support a backend without the comments migration")

        var row = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        row["sound_setup"] = ["version": 99]
        row["comments_enabled"] = true
        row["comment_count"] = 12
        let unsupported = try dec.decode(Video.self, from: JSONSerialization.data(withJSONObject: row))
        XCTAssertEqual(unsupported.id, v.id)
        XCTAssertNil(unsupported.soundSetup)
        XCTAssertEqual(unsupported.commentsEnabled, true)
        XCTAssertEqual(unsupported.commentCount, 12)
    }

    func testSearchUsesLiteralTextAndHandleScope() throws {
        XCTAssertNil(PostSearch(" @x "))
        XCTAssertNil(PostSearch("  "))
        let handle = try XCTUnwrap(PostSearch(" @cloud_music "))
        XCTAssertEqual(handle.text, "cloud_music")
        XCTAssertEqual(handle.filter, "username.imatch.\"cloud_music\"")
        let search = try XCTUnwrap(PostSearch("hi,.*"))
        XCTAssertTrue(search.filter.hasPrefix(#"caption.imatch."hi,\\.\\*",instrument.imatch."#))
        XCTAssertTrue(search.filter.contains("display_name.imatch"))
        XCTAssertEqual(search.filter(after: "cursor"), "and(or(\(search.filter)),or(cursor))")
    }

    func testCreatorLoadsFromVisibleFeedWhenCreatorViewIsMissing() async throws {
        let client = discoveryClient { request in
            if request.path == "/public_creators" { return Self.missingView }
            XCTAssertEqual(request.path, "/feed_videos")
            XCTAssertEqual(request.queryItems?.first(where: { $0.name == "user_id" })?.value?.lowercased(),
                           "eq.\(Self.discoveryUser.lowercased())")
            return (200, Self.discoveryVideo)
        }
        let user = try XCTUnwrap(UUID(uuidString: Self.discoveryUser))
        let creator = try await FeedService.creator(id: user, from: client.from)
        XCTAssertEqual(creator?.id, user)
        XCTAssertEqual(creator?.username, "musician")
        XCTAssertEqual(creator?.displayName, "The Musician")
    }

    func testFollowingWithNoFollowsReturnsEmptyWhenViewIsMissing() async throws {
        let client = discoveryClient { request in
            if request.path == "/following_videos" { return Self.missingView }
            XCTAssertEqual(request.path, "/follows")
            XCTAssertEqual(request.queryItems?.first(where: { $0.name == "follower_id" })?.value,
                           "eq.\(Self.discoveryViewer.lowercased())")
            return (200, "[]")
        }
        let user = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        let page = try await FeedService.followingPage(user: user, from: client.from)
        XCTAssertTrue(page.isEmpty)
    }

    func testFollowingFallsBackToVisiblePostsWithTheFullPaginationTimestamp() async throws {
        let client = discoveryClient { request in
            if request.path == "/following_videos" { return Self.missingView }
            if request.path == "/follows" { return (200, "[{\"followee_id\":\"\(Self.discoveryUser)\"}]") }
            XCTAssertEqual(request.path, "/feed_videos")
            XCTAssertTrue(request.queryItems?.first(where: { $0.name == "user_id" })?.value?
                .contains(Self.discoveryUser.lowercased()) == true)
            if let cursor = request.queryItems?.first(where: { $0.name == "or" })?.value {
                XCTAssertTrue(cursor.contains("2026-11-13T05:00:00.123456+00:00"))
                return (200, "[]")
            }
            return (200, Self.discoveryVideo)
        }
        let user = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        let first = try await FeedService.followingPage(user: user, from: client.from)
        let post = try XCTUnwrap(first.first)
        let next = try await FeedService.followingPage(user: user, after: post, from: client.from)
        XCTAssertTrue(next.isEmpty)
    }

    func testFollowingDoesNotHideAnAuthorizationFailure() async throws {
        let client = discoveryClient { request in
            XCTAssertEqual(request.path, "/following_videos")
            return (403, #"{"code":"42501","message":"permission denied"}"#)
        }
        let user = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        do {
            _ = try await FeedService.followingPage(user: user, from: client.from)
            XCTFail("An authorization error is not an empty feed")
        } catch let error as PostgrestError {
            XCTAssertEqual(error.code, "42501")
        }
    }

    func testMissingBookmarkTableAndLibraryReportThatSavingIsUnavailable() async throws {
        let client = discoveryClient { request in
            XCTAssertTrue(["/video_bookmarks", "/saved_videos"].contains(request.path))
            return Self.missingView
        }
        let video = try XCTUnwrap(UUID(uuidString: Self.discoveryUser))
        let viewer = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        do {
            try await FeedService.setBookmark(true, video: video, user: viewer, from: client.from)
            XCTFail("A bookmark that wasn't saved must not look successful")
        } catch FeedService.Unavailable.bookmarks {}
        do {
            _ = try await FeedService.bookmarks(from: client.from)
            XCTFail("An unavailable library isn't empty")
        } catch FeedService.Unavailable.bookmarks {}
    }

    func testMissingNotificationViewIsDistinctFromAnEmptyInbox() async throws {
        let missing = discoveryClient { _ in Self.missingView }
        do {
            _ = try await FeedService.activity(from: missing.from)
            XCTFail("An unavailable inbox isn't empty")
        } catch FeedService.Unavailable.activity {}
        let empty = discoveryClient { request in
            if request.path == "/activity_inbox_v2" { return Self.missingView }
            XCTAssertEqual(request.path, "/activity_inbox")
            return (200, "[]")
        }
        let inbox = try await FeedService.activity(from: empty.from)
        XCTAssertTrue(inbox.isEmpty)
    }

    func testGroupedLikesLoadFromVersionedInboxAndKeepExactCursor() async throws {
        let client = discoveryClient { request in
            XCTAssertEqual(request.path, "/activity_inbox_v2")
            if let cursor = request.queryItems?.first(where: { $0.name == "or" })?.value {
                XCTAssertTrue(cursor.contains("2026-11-14T05:00:00.123456+00:00"))
                return (200, "[]")
            }
            return (200, """
                [{"id":"33333333-cccc-3333-3333-333333333333","video_id":"\(Self.discoveryUser)",
                "comment_id":null,"kind":"video_like","created_at":"2026-11-14T05:00:00.123456+00:00",
                "read_at":null,"username":"listener","body":"A loop","like_count":3}]
                """)
        }
        let page = try await FeedService.activity(from: client.from)
        let item = try XCTUnwrap(page.first)
        XCTAssertEqual(item.title, "@listener and 2 others liked your video")
        XCTAssertNil(item.commentId)
        XCTAssertTrue(item.kind.isLike)
        let next = try await FeedService.activity(after: item, from: client.from)
        XCTAssertTrue(next.isEmpty)
    }

    private static let discoveryUser = "11111111-aaaa-1111-1111-111111111111"
    private static let discoveryViewer = "22222222-bbbb-2222-2222-222222222222"
    private static let missingView = (404, #"{"code":"PGRST205","message":"Missing view"}"#)
    private static let discoveryVideo = """
        [{"id":"33333333-cccc-3333-3333-333333333333","user_id":"\(discoveryUser)","video_key":"v.mp4",
          "thumb_key":"t.jpg","caption":"First loop","like_count":0,"created_at":"2026-11-13T05:00:00.123456+00:00",
          "username":"musician","display_name":"The Musician"}]
        """

    private func discoveryClient(_ respond: @escaping @Sendable (URLComponents) -> (Int, String)) -> PostgrestClient {
        PostgrestClient(url: URL(string: "https://example.test")!, logger: nil, fetch: { request in
            let url = try XCTUnwrap(request.url)
            let (status, body) = respond(try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)))
            return (Data(body.utf8), try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                                                  headerFields: ["Content-Type": "application/json"])))
        })
    }

    @MainActor
    func testFailedLikeDoesNotChangeAnotherVideoAfterFeedChanges() async throws {
        let writes = AsyncStream<Void>.makeStream()
        let started = AsyncStream<Void>.makeStream()
        let model = FeedModel { _, _, _ in
            started.continuation.yield(())
            var iterator = writes.stream.makeAsyncIterator()
            _ = await iterator.next()
            throw SocialError.message("Test write failure")
        }
        func video(id: UUID, likes: Int) throws -> Video {
            let row = """
            {"id":"\(id)","user_id":"00000000-0000-0000-0000-00000000000a","video_key":"v.mp4",
             "thumb_key":"t.jpg","caption":"","like_count":\(likes),"created_at":"2026-11-14T05:00:00Z"}
            """
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Video.self, from: Data(row.utf8))
        }
        let original = try video(id: UUID(), likes: 4)
        let replacement = try video(id: UUID(), likes: 7)
        model.videos = [original]
        let update = Task { try await model.toggleLike(original, user: UUID()) }
        var signal = started.stream.makeAsyncIterator()
        _ = await signal.next()
        XCTAssertEqual(model.videos.first?.likeCount, 5)
        model.videos = [replacement]
        writes.continuation.yield(())
        do {
            try await update.value
            XCTFail("Expected the write to fail")
        } catch {
            XCTAssertEqual(model.videos, [replacement])
        }
        writes.continuation.finish()
        started.continuation.finish()
    }

    func testCommentBodyValidationAndReplyDecoding() throws {
        XCTAssertFalse(VideoComment.isValidBody(" \t\n "))
        XCTAssertTrue(VideoComment.isValidBody(" " + String(repeating: "a", count: 300) + "\n"))
        XCTAssertFalse(VideoComment.isValidBody(String(repeating: "👨‍👩‍👦", count: 100)))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = """
        {"id":"11111111-1111-1111-1111-111111111111","video_id":"22222222-2222-2222-2222-222222222222",
         "user_id":"33333333-3333-3333-3333-333333333333","parent_id":"44444444-4444-4444-4444-444444444444",
         "username":"listener","body":"Love this sound!","created_at":"2026-11-14T05:00:00Z","reply_count":0}
        """
        let reply = try decoder.decode(VideoComment.self, from: Data(row.utf8))
        XCTAssertNotNil(reply.parentId)
        XCTAssertEqual(reply.username, "listener")
        XCTAssertEqual(reply.body, "Love this sound!")
        XCTAssertEqual(reply.replyCount, 0)
        XCTAssertNil(reply.likeCount)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(row.utf8)) as? [String: Any])
        payload["like_count"] = 2
        payload["liked_by_me"] = false
        var reaction = try decoder.decode(VideoComment.self, from: JSONSerialization.data(withJSONObject: payload))
        XCTAssertEqual(reaction.likeCount, 2)
        XCTAssertEqual(reaction.likedByMe, false)
        reaction.applyLike(true)
        reaction.applyLike(true)
        XCTAssertEqual(reaction.likeCount, 3)
        XCTAssertEqual(reaction.likedByMe, true)
        reaction.applyLike(false)
        XCTAssertEqual(reaction.likeCount, 2)
        XCTAssertEqual(reaction.likedByMe, false)
    }

    func testCapturedLoopWritesInstrumentSamplesToWAV() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).wav")
        let capture = CapturedLoopFile(url: url)
        defer { capture.discard() }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let source = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        source.frameLength = 480
        for i in 0..<480 {
            source.floatChannelData?[0][i] = Float(i) / 960
            source.floatChannelData?[1][i] = -Float(i) / 960
        }
        capture.appendPCM(source)
        capture.appendPCM(source)
        XCTAssertEqual(try capture.finish(), 0.02, accuracy: 0.000_001)
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.settings[AVLinearPCMBitDepthKey] as? Int, 24)
        XCTAssertEqual(file.length, 960)
        let result = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 960))
        try file.read(into: result)
        let samples = try XCTUnwrap(result.floatChannelData)
        XCTAssertEqual(samples[0][600], 0.125, accuracy: 0.000_01)
        XCTAssertEqual(samples[1][600], -0.125, accuracy: 0.000_01)
    }

    func testEmptyLoopCaptureDoesNotProduceAnExport() {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).wav")
        let capture = CapturedLoopFile(url: url)
        defer { capture.discard() }
        XCTAssertThrowsError(try capture.finish())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testReplayKitSamplePathPreservesGapsAndSkipsOverlaps() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).wav")
        let capture = CapturedLoopFile(url: url)
        defer { capture.discard() }
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                                 channels: 1, interleaved: true))
        func packet(start: Int64, value: Int16) throws -> CMSampleBuffer {
            let frames = 8
            let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
            pcm.frameLength = AVAudioFrameCount(frames)
            let channel = try XCTUnwrap(pcm.int16ChannelData)[0]
            for i in 0..<frames { channel[i] = value + Int16(i * 256) }
            var sample: CMSampleBuffer?
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48_000),
                                            presentationTimeStamp: CMTime(value: start, timescale: 48_000),
                                            decodeTimeStamp: .invalid)
            let status = CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                                              makeDataReadyCallback: nil, refcon: nil, formatDescription: format.formatDescription,
                                              sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                              sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample)
            XCTAssertEqual(status, noErr)
            let result = try XCTUnwrap(sample)
            XCTAssertEqual(CMSampleBufferSetDataBufferFromAudioBufferList(result, blockBufferAllocator: nil,
                blockBufferMemoryAllocator: nil, flags: 0, bufferList: pcm.audioBufferList), noErr)
            XCTAssertEqual(CMSampleBufferSetDataReady(result), noErr)
            return result
        }
        capture.append(try packet(start: 48_000, value: 8_192))
        capture.append(try packet(start: 48_012, value: 16_384))
        capture.append(try packet(start: 48_018, value: 4_096))
        XCTAssertEqual(try capture.finish(), 26.0 / 48_000, accuracy: 0.000_000_1)
        let file = try AVAudioFile(forReading: url)
        let result = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 26))
        try file.read(into: result)
        let samples = try XCTUnwrap(result.floatChannelData)[0]
        XCTAssertEqual(result.frameLength, 26)
        XCTAssertEqual(samples[0], 0.25, accuracy: 0.000_1)
        XCTAssertEqual(samples[10], 0, accuracy: 0.000_1)
        XCTAssertEqual(samples[12], 0.5, accuracy: 0.000_1)
        XCTAssertEqual(samples[20], 0.140625, accuracy: 0.000_1)
    }

    func testSoundSetupRoundTripsAndValidatesCustomDegrees() throws {
        let sound = SoundSetup(instrument: "violin", waveform: "sine", key: .C, scale: .major,
                               progression: "custom", customDegrees: [0, 3, 4], mode: .scalechordmelody,
                               bpm: 100, useSoundFont: true, autoStrum: true, padVolume: 0.3, gridOctave: 3, gridRange: 2)
        let decoded = try JSONDecoder().decode(SoundSetup.self, from: JSONEncoder().encode(sound))
        XCTAssertEqual(decoded, sound)
        XCTAssertTrue(decoded.isValid)
        XCTAssertEqual(decoded.resolvedProgression?.degrees, [0, 3, 4])
        XCTAssertEqual(decoded.presetDetails, "C Major · 100 BPM · 1-4-5")
        var unsupported = decoded
        unsupported.version = 99
        XCTAssertFalse(unsupported.isValid)
    }

    func testPrivatePresetPersistsAndDoesNotDuplicateTheSameSave() throws {
        let suite = "preset-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PersistenceManager(defaults: defaults)
        let sound = SoundSetup(instrument: "violin", waveform: "sine", key: .D, scale: .minor,
                               progression: "custom", customDegrees: [0, 3, 4], mode: .scalechordmelody,
                               bpm: 100, useSoundFont: false, autoStrum: true, padVolume: 0.3, gridOctave: 3, gridRange: 2)
        XCTAssertFalse(store.addPreset(sound, named: "  "))
        XCTAssertTrue(store.addPreset(sound, named: "  Evening jam  "))
        XCTAssertFalse(store.addPreset(sound, named: "Evening jam"))
        var invalid = sound
        invalid.version = 99
        XCTAssertFalse(store.addPreset(invalid, named: "Unknown version"))
        let setups = PersistenceManager(defaults: defaults).loadSetups()
        XCTAssertEqual(setups.map(\.name), ["Evening jam"])
        XCTAssertEqual(setups.first?.sound, sound)
        XCTAssertEqual(setups.first?.sound.presetDetails, "D Minor · 100 BPM · 1-4-5")
    }

    func testPlayAlongCountInUsesFourBeatsAndScalesForHalfSpeed() throws {
        let regular = RecordingCountIn(sourceBPM: 120, halfSpeed: false)
        let halfSpeed = RecordingCountIn(sourceBPM: 120, halfSpeed: true)
        XCTAssertTrue(regular.usesBeats)
        XCTAssertEqual(regular.steps, 4)
        XCTAssertEqual(regular.secondsPerStep, 0.5)
        XCTAssertEqual(halfSpeed.secondsPerStep, 1)
        for plan in [regular, halfSpeed, RecordingCountIn(sourceBPM: 400, halfSpeed: false)] {
            let wav = try XCTUnwrap(plan.clickTrack())
            let player = try AVAudioPlayer(data: wav)
            XCTAssertEqual(player.duration, Double(plan.steps) * plan.secondsPerStep, accuracy: 0.001)
            for beat in 0..<plan.steps {
                let start = 44 + 2 * Int((Double(beat) * plan.secondsPerStep * 22_050).rounded())
                XCTAssertTrue(wav[start..<(start + 64)].contains { $0 != 0 })
            }
            XCTAssertTrue(wav.suffix(2_000).allSatisfy { $0 == 0 })
        }
    }

    func testMissingOrInvalidTempoFallsBackToThreeSilentSeconds() {
        for bpm: Double? in [nil, 0, 401, .nan, .infinity] {
            let countIn = RecordingCountIn(sourceBPM: bpm, halfSpeed: true)
            XCTAssertFalse(countIn.usesBeats)
            XCTAssertEqual(countIn.steps, 3)
            XCTAssertEqual(countIn.secondsPerStep, 1)
            XCTAssertNil(countIn.clickTrack())
        }
    }

    func testBackingVolumeClampsInvalidPreferences() {
        XCTAssertEqual(BackingTrackVolume.clamped(-0.1), 0)
        XCTAssertEqual(BackingTrackVolume.clamped(0.3), 0.3)
        XCTAssertEqual(BackingTrackVolume.clamped(1.1), 1)
        XCTAssertEqual(BackingTrackVolume.clamped(.nan), 0.55)
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

    @MainActor
    func testHalfSpeedDraftExportsAtNormalTempoWithoutChangingRawTake() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let drafts = RecordingDrafts(directory: directory)
        var draft = try drafts.begin(instrument: "Violin", mode: "Scale", halfSpeed: true)
        let fixture = try await Self.makeClip(width: 180, height: 320, seconds: 4)
        let raw = drafts.videoURL(for: draft.id)
        try FileManager.default.moveItem(at: fixture, to: raw)
        try drafts.complete(draft)
        XCTAssertEqual(RecordingDrafts(directory: directory).drafts.first?.recordedAtHalfSpeed, true)
        let full = try await drafts.makeExport(for: draft)
        defer { try? FileManager.default.removeItem(at: full) }
        let fullDuration = try await AVURLAsset(url: full).load(.duration).seconds
        XCTAssertEqual(fullDuration, 2, accuracy: 0.08)
        draft.trimStart = 1
        draft.trimEnd = 3
        try drafts.saveTrim(draft)
        let trimmed = try await drafts.makeExport(for: draft)
        defer { try? FileManager.default.removeItem(at: trimmed) }
        let trimmedDuration = try await AVURLAsset(url: trimmed).load(.duration).seconds
        let originalDuration = try await AVURLAsset(url: raw).load(.duration).seconds
        XCTAssertEqual(trimmedDuration, 1, accuracy: 0.08)
        XCTAssertEqual(originalDuration, 4, accuracy: 0.08)
    }

    @MainActor
    func testHalfSpeedTempoUpdatesDrumTracksAndRestoresNormalTempo() {
        let engine = EngineController()
        engine.selectedDrumLoop = DRUM_LOOPS[1]
        engine.selectedDrumLoop2 = DRUM_LOOPS[1]
        let normal = engine.buildDrumCodeParts()
        XCTAssertTrue(normal.allSatisfy { $0.hasSuffix(".cpm(60.0)") })
        XCTAssertEqual(normal.count, 2)
        engine.setRecordingTempo(halfSpeed: true)
        XCTAssertEqual(engine.strudelBridge.tempoScale, 0.5)
        XCTAssertTrue(engine.buildDrumCodeParts().allSatisfy { $0.hasSuffix(".cpm(30.0)") })
        engine.setRecordingTempo(halfSpeed: false)
        XCTAssertEqual(engine.strudelBridge.tempoScale, 1)
        XCTAssertEqual(engine.buildDrumCodeParts(), normal)
    }

    @MainActor
    func testDraftPersistsTrimAndExportsWithoutChangingSource() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RecordingDrafts(directory: dir)
        var draft = try store.begin(instrument: "Piano", mode: "Scale")
        let source = store.videoURL(for: draft.id)
        let fixture = try await Self.makeClip(width: 180, height: 320, seconds: 2)
        try FileManager.default.moveItem(at: fixture, to: source)
        try store.complete(draft)
        draft.trimStart = 0.4
        draft.trimEnd = 1.4
        try store.saveTrim(draft)

        let reopened = RecordingDrafts(directory: dir)
        XCTAssertEqual(reopened.drafts, [draft])
        let export = try await reopened.makeExport(for: draft)
        defer { try? FileManager.default.removeItem(at: export) }
        let trimmed = try await AVURLAsset(url: export).load(.duration).seconds
        let original = try await AVURLAsset(url: source).load(.duration).seconds
        XCTAssertEqual(trimmed, 1, accuracy: 0.1)
        XCTAssertEqual(original, 2, accuracy: 0.1)
        do {
            let unexpectedAudio = try await reopened.makeExport(for: draft, audioOnly: true)
            try? FileManager.default.removeItem(at: unexpectedAudio)
            XCTFail("An audio export needs a recorded audio track")
        } catch {
            XCTAssertEqual(error.localizedDescription, "This take doesn't have an audio track to export.")
        }
        try reopened.delete(draft)
        XCTAssertTrue(RecordingDrafts(directory: dir).drafts.isEmpty)
    }

    @MainActor
    func testFeedBitrateFitsSixtySecondUpload() {
        let bitrate = VideoUploader.targetVideoBitrate(duration: 60) + VideoUploader.audioBitrate
        XCTAssertLessThan(bitrate * 60 / 8, 15 * 1024 * 1024)
        XCTAssertEqual(VideoUploader.targetVideoBitrate(duration: 7), VideoUploader.videoBitrate)
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
        XCTAssertNil(obj?["sound_setup"], "Posting a draft should not opt in by default")
    }
}
