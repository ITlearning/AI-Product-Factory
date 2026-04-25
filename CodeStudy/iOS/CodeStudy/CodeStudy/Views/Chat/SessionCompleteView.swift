import SwiftUI
import SwiftData
import Photos

struct SessionCompleteView: View {
    let isMastered: Bool
    let session: StudySession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ConfigService.self) private var configService
    @Query private var profiles: [UserProfile]

    /// 사용자 설정 언어. UserProfile이 없으면 디바이스 locale fallback.
    private var language: AppLanguage {
        profiles.first?.language ?? .systemDefault
    }

    @State private var displayedStreak: Int = 0
    @State private var animateIcon = false
    /// Identifiable 래퍼를 담아 .sheet(item:)로 띄움.
    /// .sheet(isPresented:) + `if let shareImage` 패턴은 최초 body 빌드 시
    /// shareImage == nil로 sheet 내부가 EmptyView로 캐시되어 첫 탭에서 빈 시트가 뜸.
    @State private var sharePayload: SharePayload?
    @State private var saveAlert: SaveAlert?

    /// Set to `true` when the user dismisses this view after a mastery
    /// AND the survey has not yet been shown. The parent (`ChatView`)
    /// reads this flag in its `.sheet(onDismiss:)` to present the
    /// SurveyModalView right after this sheet closes.
    @State private var pendingSurvey: Bool = false
    @State private var showSurvey: Bool = false

    // Design tokens
    private let accentColor = Color.warmOrange
    private let deepBlue = Color.deepBlue

    // MARK: - Survey config
    //
    // 설문 URL은 `ConfigService`(서버 /api/config)에서 받아온다.
    // App Store 심사 없이 URL 변경/설문 토글 가능. 자세한 운영은
    // CodeStudy/SURVEY.md 참조.

    var body: some View {
        ZStack {
            VStack(spacing: 28) {
                Spacer()

                // Icon
                iconSection

                // Title & subtitle
                titleSection

                // Session summary
                summarySection

                // Streak counter
                streakSection

                Spacer()

                // Action buttons
                buttonSection
            }
            .padding(24)

            // Confetti — auto plays on sheet appear, no interaction needed
            if isMastered {
                ConfettiView(particleCount: 100, duration: 3.0)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .interactiveDismissDisabled(false)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
                animateIcon = true
            }
            animateStreakCounter()
        }
        // Survey gate: after a mastery, ask once for feedback. The sheet
        // dismisses → onDismiss decides whether to persist the
        // `surveyShown` flag (NOT for `.errorOffline` so the user gets
        // another shot next time).
        .sheet(isPresented: $showSurvey, onDismiss: {
            // Sheet has fully closed. Now pop back to home.
            dismiss()
        }) {
            // surveyURL은 handleHomeButton에서 nil 체크 후 진입하므로
            // 여기 도달했다면 항상 유효. 방어적으로 force-unwrap 회피.
            if let url = configService.current.surveyURL(for: language) {
                SurveyModalView(
                    surveyURL: url,
                    onDismiss: { reason in
                        handleSurveyDismiss(reason: reason)
                    }
                )
            } else {
                // Edge case: config가 fetch 사이에 빠짐. 즉시 dismiss하고
                // surveyShown은 set하지 않음 (다음 기회 보존).
                Color.clear.onAppear { showSurvey = false }
            }
        }
    }

    // MARK: - Home / Survey flow

    /// Decides whether to present the survey before dismissing back to
    /// home. Triggered iff: this is a mastery session AND the survey
    /// hasn't been shown yet.
    private func handleHomeButton() {
        let defaults = UserDefaults.standard
        let alreadyShown = defaults.bool(forKey: OneTimeMigration.surveyShownKey)
        // 설문 게이트: 마스터리 + 미노출 + 서버에서 enabled + 유효한 URL
        let config = configService.current
        let canShowSurvey = isMastered
            && !alreadyShown
            && config.surveyEnabled
            && config.surveyURL(for: language) != nil
        if canShowSurvey {
            pendingSurvey = true
            showSurvey = true
            return
        }
        dismiss()
    }

    /// Persist `surveyShown=true` only on resolved exits (.completed or
    /// .closed). Network errors leave the flag untouched so the user
    /// gets another chance after a future mastery.
    private func handleSurveyDismiss(reason: SurveyModalView.DismissReason) {
        switch reason {
        case .completed, .closed:
            UserDefaults.standard.set(true, forKey: OneTimeMigration.surveyShownKey)
        case .errorOffline:
            // Preserve flag — the user wasn't given a real chance.
            break
        }
        // Close the survey sheet. The sheet's onDismiss closure handles
        // the final pop back to home.
        showSurvey = false
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconSection: some View {
        if isMastered {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(accentColor)
                .scaleEffect(animateIcon ? 1.0 : 0.3)
                .opacity(animateIcon ? 1.0 : 0.0)
        } else {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(deepBlue)
                .scaleEffect(animateIcon ? 1.0 : 0.5)
                .opacity(animateIcon ? 1.0 : 0.0)
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(isMastered
                 ? String(localized: "complete.mastered.title", defaultValue: "이 개념을 마스터했어요!")
                 : String(localized: "complete.manual.title", defaultValue: "학습을 마쳤어요"))
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if !isMastered {
                Text(String(localized: "complete.manual.subtitle",
                            defaultValue: "마스터하려면 다시 도전해보세요"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.secondary)
                Text("\(session.turnCount)회 대화")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let duration = session.duration {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(formattedDuration(duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(spacing: 4) {
            Text(String(localized: "complete.streak.label", defaultValue: "연속 학습"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(accentColor)
                Text("\(displayedStreak)")
                    .font(.title.bold().monospacedDigit())
                    .contentTransition(.numericText())
                Text(String(localized: "complete.streak.days", defaultValue: "일"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: 12) {
            Button {
                handleHomeButton()
            } label: {
                Text(String(localized: "complete.home", defaultValue: "홈으로"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(deepBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // 이미지로 저장 — 한 탭으로 사진 앱에 바로 저장
            Button {
                handleSaveToPhotos()
            } label: {
                Label(
                    String(localized: "complete.saveImage", defaultValue: "이미지로 저장"),
                    systemImage: "square.and.arrow.down"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // 공유하기 — 인스타/카톡/기타 앱 전송
            Button {
                if let image = ShareCardRenderer.render(
                    conceptTitle: session.conceptTitle,
                    isMastered: isMastered,
                    streakCount: displayedStreak
                ) {
                    sharePayload = SharePayload(image: image)
                }
            } label: {
                Label(
                    String(localized: "complete.share", defaultValue: "공유하기"),
                    systemImage: "square.and.arrow.up"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(deepBlue)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(deepBlue, lineWidth: 1.5)
                )
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: [payload.image])
            }

            if !isMastered {
                Button {
                    dismiss()
                    // Parent view handles retry navigation
                } label: {
                    Text(String(localized: "complete.retry", defaultValue: "다시 도전"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(accentColor)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(accentColor, lineWidth: 1.5)
                        )
                }
            }
        }
        .alert(item: $saveAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(String(
                    localized: "common.ok",
                    defaultValue: "확인"
                )))
            )
        }
    }

    // MARK: - Save to Photos

    private func handleSaveToPhotos() {
        guard let image = ShareCardRenderer.render(
            conceptTitle: session.conceptTitle,
            isMastered: isMastered,
            streakCount: displayedStreak
        ) else {
            saveAlert = SaveAlert.failed
            return
        }
        Task {
            let status = await saveImageToPhotos(image)
            await MainActor.run {
                saveAlert = status
            }
        }
    }

    /// 사진 앱에 이미지 저장. addOnly 권한 → Info.plist에
    /// INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription 필수.
    private func saveImageToPhotos(_ image: UIImage) async -> SaveAlert {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return .permissionDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return .success
        } catch {
            return .failed
        }
    }

    // MARK: - Helpers

    private func animateStreakCounter() {
        let targetStreak = fetchCurrentStreak()
        guard targetStreak > 0 else {
            displayedStreak = 0
            return
        }

        // Count-up animation
        let stepDuration = 0.4 / Double(targetStreak)
        for i in 1...targetStreak {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.snappy) {
                    displayedStreak = i
                }
            }
        }
    }

    private func fetchCurrentStreak() -> Int {
        let descriptor = FetchDescriptor<DailyStreak>()
        let streaks = (try? modelContext.fetch(descriptor)) ?? []
        return streaks.first?.currentStreak ?? 0
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        }
        return "\(seconds)초"
    }
}

// MARK: - Share payload

/// UIImage를 Identifiable로 감싸 .sheet(item:)에 전달하기 위한 래퍼.
/// .sheet(isPresented:) + `if let image`는 첫 body 빌드에 EmptyView로 캐시되는
/// SwiftUI 버그가 있음 — .sheet(item:)로 해결.
struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Save alert

/// 이미지 저장 결과를 alert로 전달. Identifiable conformance는 case별 id로.
struct SaveAlert: Identifiable {
    let id: String
    let title: String
    let message: String

    static let success = SaveAlert(
        id: "success",
        title: String(localized: "save.success.title", defaultValue: "저장 완료"),
        message: String(localized: "save.success.message",
                        defaultValue: "사진 앱에 이미지를 저장했어요.")
    )

    static let failed = SaveAlert(
        id: "failed",
        title: String(localized: "save.failed.title", defaultValue: "저장 실패"),
        message: String(localized: "save.failed.message",
                        defaultValue: "이미지를 저장하지 못했어요. 잠시 후 다시 시도해주세요.")
    )

    static let permissionDenied = SaveAlert(
        id: "permissionDenied",
        title: String(localized: "save.permission.title", defaultValue: "사진 접근 권한 필요"),
        message: String(localized: "save.permission.message",
                        defaultValue: "설정 > CodeStudy에서 사진 접근을 허용해주세요.")
    )
}

// MARK: - UIActivityViewController Wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Mastered") {
    SessionCompleteView(
        isMastered: true,
        session: StudySession(conceptID: "optionals", conceptTitle: "옵셔널")
    )
}

#Preview("Manual") {
    SessionCompleteView(
        isMastered: false,
        session: StudySession(conceptID: "optionals", conceptTitle: "옵셔널")
    )
}
