import SwiftUI

public enum DayGradient {

    public struct Stop: Equatable {
        public let location: Double
        public let hex: String
    }

    public static func stops(for moments: [Moment]) -> [Stop] {
        let sorted = moments.sorted { $0.capturedAt < $1.capturedAt }
        guard let first = sorted.first, let last = sorted.last else { return [] }

        guard sorted.count > 1 else { return [Stop(location: 0, hex: first.colorHex)] }

        let span = last.capturedAt.timeIntervalSince(first.capturedAt)

        guard span > 0 else {
            return sorted.enumerated().map {
                Stop(location: Double($0.offset) / Double(sorted.count - 1), hex: $0.element.colorHex)
            }
        }
        return sorted.map {
            Stop(location: $0.capturedAt.timeIntervalSince(first.capturedAt) / span, hex: $0.colorHex)
        }
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
