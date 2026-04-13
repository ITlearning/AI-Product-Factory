import SwiftUI

// MARK: - ViewLoadingState

enum ViewLoadingState<T> {
    case loading
    case loaded(T)
    case empty(message: String, actionLabel: String?, action: (() -> Void)?)
    case error(String, retry: (() -> Void)?)
}

// MARK: - AsyncContentView

struct AsyncContentView<T, Content: View>: View {
    let state: ViewLoadingState<T>
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let value):
            content(value)

        case .empty(let message, let actionLabel, let action):
            ContentUnavailableView {
                Label(message, systemImage: "tray")
            } description: {
                if let actionLabel, let action {
                    Button(action: action) {
                        Text(actionLabel)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.warmOrange)
                }
            }

        case .error(let message, let retry):
            ContentUnavailableView {
                Label(
                    String(localized: "error.title", defaultValue: "오류가 발생했어요"),
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(message)
            } actions: {
                if let retry {
                    Button(
                        String(localized: "error.retry", defaultValue: "다시 시도"),
                        action: retry
                    )
                    .buttonStyle(.borderedProminent)
                    .tint(Color.warmOrange)
                }
            }
        }
    }
}

#Preview("Loading") {
    AsyncContentView(state: ViewLoadingState<String>.loading) { value in
        Text(value)
    }
}

#Preview("Empty") {
    AsyncContentView(
        state: ViewLoadingState<String>.empty(
            message: "아직 데이터가 없어요",
            actionLabel: "시작하기",
            action: {}
        )
    ) { value in
        Text(value)
    }
}
