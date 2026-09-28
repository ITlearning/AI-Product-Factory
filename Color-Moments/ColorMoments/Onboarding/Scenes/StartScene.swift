import SwiftUI

/// 준비됐어요 — 방금 받은(또는 가장 최근에 받은) 조약돌이 가운데서 숨 쉬듯 떠 있다. 없으면 점선 빈 돌.
struct StartScene: View {
    let pebble: [Moment]

    @Environment(\.onboardingInk) private var ink

    var body: some View {
        Group {
            if pebble.isEmpty {
                DashedPebble(height: 130, stroke: ink.hairline)
            } else {
                PebbleView(moments: pebble, height: 150)
            }
        }
        .breathing()
        .accessibilityHidden(true)
    }

    /// 받은 하루 중 가장 최근 — 받기 전 하루의 색은 증정에서 처음 열려야 한다.
    static func latestGiftedDay(dayKeys: [String], isGifted: (String) -> Bool) -> String? {
        dayKeys.first(where: isGifted)
    }
}
