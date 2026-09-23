import SwiftUI

struct PebbleSilhouette {
    let widthRatio: Double
    let topRounding: Double
    let bottomRounding: Double
    let tilt: Double

    init(dayKey: String) {

        var h: UInt64 = 5381
        for b in dayKey.utf8 { h = (h &* 33) &+ UInt64(b) }

        h ^= h >> 33
        h = h &* 0xff51_afd7_ed55_8ccd
        h ^= h >> 33
        h = h &* 0xc4ce_b9fe_1a85_ec53
        h ^= h >> 33

        func pick(_ shift: UInt64, _ range: ClosedRange<Double>) -> Double {
            let v = Double((h >> shift) & 0xFF) / 255
            return range.lowerBound + v * (range.upperBound - range.lowerBound)
        }

        widthRatio = Shape2.pebbleRatio
        topRounding = pick(8, 0.32...0.54)
        bottomRounding = pick(16, 0.28...0.52)
        tilt = pick(24, -7...7)
    }
}

struct PebbleShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> PebbleShape {
        var s = self; s.insetAmount += amount; return s
    }

    let top: Double
    let bottom: Double

    func path(in r: CGRect) -> Path {
        let rect = r.insetBy(dx: insetAmount, dy: insetAmount)
        let w = rect.width
        let rt = min(w / 2, w * top)
        let rb = min(w / 2, w * bottom)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rt))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rt, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rt, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rt),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rb))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - rb, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rb, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - rb),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

public struct DayBadgeView: View {
    private let moments: [Moment]
    private let size: CGFloat
    private let showsCaption: Bool
    private let silhouette: PebbleSilhouette

    private let sheen: Double

    public init(moments: [Moment], size: CGFloat = 96, showsCaption: Bool = true, sheen: Double = 0) {
        self.moments = moments
        self.size = size
        self.showsCaption = showsCaption
        self.sheen = sheen
        let key = moments.first.map(\.dayKey) ?? Moment.dayKey(for: Date())
        self.silhouette = PebbleSilhouette(dayKey: key)
    }

    private var span: (from: Date, to: Date)? { DayGradient.span(for: moments) }

    public var body: some View {
        VStack(spacing: 7) {

            PebbleView(moments: moments, height: size * 1.2, sheen: sheen)
            if showsCaption { caption }
        }
    }

    private var caption: some View {
        VStack(spacing: 1) {
            if let named = PebbleNaming.name(for: moments) {
                Text(named.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            Text(dateText)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
            if let span {
                Text("\(DayGradient.timeText(span.from)) – \(DayGradient.timeText(span.to))")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var dateText: String {
        guard let first = moments.min(by: { $0.capturedAt < $1.capturedAt }) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: first.capturedAt)
    }
}

public struct BadgeRowView: View {
    private let store: DayStore

    @State private var opened: OpenedDay?

    private struct OpenedDay: Identifiable { let id: String }

    public init(store: DayStore) { self.store = store }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.finishedDayKeys, id: \.self) { key in
                    Button { opened = OpenedDay(id: key) } label: {
                        DayBadgeView(moments: store.pebbleMoments(on: key), size: 84)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4).padding(.vertical, 8)
        }
        .sheet(item: $opened) { day in
            DayMomentsView(dayKey: day.id, store: store)
        }
    }
}
