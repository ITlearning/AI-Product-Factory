import SwiftUI

struct ErrorBanner: View {
    let error: AIServiceError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.subheadline)

            Text(error.errorDescription ?? String(localized: "error.unknown",
                                                   defaultValue: "알 수 없는 오류가 발생했습니다"))
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            Button(action: onRetry) {
                Text(String(localized: "error.retry", defaultValue: "다시 시도"))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .offset(y: isVisible ? 0 : -20)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    VStack {
        ErrorBanner(
            error: .networkUnavailable,
            onRetry: { print("Retry") },
            onDismiss: { print("Dismiss") }
        )
        ErrorBanner(
            error: .serverError(statusCode: 500),
            onRetry: { print("Retry") },
            onDismiss: { print("Dismiss") }
        )
    }
    .padding()
}
