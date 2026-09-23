import SwiftUI
import UIKit

public struct DayBlock: View {
    private let moments: [Moment]
    private let pebbleMoments: [Moment]

    private let width: CGFloat

    private static let baseWidth: CGFloat = 334
    private static let baseHeight: CGFloat = 388
    // 슬롯마다 다른 크기로 캐시하면 뒷장이 앞으로 올라올 때가 매번 캐시 미스다.
    private static let cardPixels: CGFloat = 700

    @State private var cycle = 0

    @State private var dragX: CGFloat = 0

    @State private var flying: Moment?
    @State private var flyX: CGFloat = 0

    public init(moments: [Moment], pebbleMoments: [Moment]? = nil, width: CGFloat) {
        self.moments = moments
        self.pebbleMoments = pebbleMoments ?? moments
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
            if let named = PebbleNaming.name(for: pebbleMoments) {
                Text(named.name).font(Face.nameHome).foregroundStyle(Tone.primary)
                Spacer().frame(height: 9 * k)
            }
            Text(subtitle).font(Face.caption).foregroundStyle(Tone.tertiary).monospacedDigit()
        }
    }

    private struct Card: Identifiable {
        let moment: Moment
        let slot: Int
        var id: String { moment.fileName }
    }

    private struct Slot {
        let w, h: CGFloat
        let at: CGPoint
        let radius: CGFloat
        let angle: Double
        let opacity: Double
    }

    private func slotLayout(_ slot: Int) -> Slot {
        switch slot {
        case 0:  Slot(w: 314, h: 320, at: CGPoint(x: 10, y: 36),
                      radius: Shape2.cardFront, angle: 0, opacity: 1)
        case 1:  Slot(w: 290, h: 312, at: CGPoint(x: 20, y: 18),
                      radius: Shape2.cardMid, angle: wobble.mid, opacity: 0.66)
        default: Slot(w: 274, h: 300, at: CGPoint(x: 32, y: 2),
                      radius: Shape2.cardBack, angle: wobble.back, opacity: 0.42)
        }
    }

    private var visibleCards: [Card] {
        (0..<min(3, allPhotos.count)).compactMap { slot in
            guard let m = photo(slot) else { return nil }
            // 날아가는 중인 사진은 뒷자리에 넣지 않는다. 3장짜리 하루는
            // (cycle+2) % 3 이 방금 걷어낸 그 사진이라 날아가는 동안 뒤에서 튀어나온다.
            guard m.fileName != flying?.fileName else { return nil }
            return Card(moment: m, slot: slot)
        }
    }

    private var stack: some View {
        ZStack(alignment: .topLeading) {
            ForEach(visibleCards) { c in
                let g = slotLayout(c.slot)
                photoCard(c.moment, w: g.w, h: g.h, at: g.at,
                          radius: g.radius, front: c.slot == 0)
                    .rotationEffect(.degrees(g.angle))
                    .opacity(g.opacity)
                    .offset(x: c.slot == 0 ? dragX : 0)
                    .rotationEffect(.degrees(c.slot == 0 ? dragX / 46 : 0), anchor: .bottom)
                    .zIndex(Double(3 - c.slot))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .top)),
                        removal: .opacity))
                    .overlay {
                        if c.slot == 0 && canFlick {
                            HorizontalPan(onChanged: { dragX = min(0, $0) },
                                          onEnded: { tx, vx in finishFlick(tx: tx, vx: vx, width: width) })
                        }
                    }
            }

            if let flying {
                let g = slotLayout(0)
                photoCard(flying, w: g.w, h: g.h, at: g.at, radius: g.radius, front: true)
                    .offset(x: flyX)
                    .rotationEffect(.degrees(flyX / 46), anchor: .bottom)
                    .allowsHitTesting(false)
                    .zIndex(4)
            }

            PebbleView(moments: pebbleMoments, height: 84 * k, onPhoto: true)
                .offset(x: 268 * k, y: 322 * k)
                .zIndex(5)
        }
        .frame(width: width, height: boxHeight, alignment: .topLeading)
    }

    private func photoCard(_ m: Moment, w: CGFloat, h: CGFloat, at: CGPoint,
                           radius: CGFloat, front: Bool) -> some View {
        Group {
            let shape = RoundedRectangle(cornerRadius: radius * k, style: .continuous)
            ZStack(alignment: .bottom) {

                ShotThumbnail(moment: m, maxPixel: Self.cardPixels)
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

    private func finishFlick(tx: CGFloat, vx: CGFloat, width: CGFloat) {
        guard tx < -60 || vx < -700 else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragX = 0 }
            return
        }
        flying = photo(0)
        flyX = dragX
        dragX = 0
        // cycle 만 애니메이션한다. dragX 까지 같이 묶이면 새 앞장이 왼쪽에서 밀려 들어온다.
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            cycle += 1
        }
        Haptics.tickPassed()
        // 삽입과 이동이 같은 틱에 있으면 애니메이션할 이전 값이 없어 최종 위치로 바로 그려진다.
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.28)) {
                flyX = -width * 1.3
            } completion: {
                flying = nil
            }
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
