import XCTest
@testable import HandStrudel

final class SoundPageTests: XCTestCase {
    func testFeedRowShowsTakeCountOnlyWhenTheSoundHasCompany() {
        XCTAssertEqual(SoundPageText.row(title: "Rhodes", keyAndScale: "C Minor", takes: 23), "Rhodes · C Minor · 23 takes")
        XCTAssertEqual(SoundPageText.row(title: "Rhodes", keyAndScale: "C Minor", takes: 1), "Rhodes · C Minor")
        XCTAssertEqual(SoundPageText.row(title: "Rhodes", keyAndScale: "C Minor", takes: nil), "Rhodes · C Minor")
        XCTAssertEqual(SoundPageText.row(title: "Grand Piano", keyAndScale: nil, takes: 2), "Grand Piano · 2 takes")
    }

    func testTakeCountCopy() {
        XCTAssertEqual(SoundPageText.takes(1), "1 take")
        XCTAssertEqual(SoundPageText.takes(142), "142 takes")
        XCTAssertEqual(SoundPageText.takes(0), "0 takes")
    }

    func testSummaryDecodesWithAndWithoutAVisibleOriginal() throws {
        let json = Data("""
        [{"sound_id":"67000000-0000-0000-0000-000000000001","take_count":142,
          "original_video_id":"67000000-0000-0000-0000-000000000001"},
         {"sound_id":"67000000-0000-0000-0000-000000000002","take_count":3,"original_video_id":null}]
        """.utf8)
        let rows = try JSONDecoder().decode([SoundSummary].self, from: json)
        XCTAssertEqual(rows[0].takeCount, 142)
        XCTAssertEqual(rows[0].originalVideoID, rows[0].soundID)
        XCTAssertNil(rows[1].originalVideoID)
    }

    func testKeysetCursorsMatchEachSortOrder() throws {
        let json = Data("""
        {"id":"67000000-0000-0000-0000-0000000000AB","user_id":"66000000-0000-0000-0000-000000000001",
         "video_key":"v","thumb_key":"t","caption":"","like_count":7,
         "created_at":"2026-11-20T10:00:00.123456+00:00"}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return try XCTUnwrap(formatter.date(from: value))
        }
        let video = try decoder.decode(Video.self, from: json)
        let id = "67000000-0000-0000-0000-0000000000ab"
        XCTAssertEqual(SoundPageText.cursor(after: video, order: .top),
                       "like_count.lt.7,and(like_count.eq.7,id.lt.\(id))")
        XCTAssertEqual(SoundPageText.cursor(after: video, order: .recent),
                       "created_at.lt.2026-11-20T10:00:00.123456+00:00,and(created_at.eq.2026-11-20T10:00:00.123456+00:00,id.lt.\(id))")
    }
}
