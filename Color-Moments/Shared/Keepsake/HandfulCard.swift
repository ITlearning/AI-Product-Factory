import SwiftUI

/// 건넬 한 달 한 줌 카드 — 그 달 받은 돌들만 한 손 안에 모은다. 사진·장소·날짜별 이름은 없다(카드는 프로필이 아니다).
public struct HandfulCard: View {
    private let month: String
    private let pebbleGroups: [[Moment]]
    private let today: String

    public init(month: String, pebbleGroups: [[Moment]], today: String = Moment.dayKey(for: Date())) {
        self.month = month
        self.pebbleGroups = pebbleGroups
        self.today = today
    }

    public var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.60
                ZStack {
                    ForEach(Array(placements.enumerated()), id: \.offset) { i, p in
                        PebbleView(moments: pebbleGroups[i], height: 92 * p.scale, glow: .grid, classicTilt: p.rotation)
                            .offset(x: p.x * side / 2, y: p.y * side / 2)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height * 0.72)
            }
            VStack {
                Spacer()
                Text(label).font(Face.line).foregroundStyle(Tone.secondary)
                Spacer().frame(height: 18)
                Text("몽돌").font(Face.caption).foregroundStyle(Tone.tertiary)
                Spacer().frame(height: 34)
            }
        }
    }

    private var placements: [(x: Double, y: Double, rotation: Double, scale: Double)] {
        Memories.handfulLayout(count: pebbleGroups.count, seed: WordPicker.fnv1a(month))
    }

    private var label: String { Memories.handfulTitle(month: month, today: today) }
}
