import CoreGraphics
import Foundation

/// 홈 화면의 날짜/월 계산 — 뷰 상태와 분리된 순수 함수만 모은다.
public enum HomeNavigation {

    /// 이 dayKey보다 오래된 하루는 압축(한 줄) 표시 대상이다.
    public static func compactCutoff(today: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let past = cal.date(byAdding: .day, value: -30, to: today) ?? today
        return Moment.dayKey(for: past)
    }

    /// dayKey 목록에서 "yyyy-MM"만 뽑아 중복 제거하고 최신이 위로 오게 정렬한다.
    public static func months(of dayKeys: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for key in dayKeys where key.count >= 7 {
            let month = String(key.prefix(7))
            if seen.insert(month).inserted { result.append(month) }
        }
        return result.sorted(by: >)
    }

    /// 알약 끌기의 세로 위치 비율(0=맨 위)을 월 목록 인덱스로 매핑한다.
    public static func monthIndex(fraction: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let clamped = min(max(fraction, 0), 1)
        let idx = Int(clamped * CGFloat(count))
        return min(idx, count - 1)
    }
}
