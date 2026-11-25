import AVFoundation
import Combine
import ImageIO
import Supabase
import SwiftUI
import UIKit
import XCTest
@testable import HandStrudel

final class SocialTests: XCTestCase {
    func testQualifiedVideoViewRequiresPlaybackAndIgnoresScrubbing() throws {
        var watch = QualifiedClipWatch()
        func position(_ seconds: Double) throws -> FeedPlaybackPosition {
            try XCTUnwrap(FeedPlaybackPosition(duration: 8, seconds: seconds))
        }
        XCTAssertFalse(watch.sample(try position(0), playing: true))
        XCTAssertFalse(watch.sample(try position(5), playing: true))
        XCTAssertFalse(watch.sample(try position(5.2), playing: false))
        watch.resetSample()
        for seconds in [2.0, 2.5, 3.0, 3.5] {
            XCTAssertFalse(watch.sample(try position(seconds), playing: true))
        }
        XCTAssertTrue(watch.sample(try position(4.0), playing: true))
        XCTAssertFalse(watch.sample(try position(4.5), playing: true))
    }

    func testShortClipCanQualifyAtHalfItsDuration() throws {
        var watch = QualifiedClipWatch()
        XCTAssertFalse(watch.sample(try XCTUnwrap(FeedPlaybackPosition(duration: 1, seconds: 0)), playing: true))
        XCTAssertTrue(watch.sample(try XCTUnwrap(FeedPlaybackPosition(duration: 1, seconds: 0.5)), playing: true))
    }

    @MainActor
    func testUsageAnalyticsRequiresConsentAndDeduplicatesMilestones() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var events: [AppAnalytics.Event] = []
        let analytics = AppAnalytics(defaults: defaults) { events.append($0) }
        let dayEnd = Date(timeIntervalSince1970: 86_399)
        let nextDay = dayEnd.addingTimeInterval(1)

        analytics.recordActiveDay(now: dayEnd)
        analytics.record(.firstNote)
        analytics.record(.recordingStarted)
        XCTAssertTrue(events.isEmpty)

        defaults.set(true, forKey: AppAnalytics.optInKey)
        analytics.recordActiveDay(now: dayEnd)
        analytics.recordActiveDay(now: dayEnd)
        analytics.record(.firstNote)
        analytics.record(.firstNote)
        let relaunched = AppAnalytics(defaults: defaults) { events.append($0) }
        relaunched.recordActiveDay(now: dayEnd)
        relaunched.record(.firstNote)
        relaunched.recordActiveDay(now: nextDay)
        relaunched.record(.recordingStarted)
        relaunched.record(.recordingSaved)
        relaunched.record(.recordingPosted)
        relaunched.record(.recordingStarted)
        XCTAssertEqual(events, [.activeDay, .firstNote, .activeDay, .returnDay,
                                .recordingStarted, .recordingSaved, .recordingPosted, .recordingStarted])

        defaults.set(false, forKey: AppAnalytics.optInKey)
        relaunched.recordActiveDay(now: nextDay.addingTimeInterval(86_400))
        relaunched.record(.recordingPosted)
        XCTAssertEqual(events.count, 8)
    }

    @MainActor
    func testProfileAvatarIsAvailableImmediatelyOnReturnAndExpires() async throws {
        let photo = UIImage(systemName: "person.crop.circle")!
        let resource = ProfileImageStore.Resource(url: URL(string: "https://example.test/avatar.jpg")!, kind: .avatar)
        var requests = 0
        var now = Date(timeIntervalSince1970: 1)
        let store = ProfileImageStore(fetch: { _ in requests += 1; return .image(photo) }, now: { now })

        XCTAssertNil(store.displayedImage(for: resource))
        let first = await store.load(resource)
        XCTAssertTrue(first === photo)
        XCTAssertTrue(store.displayedImage(for: resource) === photo)
        let reopened = await store.load(resource)
        XCTAssertTrue(reopened === photo)
        XCTAssertEqual(requests, 1)

        now.addTimeInterval(301)
        XCTAssertNil(store.displayedImage(for: resource))
    }

    @MainActor
    func testProfileThumbnailRechecksVisibilityWithoutBlankingTheWarmImage() async {
        let photo = UIImage(systemName: "film")!
        let resource = ProfileImageStore.Resource(url: URL(string: "https://example.test/clip.jpg")!, kind: .thumbnail)
        let rechecking = expectation(description: "Thumbnail visibility is rechecked")
        let release = AsyncStream<Void>.makeStream()
        var requests = 0
        let store = ProfileImageStore(fetch: { _ in
            requests += 1
            if requests == 1 { return .image(photo) }
            rechecking.fulfill()
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
            return .denied
        })

        _ = await store.load(resource)
        let refresh = Task { await store.load(resource) }
        await fulfillment(of: [rechecking], timeout: 1)
        XCTAssertTrue(store.displayedImage(for: resource) === photo)
        release.continuation.yield(())
        release.continuation.finish()
        let result = await refresh.value
        XCTAssertNil(result)
        XCTAssertNil(store.displayedImage(for: resource))
    }

    @MainActor
    func testClearingProfileImagesRejectsAnInFlightResponse() async {
        let photo = UIImage(systemName: "film")!
        let resource = ProfileImageStore.Resource(url: URL(string: "https://example.test/clip.jpg")!, kind: .thumbnail)
        let started = expectation(description: "Old account started an image request")
        let release = AsyncStream<Void>.makeStream()
        let store = ProfileImageStore(fetch: { _ in
            started.fulfill()
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
            return .image(photo)
        })

        let old = Task { await store.load(resource) }
        await fulfillment(of: [started], timeout: 1)
        store.clear()
        release.continuation.finish()
        let result = await old.value
        XCTAssertNil(result)
        XCTAssertNil(store.displayedImage(for: resource))
    }

    @MainActor
    func testAccountPortfolioKeepsItsSnapshotWhileRefreshingOnReturn() async throws {
        let owner = try XCTUnwrap(UUID(uuidString: Self.discoveryUser))
        let client = discoveryClient { _ in (200, Self.discoveryVideo) }
        let clips: [Video] = try await client.from("videos").select().execute().value
        let updatedClips = clips.map { clip in
            var updated = clip
            updated.caption = "Updated clip"
            return updated
        }
        let requested = expectation(description: "Reopening Account refreshes immediately")
        let release = AsyncStream<Void>.makeStream()
        var calls = 0
        var offline = false
        let portfolio = AccountPortfolio(fetchPage: { _, _ in
            calls += 1
            if offline { throw URLError(.notConnectedToInternet) }
            if calls == 2 {
                requested.fulfill()
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
                return updatedClips
            }
            return clips
        }, fetchCounts: { _ in
            offline ? .init(posts: nil, followers: nil, following: nil, likesReceived: nil, viewsReceived: nil)
                : .init(posts: 1, followers: 2, following: 3, likesReceived: 42, viewsReceived: 120)
        })

        portfolio.selectAccount(owner)
        await portfolio.load(for: owner)
        let refresh = Task { await portfolio.load(for: owner) }
        await fulfillment(of: [requested], timeout: 1)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(portfolio.videos, clips)
        XCTAssertEqual(portfolio.counts?.likesReceived, 42)
        XCTAssertEqual(portfolio.counts?.viewsReceived, 120)
        release.continuation.yield(())
        release.continuation.finish()
        await refresh.value
        XCTAssertEqual(portfolio.videos, updatedClips)

        offline = true
        await portfolio.load(for: owner)
        XCTAssertEqual(calls, 3)
        XCTAssertTrue(portfolio.failed)
        XCTAssertTrue(portfolio.hasLoadedPage)
        XCTAssertEqual(portfolio.videos, updatedClips)
        XCTAssertEqual(portfolio.counts?.likesReceived, 42)
        XCTAssertEqual(portfolio.counts?.viewsReceived, 120)
    }

    @MainActor
    func testAccountSwitchRejectsAnOlderPortfolioResponse() async throws {
        let owner = try XCTUnwrap(UUID(uuidString: Self.discoveryUser))
        let client = discoveryClient { _ in (200, Self.discoveryVideo) }
        let clips: [Video] = try await client.from("videos").select().execute().value
        let requested = expectation(description: "Old account started loading")
        let release = AsyncStream<Void>.makeStream()
        let portfolio = AccountPortfolio(fetchPage: { _, _ in
            requested.fulfill()
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
            return clips
        }, fetchCounts: { _ in .init(posts: 1, followers: 0, following: 0, likesReceived: 42, viewsReceived: 120) })

        portfolio.selectAccount(owner)
        let pending = Task { await portfolio.load(for: owner) }
        await fulfillment(of: [requested], timeout: 1)
        portfolio.selectAccount(nil)
        portfolio.selectAccount(UUID())
        release.continuation.yield(())
        release.continuation.finish()
        await pending.value

        XCTAssertTrue(portfolio.videos.isEmpty)
        XCTAssertNil(portfolio.counts)
        XCTAssertFalse(portfolio.hasLoadedPage)
    }

    @MainActor
    func testFeedPlaybackHandoffPausesRetainedPlayersAndRejectsStaleRequests() {
        let gate = FeedPlaybackGate()
        let firstID = UUID()
        let nextID = UUID()
        let first = FeedPlayerSpy()
        let next = FeedPlayerSpy()
        gate.select(firstID)
        gate.play(first, videoID: firstID)
        XCTAssertTrue(first.didPlay)

        gate.select(nextID)
        XCTAssertFalse(first.didPlay, "The old player must pause even if its cell wasn't reconfigured.")
        gate.play(next, videoID: nextID)
        gate.play(first, videoID: firstID)
        XCTAssertFalse(first.didPlay, "A stale seek completion must not restart the old clip.")
        XCTAssertTrue(next.didPlay)

        gate.select(nil)
        gate.play(next, videoID: nextID)
        XCTAssertFalse(next.didPlay, "Leaving the feed stops even a retained player.")
    }

    @MainActor
    func testFeedPlaybackAllowsOnlyOnePlayerForTheSameClip() {
        let gate = FeedPlaybackGate()
        let clip = UUID()
        let outgoingHost = FeedPlayerSpy()
        let replacementHost = FeedPlayerSpy()
        gate.select(clip)
        gate.play(outgoingHost, videoID: clip)
        gate.play(replacementHost, videoID: clip)
        XCTAssertFalse(outgoingHost.didPlay)
        XCTAssertTrue(replacementHost.didPlay)
        XCTAssertFalse(gate.owns(outgoingHost, videoID: clip))
    }

    private final class FeedPlayerSpy: AVPlayer, @unchecked Sendable {
        private(set) var didPlay = false
        override func play() { didPlay = true }
        override func pause() { didPlay = false }
    }

    @MainActor
    func testFeedOpeningFrameDecodesTheActualBeginningAndAppliesOrientation() async throws {
        let url = try await Self.makeClip(width: 64, height: 96, seconds: 1)
        defer { try? FileManager.default.removeItem(at: url) }
        let source = AVURLAsset(url: url)
        let tracks = try await source.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let composition = AVMutableComposition()
        let rotated = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        try rotated.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 1, preferredTimescale: 30)), of: track, at: .zero)
        rotated.preferredTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 96, ty: 0)
        let image = try await FeedOpeningFrame.decode(composition)
        XCTAssertEqual(image.size, CGSize(width: 96, height: 64))
        let cg = try XCTUnwrap(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let mean = try pixel.withUnsafeMutableBytes { bytes -> Double in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                                 space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return (Double(bytes[0]) + Double(bytes[1]) + Double(bytes[2])) / 3
        }
        XCTAssertLessThan(mean, 20, "This fixture starts black and brightens; decode frame zero, not a later representative thumbnail.")
    }

    @MainActor
    func testFeedOpeningFrameIgnoresADecodeThatCompletesAfterEviction() async {
        let started = expectation(description: "Opening-frame decode started")
        var completion: CheckedContinuation<UIImage, Never>?
        let frame = FeedOpeningFrame(asset: AVMutableComposition(), decode: { _ in
            await withCheckedContinuation { continuation in
                completion = continuation
                started.fulfill()
            }
        })
        await fulfillment(of: [started], timeout: 2)
        frame.cancel()
        completion?.resume(returning: openingFrameMarker())
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(frame.image, "An evicted clip must not republish a late decoded image.")
    }

    @MainActor
    func testFeedPreloadsOpeningFramesFromTheSameAssetsAndReusesThem() async throws {
        let marker = openingFrameMarker()
        var decodedAssets: [AVAsset] = []
        var players: [FeedPlayerSpy] = []
        let preloader = FeedVideoPreloader(openingFrameDecoder: { asset in
            decodedAssets.append(asset)
            return marker
        }) { _ in
            let player = FeedPlayerSpy(playerItem: AVPlayerItem(asset: AVMutableComposition()))
            players.append(player)
            return player
        }
        let resources = (0..<3).map { FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/frame-\($0).mp4")!) }
        preloader.update(resources, current: resources[1].id)
        let next = try XCTUnwrap(preloader.openingFrame(for: resources[2]))
        let image = await waitForOpeningFrame(next)
        XCTAssertTrue(image === marker)
        XCTAssertEqual(decodedAssets.count, 2)
        XCTAssertTrue(decodedAssets.contains { $0 === players[1].currentItem?.asset }, "Use the buffered video's asset, not another image URL.")
        _ = preloader.take(resources[2])
        XCTAssertTrue(preloader.openingFrame(for: resources[2]) === next)
        XCTAssertEqual(decodedAssets.count, 2, "Adopting a preloaded player must not start another frame decode.")
        XCTAssertTrue(players.allSatisfy { !$0.didPlay && $0.isMuted })
        preloader.update([resources[2]], current: resources[2].id)
        XCTAssertNil(preloader.openingFrame(for: resources[0]))
        XCTAssertTrue(preloader.openingFrame(for: resources[2]) === next)
        preloader.update([], current: nil)
        XCTAssertNil(preloader.openingFrame(for: resources[2]))
        XCTAssertNil(next.image, "Leaving the preload window releases decoded images as well as video buffers.")
    }

    @MainActor
    func testFeedOpeningFrameFailureDoesNotPreventTakingOrPlayingTheVideo() async throws {
        let attempted = expectation(description: "Opening-frame failure is handled separately")
        let preloader = FeedVideoPreloader(openingFrameDecoder: { _ in
            attempted.fulfill()
            throw CancellationError()
        }) { _ in FeedPlayerSpy(playerItem: AVPlayerItem(asset: AVMutableComposition())) }
        let clip = FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/failure.mp4")!)
        preloader.update([clip], current: nil)
        await fulfillment(of: [attempted], timeout: 2)
        let player = try XCTUnwrap(preloader.take(clip) as? FeedPlayerSpy)
        XCTAssertNil(preloader.openingFrame(for: clip)?.image)
        let gate = FeedPlaybackGate()
        gate.select(clip.id)
        gate.play(player, videoID: clip.id)
        XCTAssertTrue(player.didPlay)
        preloader.update([], current: nil)
    }

    @MainActor
    func testFeedPlayerShowsTheCachedOpeningFrameBeforeSelectionAndClearsItOnReuse() async throws {
        let marker = openingFrameMarker()
        let preloader = FeedVideoPreloader(openingFrameDecoder: { _ in marker }) { _ in
            FeedPlayerSpy(playerItem: AVPlayerItem(asset: AVMutableComposition()))
        }
        let clip = FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/frame.mp4")!)
        let other = FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/other.mp4")!)
        preloader.update([clip], current: nil)
        _ = await waitForOpeningFrame(try XCTUnwrap(preloader.openingFrame(for: clip)))
        let view = FeedPlayer.PlayerView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.load(videoID: clip.id, url: clip.url, preloader: preloader, isCurrent: false)
        XCTAssertTrue(view.openingFrameView.image === marker)
        XCTAssertFalse(view.openingFrameView.isHidden)
        XCTAssertNil(view.player, "Displaying a preloaded opening frame must not start an offscreen player.")
        view.setAspectFit(true)
        XCTAssertEqual(view.openingFrameView.contentMode, .scaleAspectFit)
        view.load(videoID: other.id, url: other.url, preloader: preloader, isCurrent: false)
        XCTAssertNil(view.openingFrameView.image, "Never display the previous clip's frame while reusing a cell.")
        preloader.update([], current: nil)
    }

    @MainActor
    func testFeedOpeningFrameIsInvalidatedWhenTheVideoURLChanges() async throws {
        let marker = openingFrameMarker()
        let preloader = FeedVideoPreloader(openingFrameDecoder: { _ in marker }) { _ in
            FeedPlayerSpy(playerItem: AVPlayerItem(asset: AVMutableComposition()))
        }
        let clip = FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/old.mp4")!)
        let updated = FeedVideoPreloader.Resource(id: clip.id, url: URL(string: "https://example.test/new.mp4")!)
        preloader.update([clip], current: nil)
        let old = try XCTUnwrap(preloader.openingFrame(for: clip))
        _ = await waitForOpeningFrame(old)
        preloader.update([updated], current: nil)
        XCTAssertNil(preloader.openingFrame(for: clip))
        XCTAssertNil(old.image)
        XCTAssertFalse(preloader.openingFrame(for: updated) === old)
        preloader.update([], current: nil)
    }

    @MainActor
    private func openingFrameMarker() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.cyan.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    @MainActor
    private func waitForOpeningFrame(_ frame: FeedOpeningFrame) async -> UIImage? {
        let ready = expectation(description: "The opening frame was decoded")
        let observation = frame.$image.compactMap { $0 }.prefix(1).sink { _ in ready.fulfill() }
        await fulfillment(of: [ready], timeout: 2)
        withExtendedLifetime(observation) {}
        return frame.image
    }

    @MainActor
    func testFeedWarmsTheSelectedClipSilentlyBeforeTheFeedIsVisible() throws {
        let clips = try feedPagingClips()
        var created: [FeedPlayerSpy] = []
        let preloader = FeedVideoPreloader(makePlayer: { _ in
            let player = FeedPlayerSpy()
            created.append(player)
            return player
        })
        let gate = FeedPlaybackGate(preloader: preloader)
        func feed(visible: Bool) -> PagedFeed<Text> {
            PagedFeed(videos: clips, current: .constant(0), isVisible: visible, allowsPlayback: visible, refresh: {},
                      sharedPlaybackGate: gate, allowsPreloading: true) { video, _, _ in Text(video.caption) }
        }
        let coordinator = feed(visible: false).makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        XCTAssertEqual(created.count, 1, "Only the selected startup clip should consume video bandwidth.")
        let warmed = try XCTUnwrap(created.first)
        XCTAssertTrue(warmed.isMuted)
        XCTAssertFalse(warmed.didPlay)
        XCTAssertNil(gate.selectedVideoID, "Warmup must not grant playback or count a watch.")

        coordinator.parent = feed(visible: true)
        coordinator.applyUpdate(collection)
        XCTAssertEqual(created.count, 2, "Prepare the next clip on entering Feed, without replacing the warmed first player.")
        let first = FeedVideoPreloader.Resource(id: clips[0].id, url: clips[0].videoURL)
        XCTAssertTrue(preloader.take(first) === warmed)
        XCTAssertEqual(gate.selectedVideoID, clips[0].id)
        gate.play(warmed, videoID: clips[0].id)
        XCTAssertTrue(warmed.didPlay)
        XCTAssertFalse(created[1].didPlay)

        coordinator.parent = feed(visible: false)
        coordinator.applyUpdate(collection)
        XCTAssertFalse(warmed.didPlay)
        XCTAssertNil(gate.selectedVideoID)
        preloader.recycle(warmed, resource: first)
        XCTAssertTrue(preloader.take(first) === warmed, "Keep the paused selected clip ready when returning to Music.")
        preloader.update([], current: nil)
    }

    @MainActor
    func testFeedBackgroundingStopsWarmupEvenWhileAScrollUpdateIsDeferred() throws {
        let clips = try feedPagingClips()
        var created: [FeedPlayerSpy] = []
        let preloader = FeedVideoPreloader(makePlayer: { _ in
            let player = FeedPlayerSpy()
            created.append(player)
            return player
        })
        let gate = FeedPlaybackGate(preloader: preloader)
        func feed(preloads: Bool) -> PagedFeed<Text> {
            PagedFeed(videos: clips, current: .constant(0), isVisible: false, allowsPlayback: false, refresh: {},
                      sharedPlaybackGate: gate, allowsPreloading: preloads) { video, _, _ in Text(video.caption) }
        }
        let coordinator = feed(preloads: true).makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        let warmed = try XCTUnwrap(created.first)
        collection.simulatesTracking = true
        coordinator.parent = feed(preloads: false)
        coordinator.applyUpdate(collection)
        let first = FeedVideoPreloader.Resource(id: clips[0].id, url: clips[0].videoURL)
        XCTAssertFalse(preloader.take(first) === warmed, "Backgrounding should release the prepared player immediately, not wait for the pan to finish.")
        XCTAssertNil(gate.selectedVideoID)
        XCTAssertTrue(created.allSatisfy { !$0.didPlay })
        preloader.update([], current: nil)
    }

    @MainActor
    func testFeedWarmupFollowsTheSelectedVideoWhenItsRankChanges() throws {
        let clips = try feedPagingClips()
        var created: [FeedPlayerSpy] = []
        let preloader = FeedVideoPreloader(makePlayer: { _ in
            let player = FeedPlayerSpy()
            created.append(player)
            return player
        })
        let gate = FeedPlaybackGate(preloader: preloader)
        func feed(_ videos: [Video]) -> PagedFeed<Text> {
            PagedFeed(videos: videos, current: .constant(0), isVisible: false, allowsPlayback: false, refresh: {},
                      sharedPlaybackGate: gate, allowsPreloading: true) { video, _, _ in Text(video.caption) }
        }
        let coordinator = feed(clips).makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        coordinator.parent = feed(Array(clips.reversed()))
        coordinator.applyUpdate(collection)
        XCTAssertEqual(created.count, 2)
        let selected = FeedVideoPreloader.Resource(id: clips[2].id, url: clips[2].videoURL)
        XCTAssertTrue(preloader.take(selected) === created[1])
        XCTAssertNil(gate.selectedVideoID)
        XCTAssertTrue(created.allSatisfy { !$0.didPlay })
        preloader.update([], current: nil)
    }

    @MainActor
    func testFeedPreloadsOnlyNeighborsAndReusesTheirPausedPlayers() {
        var created: [FeedPlayerSpy] = []
        let preloader = FeedVideoPreloader(makePlayer: { _ in
            let player = FeedPlayerSpy()
            created.append(player)
            return player
        })
        let clips = (0..<4).map { FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/\($0).mp4")!) }
        preloader.update(Array(clips[0...2]), current: clips[1].id)
        XCTAssertEqual(created.count, 2, "Prepare only the previous and next clip, not the whole feed.")
        XCTAssertTrue(created.allSatisfy { !$0.didPlay && $0.isMuted })
        let next = preloader.take(clips[2])
        XCTAssertTrue(next === created[1], "Paging must adopt the buffered player, not download another copy.")

        preloader.update(Array(clips[1...3]), current: clips[2].id)
        XCTAssertEqual(created.count, 4)
        preloader.recycle(next, resource: clips[2])
        XCTAssertTrue(preloader.take(clips[2]) === next)
        XCTAssertTrue(created.allSatisfy { !$0.didPlay })
    }

    @MainActor
    func testFeedPreloaderDiscardsClipsOutsideTheWindowAndOnLeaving() {
        var created = 0
        let preloader = FeedVideoPreloader(makePlayer: { _ in created += 1; return FeedPlayerSpy() })
        let first = FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/first.mp4")!)
        let next = FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/next.mp4")!)
        preloader.update([first, next], current: first.id)
        let old = preloader.take(next)
        preloader.update([], current: nil)
        preloader.recycle(old, resource: next)
        let reopened = preloader.take(next)
        XCTAssertFalse(reopened === old)
        XCTAssertEqual(created, 2)
    }

    @MainActor
    func testFeedPreloaderRejectsStaleHostsAndChangedVideoURLs() {
        let preloader = FeedVideoPreloader(makePlayer: { _ in FeedPlayerSpy() })
        let clip = FeedVideoPreloader.Resource(id: UUID(), url: URL(string: "https://example.test/clip.mp4")!)
        let updated = FeedVideoPreloader.Resource(id: clip.id, url: URL(string: "https://example.test/updated.mp4")!)
        preloader.update([clip], current: nil)
        let old = preloader.take(clip)
        let replacement = preloader.take(clip)
        preloader.recycle(old, resource: clip)
        preloader.recycle(replacement, resource: clip)
        XCTAssertTrue(preloader.take(clip) === replacement)
        preloader.recycle(replacement, resource: clip)
        preloader.update([updated], current: nil)
        XCTAssertFalse(preloader.take(updated) === replacement)
    }

    @MainActor
    func testVerticalFeedSwipeCanCancelTheScrubberAndButtons() {
        let feed = FeedPagingCollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        XCTAssertTrue(feed.touchesShouldCancel(in: UISlider()))
        XCTAssertTrue(feed.touchesShouldCancel(in: UIButton()))
    }

    @MainActor
    func testFeedActivatesSecondAndThirdCellsAfterDecelerationFlagsClear() async throws {
        let clips = try feedPagingClips()
        var current = 0
        var active = Set<UUID>()
        var activated: XCTestExpectation?
        let feed = PagedFeed(videos: clips, current: Binding(get: { current }, set: { current = $0 }),
                             isVisible: false, allowsPlayback: true, refresh: {}) { video, isCurrent, _ in
            if isCurrent {
                active.insert(video.id)
                activated?.fulfill()
                activated = nil
            }
            return Text(video.caption)
        }
        let coordinator = feed.makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)

        for page in [1, 2, 1] {
            collection.visiblePage = page
            coordinator.configure(collection.visibleCell, at: IndexPath(item: page, section: 0))
            active.remove(clips[page].id)
            collection.simulatedOffset = CGPoint(x: 0, y: CGFloat(page) * collection.bounds.height)
            collection.simulatesDeceleration = true
            coordinator.scrollViewDidEndDecelerating(collection)
            XCTAssertEqual(current, page)
            XCTAssertFalse(active.contains(clips[page].id), "Do not replace hosting views during deceleration.")

            activated = expectation(description: "Selected cell becomes active after deceleration")
            collection.simulatesDeceleration = false
            await fulfillment(of: [try XCTUnwrap(activated)], timeout: 1)
            XCTAssertTrue(active.contains(clips[page].id), "The handoff must not depend on another API response.")
        }
    }

    private func feedPagingClips() throws -> [Video] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try (0..<3).map { index in
            let row: [String: Any] = [
                "id": UUID().uuidString, "user_id": UUID().uuidString, "like_count": 0,
                "caption": "Performance \(index)", "video_key": "clip-\(index).mp4", "thumb_key": "thumb.jpg",
                "created_at": "2026-11-19T00:00:00Z"
            ]
            return try decoder.decode(Video.self, from: JSONSerialization.data(withJSONObject: row))
        }
    }

    func testFeedNavigationKeepsAdjacentVideosInOrder() {
        for (current, step, expected) in [(0, 1, 1), (1, 1, 2), (2, -1, 1), (1, -1, 0)] {
            XCTAssertEqual(FeedNavigation.destination(from: current, by: step, count: 3, choose: { _ in
                XCTFail("Only the edges should choose a random clip.")
                return 0
            }), expected)
        }
    }

    func testFeedNavigationCanChooseEveryOtherVideoAtEitherEdge() {
        for count in 2...8 {
            for (current, step) in [(0, -1), (count - 1, 1)] {
                let targets = (0..<(count - 1)).compactMap { candidate in
                    FeedNavigation.destination(from: current, by: step, count: count, choose: { range in
                        XCTAssertEqual(range, 0..<(count - 1))
                        return candidate
                    })
                }
                XCTAssertEqual(Set(targets), Set(0..<count).subtracting([current]))
            }
        }
    }

    func testFeedNavigationDoesNotInventAnAlternativeForEmptyOrSingleClipFeeds() {
        for count in [0, 1] {
            XCTAssertNil(FeedNavigation.destination(from: 0, by: 1, count: count))
            XCTAssertNil(FeedNavigation.destination(from: 0, by: -1, count: count))
        }
        XCTAssertNil(FeedNavigation.destination(from: -1, by: 1, count: 3))
        XCTAssertNil(FeedNavigation.destination(from: 3, by: -1, count: 3))
        XCTAssertNil(FeedNavigation.destination(from: 0, by: 0, count: 3))
    }

    @MainActor
    func testFeedEdgeSwipesChooseADifferentClipAndAlignTheViewportOnce() throws {
        let clips = try feedPagingClips()
        for (start, step, candidate, expected, decelerates) in [
            (0, -1, 1, 2, false), (2, 1, 0, 0, false), (0, -1, 1, 2, true), (2, 1, 0, 0, true)
        ] {
            var current = start
            var boundaryCalls = 0
            let feed = PagedFeed(videos: clips, current: Binding(get: { current }, set: { current = $0 }),
                                 isVisible: false, allowsPlayback: true, refresh: {}, onBoundary: { amount in
                boundaryCalls += 1
                XCTAssertEqual(amount, step)
                guard let next = FeedNavigation.destination(from: current, by: amount, count: clips.count,
                                                           choose: { _ in candidate }) else { return false }
                current = next
                return true
            }) { video, _, _ in Text(video.caption) }
            let coordinator = feed.makeCoordinator()
            defer { coordinator.cancelPendingUpdates() }
            let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                                collectionViewLayout: UICollectionViewFlowLayout())
            coordinator.applyUpdate(collection)
            let origin = CGFloat(start) * collection.bounds.height
            collection.simulatesDragging = true
            coordinator.scrollViewWillBeginDragging(collection)
            collection.simulatedOffset.y = origin + CGFloat(step) * 150
            var target = collection.simulatedOffset
            coordinator.scrollViewWillEndDragging(collection, withVelocity: CGPoint(x: 0, y: CGFloat(step)), targetContentOffset: &target)
            XCTAssertEqual(target.y, origin, "Finish the edge bounce before switching, rather than scrolling across every intervening clip.")
            XCTAssertEqual(current, start)
            collection.simulatesDragging = false
            collection.simulatesDeceleration = decelerates
            coordinator.scrollViewDidEndDragging(collection, willDecelerate: decelerates)
            if decelerates {
                XCTAssertEqual(boundaryCalls, 0)
                collection.simulatedOffset = target
                collection.simulatesDeceleration = false
                coordinator.scrollViewDidEndDecelerating(collection)
            }
            XCTAssertEqual(boundaryCalls, 1)
            XCTAssertEqual(current, expected)
            XCTAssertEqual(collection.contentOffset.y, CGFloat(expected) * collection.bounds.height)
            XCTAssertEqual(coordinator.playbackGate.selectedVideoID, clips[expected].id)
            coordinator.scrollViewDidEndDecelerating(collection)
            XCTAssertEqual(boundaryCalls, 1, "Repeated scroll callbacks must not pick another random clip.")
        }
    }

    @MainActor
    func testFeedRecognizesEdgeSwipesDespiteRubberBanding() throws {
        let clips = try feedPagingClips()
        for start in [0, 2] {
            var current = start
            let step = start == 0 ? -1 : 1
            var boundaryCalls = 0
            let feed = PagedFeed(videos: clips, current: Binding(get: { current }, set: { current = $0 }),
                                 isVisible: false, allowsPlayback: true, refresh: {}, onBoundary: { amount in
                boundaryCalls += 1
                XCTAssertEqual(amount, step)
                current = 1
                return true
            }) { video, _, _ in Text(video.caption) }
            let coordinator = feed.makeCoordinator()
            defer { coordinator.cancelPendingUpdates() }
            let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                                collectionViewLayout: UICollectionViewFlowLayout())
            coordinator.applyUpdate(collection)
            collection.simulatesDragging = true
            coordinator.scrollViewWillBeginDragging(collection)
            collection.simulatedOffset.y += CGFloat(step) * 25
            collection.simulatedPan.travel = CGPoint(x: 0, y: CGFloat(-step) * 60)
            var target = CGPoint(x: 0, y: CGFloat(start) * collection.bounds.height)
            coordinator.scrollViewWillEndDragging(collection, withVelocity: .zero, targetContentOffset: &target)
            collection.simulatesDragging = false
            coordinator.scrollViewDidEndDragging(collection, willDecelerate: false)
            XCTAssertEqual(boundaryCalls, 1)
            XCTAssertEqual(current, 1)
        }
    }

    @MainActor
    func testFeedDefersTheEdgeJumpUntilLateScrollCallbacksHaveSettled() async throws {
        let clips = try feedPagingClips()
        var current = 0
        var boundaryCalls = 0
        let selected = expectation(description: "The random destination is selected once scrolling really stops")
        let feed = PagedFeed(videos: clips, current: Binding(get: { current }, set: { current = $0 }),
                             isVisible: false, allowsPlayback: true, refresh: {}, onSelection: { video in
            if video.id == clips[2].id { selected.fulfill() }
        }, onBoundary: { _ in
            boundaryCalls += 1
            current = 2
            return true
        }) { video, _, _ in Text(video.caption) }
        let coordinator = feed.makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        collection.simulatesDragging = true
        coordinator.scrollViewWillBeginDragging(collection)
        collection.simulatedOffset.y = -150
        var target = CGPoint.zero
        coordinator.scrollViewWillEndDragging(collection, withVelocity: CGPoint(x: 0, y: -1), targetContentOffset: &target)
        collection.simulatesDragging = false
        collection.simulatesDeceleration = true
        collection.simulatedOffset = target
        coordinator.scrollViewDidEndDecelerating(collection)
        XCTAssertEqual(boundaryCalls, 0, "UIKit can still report deceleration during its end callback.")
        (coordinator as UIScrollViewDelegate).scrollViewDidScroll?(collection)
        collection.simulatesDeceleration = false
        await fulfillment(of: [selected], timeout: 1)
        XCTAssertEqual(boundaryCalls, 1)
        XCTAssertEqual(current, 2)
        XCTAssertEqual(collection.contentOffset.y, collection.bounds.height * 2)
    }

    @MainActor
    func testFeedSmallEdgeDragsDoNotPickARandomClip() throws {
        let clips = try feedPagingClips()
        for start in [0, 2] {
            let feed = PagedFeed(videos: clips, current: .constant(start), isVisible: false, allowsPlayback: true,
                                 refresh: {}, onBoundary: { _ in XCTFail("A short bounce must not navigate."); return false }) {
                video, _, _ in Text(video.caption)
            }
            let coordinator = feed.makeCoordinator()
            defer { coordinator.cancelPendingUpdates() }
            let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                                collectionViewLayout: UICollectionViewFlowLayout())
            coordinator.applyUpdate(collection)
            collection.simulatesDragging = true
            coordinator.scrollViewWillBeginDragging(collection)
            collection.simulatedOffset.y += start == 0 ? -30 : 30
            var target = CGPoint(x: 0, y: CGFloat(start) * collection.bounds.height)
            coordinator.scrollViewWillEndDragging(collection, withVelocity: .zero, targetContentOffset: &target)
            collection.simulatesDragging = false
            coordinator.scrollViewDidEndDragging(collection, willDecelerate: false)
            XCTAssertEqual(coordinator.playbackGate.selectedVideoID, clips[start].id)
        }
    }

    @MainActor
    func testFeedInterruptedDecelerationAnchorsTheNextSwipeToTheVisiblePage() throws {
        let clips = try feedPagingClips()
        var current = 0
        let feed = PagedFeed(videos: clips, current: Binding(get: { current }, set: { current = $0 }),
                             isVisible: false, allowsPlayback: true, refresh: {}) { video, _, _ in Text(video.caption) }
        let coordinator = feed.makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        let height = collection.bounds.height
        collection.simulatesDeceleration = true
        collection.simulatedOffset.y = height * 0.98
        coordinator.scrollViewWillBeginDragging(collection)
        collection.simulatedOffset.y = height * 1.6
        var target = CGPoint(x: 0, y: height * 1.95)
        coordinator.scrollViewWillEndDragging(collection, withVelocity: CGPoint(x: 0, y: 2), targetContentOffset: &target)
        XCTAssertEqual(target.y, height * 2, accuracy: 1, "A second flick must advance past the video already in view.")

        collection.simulatedOffset.y = height * 2
        collection.simulatesDeceleration = false
        coordinator.scrollViewDidEndDecelerating(collection)
        collection.simulatesDeceleration = true
        collection.simulatedOffset.y = height * 1.02
        coordinator.scrollViewWillBeginDragging(collection)
        collection.simulatedOffset.y = height * 0.4
        target.y = height * 0.05
        coordinator.scrollViewWillEndDragging(collection, withVelocity: CGPoint(x: 0, y: -2), targetContentOffset: &target)
        XCTAssertEqual(target.y, 0, accuracy: 1, "Interrupted backward swipes must use the visible page too.")
    }

    @MainActor
    func testFeedSelectsTheDominantVideoWithoutWaitingForScrollingToStop() throws {
        let clips = try feedPagingClips()
        var current = 0
        let feed = PagedFeed(videos: clips, current: Binding(get: { current }, set: { current = $0 }),
                             isVisible: false, allowsPlayback: true, refresh: {}) { video, _, _ in Text(video.caption) }
        let coordinator = feed.makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        collection.simulatesDragging = true
        coordinator.scrollViewWillBeginDragging(collection)
        collection.simulatedOffset.y = collection.bounds.height * 0.6
        (coordinator as UIScrollViewDelegate).scrollViewDidScroll?(collection)
        XCTAssertEqual(current, 1, "The overlay must switch before the next video finishes settling.")
        collection.simulatedOffset.y = collection.bounds.height * 0.4
        (coordinator as UIScrollViewDelegate).scrollViewDidScroll?(collection)
        XCTAssertEqual(current, 0)
    }

    @MainActor
    func testFeedRevisitClearsTheCachedPlayheadBeforeMediaIsReady() async throws {
        let clips = try feedPagingClips()
        let store = FeedPlaybackStore()
        store.select(clips[0])
        let clip = store.clip(for: clips[0].id)
        let player = DelayedFeedSeekPlayer()
        let gate = FeedPlaybackGate()
        gate.select(clips[0].id)
        clip.playback.configure(player: player, videoID: clips[0].id, gate: gate, isCurrent: true,
                                wantsPlayback: false, durationHint: 20, countsViews: false)
        clip.playback.setSeconds(12)
        clip.paused = true
        XCTAssertEqual(clip.playback.position?.seconds, 12)
        store.select(clips[1])
        store.select(clips[0])
        XCTAssertEqual(clip.playback.position?.seconds, 0, "Do not display the previous visit while buffering.")
        XCTAssertFalse(clip.paused)
        player.completeSeek(at: 0, finished: false)
        await Task.yield()
        XCTAssertEqual(clip.playback.position?.seconds, 0, "A stale seek completion must not restore the old position.")
    }

    @MainActor
    func testFeedRestartKeepsThePlayheadAtZeroUntilTheInitialSeekCompletes() async {
        let controller = FeedPlaybackController()
        let player = DelayedFeedSeekPlayer()
        player.time = CMTime(seconds: 8, preferredTimescale: 600)
        let id = UUID()
        let gate = FeedPlaybackGate()
        gate.select(id)
        controller.configure(player: player, videoID: id, gate: gate, isCurrent: true,
                             wantsPlayback: true, durationHint: 20, countsViews: false)
        controller.setSeconds(8)
        controller.prepareForVisit(durationHint: 20)
        controller.configure(player: player, videoID: id, gate: gate, isCurrent: true,
                             wantsPlayback: true, durationHint: 20, countsViews: false)
        XCTAssertEqual(controller.position?.seconds, 0)
        XCTAssertEqual(player.seeks.count, 2)
        XCTAssertEqual(player.seeks.last?.time.seconds, 0)
        XCTAssertFalse(player.didPlay)
        player.completeSeek(at: 0, finished: false)
        await Task.yield()
        XCTAssertEqual(controller.position?.seconds, 0)
        player.completeSeek(at: 1, finished: true)
        for _ in 0..<20 {
            if player.didPlay { break }
            await Task.yield()
        }
        XCTAssertTrue(player.didPlay)
        XCTAssertEqual(controller.position?.seconds, 0)
    }

    @MainActor
    func testSharedScrubberReplacesTheOldThumbPositionEvenWhileTracking() {
        var cancelledOld = false
        var soughtNew = false
        func configuration(_ source: AnyObject.Type, seconds: Double) -> FeedSeekSlider {
            FeedSeekSlider(sourceID: ObjectIdentifier(source), seconds: seconds, duration: 20, enabled: true,
                           tint: .white, valueLabel: "0:00 of 0:20", onChange: { _ in soughtNew = true },
                           onEditing: { _ in }, onCancelEditing: { cancelledOld = true },
                           onVerticalSwipe: nil, onPaging: nil)
        }
        let coordinator = FeedSeekSlider.Coordinator(configuration(NSObject.self, seconds: 12))
        let slider = TrackingFeedSlider()
        slider.maximumValue = 20
        slider.value = 12
        coordinator.update(slider, parent: configuration(AVPlayer.self, seconds: 0))
        XCTAssertEqual(slider.value, 0)
        XCTAssertTrue(cancelledOld)
        XCTAssertFalse(soughtNew, "Resetting the thumb must not seek the newly selected video.")
    }

    @MainActor
    func testFeedIgnoresTimeCallbacksQueuedDuringAPreviousVisit() {
        let controller = FeedPlaybackController()
        let player = DelayedFeedSeekPlayer()
        let id = UUID()
        let gate = FeedPlaybackGate()
        gate.select(id)
        controller.configure(player: player, videoID: id, gate: gate, isCurrent: true,
                             wantsPlayback: false, durationHint: 20, countsViews: false)
        controller.setSeconds(8)
        let oldCallback = player.observers[0]
        controller.prepareForVisit(durationHint: 20)
        controller.configure(player: player, videoID: id, gate: gate, isCurrent: true,
                             wantsPlayback: false, durationHint: 20, countsViews: false)
        oldCallback(CMTime(seconds: 8, preferredTimescale: 600))
        XCTAssertEqual(controller.position?.seconds, 0, "A reused player must not revive a timestamp from the previous visit.")
        player.observers.last?(CMTime(seconds: 0.2, preferredTimescale: 600))
        XCTAssertEqual(controller.position?.seconds, 0.2)
    }

    private final class TrackingFeedSlider: UISlider {
        override var isTracking: Bool { true }
    }

    private final class DelayedFeedSeekPlayer: AVPlayer, @unchecked Sendable {
        var time = CMTime.zero
        private(set) var didPlay = false
        private(set) var seeks: [(time: CMTime, completion: @Sendable (Bool) -> Void)] = []
        private(set) var observers: [@Sendable (CMTime) -> Void] = []
        override func currentTime() -> CMTime { time }
        override func play() { didPlay = true }
        override func pause() { didPlay = false }
        override func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?,
                                             using block: @escaping @Sendable (CMTime) -> Void) -> Any {
            observers.append(block)
            return NSObject()
        }
        override func removeTimeObserver(_ observer: Any) {}
        override func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime,
                           completionHandler: @escaping @Sendable (Bool) -> Void) {
            seeks.append((time, completionHandler))
        }
        func completeSeek(at index: Int, finished: Bool) {
            let seek = seeks[index]
            if finished { time = seek.time }
            seek.completion(finished)
        }
    }

    @MainActor
    func testFeedRetainsTheNewestViewCountWhenRevisitingACell() throws {
        let clips = try feedPagingClips()
        let model = FeedModel()
        model.videos = clips
        model.recordViewCount(8, for: clips[0].id)
        model.current = 1
        model.recordViewCount(4, for: clips[1].id)
        model.current = 0
        XCTAssertEqual(model.videos[model.current].viewCount, 8)
        model.recordViewCount(7, for: clips[0].id)
        model.recordViewCount(-1, for: clips[0].id)
        model.recordViewCount(100, for: UUID())
        XCTAssertEqual(model.videos[0].viewCount, 8, "A late or unrelated response must not revert the count.")
        XCTAssertEqual(model.videos[1].viewCount, 4)
    }

    @MainActor
    func testFeedCoalescesDeferredUpdatesWithoutAnotherScrollCallback() async throws {
        let clips = try feedPagingClips()
        var rendered: [String] = []
        let latest = expectation(description: "Latest metadata is applied when touch tracking ends")
        func feed(_ items: [Video]) -> PagedFeed<Text> {
            PagedFeed(videos: items, current: .constant(0), isVisible: false, allowsPlayback: true, refresh: {}) { video, _, _ in
                rendered.append(video.caption)
                if video.caption == "Latest metadata" { latest.fulfill() }
                return Text(video.caption)
            }
        }
        let coordinator = feed(clips).makeCoordinator()
        defer { coordinator.cancelPendingUpdates() }
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        collection.simulatesTracking = true
        var updated = clips
        updated[0].caption = "Superseded metadata"
        coordinator.parent = feed(updated)
        coordinator.applyUpdate(collection)
        updated[0].caption = "Latest metadata"
        coordinator.parent = feed(updated)
        coordinator.applyUpdate(collection)
        XCTAssertTrue(rendered.isEmpty)
        collection.simulatesTracking = false
        await fulfillment(of: [latest], timeout: 1)
        XCTAssertEqual(rendered, ["Latest metadata"])
    }

    @MainActor
    func testFeedCancelsDeferredUpdatesWhenDismantled() async throws {
        let clips = try feedPagingClips()
        let unexpected = expectation(description: "Dismantled feed must not update its old views")
        unexpected.isInverted = true
        let feed = PagedFeed(videos: clips, current: .constant(0), isVisible: false, allowsPlayback: true, refresh: {}) { _, _, _ in
            unexpected.fulfill()
            return Text("Old feed")
        }
        let coordinator = feed.makeCoordinator()
        let collection = FeedScrollStateSpy(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                            collectionViewLayout: UICollectionViewFlowLayout())
        coordinator.applyUpdate(collection)
        collection.simulatesTracking = true
        coordinator.applyUpdate(collection)
        PagedFeed<Text>.dismantleUIView(collection, coordinator: coordinator)
        collection.simulatesTracking = false
        await fulfillment(of: [unexpected], timeout: 0.2)
    }

    private final class FeedScrollStateSpy: UICollectionView {
        var simulatesDeceleration = false
        var simulatesTracking = false
        var simulatesDragging = false
        var simulatedOffset = CGPoint.zero
        var visiblePage = 0
        let visibleCell = UICollectionViewCell()
        let simulatedPan = FeedPanSpy()
        override var panGestureRecognizer: UIPanGestureRecognizer { simulatedPan }
        override var isDecelerating: Bool { simulatesDeceleration }
        override var isTracking: Bool { simulatesTracking }
        override var isDragging: Bool { simulatesDragging }
        override var contentOffset: CGPoint {
            get { simulatedOffset }
            set { simulatedOffset = newValue }
        }
        override var indexPathsForVisibleItems: [IndexPath] { [IndexPath(item: visiblePage, section: 0)] }
        override func cellForItem(at indexPath: IndexPath) -> UICollectionViewCell? { visibleCell }
        override func reloadData() {}
    }

    private final class FeedPanSpy: UIPanGestureRecognizer {
        var travel = CGPoint.zero
        override func translation(in view: UIView?) -> CGPoint { travel }
    }

    func testComposerSharesEligibleSoundAndBackingByDefault() {
        var options = PostSharingOptions()
        var setup = SoundSetup(instrument: "violin", waveform: "sine", key: .C, scale: .major,
                               progression: "custom", customDegrees: [0, 3, 4], mode: .scalechordmelody,
                               bpm: 100, useSoundFont: true, autoStrum: true, padVolume: 0.3, gridOctave: 3, gridRange: 2)
        XCTAssertEqual(options.sharedPreset(setup), setup)
        XCTAssertTrue(options.sharesBacking(hasAudio: true, backingCredit: nil))
        XCTAssertFalse(options.sharesBacking(hasAudio: false, backingCredit: nil))
        let credit = BackingCredit(videoId: UUID(), username: "creator")
        XCTAssertFalse(options.sharesBacking(hasAudio: true, backingCredit: credit))
        setup.version = 99
        XCTAssertNil(options.sharedPreset(setup))
        setup.version = 1
        options.sharePlayablePreset = false
        options.allowPlayAlong = false
        XCTAssertNil(options.sharedPreset(setup))
        XCTAssertFalse(options.sharesBacking(hasAudio: true, backingCredit: nil))
    }

    @MainActor
    func testDiscoveryMixesCreatorsAndPagesFromUnrankedCursor() async throws {
        let firstCreator = UUID()
        let secondCreator = UUID()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        func makeVideo(_ author: UUID, likes: Int = 0, secondsAgo: TimeInterval = 0) throws -> Video {
            let data = try JSONSerialization.data(withJSONObject: [
                "id": UUID().uuidString, "user_id": author.uuidString, "like_count": likes,
                "caption": "Take", "video_key": "clip.mp4", "thumb_key": "cover.jpg",
                "created_at": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-secondsAgo))
            ])
            return try decoder.decode(Video.self, from: data)
        }
        let firstPage = try (0..<23).map { try makeVideo(firstCreator, secondsAgo: Double($0)) }
            + [makeVideo(secondCreator, likes: 42, secondsAgo: 24)]
        let secondPage = try [makeVideo(firstCreator, likes: 100, secondsAgo: 25),
                              makeVideo(secondCreator, secondsAgo: 26), firstPage[0]]
        let model = FeedModel(loadPublicPage: { cursor, limit in
            XCTAssertEqual(limit, 24)
            if let cursor {
                XCTAssertEqual(cursor.id, firstPage.last?.id)
                return secondPage
            }
            return firstPage
        }, loadAudioDownloadIDs: { _ in [] })
        await model.refresh(user: nil)
        XCTAssertEqual(model.videos.count, 24)
        XCTAssertEqual(model.videos.first?.id, firstPage.last?.id)
        model.current = 23
        await model.loadMore()
        XCTAssertEqual(model.videos.count, 26)
        XCTAssertEqual(model.videos[24].userId, secondCreator)
        XCTAssertEqual(Set(model.videos.map(\.id)).count, 26)
    }

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
        wheel.onZoneEnter = { id, zone in voiceID = id; XCTAssertEqual(zone, .melody(MelodySubzone(lane: 0))) }
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

    func testChallengeLinksOpenThePostWithTheReplyRecorder() throws {
        let id = try XCTUnwrap(UUID(uuidString: "52000000-0000-0000-0000-000000000002"))
        let challenge = ChallengeLink.url(for: id)
        XCTAssertEqual(challenge.absoluteString, "https://handstrudel.com/watch?v=\(id.uuidString.lowercased())&reply=1")
        XCTAssertEqual(PerformanceLink(url: challenge), .challenge(id))
        XCTAssertEqual(PerformanceLink(url: try XCTUnwrap(URL(string: "handstrudel://reply/\(id)"))), .challenge(id))
        XCTAssertEqual(PerformanceLink(url: try XCTUnwrap(URL(string: "https://handstrudel.com/watch?reply=1&v=\(id)"))), .challenge(id))
        XCTAssertEqual(PerformanceLink(url: try XCTUnwrap(URL(string: "https://handstrudel.com/watch?v=\(id)&reply=0"))), .watch(id))
        XCTAssertEqual(PerformanceLink.challenge(id).videoID, id)
        XCTAssertNil(PerformanceLink(url: try XCTUnwrap(URL(string: "https://handstrudel.com/watch?reply=1"))))
    }

    func testReplyFieldsDecodeAndTravelWithThePost() throws {
        let parent = "11111111-1111-1111-1111-111111111111"
        let json = """
        {"id":"22222222-2222-2222-2222-222222222222","user_id":"00000000-0000-0000-0000-00000000000a",
         "video_key":"v.mp4","thumb_key":"t.jpg","caption":"","like_count":0,"created_at":"2026-11-21T05:00:00Z",
         "username":"bob","reply_to_id":"\(parent)","reply_to_username":"alice","reply_count":3,
         "sound_setup":{"version":1,"key":"C","scale":"Major","mode":"scalechordmelody"}}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let video = try decoder.decode(Video.self, from: Data(json.utf8))
        XCTAssertEqual(video.replyToId, UUID(uuidString: parent))
        XCTAssertEqual(video.replyToUsername, "alice")
        XCTAssertEqual(video.replyCount, 3)

        let fields = VideoPostFields(caption: "", instrument: nil, mode: nil, durationS: 3, width: 720, height: 1280,
                                     replyToId: video.id)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fields)) as? [String: Any])
        XCTAssertEqual((encoded["reply_to_id"] as? String)?.lowercased(), video.id.uuidString.lowercased())
        let plain = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(VideoPostFields(caption: "", instrument: nil, mode: nil, durationS: 3, width: 720, height: 1280))
        ) as? [String: Any])
        XCTAssertNil(plain["reply_to_id"], "Ordinary posts don't name a target")
    }

    func testReplyRequestNeedsAPlayableSoundAndACreator() throws {
        func video(_ extra: String) throws -> Video {
            let json = """
            {"id":"22222222-2222-2222-2222-222222222222","user_id":"00000000-0000-0000-0000-00000000000a",
             "video_key":"v.mp4","thumb_key":"t.jpg","caption":"","like_count":0,"created_at":"2026-11-21T05:00:00Z"\(extra)}
            """
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Video.self, from: Data(json.utf8))
        }
        let sound = #","sound_setup":{"version":1,"instrument":"grand_piano","waveform":"sine","key":"D","scale":"Minor","# +
            #""progression":"free","mode":"soundfont","bpm":96,"useSoundFont":true,"autoStrum":false,"padVolume":0.3,"# +
            #""gridOctave":3,"gridRange":2}"#
        XCTAssertNil(ReplyTakeRequest(video: try video(#","username":"alice""#)))
        XCTAssertNil(ReplyTakeRequest(video: try video(sound)))
        let request = try XCTUnwrap(ReplyTakeRequest(video: try video(sound + #","username":"alice""#)))
        XCTAssertEqual(request.target, ReplyTarget(videoId: try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222")),
                                                   username: "alice"))
    }

    @MainActor
    func testDraftsKeepTheirReplyTargetAndOlderDraftsStillLoad() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = ReplyTarget(videoId: UUID(), username: "alice")
        let draft = try RecordingDrafts(directory: directory).begin(instrument: "Piano", mode: "scale", replyTo: target)
        XCTAssertEqual(draft.replyTo, target)
        let roundTrip = try JSONDecoder().decode(RecordingDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(roundTrip.replyTo, target)
        let older = #"{"id":"\#(UUID().uuidString)","createdAt":0}"#
        XCTAssertNil(try JSONDecoder().decode(RecordingDraft.self, from: Data(older.utf8)).replyTo)
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

    func testPublicCreatorDecodesProfileTotalsAndSupportsOldRows() throws {
        func creator(_ total: String) throws -> PublicCreator {
            try JSONDecoder().decode(PublicCreator.self, from: Data(
                """
                {"id":"71000000-0000-4000-8000-000000000001","username":"keys","display_name":null\(total)}
                """.utf8))
        }
        XCTAssertEqual(try creator(",\"likes_received\":1243").likesReceived, 1243)
        XCTAssertEqual(try creator(",\"likes_received\":0").likesReceived, 0)
        XCTAssertNil(try creator("").likesReceived)
        XCTAssertEqual(try creator(",\"views_received\":1234").viewsReceived, 1234)
        XCTAssertEqual(try creator(",\"views_received\":0").viewsReceived, 0)
        XCTAssertNil(try creator("").viewsReceived)
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
            if ["/following_activity_videos", "/following_videos"].contains(request.path) { return Self.missingView }
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
                if request.path == "/following_activity_videos" { return (200, "[]") }
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
            if ["/following_activity_videos", "/following_videos"].contains(request.path) { return Self.missingView }
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
            XCTAssertEqual(request.path, "/following_activity_videos")
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

    func testFollowingPaginatesByRepostTimeAndKeepsOriginalAuthor() async throws {
        let activity = "2026-11-16T12:00:01.123456+00:00"
        let response = Self.discoveryVideo.replacingOccurrences(of: "\"caption\":",
            with: "\"activity_at\":\"\(activity)\",\"reposted_by\":\"friend\",\"caption\":")
        let client = discoveryClient { request in
            XCTAssertEqual(request.path, "/following_activity_videos")
            XCTAssertEqual(request.queryItems?.first(where: { $0.name == "order" })?.value, "activity_at.desc.nullslast,id.desc.nullslast")
            if let cursor = request.queryItems?.first(where: { $0.name == "or" })?.value {
                XCTAssertTrue(cursor.contains("activity_at.lt.\(activity)"))
                return (200, "[]")
            }
            return (200, response)
        }
        let user = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        let page = try await FeedService.followingPage(user: user, from: client.from)
        let post = try XCTUnwrap(page.videos.first)
        XCTAssertEqual(post.username, "musician")
        XCTAssertEqual(post.repostedBy, "friend")
        let next = try await FeedService.followingPage(user: user, after: post, from: client.from)
        XCTAssertTrue(next.videos.isEmpty)
    }

    @MainActor
    func testFollowingModelSeparatesFallbackErrorFromConfirmedEmptyRetry() async throws {
        let viewer = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        let denied = discoveryClient { request in
            if ["/following_activity_videos", "/following_videos"].contains(request.path) { return Self.missingView }
            XCTAssertEqual(request.path, "/follows")
            return (403, #"{"code":"42501","message":"permission denied"}"#)
        }
        let model = FeedModel()
        model.mode = .following
        await model.refresh(user: viewer) { user in
            try await FeedService.followingPage(user: user, from: denied.from)
        }
        XCTAssertEqual(model.error, "Couldn't load posts from creators you follow.")
        XCTAssertFalse(model.confirmedNoFollows)
        XCTAssertFalse(model.loading)

        let empty = discoveryClient { request in
            if ["/following_activity_videos", "/following_videos"].contains(request.path) { return Self.missingView }
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
            if request.path == "/rpc/set_video_bookmark" {
                return (404, #"{"code":"PGRST202","message":"Missing function"}"#)
            }
            XCTAssertTrue(["/video_bookmarks", "/saved_videos"].contains(request.path))
            return Self.missingView
        }
        let video = try XCTUnwrap(UUID(uuidString: Self.discoveryUser))
        let viewer = try XCTUnwrap(UUID(uuidString: Self.discoveryViewer))
        do {
            try await FeedService.setBookmark(true, video: video, user: viewer, client: client)
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

    func testPublishUploadEncodesMetadataWithoutClientOwnedKeys() throws {
        let fields = VideoPostFields(caption: "c", instrument: nil, mode: "scale", durationS: 7,
                                     width: 720, height: 1558, commentsEnabled: false)
        let request = PublishUploadRequest(action: "submit", id: UUID(), fields: fields)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        let metadata = try XCTUnwrap(obj["fields"] as? [String: Any])
        XCTAssertEqual(obj["action"] as? String, "submit")
        XCTAssertEqual(metadata["duration_s"] as? Double, 7)
        XCTAssertEqual(metadata["comments_enabled"] as? Bool, false)
        XCTAssertNil(metadata["user_id"])
        XCTAssertNil(metadata["video_key"])
        XCTAssertNil(metadata["sound_setup"], "Posting a draft should not opt in by default")
    }

    func testUploadReservationSignalsModeratedClient() throws {
        let request = SignUploadRequest(videoBytes: 100, thumbBytes: 20)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(obj["moderationVersion"] as? Int, 2)
    }

    @MainActor
    private func makePostDraft(in directory: URL) throws -> (RecordingDrafts, RecordingDraft) {
        let store = RecordingDrafts(directory: directory)
        let draft = try store.begin(instrument: "Piano", mode: "Scale")
        try Data([0]).write(to: store.videoURL(for: draft.id))
        try store.complete(draft)
        return (store, draft)
    }

    private var originalPostFields: VideoPostFields {
        VideoPostFields(caption: "Original caption", instrument: "Piano", mode: "Scale",
                        durationS: 7, width: 720, height: 1280, commentsEnabled: false)
    }

    @MainActor
    func testTimedOutPostResumesFromDiskWithoutUploadingAgain() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, draft) = try makePostDraft(in: directory)
        let owner = UUID()
        let id = UUID()
        let pending = DraftPostSubmission.pending(id: id, fields: originalPostFields)
        try store.replacePostSubmission(nil, with: pending, draftID: draft.id, accountID: owner)
        let waiting = VideoUploader(pollTimeout: .zero) { request, user in
            XCTAssertEqual(request.id, id)
            XCTAssertEqual(user, owner)
            XCTAssertEqual(request.action, "status")
            return PublishUploadResponse(status: .checking)
        }
        var handoffs = 0
        let timedOut = await waiting.resume(draftID: draft.id, accountID: owner, store: store) {
            handoffs += 1
            XCTAssertEqual(store.postSubmission(for: draft.id, accountID: owner), pending)
        }
        XCTAssertEqual(handoffs, 1)
        XCTAssertFalse(timedOut)
        guard case .pending = waiting.phase else { return XCTFail("Timeout must remain pending") }

        let reopened = RecordingDrafts(directory: directory)
        XCTAssertEqual(reopened.postSubmission(for: draft.id, accountID: owner), pending)
        var requests: [PublishUploadRequest] = []
        let resumed = VideoUploader { request, _ in
            requests.append(request)
            return PublishUploadResponse(status: .published)
        }
        let unavailableClip = directory.appending(path: "no-transcode-or-upload-needed.mp4")
        let posted = await resumed.post(clip: unavailableClip, draftID: draft.id, accountID: owner, store: reopened,
                                        caption: "Edited later", instrument: nil, mode: nil, soundSetup: nil,
                                        commentsEnabled: true, backingEnabled: false, backingCredit: nil)
        XCTAssertTrue(posted)
        XCTAssertEqual(requests.map(\.action), ["status"])
        XCTAssertEqual(requests.map(\.id), [id])
        let published = RecordingDrafts(directory: directory)
        XCTAssertEqual(published.postSubmission(for: draft.id, accountID: owner), .published(id: id))
        _ = await resumed.post(clip: unavailableClip, draftID: draft.id, accountID: owner, store: published,
                               caption: "", instrument: nil, mode: nil, soundSetup: nil,
                               commentsEnabled: true, backingEnabled: false, backingCredit: nil)
        XCTAssertEqual(requests.count, 1, "A known published draft must not start another upload")
    }

    @MainActor
    func testLostSubmitResponseResendsOriginalFieldsWithSameReservation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, draft) = try makePostDraft(in: directory)
        let owner = UUID()
        let id = UUID()
        let fields = originalPostFields
        let pending = DraftPostSubmission.pending(id: id, fields: fields)
        try store.replacePostSubmission(nil, with: pending, draftID: draft.id, accountID: owner)
        var requests: [PublishUploadRequest] = []
        let uploader = VideoUploader { request, _ in
            requests.append(request)
            if request.action == "status" { return PublishUploadResponse(status: .reserved) }
            throw URLError(.networkConnectionLost)
        }
        let posted = await uploader.resume(draftID: draft.id, accountID: owner, store: store) {
            XCTFail("A failed status lookup or submission must not hand off the composer")
        }
        XCTAssertFalse(posted)
        XCTAssertEqual(requests.map(\.action), ["status", "submit"])
        XCTAssertEqual(requests.map(\.id), [id, id])
        XCTAssertEqual(requests.last?.fields, fields)
        XCTAssertEqual(RecordingDrafts(directory: directory).postSubmission(for: draft.id, accountID: owner), pending)
    }

    @MainActor
    func testTerminalStatusClearsOnlyItsOwnReservation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, draft) = try makePostDraft(in: directory)
        let owner = UUID()
        let other = UUID()
        let first = DraftPostSubmission.pending(id: UUID(), fields: originalPostFields)
        let second = DraftPostSubmission.pending(id: UUID(), fields: originalPostFields)
        XCTAssertTrue(try store.replacePostSubmission(nil, with: first, draftID: draft.id, accountID: owner))
        XCTAssertFalse(try store.replacePostSubmission(nil, with: second, draftID: draft.id, accountID: owner))
        XCTAssertNil(store.postSubmission(for: draft.id, accountID: other))
        XCTAssertTrue(try store.replacePostSubmission(nil, with: second, draftID: draft.id, accountID: other))

        let uploader = VideoUploader { _, user in
            XCTAssertEqual(user, owner)
            return PublishUploadResponse(status: .failed)
        }
        let posted = await uploader.resume(draftID: draft.id, accountID: owner, store: store)
        XCTAssertFalse(posted)
        XCTAssertNil(store.postSubmission(for: draft.id, accountID: owner))
        XCTAssertEqual(store.postSubmission(for: draft.id, accountID: other), second)
        XCTAssertTrue(try store.replacePostSubmission(nil, with: second, draftID: draft.id, accountID: owner))
        XCTAssertFalse(try store.replacePostSubmission(first, with: nil, draftID: draft.id, accountID: owner))
    }

    @MainActor
    func testGenericNotFoundDoesNotForgetAnUploadButExplicitExpirationDoes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, draft) = try makePostDraft(in: directory)
        let owner = UUID()
        let pending = DraftPostSubmission.pending(id: UUID(), fields: originalPostFields)
        try store.replacePostSubmission(nil, with: pending, draftID: draft.id, accountID: owner)
        let unavailable = VideoUploader { _, _ in
            throw FunctionsError.httpError(code: 404, data: Data(#"{"error":"Function not found"}"#.utf8))
        }
        _ = await unavailable.resume(draftID: draft.id, accountID: owner, store: store)
        XCTAssertEqual(store.postSubmission(for: draft.id, accountID: owner), pending)
        let expired = VideoUploader { _, _ in
            throw FunctionsError.httpError(code: 404, data: Data(#"{"error":"Upload not found."}"#.utf8))
        }
        _ = await expired.resume(draftID: draft.id, accountID: owner, store: store)
        XCTAssertNil(store.postSubmission(for: draft.id, accountID: owner))
    }
}

/// Pro sounds in the feed: labelled, offered for unlock, and counted.
final class ProSoundUnlockTests: XCTestCase {
    private func sound(instrument: String, useSoundFont: Bool = true) -> SoundSetup {
        SoundSetup(instrument: instrument, waveform: "sine", key: .D, scale: .minor,
                   progression: "custom", customDegrees: [0, 3, 4], mode: .scalechordmelody,
                   bpm: 100, useSoundFont: useSoundFont, autoStrum: false, padVolume: 0.3, gridOctave: 3, gridRange: 2)
    }

    func testOnlyValidSoundsNeedingAnUnownedPackAreLocked() throws {
        let premium = try XCTUnwrap(SOUNDFONT_INSTRUMENTS.first { $0.packId != nil })
        let free = try XCTUnwrap(SOUNDFONT_INSTRUMENTS.first { $0.packId == nil })
        let pro = sound(instrument: premium.id)
        XCTAssertTrue(pro.isLocked { _ in false })
        XCTAssertFalse(pro.isLocked { _ in true }, "Owning the pack unlocks it.")
        XCTAssertFalse(sound(instrument: free.id).isLocked { _ in false })
        XCTAssertFalse(sound(instrument: premium.id, useSoundFont: false).isLocked { _ in false },
                       "A synth sound doesn't need the unused sampler instrument.")
        var broken = pro
        broken.version = 99
        XCTAssertFalse(broken.isLocked { _ in false }, "Invalid sounds keep the old error instead of a sales pitch.")
    }

    func testUnlockScreenNamesTheSoundTheViewerWanted() throws {
        let premium = try XCTUnwrap(SOUNDFONT_INSTRUMENTS.first { $0.packId != nil })
        let offer = LockedSoundOffer(setup: sound(instrument: premium.id))
        XCTAssertEqual(offer.title, "Unlock \(premium.name)")
        XCTAssertTrue(offer.detail.hasPrefix("D Minor"), offer.detail)
        XCTAssertTrue(offer.detail.contains("This sound uses Pro"))
        XCTAssertNotEqual(offer.id, LockedSoundOffer(setup: offer.setup).id)
    }

    @MainActor
    func testLockedSoundEventsUseTheirDatabaseNamesAndRespectOptIn() throws {
        XCTAssertEqual(AppAnalytics.Event.lockedSoundTapped.rawValue, "locked_sound_tapped")
        XCTAssertEqual(AppAnalytics.Event.lockedSoundUnlocked.rawValue, "locked_sound_unlocked")
        let suite = "locked-sound-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var sent: [AppAnalytics.Event] = []
        let analytics = AppAnalytics(defaults: defaults) { sent.append($0) }
        analytics.record(.lockedSoundTapped)
        XCTAssertEqual(sent, [], "Nothing is sent without opt-in.")
        defaults.set(true, forKey: AppAnalytics.optInKey)
        analytics.record(.lockedSoundTapped)
        analytics.record(.lockedSoundUnlocked)
        XCTAssertEqual(sent, [.lockedSoundTapped, .lockedSoundUnlocked])
    }
}

/// Touching the Scale-mode wheel: notes and chords share the same up/down octave band.
@MainActor
final class WheelTouchOctaveTests: XCTestCase {
    private let wheel = SplitTouchUIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    private let center = CGPoint(x: 195, y: 422)
    private let wedge = 180.0 / 7

    /// A point at `degrees` clockwise from 12 o'clock, `radius` × the wheel radius out.
    private func point(_ degrees: Double, _ radius: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: center.x + sin(a) * 195 * radius, y: center.y - cos(a) * 195 * radius)
    }

    override func setUp() {
        wheel.zoneCount = 7
        wheel.melodyCount = 7
        wheel.melodyOctaveBand = true
    }

    func testScaleNotesUseTheOuterBandForOctaveUpAndDown() {
        // Notes sit on the right; wedge 2 from the top is lane 4.
        XCTAssertEqual(wheel.zone(at: point(2.5 * wedge, 0.6)), .melody(MelodySubzone(lane: 4, octave: 0)))
        XCTAssertEqual(wheel.zone(at: point(2.25 * wedge, 0.9)), .melody(MelodySubzone(lane: 4, octave: 1)))
        XCTAssertEqual(wheel.zone(at: point(2.75 * wedge, 0.9)), .melody(MelodySubzone(lane: 4, octave: -1)))
    }

    func testChordsKeepTheirBandAndTheRestHoleSelectsNothing() {
        XCTAssertEqual(wheel.zone(at: point(360 - 2.25 * wedge, 0.9)), .chord(ChordSubzone(wedge: 2, octave: 1)))
        XCTAssertEqual(wheel.zone(at: point(360 - 2.5 * wedge, 0.6)), .chord(ChordSubzone(wedge: 2, octave: 0)))
        XCTAssertNil(wheel.zone(at: center))
    }

    func testLayoutsWithoutANoteBandPlayTheBaseNoteAcrossTheWholeWedge() {
        wheel.melodyOctaveBand = false
        XCTAssertEqual(wheel.zone(at: point(2.25 * wedge, 0.9)), .melody(MelodySubzone(lane: 4, octave: 0)))
        XCTAssertEqual(wheel.zone(at: point(2.75 * wedge, 0.9)), .melody(MelodySubzone(lane: 4, octave: 0)))
    }

    func testSwappedHandsPutNotesOnTheLeft() {
        wheel.swapHands = true
        XCTAssertEqual(wheel.zone(at: point(360 - 2.25 * wedge, 0.9)), .melody(MelodySubzone(lane: 4, octave: 1)))
        XCTAssertEqual(wheel.zone(at: point(2.25 * wedge, 0.9)), .chord(ChordSubzone(wedge: 2, octave: 1)))
    }
}
