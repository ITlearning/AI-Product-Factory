import SwiftUI

/// Top-of-screen toast shown the day after a streak freeze was used.
/// Slides down on appear, auto-dismisses after 4 seconds, and can be
/// swiped up to dismiss early. Lane C wires up the `isPresented` binding
/// from RootView based on the StreakManager `freezeUsedYesterday` flag.
struct StreakToast: View {
    @Binding var isPresented: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var dismissTask: Task<Void, Never>?

    private let autoDismissSeconds: UInt64 = 4
    private let cornerRadius: CGFloat = 14

    var body: some View {
        VStack {
            toastBody
                .offset(y: combinedOffset)
                .opacity(isVisible ? 1 : 0)
                .gesture(swipeUpGesture)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isVisible = true
            }
            scheduleAutoDismiss()
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    // MARK: - Toast Body

    private var toastBody: some View {
        HStack(spacing: 10) {
            Text("🔥")
                .font(.title3)

            Text(String(
                localized: "streak.freeze.toast",
                defaultValue: "어제 freeze로 스트릭 지켰어요!"
            ))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.warmOrange.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            localized: "streak.freeze.toast.a11y",
            defaultValue: "어제 freeze로 스트릭을 지켰어요"
        ))
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Gesture

    private var swipeUpGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Only respond to upward drags
                if value.translation.height < 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height < -30 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Helpers

    private var combinedOffset: CGFloat {
        let hiddenOffset: CGFloat = -120
        return isVisible ? dragOffset : hiddenOffset
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: autoDismissSeconds * 1_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { dismiss() }
            }
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeIn(duration: 0.25)) {
            isVisible = false
        }
        // Allow the fade-out animation to play before removing from tree.
        Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            await MainActor.run { isPresented = false }
        }
    }
}

#Preview {
    StatefulPreviewWrapper(true) { binding in
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            StreakToast(isPresented: binding)
        }
    }
}

// MARK: - Preview helper

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
