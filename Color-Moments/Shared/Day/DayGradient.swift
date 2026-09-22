import SwiftUI

/// 하루치 순간을 색 그라데이션으로 바꾼다.
///
/// **띠가 아니라 그라데이션인 이유**: 띠는 점들이 끊겨 보이고, 그라데이션은 하루가 이어져 보인다.
/// 아침 회색에서 점심 흰색을 지나 저녁 분홍으로 넘어가는 게 한 장에 담긴다.
///
/// **시간축 (설계 문서 Q5 의 답)**
/// 첫 촬영~마지막 촬영 구간을 0~1 로 펴되 **그 안의 간격 비율은 유지**한다.
/// - 24시간 축에 그대로 박으면 저녁에 몰아 찍은 날은 95% 가 단색이 된다.
/// - 균등 폭으로 펴면 몰아 찍은 날과 고르게 찍은 날이 똑같이 생겨 수집할 맛이 없다.
/// 리듬은 간격이 담고, «아침형인지 저녁형인지»는 뱃지에 새기는 시각이 담는다.
public enum DayGradient {

    public struct Stop: Equatable {
        public let location: Double   // 0~1
        public let hex: String
    }

    /// 그라데이션 정지점. 순간이 없으면 빈 배열, 하나면 단색(정지점 1개).
    public static func stops(for moments: [Moment]) -> [Stop] {
        let sorted = moments.sorted { $0.capturedAt < $1.capturedAt }
        guard let first = sorted.first, let last = sorted.last else { return [] }

        guard sorted.count > 1 else { return [Stop(location: 0, hex: first.colorHex)] }

        let span = last.capturedAt.timeIntervalSince(first.capturedAt)
        // 전부 같은 순간에 찍혔으면 간격이 0이다. 균등 분할로 떨어뜨린다.
        guard span > 0 else {
            return sorted.enumerated().map {
                Stop(location: Double($0.offset) / Double(sorted.count - 1), hex: $0.element.colorHex)
            }
        }
        return sorted.map {
            Stop(location: $0.capturedAt.timeIntervalSince(first.capturedAt) / span, hex: $0.colorHex)
        }
    }

    /// 첫 촬영과 마지막 촬영 시각. 뱃지에 새겨 «어떤 하루였는지» 를 남긴다.
    public static func span(for moments: [Moment]) -> (from: Date, to: Date)? {
        let sorted = moments.sorted { $0.capturedAt < $1.capturedAt }
        guard let f = sorted.first, let l = sorted.last else { return nil }
        return (f.capturedAt, l.capturedAt)
    }

    public static func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

/// 하루 그라데이션을 그리는 뷰.
public struct DayGradientView: View {
    private let stops: [DayGradient.Stop]
    private let axis: Axis

    public enum Axis { case horizontal, vertical }

    public init(moments: [Moment], axis: Axis = .horizontal) {
        self.stops = DayGradient.stops(for: moments)
        self.axis = axis
    }

    public var body: some View {
        if stops.isEmpty {
            Color.clear
        } else if stops.count == 1 {
            Color(hex: stops[0].hex)
        } else {
            LinearGradient(
                stops: stops.map { .init(color: Color(hex: $0.hex), location: $0.location) },
                startPoint: axis == .horizontal ? .leading : .top,
                endPoint: axis == .horizontal ? .trailing : .bottom
            )
        }
    }
}
