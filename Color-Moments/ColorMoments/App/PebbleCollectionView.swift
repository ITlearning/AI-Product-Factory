import SwiftUI

/// 모은 조약돌 — 홈에서 오른쪽 가장자리를 왼쪽으로 쓸면 들어온다. 받은 조약돌만 빈틈없이 달별로 묶는다.
/// 달력 칸·빈칸·개수는 두지 않는다 — SPEC §1-2: 빈 날이 구멍으로 보이면 그 순간 스트릭이 된다.
struct PebbleCollectionView: View {
    let store: DayStore
    let gifts: GiftLog
    let closures: DayClosures
    /// 홈 옆에 붙어 열릴 때 — 제목줄을 그리고 아래 탭바 자리를 비운다. false 면 내비게이션 안(디버그)에서 쓴다.
    var embedded = false
    var onScrollMinimize: (Bool) -> Void = { _ in }
    /// 넘기는 중이거나 넘어가는 중이면 false — 화면이 손가락을 따라 움직여 손을 뗀 자리가 여전히 그 조약돌 위라,
    /// 닫는 스와이프가 탭으로도 잡혀 홈에 돌아온 뒤 상세가 떴다.
    var acceptsTaps = true

    @State private var opened: OpenedDay?

    private struct OpenedDay: Identifiable { let id: String }

    // 렌치 → 조약돌 비교의 격자와 같은 판(2026-10-01 Tabber) — 4열, 둥근 돌 62 · 반듯한 돌 70.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    @AppStorage(PebbleStyle.key, store: PebbleStyle.store) private var style: PebbleStyle = .round

    private var months: [(month: String, days: [String])] {
        let keys = store.finishedDayKeys
            .filter { gifts.isGifted($0) && !store.pebbleMoments(on: $0).isEmpty }
            .sorted(by: >)
        var out: [(month: String, days: [String])] = []
        for key in keys {
            let month = String(key.prefix(7))
            if out.last?.month == month { out[out.count - 1].days.append(key) } else { out.append((month, [key])) }
        }
        return out
    }

    var body: some View {
        let months = months
        VStack(spacing: 0) {
            if embedded { header }
            ScrollView { grid(months, lazy: true) }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { old, new in
                    TabBarFold.report(old: old, new: new, to: onScrollMinimize)
                }
        }
        .overlay {
            if months.isEmpty {
                VStack(spacing: 8) {
                    Text("아직 받은 조약돌이 없어요").font(Face.guide).foregroundStyle(Tone.secondary)
                    Text("하루가 닫혀 조약돌이 도착하면 여기에 모여요").font(Face.caption).foregroundStyle(Tone.tertiary)
                }
                .multilineTextAlignment(.center)
            }
        }
        .overlay {
        }
        .background(Tone.base.ignoresSafeArea())
        .navigationTitle(embedded ? "" : "모은 조약돌")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $opened) { day in
            DayMomentsView(dayKey: day.id, store: store, closures: closures, isGifted: gifts.isGifted,
                           makeShareSheet: { key, viewing in
                               AnyView(KeepsakeShareSheet(dayKey: key, store: store, viewingID: viewing))
                           })
        }
    }

    private var header: some View {
        Text("모은 조약돌").font(Face.lineCeremony).foregroundStyle(Tone.primary)
            .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
            .padding(.top, 6)
    }

    /// lazy: false 는 스크롤 밖에서 통째로 그릴 때(테스트 덤프).
    @ViewBuilder
    func grid(_ months: [(month: String, days: [String])], lazy: Bool) -> some View {
        let body = ForEach(months, id: \.month) { m in
            VStack(alignment: .leading, spacing: 18) {
                Text(Memories.handfulTitle(month: m.month, today: Moment.dayKey(for: Date())))
                    .font(Face.line).foregroundStyle(Tone.secondary)
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(m.days, id: \.self) { cell($0) }
                }
            }
        }
        Group {
            if lazy {
                LazyVStack(alignment: .leading, spacing: 36) { body }
            } else {
                VStack(alignment: .leading, spacing: 36) { body }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, embedded ? 110 : 24)
    }

    var monthsForPreview: [(month: String, days: [String])] { months }

    private func cell(_ key: String) -> some View {
        let moments = store.pebbleMoments(on: key)
        return Button {
            guard acceptsTaps else { return }
            opened = OpenedDay(id: key)
        } label: {
            VStack(spacing: 4) {
                Group {
                    switch style {
                    case .round: SoftPebbleView(moments: moments, height: 62, glow: .grid)
                    case .classic: LegacyPebbleView(moments: moments, height: 70)
                    }
                }
                .frame(height: 96)
                Text(Self.dateText(key)).font(Face.caption).monospacedDigit().foregroundStyle(Tone.tertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    static func monthTitle(_ month: String) -> String {
        let p = month.split(separator: "-").compactMap { Int($0) }
        return p.count == 2 ? "\(p[0])년 \(p[1])월" : month
    }

    static func dateText(_ key: String) -> String {
        let p = key.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? "\(p[1])월 \(p[2])일" : key
    }
}
