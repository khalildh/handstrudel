import AVFoundation
import ImageIO
import Supabase
import UIKit
import XCTest
@testable import HandStrudel

final class SocialTests: XCTestCase {
    func testFeedProgressBoundsSeekInsideClipAndFormatsDuration() throws {
        XCTAssertNil(FeedPlaybackPosition(duration: .infinity, seconds: 1))
        XCTAssertNil(FeedPlaybackPosition(duration: 0, seconds: 1))
        XCTAssertNil(FeedPlaybackPosition(duration: 4, seconds: .nan))
        let end = try XCTUnwrap(FeedPlaybackPosition(duration: 4, seconds: 9))
        XCTAssertEqual(end.seconds, 4)
        XCTAssertGreaterThan(end.seekSeconds, 3.9)
        XCTAssertLessThan(end.seekSeconds, 4)
        XCTAssertEqual(FeedPlaybackPosition(duration: 4, seconds: -3)?.seconds, 0)
        XCTAssertEqual(FeedPlaybackPosition.timeLabel(61), "1:01")
    }

    @MainActor
    func testAccessibleWheelReusesFocusAndReleasesAnActivatedNote() async throws {
        let wheel = SplitTouchUIView(frame: CGRect(x: 0, y: 0, width: 390, height: 790))
        wheel.updateAccessibleNotes(chords: ["Cmaj7", "Fmaj7"], melody: ["C4", "D4", "E4"])
        let initial = try XCTUnwrap(wheel.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(initial.map(\.accessibilityLabel), ["Chord Cmaj7", "Chord Fmaj7", "Note C4", "Note D4", "Note E4"])
        XCTAssertEqual(initial[0].accessibilityCustomActions?.count, 2)
        XCTAssertLessThan(initial[0].accessibilityFrameInContainerSpace.midX, 195)
        XCTAssertGreaterThan(initial[2].accessibilityFrameInContainerSpace.midX, 195)
        wheel.swapHands = true
        wheel.updateAccessibleNotes(chords: ["Dmin7", "G7"], melody: ["D4", "E4", "F4"])
        let updated = try XCTUnwrap(wheel.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertTrue(initial[2] === updated[2])
        XCTAssertEqual(updated[2].accessibilityLabel, "Note D4")
        XCTAssertLessThan(updated[2].accessibilityFrameInContainerSpace.midX, 195)
        let released = expectation(description: "Preview voice was released")
        var voiceID: String?
        wheel.onZoneEnter = { id, zone in voiceID = id; XCTAssertEqual(zone, .melody(0)) }
        wheel.onZoneExit = { id in XCTAssertEqual(id, voiceID); released.fulfill() }
        XCTAssertTrue(updated[2].accessibilityActivate())
        await fulfillment(of: [released], timeout: 1)
    }
    func testWebAudioWaitsForItsPromiseBeforeReportingReady() async throws {
        var states = ["waiting", "loading", "ready"].makeIterator()
        var polls = 0
        try await StrudelBridge.waitForWebAudio(pollNanoseconds: 1_000_000) {
            polls += 1
            return states.next()
        }
        XCTAssertEqual(polls, 3)
    }

    func testFailedWebAudioDoesNotMarkTheEngineReady() async throws {
        do {
            try await StrudelBridge.waitForWebAudio { "failed" }
            XCTFail("Failed initialization must not open a WebAudio-only session")
        } catch {
            XCTAssertEqual((error as NSError).code, 2)
        }
    }

    func testCapturedLoopMixPersistsAndOlderLoopsKeepUnityGain() throws {
        let suite = "loop-mix-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PersistenceManager(defaults: defaults)
        var loop = RecordedLoop(events: [], duration: 2, bpm: 120, name: "Test", mode: "scale")
        let legacy = try JSONDecoder().decode(RecordedLoop.self, from: JSONEncoder().encode(loop))
        XCTAssertEqual(legacy.effectiveGain, 1)
        XCTAssertEqual(RecordedLoop.cleanName("  Evening\nLoop  "), "EveningLoop")
        XCTAssertEqual(RecordedLoop.clampedGain(.nan), 1)
        XCTAssertEqual(RecordedLoop.clampedGain(-2), 0)
        loop.name = "Evening Loop"
        loop.hasCapturedAudio = true
        loop.gain = 0.35
        loop.muted = true
        store.saveLoops([loop])
        let restored = try XCTUnwrap(store.loadLoops().first)
        XCTAssertEqual(restored.name, "Evening Loop")
        XCTAssertEqual(restored.id, loop.id)
        XCTAssertEqual(restored.playbackGain, 0.35)
        XCTAssertEqual(restored.effectiveGain, 0)
        XCTAssertEqual(store.lastLoopBars, 4)
        store.lastLoopBars = 1
        store.lastLoopBars = 17
        XCTAssertEqual(PersistenceManager(defaults: defaults).lastLoopBars, 1)
    }
    @MainActor
    func testAccountDeletionFailureIsUnconfirmedAndDoesNotSignOut() async {
        var signOutCount = 0
        let result = await AuthManager.performAccountDeletion(
            request: { throw URLError(.timedOut) },
            signOut: { signOutCount += 1 }
        )

        XCTAssertEqual(result, .unconfirmed)
        XCTAssertEqual(signOutCount, 0)
    }

    @MainActor
    func testAccountDeletionSignsOutAfterSuccessfulRequest() async {
        var calls: [String] = []
        let result = await AuthManager.performAccountDeletion(
            request: { calls.append("delete") },
            signOut: { calls.append("sign out") }
        )

        XCTAssertEqual(result, .deleted)
        XCTAssertEqual(calls, ["delete", "sign out"])
    }

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

    func testJamNativeLongHoldRecoversAfterHeartbeatBlackout() {
        let chord = JamHeldVoice(pitches: [60, 64, 67, 71], program: 40, waveform: "triangle", velocity: 0.6)
        let voices = ["pad": chord]
        var peer = JamPeerState()
        XCTAssertTrue(peer.accept(JamHeldState(sequence: 1, voices: voices), now: 0))

        // Deliver only every fourth 0.5 s heartbeat for a 12 s native hold.
        for tick in 1...24 {
            let now = Double(tick) * 0.5
            XCTAssertFalse(peer.expire(now: now), "Hold expired at \(now) s")
            if tick.isMultiple(of: 4) {
                XCTAssertFalse(peer.accept(JamHeldState(sequence: UInt64(tick + 1), voices: voices), now: now),
                               "Heartbeat retriggered audio at \(now) s")
            }
            XCTAssertEqual(peer.voices, voices)
        }

        // Lose every heartbeat after 12 s. A duplicate must not renew the watchdog.
        XCTAssertFalse(peer.accept(JamHeldState(sequence: 25, voices: voices), now: 14))
        XCTAssertFalse(peer.expire(now: 14.25))
        XCTAssertTrue(peer.expire(now: 14.5))
        XCTAssertFalse(peer.accept(JamHeldState(sequence: 25, voices: voices), now: 14.75))
        XCTAssertTrue(peer.voices.isEmpty)

        // The next fresh snapshot restores the same attack; a heartbeat delayed
        // until after the release must not bring the chord back.
        XCTAssertTrue(peer.accept(JamHeldState(sequence: 31, voices: voices), now: 15))
        XCTAssertEqual(peer.voices, voices)
        let delayedHeartbeat = JamHeldState(sequence: 32, voices: voices)
        XCTAssertTrue(peer.accept(JamHeldState(sequence: 33, voices: [:]), now: 16))
        XCTAssertFalse(peer.accept(delayedHeartbeat, now: 16.5))
        XCTAssertTrue(peer.voices.isEmpty)
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

    @MainActor
    func testFeedClipReportsMissingMediaOnEachPlaybackAttempt() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).mp4")
        for attempt in 1...2 {
            let failed = expectation(description: "Missing clip reports failure on attempt \(attempt)")
            let player = AVQueuePlayer()
            let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            let monitor = FeedClipFailureMonitor(player: player, looper: looper) { failed.fulfill() }
            player.play()
            await fulfillment(of: [failed], timeout: 5)
            player.pause()
            withExtendedLifetime((looper, monitor)) {}
        }
    }

    func testPublicCreatorDecodesLikesReceivedAndSupportsOldRows() throws {
        func creator(_ total: String) throws -> PublicCreator {
            try JSONDecoder().decode(PublicCreator.self, from: Data(
                """
                {"id":"71000000-0000-4000-8000-000000000001","username":"keys","display_name":null\(total)}
                """.utf8))
        }
        XCTAssertEqual(try creator(",\"likes_received\":1243").likesReceived, 1243)
        XCTAssertEqual(try creator(",\"likes_received\":0").likesReceived, 0)
        XCTAssertNil(try creator("").likesReceived)
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

    func testSearchCanBroadenAHandleMissWithoutChangingTheTerm() throws {
        let handle = try XCTUnwrap(PostSearch(" @Cloud_Music "))
        XCTAssertTrue(handle.isHandleSearch)
        let input = try XCTUnwrap(handle.broaderInput)
        XCTAssertEqual(input, "Cloud_Music")

        let broader = try XCTUnwrap(PostSearch(input))
        XCTAssertFalse(broader.isHandleSearch)
        XCTAssertEqual(broader.text, handle.text)
        XCTAssertTrue(broader.filter.contains(handle.filter))
        XCTAssertTrue(broader.filter.contains("display_name.imatch"))
        XCTAssertNil(broader.broaderInput)
    }

    func testSearchCannotBroadenToAnotherHandleSearch() throws {
        let handle = try XCTUnwrap(PostSearch("@ @cloud_music"))
        XCTAssertTrue(handle.isHandleSearch)
        XCTAssertNil(handle.broaderInput)
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
        XCTAssertTrue(page.videos.isEmpty)
        XCTAssertTrue(page.confirmedNoFollows)
    }

    func testFollowingEmptyViewOnlyClaimsNoFollowsWhenConfirmed() async throws {
        let user = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        let responses = [
            (200, "[]", true),
            (200, "[{\"followee_id\":\"\(Self.discoveryUser)\"}]", false),
            (403, #"{"code":"42501","message":"permission denied"}"#, false),
        ]
        for (status, body, expectedNoFollows) in responses {
            let client = discoveryClient { request in
                if request.path == "/following_videos" { return (200, "[]") }
                XCTAssertEqual(request.path, "/follows")
                XCTAssertEqual(request.queryItems?.first(where: { $0.name == "follower_id" })?.value,
                               "eq.\(Self.discoveryViewer)")
                XCTAssertEqual(request.queryItems?.first(where: { $0.name == "limit" })?.value, "1")
                return (status, body)
            }
            let page = try await FeedService.followingPage(user: user, from: client.from)
            XCTAssertTrue(page.videos.isEmpty)
            XCTAssertEqual(page.confirmedNoFollows, expectedNoFollows)
        }
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
        let post = try XCTUnwrap(first.videos.first)
        XCTAssertFalse(first.confirmedNoFollows)
        let next = try await FeedService.followingPage(user: user, after: post, from: client.from)
        XCTAssertTrue(next.videos.isEmpty)
        XCTAssertFalse(next.confirmedNoFollows)
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

    @MainActor
    func testFollowingModelSeparatesFallbackErrorFromConfirmedEmptyRetry() async throws {
        let viewer = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        let denied = discoveryClient { request in
            if request.path == "/following_videos" { return Self.missingView }
            XCTAssertEqual(request.path, "/follows")
            return (403, #"{"code":"42501","message":"permission denied"}"#)
        }
        let model = FeedModel()
        model.followingOnly = true
        await model.refresh(user: viewer) { user in
            try await FeedService.followingPage(user: user, from: denied.from)
        }
        XCTAssertEqual(model.error, "Couldn't load posts from creators you follow.")
        XCTAssertFalse(model.confirmedNoFollows)
        XCTAssertFalse(model.loading)

        let empty = discoveryClient { request in
            if request.path == "/following_videos" { return Self.missingView }
            XCTAssertEqual(request.path, "/follows")
            return (200, "[]")
        }
        await model.refresh(user: viewer) { user in
            try await FeedService.followingPage(user: user, from: empty.from)
        }
        XCTAssertTrue(model.videos.isEmpty)
        XCTAssertNil(model.error)
        XCTAssertTrue(model.confirmedNoFollows)
        XCTAssertFalse(model.loading)
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

    @MainActor
    func testCommentRefreshKeepsReplyTargetOutsideFirstPage() async {
        let target = commentRoot()
        let firstPage = (0..<FeedService.commentPageSize).map { index in
            commentRoot(videoID: target.videoId, createdAt: target.createdAt.addingTimeInterval(Double(index + 1)))
        }

        let refreshedTarget = CommentsView.replyTargetAfterRefresh(target, firstPage: firstPage)

        XCTAssertEqual(refreshedTarget, target)
    }

    @MainActor
    func testCommentRefreshUsesLatestRowForSameReplyTarget() async {
        let target = commentRoot()
        var fresh = target
        fresh.likeCount = 1
        let firstPage = [commentRoot(videoID: target.videoId), fresh]

        let refreshedTarget = CommentsView.replyTargetAfterRefresh(target, firstPage: firstPage)

        XCTAssertEqual(refreshedTarget, fresh)
        XCTAssertNil(CommentsView.replyTargetAfterRefresh(nil, firstPage: firstPage))
    }

    private func commentRoot(videoID: UUID = UUID(), createdAt: Date = Date(timeIntervalSince1970: 1)) -> VideoComment {
        VideoComment(id: UUID(), videoId: videoID, userId: UUID(), parentId: nil, body: "A comment",
                     createdAt: createdAt, username: "listener", replyCount: 0)
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

    func testCapturedLoopExportRejectsTruncatedWAV() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appending(path: UUID().uuidString)
        let exports = directory.appending(path: "Exports")
        try manager.createDirectory(at: exports, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }

        let source = directory.appending(path: "Capture.wav")
        let capture = CapturedLoopFile(url: source)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        buffer.frameLength = 480
        let samples = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<2 {
            samples[channel].initialize(repeating: 0.25, count: 480)
        }
        capture.appendPCM(buffer)
        let duration = try capture.finish()
        let original = try Data(contentsOf: source)
        let shared = try AudioExporter.shareCaptured(at: source, duration: duration, into: exports)
        XCTAssertEqual(try Data(contentsOf: shared), original)

        // Remove half the 24-bit stereo sample data without changing the header.
        let truncated = original.dropLast(240 * 2 * 3)
        try truncated.write(to: source)
        XCTAssertThrowsError(try AudioExporter.shareCaptured(at: source, duration: duration, into: exports))
        XCTAssertEqual(try manager.contentsOfDirectory(atPath: exports.path), [shared.lastPathComponent])
        XCTAssertEqual(try Data(contentsOf: source), truncated)
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

    @MainActor
    func testPresetPackRoundTripsWithoutReplacingPresetsOrUnlockingPacks() throws {
        let suite = "pack-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let target = PersistenceManager(defaults: defaults)
        let premiumInstrument = try XCTUnwrap(SOUNDFONT_INSTRUMENTS.first { $0.packId != nil })
        let sound = SoundSetup(instrument: premiumInstrument.id, waveform: "sine", key: .D, scale: .minor,
                               progression: "custom", customDegrees: [0, 3, 4], mode: .scalechordmelody,
                               bpm: 100, useSoundFont: true, autoStrum: true, padVolume: 0.3, gridOctave: 3, gridRange: 2)
        XCTAssertTrue(target.addPreset(sound, named: "Existing"))
        let existingID = target.loadSetups().first?.id
        let portable = NamedSoundSetup(id: UUID(), name: "Portable", sound: sound)
        let data = try SoundPresetPack([portable, portable]).encoded()
        let pack = try SoundPresetPack.decode(data)
        XCTAssertEqual(try target.importPresetPack(pack), 1)
        XCTAssertEqual(try target.importPresetPack(pack), 0)
        let saved = target.loadSetups()
        XCTAssertEqual(saved.map(\.name), ["Portable", "Existing"])
        XCTAssertEqual(saved.last?.id, existingID)
        XCTAssertNotEqual(saved.first?.id, portable.id)
        XCTAssertEqual(saved.first?.sound.requiredPacks, sound.requiredPacks)
        XCTAssertFalse(EngineController().applySoundSetup(sound, store: StoreManager()))

        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        payload["version"] = 2
        XCTAssertThrowsError(try SoundPresetPack.decode(JSONSerialization.data(withJSONObject: payload)))
        XCTAssertThrowsError(try SoundPresetPack.decode(Data(repeating: 32, count: SoundPresetPack.byteLimit + 1)))
        XCTAssertThrowsError(try SoundPresetPack([NamedSoundSetup(id: UUID(), name: " ", sound: sound)]))
        XCTAssertEqual(target.loadSetups().count, 2)
    }

    @MainActor
    func testMusicHomeCanSaveTheSelectedScaleWheelBeforeStarting() throws {
        let engine = EngineController()
        engine.selectedKey = .E
        engine.selectedScale = .major
        engine.scaleUseSoundFont = true
        engine.chordMelodyProgression = try XCTUnwrap(ChordProgression.parse("2 5 1"))
        let sound = try XCTUnwrap(engine.soundSetupForSaving)
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(sound.mode, .scalechordmelody)
        XCTAssertEqual(sound.key, .E)
        XCTAssertEqual(sound.customDegrees, [1, 4, 0])
        XCTAssertTrue(sound.isValid)
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
        defer { full.remove() }
        let fullDuration = try await AVURLAsset(url: full.url).load(.duration).seconds
        XCTAssertEqual(fullDuration, 2, accuracy: 0.08)
        draft.trimStart = 1
        draft.trimEnd = 3
        try drafts.saveTrim(draft)
        let trimmed = try await drafts.makeExport(for: draft)
        defer { trimmed.remove() }
        let trimmedDuration = try await AVURLAsset(url: trimmed.url).load(.duration).seconds
        let originalDuration = try await AVURLAsset(url: raw).load(.duration).seconds
        XCTAssertEqual(trimmedDuration, 1, accuracy: 0.08)
        XCTAssertEqual(originalDuration, 4, accuracy: 0.08)
    }

    @MainActor
    func testHalfSpeedDraftVideoPreservesMusicalPitch() async throws {
        guard let fixture = ProcessInfo.processInfo.environment["HANDSTRUDEL_HALF_SPEED_AUDIO_FIXTURE"] else {
            throw XCTSkip("Set TEST_RUNNER_HANDSTRUDEL_HALF_SPEED_AUDIO_FIXTURE to a four-second video with an A440 tone.")
        }
        let files = FileManager.default
        let directory = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: directory) }
        let drafts = RecordingDrafts(directory: directory)
        let draft = try drafts.begin(instrument: nil, mode: nil, halfSpeed: true)
        let source = drafts.videoURL(for: draft.id)
        let original = try Data(contentsOf: URL(fileURLWithPath: fixture))
        try original.write(to: source)
        try drafts.complete(draft)

        let video = try await drafts.makeExport(for: draft)
        defer { video.remove() }
        let asset = AVURLAsset(url: video.url)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 2, accuracy: 0.1)
        XCTAssertFalse(try Data(contentsOf: video.url).isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), original)

        // Decode the audio stream from the finished MP4, not a parallel render.
        let extractor = try XCTUnwrap(AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A))
        let audio = directory.appendingPathComponent("decoded-audio.m4a")
        extractor.outputURL = audio
        extractor.outputFileType = .m4a
        await extractor.export()
        XCTAssertEqual(extractor.status, .completed, extractor.error?.localizedDescription ?? "")
        let file = try AVAudioFile(forReading: audio)
        let rate = file.processingFormat.sampleRate
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                   frameCapacity: AVAudioFrameCount(min(file.length, 192_000))))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData)[0]
        let range = Int(rate * 0.5)..<Int(rate * 1.5)
        guard range.upperBound < Int(buffer.frameLength) else { return XCTFail("Missing the center audio") }
        let crossings = range.filter { channel[$0 - 1] <= 0 && channel[$0] > 0 }.count
        let peak = range.map { abs(channel[$0]) }.max() ?? 0
        XCTAssertGreaterThan(peak, 0.01)
        XCTAssertEqual(Double(crossings) * rate / Double(range.count), 440, accuracy: 15)
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
    func testDraftTrimClampsBothHandlesAndRejectsInvalidSavedRanges() throws {
        let trim = try XCTUnwrap(DraftTrimSelection(duration: 4, start: 1, end: 3))
        XCTAssertEqual(trim.moving(.start, to: -1).start, 0)
        XCTAssertEqual(trim.moving(.start, to: 4).start, 2.75)
        XCTAssertEqual(trim.moving(.end, to: -1).end, 1.25)
        XCTAssertEqual(trim.moving(.end, to: 5).end, 4)
        XCTAssertEqual(trim.moving(.start, to: .nan), trim)
        XCTAssertEqual(trim.range.duration.seconds, 2, accuracy: 0.001)
        XCTAssertNil(DraftTrimSelection(duration: 4, start: 1, end: 5))
        XCTAssertNil(DraftTrimSelection(duration: 4, start: 3, end: 1))
        XCTAssertNil(DraftTrimSelection(duration: Double.infinity))
        let short = try XCTUnwrap(DraftTrimSelection(duration: 0.1))
        XCTAssertEqual(short.moving(.start, to: 0.09), short)
        XCTAssertEqual(short.moving(.end, to: 0.01), short)
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
        defer { export.remove() }
        let trimmed = try await AVURLAsset(url: export.url).load(.duration).seconds
        let original = try await AVURLAsset(url: source).load(.duration).seconds
        XCTAssertEqual(trimmed, 1, accuracy: 0.1)
        XCTAssertEqual(original, 2, accuracy: 0.1)
        do {
            _ = try await reopened.makeExport(for: draft, audioOnly: true)
            XCTFail("An audio export needs a recorded audio track")
        } catch {
            XCTAssertEqual(error.localizedDescription, "This take doesn't have an audio track to export.")
        }
        var broken = draft
        broken.trimEnd = 99
        do {
            let unexpected = try await reopened.makeExport(for: broken)
            unexpected.remove()
            XCTFail("Invalid saved trim must never export the entire original")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("trim no longer fits"))
        }
        XCTAssertEqual(RecordingDrafts(directory: dir).drafts, [draft])
        try reopened.delete(draft)
        XCTAssertTrue(RecordingDrafts(directory: dir).drafts.isEmpty)
    }

    @MainActor
    func testDraftExportDiscardsCopyWhenWriterFinishesAfterCancellation() async throws {
        let files = FileManager.default
        let dir = files.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try files.createDirectory(at: dir, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: dir) }

        let task = Task {
            try await RecordingDraftExport.prepare(in: dir, audioOnly: false) { output in
                withUnsafeCurrentTask { $0?.cancel() }
                // Simulate a writer that doesn't observe the cancellation.
                try Data([1, 2, 3]).write(to: output)
            }
        }
        do {
            _ = try await task.value
            XCTFail("A cancelled export should not hand a copy to its consumer")
        } catch is CancellationError {
            XCTAssertEqual(try files.contentsOfDirectory(atPath: dir.path), [])
        }
    }

    @MainActor
    func testDraftExportCleansPartialOutputAndRetainsRetryCopyUntilReleased() async throws {
        struct WriteFailed: Error {}
        let files = FileManager.default
        let dir = files.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try files.createDirectory(at: dir, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: dir) }
        let data = Data([1, 2, 3])

        do {
            _ = try await RecordingDraftExport.prepare(in: dir, audioOnly: true) { output in
                try data.write(to: output)
                throw WriteFailed()
            }
            XCTFail("Expected the export to fail")
        } catch is WriteFailed {
            XCTAssertEqual(try files.contentsOfDirectory(atPath: dir.path), [])
        }

        var copy: RecordingDraftExport? = try await RecordingDraftExport.prepare(in: dir, audioOnly: true) { output in
            try data.write(to: output)
        }
        let url = try XCTUnwrap(copy?.url)
        withExtendedLifetime(copy) {
            XCTAssertEqual(url.pathExtension, "m4a")
            XCTAssertEqual(try? Data(contentsOf: url), data)
        }
        copy = nil
        XCTAssertEqual(try files.contentsOfDirectory(atPath: dir.path), [])
    }

    @MainActor
    func testPrivateDraftRenamePersistsWithoutChangingTrimOrVideo() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecordingDrafts(directory: directory)
        var legacy = try store.begin(instrument: "Piano", mode: "Scale", halfSpeed: true)
        let source = store.videoURL(for: legacy.id)
        let clip = try await Self.makeClip(width: 180, height: 320, seconds: 2)
        try FileManager.default.moveItem(at: clip, to: source)
        try store.complete(legacy)
        legacy.trimStart = 0.25
        legacy.trimEnd = 1.5
        try store.saveTrim(legacy)
        let originalVideo = try Data(contentsOf: source)
        let sidecar = source.deletingLastPathComponent().appendingPathComponent("draft.json")
        let legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: sidecar)) as? [String: Any])
        XCTAssertNil(legacyJSON["title"])

        let reopened = RecordingDrafts(directory: directory)
        XCTAssertEqual(reopened.drafts, [legacy])
        var expected = legacy
        expected.title = "Evening take"
        XCTAssertEqual(try reopened.rename(legacy.id, to: " \n Evening\t  take \r\n"), expected)
        XCTAssertEqual(reopened.drafts, [expected])
        XCTAssertEqual(RecordingDrafts(directory: directory).drafts, [expected])
        XCTAssertEqual(try Data(contentsOf: source), originalVideo)

        // A trim edit made from an older snapshot must not overwrite the private name.
        var newTrim = legacy
        newTrim.trimEnd = 1.75
        expected.trimEnd = newTrim.trimEnd
        XCTAssertEqual(try reopened.saveTrim(newTrim), expected)
        XCTAssertEqual(RecordingDrafts(directory: directory).drafts, [expected])

        expected.title = nil
        XCTAssertEqual(try reopened.rename(legacy.id, to: " \n\t "), expected)
        XCTAssertEqual(RecordingDrafts(directory: directory).drafts, [expected])
        XCTAssertEqual(try Data(contentsOf: source), originalVideo)
    }

    func testPrivateDraftTitleNormalizesWhitespaceAndBoundsGraphemes() {
        let performer = "\u{1F469}\u{200D}\u{1F3A4}"
        let limit = RecordingDraft.titleLimit
        XCTAssertEqual(RecordingDraft.normalizedTitle("  A\u{0}  B \n C "), "A B C")
        XCTAssertNil(RecordingDraft.normalizedTitle("\u{0}\t\n"))
        XCTAssertEqual(RecordingDraft.normalizedTitle(String(repeating: performer, count: limit + 1)),
                       String(repeating: performer, count: limit))
        XCTAssertEqual(RecordingDraft.normalizedTitle(String(repeating: "a", count: limit - 1) + " b")?.count,
                       limit - 1, "The cutoff must not leave trailing whitespace")
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
