import XCTest
@testable import ColorMoments

final class PebbleNameTests: XCTestCase {

    private func moment(_ hex: String, minute: Int = 0) -> Moment {
        Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000 + Double(minute) * 60),
               colorHex: hex, fileName: "\(hex)-\(minute).jpg", source: .app)
    }

    func testRepresentativeIsTheMostVividMoment() {

        let day = [moment("#333032"), moment("#353035", minute: 1),
                   moment("#1B2462", minute: 2), moment("#B12E12", minute: 3)]
        let named = PebbleNaming.name(for: day)
        XCTAssertEqual(named?.name, "노을", "가장 선명한 #B12E12 가 하루를 대표해야 한다")
    }

    func testAchromaticDaysAreNamedByBrightness() {
        XCTAssertEqual(PebbleNaming.name(for: [moment("#0A0A0A")])?.name, "그믐")
        XCTAssertEqual(PebbleNaming.name(for: [moment("#4A4A4A")])?.name, "먹빛")
        XCTAssertEqual(PebbleNaming.name(for: [moment("#8C8C8C")])?.name, "잿빛")
        XCTAssertEqual(PebbleNaming.name(for: [moment("#F2F2F2")])?.name, "해미")
    }

    func testHueFamiliesGetTheirNames() {
        let cases: [(String, String)] = [
            ("#B12E12", "노을"),
            ("#E0A93B", "볕뉘"),
            ("#6FA83C", "풀빛"),
            ("#2FA3B8", "물빛"),
            ("#5B9BE0", "하늘빛"),
            ("#1B2462", "너울"),
            ("#9B5BD6", "어스름"),
            ("#8A5BD6", "새벽빛"),
        ]
        for (hex, expected) in cases {
            XCTAssertEqual(PebbleNaming.name(for: [moment(hex)])?.name, expected, "\(hex)")
        }
    }

    func testEmptyDayHasNoName() {
        XCTAssertNil(PebbleNaming.name(for: []))
    }

    func testLinesDoNotJudgeTheDay() {

        let banned = ["우울한", "슬픈 하루", "힘든 하루", "실패", "기쁜 하루", "행복한 하루", "좋은 하루였"]
        let samples = ["#B12E12", "#0A0A0A", "#8C8C8C", "#1B2462", "#6FA83C",
                       "#E0A93B", "#9B5BD6", "#2FA3B8", "#F2F2F2", "#5B9BE0", "#4A4A4A"]
        for hex in samples {
            let line = PebbleNaming.name(for: [moment(hex)])!.line
            for word in banned {
                XCTAssertFalse(line.contains(word), "\(hex) 의 한 줄이 기분을 단정한다: \(line)")
            }
            XCTAssertLessThanOrEqual(line.count, 26, "한 줄이 길면 위로가 아니라 훈수가 된다: \(line)")
        }
    }
}
