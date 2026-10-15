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
    var meaningShown = false

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
        meaningShown = false
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

    var body: some View {
        OnboardingPage {
            SceneLayout {
                scene
            } words: {
                words
            }
        } actions: {
            switch model.phase {
            case .ask:
                PrimaryAction(title: "말 받기") {
                    withAnimation(.easeInOut(duration: 0.35)) { if !model.reveal() { next() } }
                }
                SecondaryAction(title: "건너뛰기", action: next)
            case .shown:
                PrimaryAction(title: "주운 말에 담기") {
                    withAnimation(.easeInOut(duration: 0.35)) { if !model.keep() { next() } }
                }
            case .kept:
                PrimaryAction(title: "다음", action: next)
            }
        }
    }

    @ViewBuilder
    private var scene: some View {
        switch model.phase {
        case .ask:
            BirthdayWheel(model: model)
        case .shown(let pick), .kept(let pick):
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { model.meaningShown.toggle() }
            } label: {
                VStack(spacing: 14) {
                    Text("\(model.month)월 \(model.day)일")
                        .font(Face.caption).foregroundStyle(ink.secondary)
                    Text(pick.word)
                        .font(Face.nameCeremony).foregroundStyle(ink.primary)
                    Text(model.meaningShown ? pick.meaning : "눌러서 뜻 보기")
                        .font(model.meaningShown ? Face.line : Face.caption)
                        .foregroundStyle(ink.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.meaningShown ? "\(pick.word). \(pick.meaning)" : pick.word)
            .accessibilityHint(model.meaningShown ? "" : "눌러서 뜻 보기")
        }
    }

    @ViewBuilder
    private var words: some View {
        switch model.phase {
        case .ask:
            OnboardingText(title: "태어난 날의 말",
                           detail: "생일을 알려 주면 그날의 말을 첫 「주운 말」로 드려요. 생일은 이 기기 밖으로 나가지 않아요.")
        case .shown:
            OnboardingText(title: "태어난 날의 말이에요")
        case .kept:
            OnboardingText(title: "주웠어요", detail: "주운 말에 첫 말로 담았어요.")
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
