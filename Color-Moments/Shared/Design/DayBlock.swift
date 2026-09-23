import SwiftUI
import UIKit

/// 홈에 세로로 반복되는 «하루» 한 덩어리. `DESIGN.md` §1.1 · §2.5 · §3.1.
///
/// 겹친 사진 더미 + 우측 하단에 걸친 조약돌 + 이름·날짜·개수.
/// **1일차에도 7일차에도 1년차에도 화면 구성이 같다** — 그게 이 정의를 고른 이유다.
public struct DayBlock: View {
    private let moments: [Moment]
    /// 기준 폭(설계 기준 334pt). 화면 폭에 따라 전체가 비례로 줄고 는다.
    private let width: CGFloat

    private static let baseWidth: CGFloat = 334
    private static let baseHeight: CGFloat = 388

    public init(moments: [Moment], width: CGFloat) {
        self.moments = moments
        self.width = width
    }

    private var k: CGFloat { width / Self.baseWidth }      // 축척
    private var boxHeight: CGFloat { Self.baseHeight * k }

    /// 더미의 어긋남은 **날짜 해시로 뽑는다.** 고정값이면 모든 하루가 같은 각도로 겹쳐
    /// 손으로 쌓은 더미가 아니라 인쇄물처럼 보인다(§2.5).
    private var wobble: (back: Double, mid: Double) {
        var h: UInt64 = 5381
        for b in (moments.first?.dayKey ?? "").utf8 { h = (h &* 33) &+ UInt64(b) }
        h ^= h >> 33; h = h &* 0xff51_afd7_ed55_8ccd; h ^= h >> 33
        func pick(_ shift: UInt64, _ r: ClosedRange<Double>) -> Double {
            r.lowerBound + Double((h >> shift) & 0xFF) / 255 * (r.upperBound - r.lowerBound)
        }
        let back = pick(8, 2.0...3.0)
        return (back, -pick(16, 1.5...2.0))     // 뒤·중이 반대로 기울어야 더미로 보인다
    }

    private var photos: [Moment] {
        // 앞에 오는 것이 그날 «마지막»이다. 더미는 위에 쌓인 게 최근이다.
        Array(moments.suffix(3).reversed())
    }

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

    // MARK: 사진 더미 + 조약돌

    private var stack: some View {
        ZStack(alignment: .topLeading) {
            // **자리를 어긋나게 둬야 더미로 읽힌다.** 가운데 정렬로 겹치면 가장 큰 앞장(314×320)이
            // 뒤 장(274×300)을 통째로 덮어 한 장으로 보인다 — 회전 ±2~3° 로는 크기 차이를 못 이긴다.
            // 뒤로 갈수록 위로 올라가고 좌우로 어긋나, 위쪽 가장자리만 빼꼼 나오게 한다.
            card(index: 2, w: 274, h: 300, at: CGPoint(x: 32, y: 2), radius: Shape2.cardBack,
                 angle: wobble.back, opacity: 0.42)
            card(index: 1, w: 290, h: 312, at: CGPoint(x: 20, y: 18), radius: Shape2.cardMid,
                 angle: wobble.mid, opacity: 0.66)
            card(index: 0, w: 314, h: 320, at: CGPoint(x: 10, y: 36), radius: Shape2.cardFront,
                 angle: 0, opacity: 1)
            // 앞장 우측 하단에 걸친다. 사진 위에 얹히므로 분리 테두리를 켠다.
            PebbleView(moments: moments, height: 84 * k, onPhoto: true)
                .offset(x: 268 * k, y: 322 * k)
        }
        .frame(width: width, height: boxHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func card(index: Int, w: CGFloat, h: CGFloat, at: CGPoint,
                      radius: CGFloat, angle: Double, opacity: Double) -> some View {
        if index < photos.count {
            let m = photos[index]
            let shape = RoundedRectangle(cornerRadius: radius * k, style: .continuous)
            ZStack(alignment: .bottom) {
                if let img = ShotImage.thumbnail(m.fileName, maxPixel: index == 0 ? 700 : 500) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Color(hex: m.colorHex)
                }
                if index == 0 {
                    // 사진 위에 글자가 없어도 바닥을 만들어 준다(§2.5).
                    LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 104 * k)
                }
            }
            .frame(width: w * k, height: h * k)
            .clipShape(shape)
            .rotationEffect(.degrees(angle))
            .opacity(opacity)
            .shadow(color: .black.opacity(index == 0 ? 0.62 : 0),
                    radius: index == 0 ? 38 * k : 0, y: index == 0 ? 20 * k : 0)
            .offset(x: at.x * k, y: at.y * k)
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
