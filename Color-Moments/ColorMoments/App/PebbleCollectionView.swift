import SwiftUI

/// 모은 조약돌 — 홈에서 오른쪽 가장자리를 왼쪽으로 쓸면 들어온다. 받은 조약돌만 빈틈없이 달별로 묶는다.
/// 달력 칸·빈칸·개수는 두지 않는다 — SPEC §1-2: 빈 날이 구멍으로 보이면 그 순간 스트릭이 된다.
struct PebbleCollectionView: View {
    let store: DayStore
    let gifts: GiftLog
    let closures: DayClosures
    /// 홈 옆에 붙어 열릴 때 — 제목줄과 돌아가기 버튼을 그린다. nil 이면 내비게이션 안(디버그)에서 쓴다.
    var onClose: (() -> Void)? = nil
    /// 넘기는 중이거나 넘어가는 중이면 false — 화면이 손가락을 따라 움직여 손을 뗀 자리가 여전히 그 조약돌 위라,
    /// 닫는 스와이프가 탭으로도 잡혀 홈에 돌아온 뒤 상세가 떴다.
    var acceptsTaps = true

    @State private var opened: OpenedDay?

    private struct OpenedDay: Identifiable { let id: String }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

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
            if let onClose { header(onClose) }
            ScrollView { grid(months, lazy: true) }
                .scrollIndicators(.hidden)
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
        .background(Tone.base.ignoresSafeArea())
        .navigationTitle(onClose == nil ? "모은 조약돌" : "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $opened) { day in
            DayMomentsView(dayKey: day.id, store: store, closures: closures, isGifted: gifts.isGifted,
                           makeShareSheet: { key, viewing in
                               AnyView(KeepsakeShareSheet(dayKey: key, store: store, viewingID: viewing))
                           })
        }
    }

    private func header(_ onClose: @escaping () -> Void) -> some View {
        ZStack {
            Text("모은 조약돌").font(Face.lineCeremony).foregroundStyle(Tone.primary)
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Tone.secondary)
                        .frame(width: Shape2.minTouch, height: Shape2.minTouch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("홈으로")
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    /// lazy: false 는 스크롤 밖에서 통째로 그릴 때(테스트 덤프).
    @ViewBuilder
    func grid(_ months: [(month: String, days: [String])], lazy: Bool) -> some View {
        let body = ForEach(months, id: \.month) { m in
            VStack(alignment: .leading, spacing: 18) {
                Text(Self.monthTitle(m.month)).font(Face.caption).foregroundStyle(Tone.tertiary)
                LazyVGrid(columns: columns, spacing: 26) {
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
        .padding(.vertical, 24)
    }

    var monthsForPreview: [(month: String, days: [String])] { months }

    private func cell(_ key: String) -> some View {
        let moments = store.pebbleMoments(on: key)
        return Button {
            guard acceptsTaps else { return }
            opened = OpenedDay(id: key)
        } label: {
            VStack(spacing: 8) {
                PebbleView(moments: moments, height: 78, glow: .grid)
                    .frame(height: 96)
                if let named = PebbleNaming.name(for: moments) {
                    Text(named.name).font(Face.nameCompact).foregroundStyle(Tone.primary)
                }
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
