import SafariServices
import SwiftUI
import UIKit

/// 홈 오른쪽 위 설정 — 조약돌 모양(고르면 그 자리에서 바뀐다)과 사진 앱 ♥ 담기.
struct SettingsSheet: View {
    /// 미리보기에 세울 하루 — 가장 최근에 받은 조약돌, 없으면 견본.
    let preview: [Moment]

    @Environment(\.dismiss) private var dismiss
    @AppStorage(PebbleStyle.key, store: PebbleStyle.store) private var style: PebbleStyle = .round
    @AppStorage(FavoriteAdopter.enabledKey) private var adoptsFavorites = true
    @AppStorage(PlaceFinder.enabledKey) private var recordsPlace = true
    /// 스위치는 설정값만이 아니라 실제 권한까지 — 켜진 채로 보이면 이미 허용한 줄 안다(2026-10-01 Tabber).
    @State private var placeAccess = PlaceFinder.shared.access
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(MomentReminder.key) private var reminder: MomentReminder.Frequency = .sometimes
    @AppStorage(Telemetry.enabledKey) private var sendsTelemetry = true
    @State private var hasUpdate = false
    @State private var showingLicenses = false
    @State private var showingSuggestion = false
    var store: DayStore? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
                links
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(Tone.base.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationBackground(Tone.base)
        .preferredColorScheme(.dark)
        .task { hasUpdate = await UpdateCheck.live.newerVersion(than: AppVersion.current.short) != nil }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("설정").font(Face.lineCeremony).foregroundStyle(Tone.primary)
                Spacer()
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
            .padding(.top, 20)

            Text("조약돌 모양").font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 28)
            HStack(spacing: 12) {
                option(.round, "둥근 돌")
                option(.classic, "반듯한 돌")
            }
            .padding(.top, 12)

            Text("사진 앱").font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 28)
            Toggle(isOn: $adoptsFavorites) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("♥ 누른 사진도 담기").font(Face.line).foregroundStyle(Tone.primary)
                    Text("오늘 찍고 사진 앱에서 하트를 누르면 몽돌에도 담겨요.")
                        .font(Face.caption).foregroundStyle(Tone.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Tone.primary.opacity(0.6))
            .padding(.top, 10)
            Toggle(isOn: Binding(get: { recordsPlace && placeAccess == .granted }, set: setRecordsPlace)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("찍은 곳 남기기").font(Face.line).foregroundStyle(Tone.primary)
                    Text(recordsPlace && placeAccess == .denied
                         ? "iOS 설정에서 몽돌의 위치를 허용해야 적혀요."
                         : "몽돌로 찍은 사진 옆에 동네 이름과 그때 날씨가 적혀요.")
                        .font(Face.caption).foregroundStyle(Tone.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Tone.primary.opacity(0.6))
            .padding(.top, 14)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { placeAccess = PlaceFinder.shared.access }
            }

            Text("사진이 없는 날 알림").font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 28)
            HStack(spacing: 8) {
                ForEach(MomentReminder.Frequency.allCases, id: \.self) { f in
                    let on = reminder == f
                    Button {
                        guard reminder != f else { return }
                        Haptics.tickPassed()
                        reminder = f
                        if let store { Task { await MomentReminder.sync(store: store) } }
                    } label: {
                        Text(f.title)
                            .font(Face.guide)
                            .foregroundStyle(on ? Tone.primary : Tone.secondary)
                            .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
                            .background(Capsule().fill(on ? Color.white.opacity(0.12) : .clear))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.top, 10)
            Text("아침과 노을 무렵에 가볍게. 담은 날은 오지 않아요.")
                .font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 8)

            Text("사용 기록").font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 28)
            Toggle(isOn: $sendsTelemetry) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("사용 기록 보내기").font(Face.line).foregroundStyle(Tone.primary)
                    Text("어디서 멈추는지 익명으로 보내요. 사진·단어·색·위치는 보내지 않아요.")
                        .font(Face.caption).foregroundStyle(Tone.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Tone.primary.opacity(0.6))
            .padding(.top, 10)
            .padding(.bottom, 24)
            .onChange(of: sendsTelemetry) { _, _ in Telemetry.apply() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: 0) {
            linkRow("리뷰 남기기", hint: "App Store 리뷰 쓰기 화면을 엽니다") {
                UIApplication.shared.open(UpdateCheck.reviewURL)
            }
            if SuggestionForm.url != nil {
                linkRow("건의하기", hint: "건의 페이지를 엽니다") { showingSuggestion = true }
            }
        }
        .padding(.bottom, 16)
        .sheet(isPresented: $showingSuggestion) {
            if let url = SuggestionForm.url { SafariSheet(url: url).ignoresSafeArea() }
        }
    }

    /// 맨 아래 고정 — 작은 화면에선 위 내용만 스크롤된다.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasUpdate {
                Button { UIApplication.shared.open(UpdateCheck.storeURL) } label: {
                    HStack(spacing: 6) {
                        Text("새 버전이 있어요").foregroundStyle(Tone.secondary)
                        Text("·").foregroundStyle(Tone.tertiary)
                        Text("업데이트").foregroundStyle(Tone.primary)
                    }
                    .font(Face.guide)
                    .frame(maxWidth: .infinity, minHeight: Shape2.minTouch, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("새 버전이 있어요. 업데이트")
            }
            Text(AppVersion.current.line)
                .font(Face.caption).foregroundStyle(Tone.tertiary)
            Text("단어는 이 기기 안에서 사진을 보고 고릅니다")
                .font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 4)
            Button { showingLicenses = true } label: {
                Text("단어 뜻풀이 · 국립국어원 표준국어대사전 (CC BY-SA 2.0 KR) · 이미지 모델 TinyCLIP (MIT)")
                    .font(Face.caption).foregroundStyle(Tone.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: Shape2.minTouch, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("출처와 라이선스 전문을 엽니다")
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showingLicenses) { LicensesSheet() }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tone.base)
    }

    private func linkRow(_ title: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Face.guide).foregroundStyle(Tone.secondary)
                .frame(maxWidth: .infinity, minHeight: Shape2.minTouch, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }

    private func option(_ s: PebbleStyle, _ title: String) -> some View {
        let on = style == s
        return Button {
            guard style != s else { return }
            Haptics.tickPassed()
            style = s
            AppIconStyle.apply(s)
        } label: {
            VStack(spacing: 10) {
                Group {
                    switch s {
                    case .round:
                        SoftPebbleView(moments: preview, height: 84 * Shape2.softDiameter, glow: .grid)
                    case .classic:
                        LegacyPebbleView(moments: preview, height: 84)
                    }
                }
                .frame(height: 110)
                Text(title).font(Face.guide).foregroundStyle(on ? Tone.primary : Tone.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: Shape2.cardFront, style: .continuous)
                .fill(.white.opacity(on ? 0.08 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: Shape2.cardFront, style: .continuous)
                .strokeBorder(on ? Tone.secondary : Tone.hairline, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: Shape2.cardFront, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    static let sample: [Moment] = {
        let base = Date(timeIntervalSince1970: 1_758_000_000)
        return ["#6A7EA0", "#9FBDDB", "#F4E6CF", "#F6C7A2", "#EC9383", "#B86676"].enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 1800),
                   colorHex: $0.element, fileName: "settings-\($0.offset).jpg", source: .app)
        }
    }()

    private func setRecordsPlace(_ on: Bool) {
        guard on else { recordsPlace = false; return }
        recordsPlace = true
        switch placeAccess {
        case .granted:
            break
        case .notAsked:
            Task {
                _ = await PlaceFinder.shared.requestIfNeeded()
                placeAccess = PlaceFinder.shared.access
            }
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
    }
}

/// 출처·라이선스 전문 — 저장소의 NOTICE 를 그대로 싣는다(project.yml 이 앱 번들에 넣는다).
struct LicensesSheet: View {
    @Environment(\.dismiss) private var dismiss

    static func text(in bundle: Bundle = .main) -> String? {
        bundle.url(forResource: "NOTICE", withExtension: nil).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("출처와 라이선스").font(Face.lineCeremony).foregroundStyle(Tone.primary)
                Spacer()
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
            .padding(.top, 20)
            .padding(.bottom, 16)
            ScrollView {
                Text(Self.text() ?? "")
                    .font(Face.caption).foregroundStyle(Tone.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 24)
        .background(Tone.base.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationBackground(Tone.base)
        .preferredColorScheme(.dark)
    }
}

/// 설정의 「건의하기」 — 구글 설문 주소가 생기면 address 한 줄만 채운다. 비어 있으면 줄이 숨는다.
enum SuggestionForm {
    static let address: String? = nil
    static var url: URL? { link(address) }

    static func link(_ address: String?) -> URL? {
        guard let address, let url = URL(string: address.trimmingCharacters(in: .whitespaces)),
              url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = .white
        vc.preferredBarTintColor = .black
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
