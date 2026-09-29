import SwiftUI

/// 받기 결과 문구 — 화면과 떼어 둔 순수 판정.
enum ReceivedCopy {

    struct Text: Equatable {
        let title: String
        let detail: String?
    }

    /// dayGifted — 담긴 하루가 이미 받은 하루인지(.added 에서만 본다).
    static func text(_ outcome: OnboardingFlow.ImportOutcome, addedCount: Int, dayGifted: Bool) -> Text {
        switch outcome {
        case .gift:
            return Text(title: "첫 조약돌을 받았어요", detail: "홈에서 언제든 다시 볼 수 있어요.")
        case .added:
            let title = addedCount > 0 ? "\(addedCount)장 더 담겼어요" : "사진이 담겼어요"
            return Text(title: title, detail: dayGifted ? "이미 받은 하루라 조약돌 색은 그대로예요" : nil)
        case .todayOnly:
            return Text(title: "오늘 진행 중에 담겼어요", detail: "색은 자정에 열려요")
        case .nothing:
            return Text(title: "사진이 담겼어요", detail: nil)
        }
    }

    /// 장면에 세울 하루 — 오늘을 뺀 가장 최근, 없으면 오늘.
    static func focusDay(importedDayKeys: Set<String>, today: String) -> String? {
        importedDayKeys.filter { $0 != today }.max() ?? importedDayKeys.max()
    }
}

/// 받기 결과 — 고른 사진이 겹쳐 쌓였다가 조약돌로 모이거나(첫 조약돌), 조약돌 옆에 쌓인다.
struct ReceivedScene: View {
    let outcome: OnboardingFlow.ImportOutcome
    /// 색을 보여도 되는 조약돌 — 비었으면 점선 빈 돌.
    let pebble: [Moment]
    let photos: [Moment]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingScenesPaused) private var paused
    @State private var played = false

    private static let tilt: [Double] = [-8, 5, -3, 9]
    private static let spread: [CGSize] = [.init(width: -14, height: 6), .init(width: 12, height: -8),
                                           .init(width: -4, height: -14), .init(width: 16, height: 10)]

    var body: some View {
        Group {
            switch outcome {
            case .gift: gathering
            case .added, .todayOnly: beside
            case .nothing: DashedPebble(height: 110).breathing()
            }
        }
        .accessibilityHidden(true)
        // 증정 커버 아래에서 먼저 끝나 버리지 않게, 덮인 동안은 기다렸다 시작한다.
        .task(id: paused) {
            guard !paused, !played else { return }
            if reduceMotion { played = true; return }
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) { played = true }
        }
    }

    private var stone: some View {
        Group {
            if pebble.isEmpty { DashedPebble(height: 116) } else { PebbleView(moments: pebble, height: 116) }
        }
    }

    private var gathering: some View {
        ZStack {
            ForEach(Array(photos.prefix(4).enumerated()), id: \.element.id) { i, m in
                PhotoCard(moment: m)
                    .rotationEffect(.degrees(played ? 0 : Self.tilt[i]))
                    .offset(played ? .zero : Self.spread[i])
                    .scaleEffect(played ? 0.25 : 1)
                    .opacity(played ? 0 : 1)
            }
            stone
                .scaleEffect(played ? 1 : 0.6)
                .opacity(played ? 1 : 0)
                .breathing()
        }
    }

    private var beside: some View {
        HStack(spacing: 28) {
            stone.breathing()
            ZStack {
                ForEach(Array(photos.prefix(4).enumerated()), id: \.element.id) { i, m in
                    PhotoCard(moment: m, side: 58)
                        .rotationEffect(.degrees(Self.tilt[i] * 0.7))
                        .offset(x: Self.spread[i].width * 0.5, y: played ? Self.spread[i].height * 0.5 : -40)
                        .opacity(played ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75)
                            .delay(Double(i) * 0.14), value: played)
                }
            }
            .frame(width: 80, height: 80)
        }
    }
}

private struct PhotoCard: View {
    let moment: Moment
    var side: CGFloat = 74

    var body: some View {
        // 담은 사진에는 아직 받지 않은 날(오늘·다른 날)도 섞인다 — 로딩 자리에 색을 비추지 않는다.
        ShotThumbnail(moment: moment, maxPixel: side * 3, hidesColor: true)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: Shape2.cardBack, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Shape2.cardBack, style: .continuous)
                .strokeBorder(Tone.hairline, lineWidth: 1))
            .shadow(color: Tone.pure.opacity(0.4), radius: 8, y: 4)
    }
}
