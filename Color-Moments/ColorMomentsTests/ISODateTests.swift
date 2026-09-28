import XCTest
@testable import ColorMoments

final class ISODateTests: XCTestCase {

    private let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func testMatchesFormatterForFractionalSeconds() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<5_000 {
            let date = Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000, using: &rng))
            let text = DayStore.encodeDate(date)
            XCTAssertEqual(ISODate.parse(text), fractional.date(from: text), text)
        }
    }

    func testMatchesFormatterForWholeSeconds() {
        let whole = ISO8601DateFormatter()
        for t in stride(from: 0.0, to: 2_000_000_000, by: 7_654_321) {
            let text = whole.string(from: Date(timeIntervalSince1970: t))
            XCTAssertEqual(ISODate.parse(text), whole.date(from: text), text)
        }
        XCTAssertEqual(ISODate.parse("2024-02-29T23:59:59Z"), whole.date(from: "2024-02-29T23:59:59Z"))
        XCTAssertEqual(ISODate.parse("2000-03-01T00:00:00Z"), whole.date(from: "2000-03-01T00:00:00Z"))
    }

    func testOtherShapesFallBackToFormatter() {
        XCTAssertNil(ISODate.parse("2026-09-28T12:00:00+09:00"))
        XCTAssertNil(ISODate.parse("2026-09-28 12:00:00Z"))
        XCTAssertNil(ISODate.parse("2026-13-28T12:00:00Z"))
        XCTAssertNil(ISODate.parse("2026-09-28T12:00:00.Z"))
        XCTAssertNil(ISODate.parse("날짜"))
    }

    /// 옛 초 단위·오프셋 표기로 남은 파일도 그대로 읽힌다.
    func testDecodeKeepsLegacyShapes() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-01T03:04:05Z","colorHex":"#112233","fileName":"a","source":"app"},
         {"id":"\(UUID().uuidString)","capturedAt":"2026-09-01T12:04:05.250+09:00","colorHex":"#112233","fileName":"b","source":"app"},
         {"id":"\(UUID().uuidString)","capturedAt":"2026-09-01T03:04:05.250Z","colorHex":"#112233","fileName":"c","source":"app"}]
        """
        let moments = DayStore.decodeMoments(Data(json.utf8))
        XCTAssertEqual(moments.count, 3)
        XCTAssertEqual(moments[0].capturedAt, ISO8601DateFormatter().date(from: "2026-09-01T03:04:05Z"))
        XCTAssertEqual(moments[1].capturedAt.timeIntervalSince1970, moments[2].capturedAt.timeIntervalSince1970, accuracy: 0.0005)
    }
}
