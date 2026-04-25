import SwiftUI

/// Two-state .sheet shown after a user masters their first concept,
/// asking for voluntary feedback via a Google Forms WebView.
///
/// Lane C wires up the trigger (UserDefaults `surveyShown` flag) and
/// injects the Forms URL. This view is presentation-only — it does not
/// own persistence. The `onDismiss` callback communicates which exit
/// branch the user took so the caller can decide whether to set the
/// `surveyShown` flag (NOT set in the `.errorOffline` case so the user
/// gets another chance later).
struct SurveyModalView: View {

    // MARK: - DismissReason

    enum DismissReason {
        /// User finished the form (or closed the WebView after navigating into it).
        case completed
        /// User tapped X on the intro card, or dismissed the sheet pre-WebView.
        case closed
        /// WebView failed to load (network/offline). Caller should preserve flag.
        case errorOffline
    }

    // MARK: - Inputs

    let surveyURL: URL
    let onDismiss: (DismissReason) -> Void

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .intro
    @State private var webLoadingState: WebLoadingState = .loading
    @State private var errorAutoDismissTask: Task<Void, Never>?

    private enum Phase {
        case intro
        case web
    }

    private enum WebLoadingState {
        case loading
        case loaded
        case failed
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch phase {
            case .intro:
                introContent
            case .web:
                webContent
            }
        }
        .onDisappear {
            errorAutoDismissTask?.cancel()
            errorAutoDismissTask = nil
        }
    }

    // MARK: - Intro

    private var introContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                Text(String(
                    localized: "survey.intro.heading",
                    defaultValue: "이 개념 마스터한 거 자랑스러워요!"
                ))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                VStack(spacing: 4) {
                    Text(String(
                        localized: "survey.intro.body.line1",
                        defaultValue: "1-2분만 의견 들려주시면 추첨으로 스타벅스 쿠폰 보내드려요 ☕️"
                    ))
                    Text(String(
                        localized: "survey.intro.body.line2",
                        defaultValue: "더 나은 앱 만들고 싶어서요."
                    ))
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .web
                    }
                } label: {
                    Text(String(
                        localized: "survey.intro.cta",
                        defaultValue: "응답하기"
                    ))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.deepBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            Button {
                onDismiss(.closed)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityLabel(String(
                localized: "survey.intro.close.a11y",
                defaultValue: "닫기"
            ))
        }
    }

    // MARK: - WebView

    private var webContent: some View {
        ZStack {
            WebViewWrapper(
                url: surveyURL,
                onLoadSuccess: {
                    if case .loading = webLoadingState {
                        webLoadingState = .loaded
                    }
                },
                onLoadFailure: { _ in
                    webLoadingState = .failed
                    scheduleErrorAutoDismiss()
                }
            )
            .opacity(webLoadingState == .loaded ? 1 : 0)

            if case .loading = webLoadingState {
                ProgressView()
                    .controlSize(.large)
            }

            if case .failed = webLoadingState {
                errorState
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onDismiss(.completed)
                    dismiss()
                } label: {
                    Text(String(
                        localized: "survey.web.done",
                        defaultValue: "완료"
                    ))
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(String(
                localized: "survey.error.offline",
                defaultValue: "다음 업데이트 때 다시 있을게요"
            ))
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Helpers

    private func scheduleErrorAutoDismiss() {
        errorAutoDismissTask?.cancel()
        errorAutoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    onDismiss(.errorOffline)
                    dismiss()
                }
            }
        }
    }
}

#Preview("Intro") {
    Color(.systemBackground)
        .sheet(isPresented: .constant(true)) {
            SurveyModalView(
                surveyURL: URL(string: "https://forms.gle/example")!,
                onDismiss: { reason in
                    print("Dismissed: \(reason)")
                }
            )
        }
}
