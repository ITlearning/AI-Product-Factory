import XCTest
@testable import ColorMoments

final class PebbleNameTests: XCTestCase {

    private func moment(_ hex: String, minute: Int = 0) -> Moment {
        Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000 + Double(minute) * 60),
               colorHex: hex, fileName: "\(hex)-\(minute).jpg", source: .app)
    }

    /// 평균을 내면 다채로운 하루일수록 회색으로 수렴해 이름이 밋밋해진다.
    /// 가장 선명한 순간이 그날을 대표해야 한다.
    func testRepresentativeIsTheMostVividMoment() {
        // 어두운 무채색 셋 + 파랑 하나 + 선명한 붉은색 하나 (2026-09-22 실제 데이터)
        let day = [moment("#333032"), moment("#353035", minute: 1),
                   moment("#1B2462", minute: 2), moment("#B12E12", minute: 3)]
        let named = PebbleNaming.name(for: day)
        XCTAssertEqual(named?.name, "노을", "가장 선명한 #B12E12 가 하루를 대표해야 한다")
    }

    /// 채도가 낮으면 색이 아니라 밝기가 그날을 말한다.
    func testAchromaticDaysAreNamedByBrightness() {
        XCTAssertEqual(PebbleNaming.name(for: [moment("#0A0A0A")])?.name, "그믐")
        XCTAssertEqual(PebbleNaming.name(for: [moment("#4A4A4A")])?.name, "먹빛")
        XCTAssertEqual(PebbleNaming.name(for: [moment("#8C8C8C")])?.name, "잿빛")
        XCTAssertEqual(PebbleNaming.name(for: [moment("#F2F2F2")])?.name, "해미")
    }

    func testHueFamiliesGetTheirNames() {
        let cases: [(String, String)] = [
            ("#B12E12", "노을"),      // 붉은
            ("#E0A93B", "볕뉘"),      // 주황
            ("#6FA83C", "풀빛"),      // 초록
            ("#2FA3B8", "물빛"),      // 청록
            ("#5B9BE0", "하늘빛"),    // 파랑
            ("#1B2462", "너울"),      // 어두운 파랑
            ("#9B5BD6", "어스름"),    // 보라 (hue 275)
            ("#8A5BD6", "새벽빛"),    // 남보라 (hue 263) — 경계 바로 아래
        ]
        for (hex, expected) in cases {
            XCTAssertEqual(PebbleNaming.name(for: [moment(hex)])?.name, expected, "\(hex)")
        }
    }

    func testEmptyDayHasNoName() {
        XCTAssertNil(PebbleNaming.name(for: []))
    }

    /// 한 줄은 판단하지 않는다. 기분을 단정하는 말이 들어가면 안 된다.
    func testLinesDoNotJudgeTheDay() {
        // 사용자의 하루를 단정하는 말만 막는다.
        // "나쁜 게 아니에요" 처럼 부정을 부정하는 문장은 판단이 아니므로 단순 포함 검사로는 못 잡는다.
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
