import XCTest
@testable import ColorMoments

/// 사진첩을 조금씩 읽으며 보여 줄 때 — 덜 모인 하루는 빼고, 다 읽으면 한 번에 만든 것과 같은지.
final class LibraryLoadTests: XCTestCase {

    private func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = mo; c.day = day; c.hour = h
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        return cal.date(from: c)!
    }

    func testPartialDropsTheDayStillBeingRead() {
        var b = LibrarySectionBuilder()
        [d(2026, 9, 22, 18), d(2026, 9, 22, 9), d(2026, 9, 21, 20)].forEach { b.append($0) }
        XCTAssertEqual(b.sections(complete: false).map(\.dayKey), ["2026-09-22"], "21일은 더 남았을 수 있다")
        b.append(d(2026, 9, 21, 8))
        b.append(d(2026, 9, 19, 12))
        XCTAssertEqual(b.sections(complete: false).map(\.dayKey), ["2026-09-22", "2026-09-21"])
        XCTAssertEqual(b.sections(complete: false)[1].indices, [2, 3])
        XCTAssertEqual(b.sections(complete: true).map(\.dayKey), ["2026-09-22", "2026-09-21", "2026-09-19"])
    }

    func testBuilderMatchesMakeAndStaysCheapAtTwentyThousand() {
        let now = Date()
        let dates: [Date?] = (0..<20_000).map { i in i % 997 == 0 ? nil : now.addingTimeInterval(-Double(i) * 1_700) }
        let t = CFAbsoluteTimeGetCurrent()
        var b = LibrarySectionBuilder(now: now)
        var partials = 0
        for (i, date) in dates.enumerated() {
            b.append(date)
            if i % 300 == 299 { _ = b.sections(complete: false); partials += 1 }
        }
        let built = b.sections(complete: true)
        let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000
        print("measured perf.j.librarySections20000+\(partials)partials: \(String(format: "%.1f", ms)) ms")
        XCTAssertEqual(built, LibrarySections.make(dates: dates, now: now))
        XCTAssertEqual(built.reduce(0) { $0 + $1.indices.count }, 20_000)
    }
}
