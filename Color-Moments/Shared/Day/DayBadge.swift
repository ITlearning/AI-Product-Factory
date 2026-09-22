import SwiftUI

/// 하루가 증정되는 물건.
///
/// 그라데이션은 내용이고 이것은 담는 그릇이다. 그릇이 수집물의 생김새를 정한다.
/// 설계 제약 둘:
/// - **격자로 깔지 않는다.** 빈 날이 구멍으로 보이면 그 순간 스트릭이 된다.
/// - **한 줄로 이어붙인다.** 안 담은 날은 그냥 뱃지가 없는 것이지 빠진 것이 아니다.
/// 조약돌의 실루엣. 날짜에서 결정론적으로 뽑는다.
///
/// 모든 날이 같은 모양이면 수집물이 아니라 규격품이다. 실제 조약돌도 다 다르게 생겼다.
/// 같은 날은 항상 같은 모양이 나와야 하므로 난수를 쓰지 않고 날짜 문자열의 해시를 쓴다.
struct PebbleSilhouette {
    let widthRatio: Double      // 높이 대비 폭
    let topRounding: Double     // 위쪽 둥글기
    let bottomRounding: Double  // 아래쪽 둥글기
    let tilt: Double            // 살짝 기울임(도)

    init(dayKey: String) {
        // 문자열 해시는 실행마다 달라질 수 있다(Swift Hasher 는 시드가 랜덤).
        // 바이트를 직접 접어서 만들면 언제 어디서 돌려도 같은 값이 나온다.
        var h: UInt64 = 5381
        for b in dayKey.utf8 { h = (h &* 33) &+ UInt64(b) }
        func pick(_ shift: UInt64, _ range: ClosedRange<Double>) -> Double {
            let v = Double((h >> shift) & 0xFF) / 255
            return range.lowerBound + v * (range.upperBound - range.lowerBound)
        }
        widthRatio = pick(0, 0.58...0.76)
        topRounding = pick(8, 0.38...0.52)
        bottomRounding = pick(16, 0.34...0.50)
        tilt = pick(24, -4...4)
    }
}

/// 위아래 둥글기가 다른 조약돌 모양.
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

/// 하루 뱃지 한 개. 조약돌 하나가 하루다.
///
/// 그라데이션이 **위에서 아래로** 흐른다 — 아침이 위, 밤이 아래. 하루를 읽는 방향과 같다.
///
/// **만지는 반응은 2026-09-22 에 전부 걷어냈다** (누르면 눌림·문지르면 손끝이 빛남·
/// 기울기 광택). 반응을 얹을수록 «빛이 훑고 지나가는» 한 장면이 뿌옇게 덮였고,
/// 특히 손끝 광택으로 쓰던 `RadialGradient` + `plusLighter` 가 돌 위쪽에 회색 얼룩으로
/// 남아 슁이 끝나는 순간 드러났다. 조약돌은 «보는 것»으로 되돌린다.
public struct DayBadgeView: View {
    private let moments: [Moment]
    private let size: CGFloat
    private let showsCaption: Bool
    private let silhouette: PebbleSilhouette

    /// 표면을 훑고 지나가는 빛의 진행도. 0 에서 출발해 1 로 지나간다.
    ///
    /// **Optional 이 아니다.** `Double?` 로 두고 `if let` 으로 껐다 켜던 판은 두 가지로 터졌다:
    /// (1) `nil → 1` 은 값 변화가 아니라 **뷰 삽입**이라 애니메이션이 안 걸린다 —
    ///     띠가 도착지에 멈춰 선 채 조약돌을 옅게 덮고 있다가 사라졌다(슁이 안 보임).
    /// (2) `blendMode` 를 가진 자식이 ZStack 에 들고 날 때마다 합성 그룹이 다시 잡혀
    ///     남은 레이어들의 밝기가 한 프레임에 «뚝» 바뀐다.
    /// 항상 그려두고 진행도만 움직인다. 양 끝(0·1)에서는 스스로 투명해진다.
    ///
    /// **조약돌 안쪽에서 그려야 한다** — 바깥에 overlay 로 두면 마스킹이 안 돼
    /// 사각형이 지나가는 것처럼 보인다(실측으로 잡힌 버그).
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
            let shape = PebbleShape(top: silhouette.topRounding, bottom: silhouette.bottomRounding)
            ZStack {
                DayGradientView(moments: moments, axis: .vertical)
                // 돌 표면의 광택. 위쪽에서 비스듬히 들어온다.
                LinearGradient(colors: [.white.opacity(0.26), .clear, .black.opacity(0.10)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blendMode(.plusLighter)
                sheenLayer(progress: sheen)
                shape.strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .frame(width: size * silhouette.widthRatio, height: size * 1.2)
            .clipShape(shape)
            .rotationEffect(.degrees(silhouette.tilt))
            .shadow(color: .black.opacity(0.24), radius: 5, y: 3)

            if showsCaption { caption }
        }
    }

    /// 비스듬히 훑고 지나가는 띠.
    ///
    /// 띠를 조약돌만 하게 잡으면 **끝에서 모서리가 드러나 사각형이 지나간 것처럼 보인다**
    /// (실측). 반대로 너무 넓게 잡으면 지나가는 내내 조약돌을 통째로 덮어
    /// 스침이 아니라 «전체가 뿌옇게 떴다 돌아오는» 것처럼 보인다(이것도 실측).
    /// 폭은 조약돌보다 조금 넓게 두되 **흰 심지만 좁게**, 양 끝은 완전히 투명하게.
    private func sheenLayer(progress: Double) -> some View {
        let w = size * silhouette.widthRatio
        let h = size * 1.2
        let band = w * 1.15
        // **이동 폭이 곧 «언제 보이나»다.** ±1.7w 로 잡았더니 흰 심지가 앞 40% 동안 조약돌
        // 바깥에 있다가 한복판에서 불쑥 나타났다(렌더 실측). 20° 기운 심지가 조약돌을
        // 벗어나는 지점이 약 ±1.02w 라서, 그 언저리까지만 움직여야 0→1 내내 고르게 지나간다.
        let travel = w * 1.05
        // 들고 날 때 잘리지 않게 진행도 양 끝에서 스스로 잦아든다. 0 과 1 에서는 완전히 투명하므로
        // 평소(진행도 0)에는 아무것도 안 그린 것과 **픽셀 단위로 같다**(SheenTests 가 못 박는다).
        let fade = min(1, min(progress, 1 - progress) / 0.20)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.07), location: 0.36),
                .init(color: .white.opacity(0.30), location: 0.50),
                .init(color: .white.opacity(0.07), location: 0.64),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(width: band, height: h * 2.2)
        .rotationEffect(.degrees(20))
        .offset(x: -travel + progress * (travel * 2))
        .opacity(fade)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
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

/// 뱃지들이 이어붙은 줄. **격자가 아니다** — 빈 날이 보이지 않는다.
public struct BadgeRowView: View {
    private let store: DayStore

    public init(store: DayStore) { self.store = store }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.dayKeys, id: \.self) { key in
                    DayBadgeView(moments: store.moments(on: key), size: 84)
                }
            }
            .padding(.horizontal, 4).padding(.vertical, 8)
        }
    }
}
