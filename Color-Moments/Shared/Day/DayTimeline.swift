import CoreGraphics

public enum DayTimeline {

    public struct Placement: Equatable {
        public let moment: Moment
        public let y: CGFloat
        public let shift: Int
        public let showsTime: Bool
    }

    public static func place(_ moments: [Moment], height: CGFloat, photoHeight: CGFloat,
                             maxShift: Int = 3, minLabelGap: CGFloat = 14) -> [Placement] {
        var out: [Placement] = []
        var lastLabelY = -CGFloat.infinity
        for p in DayGradient.positions(for: moments) {
            let y = CGFloat(p.location) * height
            var shift = 0
            if let prev = out.last, y < prev.y + photoHeight {
                shift = (prev.shift + 1) % (maxShift + 1)
            }
            let showsTime = y - lastLabelY >= minLabelGap
            if showsTime { lastLabelY = y }
            out.append(Placement(moment: p.moment, y: y, shift: shift, showsTime: showsTime))
        }
        return out
    }
}
