import SwiftUI

/// 지난 달 머리글을 누르면 뜨는 전체 화면 — 그 달 받은 돌들이 한 손 안에 모인다. 안 받은 하루는 pebbleGroups 에 애초에 없다.
public struct HandfulView: View {
    private let month: String
    private let pebbleGroups: [[Moment]]
    private let today: String
    // ImageRenderer/ShareLink 는 앱 타깃 전용이라 카드 시트 내용은 호출부(App)가 만들어 넘긴다.
    private let makeShareSheet: (() -> AnyView)?

    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false

    public init(month: String, pebbleGroups: [[Moment]], today: String = Moment.dayKey(for: Date()),
                makeShareSheet: (() -> AnyView)? = nil) {
        self.month = month
        self.pebbleGroups = pebbleGroups
        self.today = today
        self.makeShareSheet = makeShareSheet
    }

    public var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.62
                ZStack {
                    ForEach(Array(placements.enumerated()), id: \.offset) { i, p in
                        PebbleView(moments: pebbleGroups[i], height: 100 * p.scale, glow: .grid, classicTilt: p.rotation)
                            .offset(x: p.x * side / 2, y: p.y * side / 2)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
            VStack {
                topBar
                Spacer()
                Text(label).font(Face.line).foregroundStyle(Tone.secondary)
                Spacer().frame(height: 44)
            }
        }
        .sheet(isPresented: $sharing) { makeShareSheet?() ?? AnyView(EmptyView()) }
    }

    private var topBar: some View {
        HStack {
            closeButton
            Spacer()
            shareButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("닫기")
                .font(Face.actionSecondary)
                .foregroundStyle(Tone.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: Shape2.minTouch)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var shareButton: some View {
        if makeShareSheet != nil {
            Button { sharing = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Tone.secondary)
                    .frame(width: Shape2.minTouch, height: Shape2.minTouch)
            }
            .buttonStyle(.plain)
        }
    }

    private var placements: [(x: Double, y: Double, rotation: Double, scale: Double)] {
        Memories.handfulLayout(count: pebbleGroups.count, seed: WordPicker.fnv1a(month))
    }

    private var label: String { Memories.handfulTitle(month: month, today: today) }
}
