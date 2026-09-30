import CloudKit
import SwiftUI
import UserNotifications

// MARK: 공용

enum OnboardingLayout {
    /// 페이지 좌우 여백 — 사진 격자는 스크롤 뷰를 이 밖으로 꺼낸다.
    static let margin: CGFloat = 28
    /// 사진 고르기 격자의 좌우 여백·칸 사이 — 한 칸이 (폭 − 여백×2 − 사이×2) / 3 로 크게 잡히게 페이지 여백보다 좁다.
    static let gridMargin: CGFloat = 12
    static let gridSpacing: CGFloat = 4
}

struct OnboardingPage<Content: View, Actions: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(spacing: 6) { actions }
                .padding(.bottom, 24)
        }
        .padding(.horizontal, OnboardingLayout.margin)
    }
}

struct OnboardingText: View {
    let title: String
    var detail: String?

    @Environment(\.onboardingInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Face.lineCeremony)
                .foregroundStyle(ink.primary)
            if let detail {
                Text(detail)
                    .font(Face.line)
                    .foregroundStyle(ink.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .lineSpacing(4)
    }
}

/// 사진이 없는 날의 알림 빈도 — 도착 소식 장에서 같이 고른다. 기본 가끔.
struct ReminderChoice: View {
    @AppStorage(MomentReminder.key) private var frequency: MomentReminder.Frequency = .sometimes
    @Environment(\.onboardingInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(MomentReminder.Frequency.allCases, id: \.self) { f in
                    let on = frequency == f
                    Button {
                        guard frequency != f else { return }
                        Haptics.tickPassed()
                        frequency = f
                    } label: {
                        Text(f.title)
                            .font(Face.guide)
                            .foregroundStyle(on ? ink.primary : ink.secondary)
                            .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
                            .background(Capsule().fill(on ? ink.hairline : .clear))
                            .overlay(Capsule().strokeBorder(ink.hairline, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// 사진이 없는 날 알림 — 고르고 「다음」을 누를 때, 알림을 받기로 했는데 아직 권한을 안 물었으면 그때 묻는다.
struct ReminderStep: View {
    let store: DayStore
    /// 바로 앞이 조약돌 도착 알림 장이면 「그리고」로 이어 읽힌다 — 알림 권한을 이미 정한 기기에선 그 장이 빠진다.
    var followsArrival = false
    let next: () -> Void

    @AppStorage(MomentReminder.key) private var frequency: MomentReminder.Frequency = .sometimes
    @State private var asking = false

    var body: some View {
        OnboardingPage {
            SceneLayout {
                ReminderScene()
            } words: {
                VStack(alignment: .leading, spacing: 18) {
                    OnboardingText(title: (followsArrival ? "그리고 사진이 없는 날엔" : "사진이 없는 날엔")
                                   + " 아침과 노을 무렵에 가볍게 알려 드릴게요.",
                                   detail: "한 장이라도 담은 날은 오지 않아요. 설정에서 언제든 바꿀 수 있어요.")
                    ReminderChoice()
                }
            }
        } actions: {
            PrimaryAction(title: "다음", working: asking) {
                asking = true
                Task {
                    if frequency != .off, await ArrivalNotice.permission() == .notDetermined {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    }
                    await MomentReminder.sync(store: store)
                    asking = false
                    next()
                }
            }
        }
    }
}

/// 조약돌 모양 고르기 — 첫 화면(모두가 지나가는 유일한 화면)에 둔다. 누르면 위 장면의 조약돌이 그 자리에서 바뀐다.
struct PebbleStyleChoice: View {
    @AppStorage(PebbleStyle.key, store: PebbleStyle.store) private var style: PebbleStyle = .round
    @Environment(\.onboardingInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                chip(.round, "둥근 돌")
                chip(.classic, "반듯한 돌")
            }
            Text("설정에서 언제든 바꿀 수 있어요").font(Face.caption).foregroundStyle(ink.secondary)
        }
    }

    private func chip(_ s: PebbleStyle, _ title: String) -> some View {
        let on = style == s
        return Button {
            guard style != s else { return }
            Haptics.tickPassed()
            style = s
        } label: {
            Text(title)
                .font(Face.guide)
                .foregroundStyle(on ? ink.primary : ink.secondary)
                .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
                .background(Capsule().fill(on ? ink.hairline : .clear))
                .overlay(Capsule().strokeBorder(ink.hairline, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct PrimaryAction: View {
    let title: String
    var enabled = true
    var working = false
    let action: () -> Void

    @Environment(\.onboardingInk) private var ink

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(working ? 0 : 1)
                if working { ProgressView().tint(ink.buttonText) }
            }
            .font(Face.actionCeremony)
            .foregroundStyle(ink.buttonText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(ink.buttonFill.opacity(enabled ? 1 : 0.4), in: Capsule())
        }
        .disabled(!enabled || working)
    }
}

struct SecondaryAction: View {
    let title: String
    let action: () -> Void

    @Environment(\.onboardingInk) private var ink

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Face.actionSecondary)
                .foregroundStyle(ink.secondary)
                .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
        }
    }
}

// MARK: 1. 몽돌이 뭔지

struct IntroStep: View {
    let next: () -> Void

    private static let sample: [Moment] = {
        let base = Date(timeIntervalSince1970: 1_758_000_000)
        return ["#E7B98A", "#9DB7CF", "#D98F7A"].enumerated().map { i, hex in
            Moment(capturedAt: base.addingTimeInterval(Double(i) * 9_000), colorHex: hex,
                   fileName: "onboarding-sample-\(i)", source: .app)
        }
    }()

    var body: some View {
        OnboardingPage {
            SceneLayout {
                VStack(alignment: .leading, spacing: 0) {
                    Text("몽돌").font(Face.wordmark).foregroundStyle(Tone.primary)
                        .padding(.top, 20)
                    IntroScene(moments: Self.sample)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } words: {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingText(title: "찍을 때는 색을 숨겨 두고, 하루가 닫히면 그날의 색으로 빚은 조약돌이 도착해요.")
                    PebbleStyleChoice()
                }
            }
        } actions: {
            PrimaryAction(title: "다음", action: next)
        }
    }
}

// MARK: 2. 첫 조약돌 받아 보기

struct FirstPebbleStep: View {
    let model: FirstPebbleModel
    let store: DayStore
    let result: ReceivedResult
    let begin: (_ ask: Bool) async -> Void
    let receive: () async -> Void
    let pickManually: () -> Void
    let next: () -> Void

    @State private var asking = false
    @Environment(\.onboardingInk) private var ink

    private let columns = Array(repeating: GridItem(.flexible(), spacing: OnboardingLayout.gridSpacing), count: 3)

    var body: some View {
        OnboardingPage {
            switch model.phase {
            case .ask:
                SceneLayout {
                    DashedPebble(height: 120).breathing()
                } words: {
                    OnboardingText(title: "지난 두 주 사진으로 첫 조약돌을 받아 볼까요?",
                                   detail: "사진첩에서 풍경 사진 몇 장을 기기 안에서 골라 둘게요. 사진은 기기 밖으로 나가지 않아요.")
                }
            case .suggesting, .importing:
                suggestionGrid
            case .received(let outcome):
                received(outcome)
            }
        } actions: {
            actions
        }
        // 이미 허락한 사람에게는 이유를 다시 묻지 않고 바로 고른다.
        .task { if model.phase == .ask, FirstPebbleModel.access != .notDetermined { await begin(false) } }
    }

    @ViewBuilder
    private var actions: some View {
        switch model.phase {
        case .ask:
            PrimaryAction(title: "사진 보기", working: asking) {
                asking = true
                Task { await begin(true); asking = false }
            }
        case .suggesting, .importing:
            if model.selected.isEmpty {
                PrimaryAction(title: "다음", action: next)
            } else {
                PrimaryAction(title: "이 사진으로 받기", working: model.phase == .importing) {
                    Task { await receive() }
                }
            }
            SecondaryAction(title: "직접 고르기", action: pickManually)
                .disabled(model.phase == .importing)
        case .received:
            PrimaryAction(title: "다음", action: next)
        }
    }

    private var suggestionGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("마음에 드는 사진을 골라 주세요")
                    .font(Face.lineCeremony).foregroundStyle(Tone.primary)
                if model.scanning { ProgressView().controlSize(.small).tint(Tone.tertiary) }
            }
            if model.suggestions.isEmpty {
                Text(model.scanning ? "사진을 살펴보는 중이에요" : "골라 둘 만한 사진을 찾지 못했어요. 직접 골라도 돼요.")
                    .font(Face.line).foregroundStyle(Tone.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: OnboardingLayout.gridSpacing) {
                        ForEach(model.suggestions) { s in
                            cell(s)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                }
                // 여백은 스크롤 안쪽(콘텐츠)에만 — 스크롤 뷰 자체에 padding 을 주면 그 선에서 사진이 잘려 보인다.
                .contentMargins(.top, 20, for: .scrollContent)
                .contentMargins(.bottom, 36, for: .scrollContent)
                .contentMargins(.horizontal, OnboardingLayout.gridMargin, for: .scrollContent)
                .scrollIndicators(.hidden)
                // 스크롤 가장자리에서 사진이 칼같이 잘리지 않고 배경으로 스며들게.
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 14)
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 48)
                    }
                }
                // 스크롤 뷰는 페이지 좌우 여백 밖으로 — 화면 양옆에 붙이고 사진 자리는 contentMargins 가 맞춘다.
                .padding(.horizontal, -OnboardingLayout.margin)
                .overlay {
                    if model.phase == .importing {
                        ZStack {
                            Tone.base.opacity(0.72)
                                .padding(.horizontal, -OnboardingLayout.margin)
                            ImportProgressNote(progress: model.importProgress, ink: ink.primary, subInk: ink.secondary)
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: model.phase == .importing)
            }
        }
        .padding(.top, 12)
        .disabled(model.phase == .importing)
    }

    private func cell(_ s: PhotoSuggester.Suggestion) -> some View {
        let on = model.selected.contains(s.id)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(uiImage: s.image).resizable().scaledToFill()
            }
            .clipped()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .strokeBorder(Tone.primary, lineWidth: 1.5)
                    .background(Circle().fill(on ? Tone.primary : .clear))
                    .overlay { if on { Image(systemName: "checkmark").font(Face.caption).foregroundStyle(Tone.base) } }
                    .frame(width: 22, height: 22)
                    .padding(6)
            }
            .opacity(on || model.selected.isEmpty ? 1 : 0.72)
            .contentShape(Rectangle())
            .onTapGesture { model.toggle(s.id) }
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func received(_ outcome: OnboardingFlow.ImportOutcome) -> some View {
        let copy = ReceivedCopy.text(outcome, addedCount: result.photos.count, dayGifted: result.dayGifted)
        return SceneLayout {
            ReceivedScene(outcome: outcome, pebble: result.pebble, photos: result.photos)
        } words: {
            OnboardingText(title: copy.title, detail: copy.detail)
        }
    }
}

/// 방금 담은 것 — 결과 장면에 쓸 사진과, 색을 보여도 되는 조약돌.
struct ReceivedResult {
    var photos: [Moment] = []
    var pebble: [Moment] = []
    var dayGifted = false
}

// MARK: 3. 아침 도착 소식

struct ArrivalStep: View {
    let store: DayStore
    let closures: DayClosures
    let gifts: GiftLog
    let answered: () -> Void

    @AppStorage("didAskArrivalNotice") private var didAskArrivalNotice = false
    @State private var asking = false

    var body: some View {
        OnboardingPage {
            SceneLayout {
                ArrivalScene()
            } words: {
                OnboardingText(title: "사진을 담은 다음 날 아침, 조약돌이 도착하면 한 번 알려 드려요.",
                               detail: didAskArrivalNotice ? "알림은 설정에서 언제든 바꿀 수 있어요." : nil)
            }
        } actions: {
            if didAskArrivalNotice {
                PrimaryAction(title: "다음", action: answered)
            } else {
                PrimaryAction(title: "알려 주세요", working: asking) {
                    asking = true
                    Task {
                        let granted = (try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound])) ?? false
                        didAskArrivalNotice = true
                        asking = false
                        answered()
                        if granted {
                            await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts)
                            await MomentReminder.sync(store: store)
                        }
                    }
                }
                SecondaryAction(title: "괜찮아요") {
                    didAskArrivalNotice = true
                    answered()
                }
            }
        }
    }
}

/// 찍은 곳·날씨 — 허용하면 사진 보기에 무엇이 붙는지 장면으로 먼저 보여 주고 묻는다.
/// 「괜찮아요」면 설정의 「찍은 곳 남기기」도 꺼 둔다(켜진 채로 보이면 이미 허용한 줄 안다).
struct PlaceStep: View {
    let answered: () -> Void

    @AppStorage(PlaceFinder.enabledKey) private var recordsPlace = true
    @State private var asking = false

    var body: some View {
        OnboardingPage {
            SceneLayout {
                PlaceScene()
            } words: {
                OnboardingText(title: "사진 옆에 찍은 곳과 그때 날씨를 적어 둘게요.",
                               detail: "위치는 동네 이름과 날씨를 찾는 데만 써요.")
            }
        } actions: {
            PrimaryAction(title: "적어 주세요", working: asking) {
                asking = true
                Task {
                    recordsPlace = true
                    _ = await PlaceFinder.shared.requestIfNeeded()
                    asking = false
                    answered()
                }
            }
            SecondaryAction(title: "괜찮아요") {
                recordsPlace = false
                answered()
            }
        }
    }
}

/// 기존 사용자에게 한 번만 — 새 온보딩 전체 대신 아침 소식 한 장.
struct ArrivalAskOverlay: View {
    let store: DayStore
    let closures: DayClosures
    let gifts: GiftLog

    var body: some View {
        ZStack {
            SceneBackdrop(hexes: BackdropPalette.sourceHexes(store: store, gifts: gifts))
            VStack(spacing: 0) {
                Spacer().frame(height: 52)
                ArrivalStep(store: store, closures: closures, gifts: gifts, answered: {})
            }
        }
    }
}

// MARK: 4. iCloud

struct CloudStep: View {
    let remoteDays: Int
    let dayCount: Int
    let actionTitle: String
    /// 이어 온 사람 — 누르면 사진 권한을 물으니 무엇을 물을지 먼저 한 줄로.
    var asksPhotos = false
    let next: () -> Void

    @State private var signedIn: Bool?
    @State private var receiving = false
    @State private var settle: Task<Void, Never>?

    var body: some View {
        OnboardingPage {
            SceneLayout {
                CloudScene(linked: remoteDays > 0 || signedIn == true, receiving: receiving, remoteDays: remoteDays)
                    .opacity(signedIn == nil && remoteDays == 0 ? 0 : 1)
                    .animation(.easeOut(duration: 0.4), value: signedIn)
            } words: {
                OnboardingText(title: title, detail: detail)
                    .opacity(signedIn == nil && remoteDays == 0 ? 0 : 1)
            }
        } actions: {
            PrimaryAction(title: actionTitle, action: next)
        }
        .task { signedIn = await Self.accountAvailable() }
        .onChange(of: dayCount) { _, _ in
            receiving = true
            settle?.cancel()
            settle = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                receiving = false
            }
        }
    }

    private var title: String {
        if remoteDays > 0 || signedIn == true { return "기록이 iCloud로 다른 기기와 이어져요" }
        return "지금은 이 기기에만 남아요"
    }

    private var detail: String? {
        if remoteDays > 0 {
            let got = receiving ? "iCloud에서 \(remoteDays)개의 하루를 가져오는 중" : "iCloud에서 \(remoteDays)개의 하루를 가져왔어요"
            return asksPhotos ? got + ". 사진은 이 기기 사진첩에서 다시 불러와요." : got
        }
        return signedIn == false ? "설정 › iCloud에서 켤 수 있어요" : nil
    }

    private static func accountAvailable() async -> Bool {
        // 유닛 테스트 호스트에선 CKContainer 가 권한 없이 크래시한다.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return false }
        let status = try? await CKContainer(identifier: CloudSync.containerID).accountStatus()
        return status == .available
    }
}

// MARK: 5. 찍는 법

struct HowToStep: View {
    let next: () -> Void

    var body: some View {
        OnboardingPage {
            SceneLayout {
                HowToScene()
            } words: {
                VStack(alignment: .leading, spacing: 22) {
                    OnboardingText(title: "홈에서 왼쪽 가장자리를 오른쪽으로 쓸면 카메라가 열려요")
                    OnboardingText(title: "잠금화면에서도 찍을 수 있어요",
                                   detail: "잠금화면 카메라 컨트롤에서 몽돌을 고르면 돼요.")
                }
            }
        } actions: {
            PrimaryAction(title: "다음", action: next)
        }
    }
}

// MARK: 5-1. 카메라 컨트롤 — 그 버튼이 있는 기기만

struct CameraButtonStep: View {
    let next: () -> Void

    var body: some View {
        OnboardingPage {
            SceneLayout {
                CameraButtonScene()
            } words: {
                OnboardingText(title: "옆면 카메라 컨트롤로 바로 몽돌을 열 수 있어요",
                               detail: "설정 → 카메라 → 카메라 컨트롤에서 몽돌을 고르면 돼요.")
            }
        } actions: {
            PrimaryAction(title: "다음", action: next)
        }
    }
}

// MARK: 6. 모은 조약돌

struct CollectionStep: View {
    let next: () -> Void

    var body: some View {
        OnboardingPage {
            SceneLayout {
                CollectionScene()
            } words: {
                OnboardingText(title: "오른쪽 가장자리를 왼쪽으로 쓸면 받은 조약돌을 모아 볼 수 있어요")
            }
        } actions: {
            PrimaryAction(title: "다음", action: next)
        }
    }
}

// MARK: 7. 시작하기

struct StartStep: View {
    let pebble: [Moment]
    /// 이번 온보딩에서 증정까지 받은 하루 — 있으면 방금 받은 조약돌로 먼저 보낸다. 사진을 담은 사람에게 촬영부터 권하지 않는다.
    let receivedDay: String?
    let ready: Bool
    let onCamera: () -> Void
    let onStart: () -> Void
    let onOpenDay: (String) -> Void

    var body: some View {
        OnboardingPage {
            SceneLayout {
                StartScene(pebble: pebble)
            } words: {
                if receivedDay != nil {
                    OnboardingText(title: "준비됐어요", detail: "방금 받은 조약돌이 홈에서 기다려요.")
                } else {
                    OnboardingText(title: "준비됐어요", detail: "오늘 담은 것은 자정에 조약돌이 돼요.")
                }
            }
        } actions: {
            if let day = receivedDay {
                PrimaryAction(title: "내 조약돌 보러 가기", working: !ready) { onOpenDay(day) }
                SecondaryAction(title: "지금 한 장 남겨보기", action: onCamera)
                    .disabled(!ready)
                    .opacity(ready ? 1 : 0.5)
            } else {
                PrimaryAction(title: "지금 한 장 남겨보기", working: !ready, action: onCamera)
                SecondaryAction(title: "시작하기", action: onStart)
                    .disabled(!ready)
                    .opacity(ready ? 1 : 0.5)
            }
        }
    }
}
