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

        // **djb2 만으로는 부족하다.** 날짜는 마지막 한두 글자만 다른데, djb2 는 그 차이가
        // 하위 8비트에만 남는다 — shift 8·16·24 로 뽑는 값들이 인접한 날끼리 **전부 같아진다.**
        // 예전엔 폭을 하위 비트(shift 0)에서 뽑아 폭만 달라 보였고, 나머지는 원래 다 같았다.
        // 폭을 고정(DESIGN §2.3)하는 순간 모든 조약돌이 같은 모양이 됐다(테스트가 잡음).
        // 아래는 MurmurHash3 의 fmix64 — 결정론적이면서 한 비트 차이가 전 비트로 번진다.
        h ^= h >> 33
        h = h &* 0xff51_afd7_ed55_8ccd
        h ^= h >> 33
        h = h &* 0xc4ce_b9fe_1a85_ec53
        h ^= h >> 33

        func pick(_ shift: UInt64, _ range: ClosedRange<Double>) -> Double {
            let v = Double((h >> shift) & 0xFF) / 255
            return range.lowerBound + v * (range.upperBound - range.lowerBound)
        }
        // **폭 비율은 고정이다** (`DESIGN.md` §2.3 — 0.70).
        // 폭까지 날마다 달라지면 세로로 쌓이는 홈에서 줄이 들쭉날쭉해 보인다.
        // 「날마다 다르다」는 둥글기와 기울임이 담고, 범위를 넓혀 «눈에 띄게» 다르게 한다(§2.4).
        widthRatio = Shape2.pebbleRatio
        topRounding = pick(8, 0.32...0.54)
        bottomRounding = pick(16, 0.28...0.52)
        tilt = pick(24, -7...7)
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
            // 표면 처리는 전부 `PebbleView`(DESIGN §2.4 여섯 겹)가 한다.
            // 기존 「그라데이션 + 대각 광택 한 겹」은 평면으로 보여서 버렸다.
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

/// 뱃지들이 이어붙은 줄. **격자가 아니다** — 빈 날이 보이지 않는다.
///
/// **오늘은 여기 없다.** 아직 끝나지 않은 하루라 조약돌이 아니다 — 자정에 증정되면서
/// 비로소 줄에 붙는다. 오늘을 여기 얹으면 조약돌을 눌러 색을 볼 수 있게 되어
/// 「자정에 열린다」가 그 자리에서 깨진다(색 고치기 입구가 이 줄이기 때문).
public struct BadgeRowView: View {
    private let store: DayStore
    /// 열어본 하루. 색을 고치러 들어가는 유일한 입구다.
    @State private var opened: OpenedDay?

    /// `sheet(item:)` 이 Identifiable 을 요구해서 두는 껍데기.
    /// `String` 에 직접 Identifiable 을 달면 앱 전체의 모든 문자열에 영향을 준다.
    private struct OpenedDay: Identifiable { let id: String }

    public init(store: DayStore) { self.store = store }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.finishedDayKeys, id: \.self) { key in
                    Button { opened = OpenedDay(id: key) } label: {
                        DayBadgeView(moments: store.moments(on: key), size: 84)
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
