import SwiftUI
import UIKit

public struct DayBlock: View {
    private let moments: [Moment]

    private let width: CGFloat

    private static let baseWidth: CGFloat = 334
    private static let baseHeight: CGFloat = 388

    @State private var cycle = 0

    @State private var dragX: CGFloat = 0

    @State private var flying: Moment?
    @State private var flyX: CGFloat = 0

    public init(moments: [Moment], width: CGFloat) {
        self.moments = moments
        self.width = width
    }

    private var k: CGFloat { width / Self.baseWidth }
    private var boxHeight: CGFloat { Self.baseHeight * k }

    private var wobble: (back: Double, mid: Double) {
        var h: UInt64 = 5381
        for b in (moments.first?.dayKey ?? "").utf8 { h = (h &* 33) &+ UInt64(b) }
        h ^= h >> 33; h = h &* 0xff51_afd7_ed55_8ccd; h ^= h >> 33
        func pick(_ shift: UInt64, _ r: ClosedRange<Double>) -> Double {
            r.lowerBound + Double((h >> shift) & 0xFF) / 255 * (r.upperBound - r.lowerBound)
        }
        let back = pick(8, 2.0...3.0)
        return (back, -pick(16, 1.5...2.0))
    }

    private var allPhotos: [Moment] { Array(moments.reversed()) }

    private func photo(_ slot: Int) -> Moment? {
        guard slot < allPhotos.count else { return nil }
        return allPhotos[(cycle + slot) % allPhotos.count]
    }

    private var canFlick: Bool { allPhotos.count > 1 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stack
            Spacer().frame(height: 26 * k)
            if let named = PebbleNaming.name(for: moments) {
                Text(named.name).font(Face.nameHome).foregroundStyle(Tone.primary)
                Spacer().frame(height: 9 * k)
            }
            Text(subtitle).font(Face.caption).foregroundStyle(Tone.tertiary).monospacedDigit()
        }
    }

    private var stack: some View {
        ZStack(alignment: .topLeading) {

            card(slot: 2, w: 274, h: 300, at: CGPoint(x: 32, y: 2), radius: Shape2.cardBack,
                 angle: wobble.back, opacity: 0.42)
            card(slot: 1, w: 290, h: 312, at: CGPoint(x: 20, y: 18), radius: Shape2.cardMid,
                 angle: wobble.mid, opacity: 0.66)
            card(slot: 0, w: 314, h: 320, at: CGPoint(x: 10, y: 36), radius: Shape2.cardFront,
                 angle: 0, opacity: 1)
                .offset(x: dragX)
                .rotationEffect(.degrees(dragX / 46), anchor: .bottom)
                .gesture(canFlick ? flick(width: width) : nil)

            if let flying {
                photoCard(flying, w: 314, h: 320, at: CGPoint(x: 10, y: 36),
                          radius: Shape2.cardFront, front: true)
                    .offset(x: flyX)
                    .rotationEffect(.degrees(flyX / 46), anchor: .bottom)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }

            PebbleView(moments: moments, height: 84 * k, onPhoto: true)
                .offset(x: 268 * k, y: 322 * k)
        }
        .frame(width: width, height: boxHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func card(slot: Int, w: CGFloat, h: CGFloat, at: CGPoint,
                      radius: CGFloat, angle: Double, opacity: Double) -> some View {
        if let m = photo(slot) {
            photoCard(m, w: w, h: h, at: at, radius: radius, front: slot == 0)
                .rotationEffect(.degrees(angle))
                .opacity(opacity)
        }
    }

    private func photoCard(_ m: Moment, w: CGFloat, h: CGFloat, at: CGPoint,
                           radius: CGFloat, front: Bool) -> some View {
        Group {
            let shape = RoundedRectangle(cornerRadius: radius * k, style: .continuous)
            ZStack(alignment: .bottom) {

                ShotThumbnail(moment: m, maxPixel: front ? 700 : 500)
                if front {

                    LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 104 * k)
                }
            }
            .frame(width: w * k, height: h * k)
            .clipShape(shape)
            .shadow(color: .black.opacity(front ? 0.62 : 0),
                    radius: front ? 38 * k : 0, y: front ? 20 * k : 0)
            .offset(x: at.x * k, y: at.y * k)
        }
    }

    private func flick(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { v in
                guard v.translation.width < 0,
                      abs(v.translation.width) > abs(v.translation.height) * 1.4 else { return }
                dragX = v.translation.width
            }
            .onEnded { v in
                let vx = v.predictedEndTranslation.width - v.translation.width
                guard dragX < -60 || vx < -300 else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragX = 0 }
                    return
                }

                flying = photo(0)
                flyX = dragX
                cycle += 1
                dragX = 0
                withAnimation(.easeOut(duration: 0.26)) {
                    flyX = -width * 1.25
                } completion: {
                    flying = nil
                }
                Haptics.tickPassed()
            }
    }

    private var subtitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        let date = moments.first.map { f.string(from: $0.capturedAt) } ?? ""
        return "\(date) · \(moments.count)개"
    }
}
