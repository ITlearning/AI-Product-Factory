import Observation
import SwiftUI
import WidgetKit

// MARK: 생일 말

/// 생일 말 장의 상태 — 앞뒤로 넘겨도 이어지도록 온보딩 화면이 들고 있다. 생일은 고르는 데만 쓰고 어디에도 적지 않는다.
@MainActor
@Observable
final class BirthdayWordModel {

    enum Phase: Equatable {
        case ask
        case shown(BirthdayPick)
        case kept(BirthdayPick)
    }

    private(set) var phase = Phase.ask
    var month: Int
    var day: Int
    /// 굴림 동안 스쳐 갈 말 — 같은 달 말에서, 고른 말은 빼고.
    private(set) var passing: [String] = []

    @ObservationIgnored private let picks: () -> PickedWords?
    @ObservationIgnored private let seed: () -> String
    @ObservationIgnored private let words: () -> [BirthdayWord]?

    init(now: Date = Date(),
         picks: @escaping () -> PickedWords? = { PickedWords(writer: .app) },
         seed: @escaping () -> String = { BirthdayWords.installSeed() },
         words: @escaping () -> [BirthdayWord]? = { BirthdayWords.load() }) {
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: now)
        month = c.month ?? 1
        day = c.day ?? 1
        self.picks = picks
        self.seed = seed
        self.words = words
    }

    var pickedWord: String? {
        switch phase {
        case .ask: nil
        case .shown(let p), .kept(let p): p.word
        }
    }

    var isKept: Bool { if case .kept = phase { true } else { false } }

    static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    static func days(in month: Int) -> Int { daysInMonth[max(1, min(12, month)) - 1] }

    func setMonth(_ m: Int) {
        month = m
        day = min(day, Self.days(in: m))
    }

    /// 고를 말이 없으면(목록을 못 읽음) false — 그땐 조용히 다음 장으로.
    func reveal() -> Bool {
        guard case .ask = phase, let list = words(),
              let pick = BirthdayWords.pick(list, seed: seed(), month: month, day: day) else { return false }
        let pool = list.filter { $0.months.contains(month) && $0.w != pick.word }.map(\.w)
        passing = Array((pool.isEmpty ? list.map(\.w).filter { $0 != pick.word } : pool).shuffled().prefix(BirthdayReveal.ticks.count))
        phase = .shown(pick)
        return true
    }

    /// 디스크에 닿았을 때만 true — 던지면 「주웠어요」를 보이지 않는다.
    func keep(at: Date = Date()) -> Bool {
        guard case .shown(let pick) = phase, let picks = picks() else { return false }
        do {
            let line = try picks.pick(pick.word, meaning: pick.meaning, source: .birthday, at: at)
            if let event = Telemetry.WordPick(line) { Telemetry.send(.wordPicked(event)) }
        } catch {
            return false
        }
        phase = .kept(pick)
        return true
    }
}

struct BirthdayStep: View {
    let model: BirthdayWordModel
    let next: () -> Void

    @Environment(\.onboardingInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 「말 받기」를 누른 때 — 앞뒤로 넘겨 다시 온 장에선 nil 이라 연출 없이 다 보인 채로.
    @State private var revealedAt: Date?
    @State private var land = BirthdayReveal.land
    @State private var keptAt: Date?
    @State private var moving = false
    @State private var buzz: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(paused: !moving)) { context in
            let t = revealedAt.map { context.date.timeIntervalSince($0) } ?? 60
            let fold = keptAt.map { context.date.timeIntervalSince($0) } ?? (model.isKept ? 60 : nil)
            page(t: t, fold: fold)
        }
        .onDisappear { buzz?.cancel() }
    }

    private func page(t: Double, fold: Double?) -> some View {
        OnboardingPage {
            SceneLayout {
                scene(t: t, fold: fold)
            } words: {
                words(t: t, fold: fold)
            }
        } actions: {
            switch model.phase {
            case .ask:
                PrimaryAction(title: "말 받기", action: reveal)
                SecondaryAction(title: "건너뛰기", action: next)
            case .shown:
                let shown = BirthdayRevealFollow.shown(t: t, land: land, still: reduceMotion)
                PrimaryAction(title: "주운 말에 담기", action: keep)
                    .opacity(shown)
                    .offset(y: 14 * (1 - shown))
                    .allowsHitTesting(shown > 0.5)
            case .kept:
                let shown = BirthdayRevealFollow.kept(fold: fold ?? 60, still: reduceMotion)
                PrimaryAction(title: "다음", action: next)
                    .opacity(shown)
                    .allowsHitTesting(shown > 0.5)
            }
        }
    }

    @ViewBuilder
    private func scene(t: Double, fold: Double?) -> some View {
        switch model.phase {
        case .ask:
            BirthdayWheel(model: model)
        case .shown(let pick), .kept(let pick):
            BirthdayRevealScene(pick: pick, month: model.month, day: model.day, passing: model.passing,
                                t: t, land: land, fold: fold, still: reduceMotion)
                .contentShape(Rectangle())
                // 굴리는 동안 누르면 바로 멈춘다(웹과 같이).
                .onTapGesture { if BirthdayReveal.tick(at: t, land: land) != nil, !reduceMotion { landNow(t) } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(model.month)월 \(model.day)일의 말, \(pick.word). \(pick.meaning)")
        }
    }

    @ViewBuilder
    private func words(t: Double, fold: Double?) -> some View {
        switch model.phase {
        case .ask:
            OnboardingText(title: "태어난 날의 말",
                           detail: "생일을 알려 주면 그날의 말을 첫 「주운 말」로 드려요. 생일은 이 기기 밖으로 나가지 않아요.")
        case .shown:
            let shown = BirthdayRevealFollow.shown(t: t, land: land, still: reduceMotion)
            OnboardingText(title: "태어난 날의 말이에요")
                .opacity(shown)
                .offset(y: 14 * (1 - shown))
        case .kept:
            let shown = BirthdayRevealFollow.kept(fold: fold ?? 60, still: reduceMotion)
            OnboardingText(title: "주웠어요", detail: "주운 말에 첫 말로 담았어요.")
                .opacity(shown)
                .offset(y: reduceMotion ? 0 : 10 * (1 - shown))
        }
    }

    private func reveal() {
        Haptics.prepare()
        guard model.reveal() else { return next() }
        revealedAt = Date()
        land = BirthdayReveal.land
        play(for: BirthdayReveal.settled(wordLength: model.pickedWord?.count ?? 0, land: land))
        buzz?.cancel()
        let at = reduceMotion ? 0.3 : land
        buzz = Task { @MainActor in
            try? await Task.sleep(for: .seconds(at))
            guard !Task.isCancelled else { return }
            Haptics.snapped()
        }
    }

    private func landNow(_ t: Double) {
        buzz?.cancel()
        land = t
        Haptics.snapped()
        play(for: BirthdayReveal.settled(wordLength: model.pickedWord?.count ?? 0, land: land) - t)
    }

    private func keep() {
        // 디스크에 닿은 뒤에만 접는다 — 실패하면 받았다고 하지 않고 다음 장으로.
        guard model.keep() else { return next() }
        keptAt = Date()
        play(for: BirthdayReveal.keptWordsAt + 0.7)
    }

    @State private var stopper: Task<Void, Never>?

    private func play(for seconds: Double) {
        moving = true
        stopper?.cancel()
        stopper = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0, seconds) + 0.1))
            guard !Task.isCancelled else { return }
            moving = false
        }
    }
}

/// 달·날 바퀴 두 개 — 해는 묻지 않는다.
private struct BirthdayWheel: View {
    @Bindable var model: BirthdayWordModel

    var body: some View {
        HStack(spacing: 0) {
            Picker("달", selection: Binding(get: { model.month }, set: { model.setMonth($0) })) {
                ForEach(1...12, id: \.self) { Text("\($0)월").font(Face.lineCeremony).tag($0) }
            }
            Picker("날", selection: $model.day) {
                ForEach(1...BirthdayWordModel.days(in: model.month), id: \.self) { Text("\($0)일").font(Face.lineCeremony).tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: 260, maxHeight: 180)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: 위젯 붙이기 — OnboardingFlow.showsWidgetStep 이 켜졌을 때만

struct WidgetStep: View {
    let next: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var attached = false
    @State private var leftApp = false

    var body: some View {
        OnboardingPage {
            SceneLayout {
                Color.clear
            } words: {
                VStack(alignment: .leading, spacing: 14) {
                    OnboardingText(title: attached ? "붙었어요" : "이제 홈 화면에서 지금 밖에 맞는 말을 알려 줄게요",
                                   detail: attached ? nil : "홈 화면을 길게 눌러 이 순서로 몽돌을 골라 주세요.")
                    if !attached {
                        SettingsPath(steps: ["편집", "위젯 추가", "몽돌"])
                    }
                }
            }
        } actions: {
            PrimaryAction(title: "다음", action: next)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { leftApp = true }
            guard phase == .active, leftApp, !attached else { return }
            Task { @MainActor in
                let kinds = (try? await WidgetCenter.shared.currentConfigurations())?.map(\.kind) ?? []
                if WidgetAttach.attached(kinds: kinds) { withAnimation(.easeInOut(duration: 0.35)) { attached = true } }
            }
        }
    }
}

enum WidgetAttach {
    static func attached(kinds: [String], wanted: Set<String> = OnboardingFlow.wordWidgetKinds) -> Bool {
        kinds.contains { wanted.contains($0) }
    }
}

// MARK: 업데이트 안내

/// 1.2로 업데이트한 사람에게 한 번 — 처음 본 장 목록을 붙잡고, 한 장 넘길 때마다 본 것으로 적는다.
struct UpdateNoticeOverlay: View {
    let store: DayStore
    let gifts: GiftLog

    @State private var pages = UpdateNotice.pages()
    @State private var index = 0
    @State private var birthday = BirthdayWordModel()

    var body: some View {
        ZStack {
            SceneBackdrop(hexes: BackdropPalette.sourceHexes(store: store, gifts: gifts))
            VStack(spacing: 0) {
                Spacer().frame(height: 52)
                if index < pages.count {
                    Group {
                        switch pages[index] {
                        case .birthday: BirthdayStep(model: birthday, next: advance)
                        case .widget: WidgetStep(next: advance)
                        }
                    }
                    .id(index)
                    .transition(.opacity)
                }
            }
        }
    }

    private func advance() {
        guard index < pages.count else { return }
        UpdateNotice.markOffered(pages[index])
        withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
    }
}
