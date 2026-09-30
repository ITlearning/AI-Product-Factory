import XCTest
@testable import ColorMoments

final class PebbleNameTests: XCTestCase {

    private func moment(_ hex: String, minute: Int = 0) -> Moment {
        Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000 + Double(minute) * 60),
               colorHex: hex, fileName: "\(hex)-\(minute).jpg", source: .app)
    }

    private func names(_ cell: PebbleNaming.Cell) -> Set<String> { Set(cell.map(\.name)) }

    private func rgb(_ hex: String) -> ColorExtractor.RGB { PebbleNaming.rgb(fromHex: hex)! }

    /// 1970-01-01 부터 센 날 → "YYYY-MM-DD"(UTC 달력).
    private func dayKey(_ day: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(day) * 86_400))
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func testRepresentativeIsTheMostVividMoment() {
        let day = [moment("#333032"), moment("#353035", minute: 1),
                   moment("#1B2462", minute: 2), moment("#B12E12", minute: 3)]
        XCTAssertEqual(PebbleNaming.representative(of: day), rgb("#B12E12"), "가장 선명한 #B12E12 가 하루를 대표해야 한다")
        let named = PebbleNaming.name(for: day)
        XCTAssertTrue(names(PebbleNaming.cell(for: rgb("#B12E12"))).contains(named?.name ?? ""), "\(String(describing: named))")
    }

    func testAchromaticDaysAreNamedByBrightness() {
        XCTAssertEqual(PebbleNaming.name(for: rgb("#0A0A0A")).name, "그믐")
        XCTAssertEqual(PebbleNaming.name(for: rgb("#4A4A4A")).name, "먹빛")
        XCTAssertEqual(PebbleNaming.name(for: rgb("#8C8C8C")).name, "잿빛")
        XCTAssertEqual(PebbleNaming.name(for: rgb("#C8C8C8")).name, "안개")
        XCTAssertEqual(PebbleNaming.name(for: rgb("#F2F2F2")).name, "해미")
    }

    /// 날짜를 모르면 칸의 첫 이름 — 색이 어느 칸에 떨어지는지 고정한다.
    func testColorsLandInTheirCells() {
        let cases: [(String, String)] = [
            ("#B12E12", "노을"),    // 빨강 · 선명
            ("#5A1410", "불씨"),    // 빨강 · 어두움
            ("#E0A93B", "볕뉘"),    // 주황 · 선명
            ("#D8B9A0", "살구"),    // 다홍 · 옅음
            ("#D8C0A0", "햇살"),    // 주황 · 옅음
            ("#E8C83A", "햇귀"),    // 노랑 · 선명
            ("#6FA83C", "풀잎"),    // 연두 · 선명
            ("#3FA860", "풀빛"),    // 초록 · 선명
            ("#1F4A2A", "숲"),      // 초록 · 어두움
            ("#2FB8A0", "물빛"),    // 청록 · 선명
            ("#5B9BE0", "하늘빛"),  // 하늘 · 선명
            ("#8FA5B8", "먼바다"),    // 하늘 · 옅음
            ("#1B2462", "밤바다"),  // 파랑 · 어두움
            ("#8A5BD6", "별빛"),    // 남보라 · 선명
            ("#B05BD6", "무지개"),  // 보라 · 선명
            ("#D65BA0", "꽃물"),    // 분홍 · 선명
        ]
        for (hex, expected) in cases {
            XCTAssertEqual(PebbleNaming.name(for: rgb(hex)).name, expected, hex)
        }
    }

    func testEmptyDayHasNoName() {
        XCTAssertNil(PebbleNaming.name(for: []))
    }

    func testSameDayGetsTheSameNameEverywhere() {
        let day = [moment("#6FA83C"), moment("#3C6A9B", minute: 5)]
        let key = day[0].dayKey
        let direct = PebbleNaming.name(for: PebbleNaming.representative(of: day)!, dayKey: key)
        for _ in 0..<3 { XCTAssertEqual(PebbleNaming.name(for: day), direct) }
    }

    func testEveryCellHasTwoYearRoundNames() {
        let cells = PebbleNaming.achromatic.map(\.cell) + PebbleNaming.hues.flatMap { [$0.dark, $0.soft, $0.bright] }
        for cell in cells {
            XCTAssertGreaterThanOrEqual(cell.filter(\.months.isEmpty).count, 2,
                                        "\(cell.map(\.name)) — 제철이 아닐 때 한 이름만 남으면 날마다 겹친다")
        }
    }

    /// 한 칸에서 이틀 잇달아 같은 이름이 나오지 않는다(제철이 바뀌는 달 경계는 뺀다) · 제철 이름도 제철에 나온다.
    func testSameColorOnConsecutiveDaysDoesNotRepeat() {
        let cells = PebbleNaming.achromatic.map(\.cell) + PebbleNaming.hues.flatMap { [$0.dark, $0.soft, $0.bright] }
        let start = PebbleNaming.dayNumber("2026-01-01")!
        for cell in cells {
            let pool = cell
            var seen: Set<String> = []
            var previous: (key: String, name: String)?
            for day in start..<(start + 730) {
                let key = dayKey(day)
                let month = Int(key.split(separator: "-")[1])!
                let inSeason = pool.filter { $0.months.isEmpty || $0.months.contains(month) }
                let name = inSeason[PebbleNaming.rotation(count: inSeason.count, day: day, seed: inSeason[0].name)].name
                seen.insert(name)
                if let previous, previous.key.prefix(7) == key.prefix(7) {
                    XCTAssertNotEqual(previous.name, name, "\(key) — \(pool.map(\.name))")
                }
                previous = (key, name)
            }
            XCTAssertEqual(seen, names(pool), "두 해 동안 한 번도 안 나온 이름이 있다")
        }
    }

    func testSeasonalNamesStayInSeason() {
        let azalea = rgb("#D65BA0")
        for key in ["2026-01-10", "2026-07-20", "2026-11-03"] {
            for offset in 0..<20 {
                let day = dayKey(PebbleNaming.dayNumber(key)! + offset)
                XCTAssertNotEqual(PebbleNaming.name(for: azalea, dayKey: day).name, "진달래", day)
            }
        }
    }

    func testNamesAreUniqueAndLinesDoNotJudgeTheDay() {
        let all = PebbleNaming.allNames
        XCTAssertEqual(Set(all.map(\.name)).count, all.count, "같은 이름이 두 칸에 있다")
        let banned = ["우울한", "슬픈 하루", "힘든 하루", "실패", "기쁜 하루", "행복한 하루", "좋은 하루였"]
        for named in all {
            for word in banned {
                XCTAssertFalse(named.line.contains(word), "\(named.name) 의 한 줄이 기분을 단정한다: \(named.line)")
            }
            XCTAssertLessThanOrEqual(named.line.count, 26, "한 줄이 길면 위로가 아니라 훈수가 된다: \(named.line)")
        }
    }

    func testDayNumberMatchesTheCalendar() {
        XCTAssertEqual(PebbleNaming.dayNumber("1970-01-01"), 0)
        XCTAssertEqual(PebbleNaming.dayNumber("2026-09-30"), 20_726)
        XCTAssertEqual(PebbleNaming.dayNumber("2024-03-01")! - PebbleNaming.dayNumber("2024-02-28")!, 2)
        XCTAssertNil(PebbleNaming.dayNumber(""))
        XCTAssertNil(PebbleNaming.dayNumber("2026-13-01"))
    }
}
