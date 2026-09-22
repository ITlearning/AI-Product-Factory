import Foundation

/// 붙잡은 한 순간.
///
/// 색은 저장해두지만 **필요하면 언제든 다시 뽑을 수 있다** — 추출기가 결정론적이라
/// 같은 사진은 항상 같은 색을 낸다. 그래서 잠긴 확장이 색을 못 넘겨도 문제가 없다.
public struct Moment: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let capturedAt: Date
    /// `#RRGGBB`
    public let colorHex: String
    /// `ShotStore.directory` 기준 파일명.
    public let fileName: String
    public let source: Source
    /// 사용자가 사진 위를 탭해 직접 고른 색인가. 자동 추출이면 false.
    public var colorWasChosen: Bool

    public enum Source: String, Codable, Sendable {
        /// 앱을 열고 찍음
        case app
        /// 잠금화면 확장에서 찍음
        case locked
        /// 사진첩에서 끌어옴 (B 경로, 아직 미구현)
        case library
    }

    public init(id: UUID = UUID(), capturedAt: Date, colorHex: String,
                fileName: String, source: Source, colorWasChosen: Bool = false) {
        self.id = id
        self.capturedAt = capturedAt
        self.colorHex = colorHex
        self.fileName = fileName
        self.source = source
        self.colorWasChosen = colorWasChosen
    }
}

public extension Moment {
    /// 이 순간이 속한 «하루».
    ///
    /// **자정이 아니라 새벽 4시가 경계다.** 새벽 2시에 찍은 것은 아직 어제의 하루다 —
    /// 사람의 하루는 잠으로 끊기지 날짜로 끊기지 않는다. 설계 문서 Q3 의 답.
    var dayKey: String { Moment.dayKey(for: capturedAt) }

    static let dayBoundaryHour = 4

    static func dayKey(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let shifted = cal.date(byAdding: .hour, value: -dayBoundaryHour, to: date) ?? date
        let c = cal.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
