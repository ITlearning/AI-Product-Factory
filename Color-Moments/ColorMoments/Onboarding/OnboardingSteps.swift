import CloudKit
import SwiftUI
import UserNotifications

// MARK: 공용

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
        .padding(.horizontal, 28)
    }
}

struct OnboardingText: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Face.lineCeremony)
                .foregroundStyle(Tone.primary)
            if let detail {
                Text(detail)
                    .font(Face.line)
                    .foregroundStyle(Tone.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .lineSpacing(4)
    }
}

struct PrimaryAction: View {
    let title: String
    var enabled = true
    var working = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(working ? 0 : 1)
                if working { ProgressView().tint(Tone.base) }
            }
            .font(Face.lineCeremony)
            .foregroundStyle(Tone.base)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Tone.primary.opacity(enabled ? 1 : 0.4), in: Capsule())
        }
        .disabled(!enabled || working)
    }
}

struct SecondaryAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Face.line)
                .foregroundStyle(Tone.secondary)
                .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
        }
    }
}

// MARK: 1. 몽돌이 뭔지

struct IntroStep: View {
    let next: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    private static let sample: [Moment] = {
        let base = Date(timeIntervalSince1970: 1_758_000_000)
        return ["#E7B98A", "#9DB7CF", "#D98F7A"].enumerated().map { i, hex in
            Moment(capturedAt: base.addingTimeInterval(Double(i) * 9_000), colorHex: hex,
                   fileName: "onboarding-sample-\(i)", source: .app)
        }
    }()

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 20)
                Text("몽돌").font(Face.wordmark).foregroundStyle(Tone.primary)
                Spacer()
                PebbleView(moments: Self.sample, height: 150)
                    .frame(maxWidth: .infinity)
                    .offset(x: arrived || reduceMotion ? 0 : -260)
                    .rotationEffect(.degrees(arrived || reduceMotion ? 0 : -150))
                    .opacity(arrived ? 1 : 0)
                Spacer()
                OnboardingText(title: "찍을 때는 색을 숨겨 두고, 하루가 닫히면 그날의 색으로 빚은 조약돌이 도착해요.")
                Spacer().frame(height: 36)
            }
        } actions: {
            PrimaryAction(title: "다음", action: next)
        }
        .onAppear {
            let animation: Animation = reduceMotion ? .easeOut(duration: 0.6) : .easeOut(duration: 1.6)
            withAnimation(animation.delay(0.25)) { arrived = true }
        }
    }
}

// MARK: 2. 첫 조약돌 받아 보기

struct FirstPebbleStep: View {
    let model: FirstPebbleModel
    let store: DayStore
    let begin: (_ ask: Bool) async -> Void
    let receive: () async -> Void
    let pickManually: () -> Void
    let next: () -> Void

    @State private var asking = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        OnboardingPage {
            switch model.phase {
            case .ask:
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    DashedPebble(height: 110).frame(maxWidth: .infinity)
                    Spacer()
                    OnboardingText(title: "지난 두 주 사진으로 첫 조약돌을 받아 볼까요?",
                                   detail: "사진첩에서 풍경 사진 몇 장을 기기 안에서 골라 둘게요. 사진은 기기 밖으로 나가지 않아요.")
                    Spacer().frame(height: 36)
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
                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(model.suggestions) { s in
                            cell(s)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onScrollPhaseChange { _, phase in if phase.isScrolling { model.freeze() } }
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

    @ViewBuilder
    private func received(_ outcome: OnboardingFlow.ImportOutcome) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            switch outcome {
            case .gift(let day):
                PebbleView(moments: store.pebbleMoments(on: day), height: 130).frame(maxWidth: .infinity)
                Spacer()
                OnboardingText(title: "첫 조약돌을 받았어요", detail: "홈에서 언제든 다시 볼 수 있어요.")
            case .todayOnly:
                DashedPebble(height: 110).frame(maxWidth: .infinity)
                Spacer()
                OnboardingText(title: "오늘 사진이 담겼어요", detail: "오늘은 아직 진행 중이라, 하루가 닫히면 조약돌이 도착해요.")
            case .added, .nothing:
                Spacer()
                OnboardingText(title: "사진이 담겼어요")
            }
            Spacer().frame(height: 36)
        }
    }
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
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                OnboardingText(title: "사진을 담은 다음 날 아침, 조약돌이 도착하면 한 번 알려 드려요.",
                               detail: didAskArrivalNotice ? "알림은 설정에서 언제든 바꿀 수 있어요." : nil)
                Spacer().frame(height: 36)
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
                        if granted { await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts) }
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

/// 기존 사용자에게 한 번만 — 새 온보딩 전체 대신 아침 소식 한 장.
struct ArrivalAskOverlay: View {
    let store: DayStore
    let closures: DayClosures
    let gifts: GiftLog

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
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
    let next: () -> Void

    @State private var signedIn: Bool?
    @State private var receiving = false
    @State private var settle: Task<Void, Never>?

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Image(systemName: signedIn == false ? "icloud.slash" : "icloud")
                    .font(Face.wordmark)
                    .foregroundStyle(Tone.secondary)
                    .frame(maxWidth: .infinity)
                    .opacity(signedIn == nil ? 0 : 1)
                Spacer()
                OnboardingText(title: title, detail: detail)
                    .opacity(signedIn == nil && remoteDays == 0 ? 0 : 1)
                Spacer().frame(height: 36)
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
            return receiving ? "iCloud에서 \(remoteDays)개의 하루를 가져오는 중" : "iCloud에서 \(remoteDays)개의 하루를 가져왔어요"
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.clear, Tone.secondary], startPoint: .leading, endPoint: .trailing))
                        .frame(width: sweep ? 150 : 0, height: 3)
                    Circle()
                        .fill(Tone.primary)
                        .frame(width: 22, height: 22)
                        .offset(x: sweep ? 139 : -11)
                }
                .opacity(sweep && !reduceMotion ? 0 : 1)
                .frame(height: 22)
                Spacer()
                VStack(alignment: .leading, spacing: 22) {
                    OnboardingText(title: "홈에서 왼쪽 가장자리를 오른쪽으로 쓸면 카메라가 열려요")
                    OnboardingText(title: "잠금화면에서도 찍을 수 있어요",
                                   detail: "잠금화면 카메라 컨트롤에서 몽돌을 고르면 돼요.")
                }
                Spacer().frame(height: 36)
            }
        } actions: {
            PrimaryAction(title: "다음", action: next)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.3).delay(0.3).repeatForever(autoreverses: false)) { sweep = true }
        }
    }
}

// MARK: 6. 시작하기

struct StartStep: View {
    let ready: Bool
    let onCamera: () -> Void
    let onStart: () -> Void

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text("몽돌").font(Face.wordmark).foregroundStyle(Tone.primary)
                Spacer().frame(height: 14)
                OnboardingText(title: "준비됐어요", detail: "오늘 담은 것은 자정에 조약돌이 돼요.")
                Spacer().frame(height: 36)
            }
        } actions: {
            PrimaryAction(title: "지금 한 장 남겨보기", working: !ready, action: onCamera)
            SecondaryAction(title: "시작하기", action: onStart)
                .disabled(!ready)
                .opacity(ready ? 1 : 0.5)
        }
    }
}
