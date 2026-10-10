import SwiftUI

public enum DayGradient {

    public struct Stop: Equatable {
        public let location: Double
        public let hex: String

        public init(location: Double, hex: String) { self.location = location; self.hex = hex }
    }

    public static func stops(for moments: [Moment]) -> [Stop] {
        positions(for: moments).map { Stop(location: $0.location, hex: $0.moment.colorHex) }
    }

    public nonisolated(unsafe) static var stamps = PebbleStopsLog.shared
    public nonisolated(unsafe) static var isGifted: (String) -> Bool = { _ in false }

    /// 조약돌 정지점 — 받을 때 찍은 도장, 없으면 이미 받은 날은 1.1 규칙(그림이 바뀌지 않게), 아니면 사진 팔레트.
    public static func pebbleStops(for moments: [Moment]) -> [Stop] {
        guard let key = moments.map(\.dayKey).min() else { return [] }
        if let stamped = stamps.stops(on: key) { return stamped }
        if isGifted(key) { return legacyPebbleStops(for: moments) }
        return paletteStops(for: moments)
    }

    public static func paletteStops(for moments: [Moment]) -> [Stop] {
        let placed = positions(for: moments)
        guard placed.contains(where: { !$0.moment.paletteColors.isEmpty }) else { return legacyPebbleStops(for: moments) }
        let centers = legacyLocations(placed)
        var out: [Stop] = []
        for (i, p) in placed.enumerated() {
            let from = i == 0 ? 0 : (centers[i - 1] + centers[i]) / 2
            let to = i == placed.count - 1 ? 1 : (centers[i] + centers[i + 1]) / 2
            let accents = p.moment.paletteColors.dropFirst().filter { $0.share >= 8 }.prefix(2).map(\.hex)
            let parts: [(hex: String, width: Double)] = accents.isEmpty
                ? [(p.moment.colorHex, 1)]
                : [(p.moment.colorHex, 0.6)] + accents.map { ($0, 0.4 / Double(accents.count)) }
            var x = from
            for part in parts {
                let span = (to - from) * part.width
                out.append(Stop(location: x + span / 2, hex: part.hex))
                x += span
            }
        }
        return out
    }

    /// 1.1 조약돌 정지점 — 시각 비례와 찍은 순서를 반반 섞는다. 시각만 쓰면 몇 분 사이 찍은 색이 칼선이 되고
    /// 하루 끝 사진이 테두리 조각으로 몰린다. 타임라인은 시각이 정확해야 하니 stops 를 쓴다.
    public static func legacyPebbleStops(for moments: [Moment]) -> [Stop] {
        let placed = positions(for: moments)
        guard placed.count > 1 else { return stops(for: moments) }
        return zip(placed, legacyLocations(placed)).map { Stop(location: $1, hex: $0.moment.colorHex) }
    }

    private static func legacyLocations(_ placed: [(moment: Moment, location: Double)]) -> [Double] {
        guard placed.count > 1 else { return [0] }
        let last = Double(placed.count - 1)
        return placed.enumerated().map { i, p in 0.5 * p.location + 0.5 * Double(i) / last }
    }

    public static func positions(for moments: [Moment]) -> [(moment: Moment, location: Double)] {
        let sorted = moments.sorted { $0.capturedAt < $1.capturedAt }
        guard let first = sorted.first, let last = sorted.last else { return [] }

        guard sorted.count > 1 else { return [(first, 0)] }

        let span = last.capturedAt.timeIntervalSince(first.capturedAt)

        guard span > 0 else {
            return sorted.enumerated().map { ($0.element, Double($0.offset) / Double(sorted.count - 1)) }
        }
        return sorted.map { ($0, $0.capturedAt.timeIntervalSince(first.capturedAt) / span) }
    }

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
