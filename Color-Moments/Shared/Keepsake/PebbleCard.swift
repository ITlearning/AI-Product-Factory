import SwiftUI

/// 건넬 조약돌 카드 — 돌·이름·날짜·작은 "몽돌"만. 사진·장소·단어는 절대 넣지 않는다(카드가 곧 프로필이 되면 안 된다).
public struct PebbleCard: View {
    private let dayKey: String
    private let pebbleMoments: [Moment]

    public init(dayKey: String, pebbleMoments: [Moment]) {
        self.dayKey = dayKey
        self.pebbleMoments = pebbleMoments
    }

    public var body: some View {
        ZStack {
            background
            VStack(spacing: 22) {
                Spacer()
                PebbleView(moments: pebbleMoments, height: 220)
                VStack(spacing: 10) {
                    if let named = PebbleNaming.name(for: pebbleMoments) {
                        Text(named.name).font(Face.nameDay).foregroundStyle(Tone.primary)
                    }
                    Text(dateText).font(Face.line).foregroundStyle(Tone.secondary).monospacedDigit()
                }
                Spacer()
                Text("몽돌").font(Face.caption).foregroundStyle(Tone.tertiary)
                Spacer().frame(height: 34)
            }
        }
    }

    private var background: some View {
        ZStack {
            Tone.base
            DayGradientView(moments: pebbleMoments, axis: .vertical)
                .blur(radius: 90)
                .opacity(0.55)
        }
        .ignoresSafeArea()
    }

    private var dateText: String {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dayKey }
        return "\(parts[0])년 \(parts[1])월 \(parts[2])일"
    }
}
