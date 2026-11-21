import XCTest
@testable import HandStrudel

@MainActor
final class DailySoundTests: XCTestCase {
    private func setup(instrument: String = "grand_piano", key: MusicKey = .Eb, scale: Scale = .major,
                       progression: String = "pop", mode: SoundSetup.Mode = .scalechordmelody,
                       bpm: Double = 96, useSoundFont: Bool = true, waveform: String = "sine") -> SoundSetup {
        SoundSetup(instrument: instrument, waveform: waveform, key: key, scale: scale, progression: progression,
                   customDegrees: progression == "custom" ? [0, 3, 4] : nil, mode: mode, bpm: bpm,
                   useSoundFont: useSoundFont, autoStrum: false, padVolume: 0.3, gridOctave: 3, gridRange: 2)
    }

    private static let payloadJSON = """
    {
      "day": "2026-11-21",
      "starts_at": "2026-11-21T00:00:00+00:00",
      "ends_at": "2026-11-22T00:00:00+00:00",
      "server_now": "2026-11-21T18:30:00.123456+00:00",
      "sound": {
        "setup": {"version": 1, "instrument": "grand_piano", "waveform": "sine", "key": "Eb", "scale": "Major",
                  "progression": "pop", "mode": "scalechordmelody", "bpm": 96, "useSoundFont": true,
                  "autoStrum": false, "padVolume": 0.3, "gridOctave": 3, "gridRange": 2},
        "title": null, "note": "Keep it slow.", "source": "auto",
        "video": {"id": "30000000-0000-0000-0000-000000000001", "user_id": "20000000-0000-0000-0000-000000000002",
                  "video_key": "videos/a/screened/b.mp4", "thumb_key": "thumbs/a/screened/b.jpg", "caption": "Evening loop",
                  "like_count": 4, "created_at": "2026-11-20T10:00:00.5+00:00", "username": "loopmaker"}
      },
      "take_count": 3,
      "takes": [
        {"id": "30000000-0000-0000-0000-000000000002", "user_id": "20000000-0000-0000-0000-000000000003",
         "video_key": "videos/c/screened/d.mp4", "thumb_key": "thumbs/c/screened/d.jpg", "caption": "",
         "like_count": 1, "created_at": "2026-11-21T09:00:00+00:00", "username": "cara"},
        {"id": "not-a-uuid"}
      ],
      "streak": {"current": 7, "best": 9, "posted_today": true, "alive": true, "freeze_covering": [],
                 "freeze_available": false, "freeze_used_on": "2026-11-19", "ends_at": "2026-11-23T00:00:00+00:00",
                 "badges": [3, 7], "next_milestone": 30,
                 "theme_grant": {"theme_id": "purple_gold", "expires_at": "2026-11-28T18:00:00+00:00"}}
    }
    """

    private func payload(_ json: String = payloadJSON) throws -> DailySoundPayload {
        try DailySoundService.decoder.decode(DailySoundPayload.self, from: Data(json.utf8))
    }

    func testDecodesTheServerPayload() throws {
        let today = try payload()
        XCTAssertEqual(today.day, "2026-11-21")
        XCTAssertEqual(today.endsAt.timeIntervalSince(today.serverNow), 5.5 * 3600, accuracy: 1)
        XCTAssertEqual(today.sound?.displayTitle, "Grand Piano")
        XCTAssertEqual(today.sound?.note, "Keep it slow.")
        XCTAssertEqual(today.sound?.video?.username, "loopmaker")
        XCTAssertEqual(today.takeCount, 3)
        XCTAssertEqual(today.takes.map(\.username), ["cara"], "A malformed take is skipped, not fatal")
        XCTAssertEqual(today.streak?.current, 7)
        XCTAssertEqual(today.streak?.badges, [3, 7])
        XCTAssertEqual(today.streak?.themeGrant?.themeID, "purple_gold")
        XCTAssertEqual(today.streak?.freezeUsedOn, "2026-11-19")
    }

    func testSignedOutPayloadHasNoStreakAndADayWithoutASoundHidesTheCard() throws {
        let json = """
        {"day": "2026-11-21", "starts_at": "2026-11-21T00:00:00+00:00", "ends_at": "2026-11-22T00:00:00+00:00",
         "server_now": "2026-11-21T01:00:00+00:00", "sound": null, "take_count": 0, "takes": [], "streak": null}
        """
        let today = try payload(json)
        XCTAssertNil(today.sound)
        XCTAssertNil(today.streak)
    }

    func testTakeMatchingIgnoresTempoModeAndTheInactiveSynth() {
        let featured = setup()
        XCTAssertTrue(setup(mode: .radialchordmelody, bpm: 140, waveform: "pluck").isSameDailySound(as: featured))
        XCTAssertFalse(setup(instrument: "violin").isSameDailySound(as: featured))
        XCTAssertFalse(setup(key: .E).isSameDailySound(as: featured))
        XCTAssertFalse(setup(scale: .minor).isSameDailySound(as: featured))
        XCTAssertFalse(setup(progression: "jazz").isSameDailySound(as: featured))
        XCTAssertFalse(setup(useSoundFont: false).isSameDailySound(as: featured))
        let synth = setup(instrument: "violin", useSoundFont: false, waveform: "kalimba")
        XCTAssertTrue(setup(instrument: "choir", useSoundFont: false, waveform: "kalimba").isSameDailySound(as: synth))
    }

    func testCountdownAndThemeLoanUseServerTimeAndUptimeNotTheDeviceClock() async throws {
        var uptime: TimeInterval = 1_000
        let today = try payload()
        let store = DailySoundStore(load: { today }, uptime: { uptime })
        await store.refresh()
        XCTAssertEqual(store.timeLeft ?? 0, 5.5 * 3600, accuracy: 1)
        XCTAssertTrue(store.isTodaysSound(setup(bpm: 120)))
        XCTAssertFalse(store.isTodaysSound(nil))

        let loan = try XCTUnwrap(store.themeLoan)
        XCTAssertTrue(loan.isActive(for: "purple_gold", uptime: uptime))
        XCTAssertFalse(loan.isActive(for: "matrix", uptime: uptime))
        // The grant ends ~7 days minus 30 minutes after the server's now.
        XCTAssertTrue(loan.isActive(for: "purple_gold", uptime: uptime + 6 * 86_400))
        XCTAssertFalse(loan.isActive(for: "purple_gold", uptime: uptime + 7 * 86_400))

        uptime += 6 * 3600
        XCTAssertEqual(store.timeLeft, 0)
        XCTAssertTrue(store.isStale)
        XCTAssertFalse(store.isTodaysSound(setup()), "Yesterday's sound no longer counts after the rollover")
    }

    func testRefreshSkipsRecentLoadsButNotAfterRollover() async throws {
        var loads = 0
        var uptime: TimeInterval = 50
        let today = try payload()
        let store = DailySoundStore(load: { loads += 1; return today }, uptime: { uptime })
        await store.refresh(maxAge: 30)
        await store.refresh(maxAge: 30)
        XCTAssertEqual(loads, 1)
        uptime += 31
        await store.refresh(maxAge: 30)
        XCTAssertEqual(loads, 2)
        await store.refresh(viewer: UUID(), maxAge: 30)
        XCTAssertEqual(loads, 3, "Signing in reloads for the new account")
        store.clear()
        XCTAssertNil(store.payload)
        XCTAssertNil(store.themeLoan)
    }

    func testStreakThemeLoanUnlocksOnlyThatHandTheme() throws {
        let store = StoreManager { throw CancellationError() }
        let royal = try XCTUnwrap(HAND_THEMES.first { $0.id == "purple_gold" })
        let matrix = try XCTUnwrap(HAND_THEMES.first { $0.id == "matrix" })
        XCTAssertTrue(store.isUnlocked(theme: HAND_THEMES[0]))
        XCTAssertFalse(store.isUnlocked(theme: royal))
        let now = Date()
        store.streakThemeLoan = StreakThemeLoan(themeID: royal.id, expiresAt: now.addingTimeInterval(3600), serverNow: now)
        XCTAssertTrue(store.isUnlocked(theme: royal))
        XCTAssertFalse(store.isUnlocked(theme: matrix))
        store.streakThemeLoan = StreakThemeLoan(themeID: royal.id, expiresAt: now.addingTimeInterval(-1), serverNow: now)
        XCTAssertFalse(store.isUnlocked(theme: royal))
    }

    func testFormatting() {
        XCTAssertEqual(DailySoundFormat.timeLeft(5 * 3600 + 12 * 60 + 30), "5h 12m")
        XCTAssertEqual(DailySoundFormat.timeLeft(48 * 60), "48m")
        XCTAssertEqual(DailySoundFormat.timeLeft(20), "under a minute")
        XCTAssertNotNil(DailySoundFormat.weekday("2026-11-19"))
        XCTAssertNil(DailySoundFormat.weekday("Thursday"))
    }

    /// The server only auto-picks sounds a player without Pro can open. Its allowlist must match
    /// the app's catalog, or the daily sound could show "Unlock" to free players.
    func testServerFreeSoundListMatchesTheAppCatalog() throws {
        let migration = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("supabase/migrations/20261121040000_daily_sound_streaks.sql")
        let sql = try String(contentsOf: migration, encoding: .utf8)
        let block = try XCTUnwrap(sql.components(separatedBy: "-- BEGIN FREE SOUND VALUES").last?
            .components(separatedBy: "-- END FREE SOUND VALUES").first)
        var server: [String: Set<String>] = [:]
        let pair = try NSRegularExpression(pattern: #"\('(\w+)', '([^']+)'\)"#)
        for match in pair.matches(in: block, range: NSRange(block.startIndex..., in: block)) {
            let kind = String(block[Range(match.range(at: 1), in: block)!])
            server[kind, default: []].insert(String(block[Range(match.range(at: 2), in: block)!]))
        }
        XCTAssertEqual(server["soundfont"], Set(SOUNDFONT_INSTRUMENTS.filter { $0.packId == nil }.map(\.id)))
        XCTAssertEqual(server["waveform"], Set(WAVEFORMS.filter { $0.packId == nil }.map(\.id)))
        XCTAssertEqual(server["scale"], Set(BuiltInScale.allCases.filter { Scale.builtIn($0).packId == nil }.map(\.rawValue)))
        XCTAssertEqual(server["progression"], Set(CHORD_PROGRESSIONS.filter { $0.packId == nil }.map(\.id) + ["custom"]))
    }
}
