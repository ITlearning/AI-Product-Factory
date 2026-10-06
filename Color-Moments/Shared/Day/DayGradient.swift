import SwiftUI

public enum DayGradient {

    public struct Stop: Equatable {
        public let location: Double
        public let hex: String
    }

    public static func stops(for moments: [Moment]) -> [Stop] {
        positions(for: moments).map { Stop(location: $0.location, hex: $0.moment.colorHex) }
    }

    /// 조약돌용 색 자리. 사진마다 제 색 자리(무채색은 35%)와 사이 전환을 두고, 전환 가운데 색은 무채색 쪽으로 민다.
    /// 시각은 전환 길이에만(공백의 제곱근) 조금 반영한다 — 점심과 저녁 사이 긴 공백의 탁한 섞임이 돌을 덮지 않게.
    /// 타임라인은 시각이 정확해야 하니 stops 를 쓴다.
    public static func pebbleStops(for moments: [Moment]) -> [Stop] {
        let sorted = moments.sorted { $0.capturedAt < $1.capturedAt }
        guard sorted.count > 1 else { return stops(for: moments) }
        let hexes = sorted.map(\.colorHex)
        let weights = hexes.map { hex in rgb(hex).map { 0.35 + 0.65 * min(1, chroma($0) / 0.35) } ?? 1 }
        let gaps = zip(sorted, sorted.dropFirst()).map { max($1.capturedAt.timeIntervalSince($0.capturedAt), 1).squareRoot() }
        let longest = gaps.max() ?? 1

        var placed: [(location: Double, hex: String)] = []
        var x = 0.0
        for i in hexes.indices {
            placed.append((x, hexes[i]))
            x += weights[i]
            placed.append((x, hexes[i]))
            guard i < gaps.count else { break }
            let span = 1.6 * (0.6 + 0.4 * gaps[i] / longest)
            let lean = weights[i] / (weights[i] + weights[i + 1])
            placed.append((x + span * lean, halfway(hexes[i], hexes[i + 1])))
            x += span
        }
        return placed.map { Stop(location: $0.location / x, hex: $0.hex) }
    }

    private static func rgb(_ hex: String) -> SIMD3<Double>? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let v = UInt32(digits, radix: 16) else { return nil }
        return [Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF)] / 255
    }

    private static func chroma(_ c: SIMD3<Double>) -> Double { c.max() - c.min() }

    private static func halfway(_ a: String, _ b: String) -> String {
        guard let ca = rgb(a), let cb = rgb(b) else { return a }
        let m = ((ca + cb) * 127.5).rounded(.toNearestOrAwayFromZero)
        return String(format: "#%02X%02X%02X", Int(m.x), Int(m.y), Int(m.z))
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
