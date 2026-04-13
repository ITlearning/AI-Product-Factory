import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var showCompletionSheet = false
    @State private var showExitConfirm = false
    @State private var isCodeMode = false
    @State private var lastAutoToggledMessageID: UUID?
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    /// Keywords in AI responses that signal a code-writing request.
    /// When the latest completed AI message contains any of these, code mode
    /// auto-enables so the user's next message goes in as Swift code.
    private static let codeRequestKeywords: [String] = [
        // Korean
        "코드를 작성", "코드를 써", "코드로 작성", "코드로 써",
        "직접 구현", "구현해보세요", "구현해봐", "구현해 봐",
        "작성해보세요", "작성해봐", "작성해 봐",
        "적어보세요", "적어봐", "적어 봐",
        "써보세요", "써봐", "써 봐",
        "짜보세요", "짜봐", "짜 봐",
        // English
        "write the code", "write code", "implement it", "implement this",
        "try writing", "code it", "write a function",
    ]

    var body: some View {
        messageScrollArea
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomInputArea
            }
            .navigationTitle(viewModel.session.conceptTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        handleBackButton()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                    }
                }
            }
            .toolbarVisibility(.hidden, for: .tabBar)
            .task {
                print("[ChatView] .task fired, messages count: \(viewModel.messages.count)")
                await viewModel.handle(.startInitialMessage)
            }
            .onChange(of: viewModel.sessionState) { _, newState in
                // Auto-show celebration sheet on mastery.
                // Manual completion from back button handles its own dismiss.
                if newState == .mastered {
                    showCompletionSheet = true
                }
            }
            // Auto-toggle code mode when AI asks for code
            .onChange(of: viewModel.isStreaming) { _, streaming in
                // Only check when streaming just ended (AI finished responding)
                guard !streaming else { return }
                autoToggleCodeModeIfNeeded()
            }
            .sheet(isPresented: $showCompletionSheet, onDismiss: {
                // After user dismisses the completion sheet, pop back to home
                dismiss()
            }) {
                SessionCompleteView(
                    isMastered: viewModel.sessionState == .mastered,
                    session: viewModel.session
                )
            }
            .alert(
                String(localized: "chat.exit.title", defaultValue: "정말 나가시겠어요?"),
                isPresented: $showExitConfirm
            ) {
                Button(String(localized: "chat.exit.continue", defaultValue: "계속 학습하기"),
                       role: .cancel) { }
                Button(String(localized: "chat.exit.leave", defaultValue: "나가기"),
                       role: .destructive) {
                    Task {
                        await viewModel.handle(.abandon)
                        dismiss()
                    }
                }
            } message: {
                Text(String(
                    localized: "chat.exit.message",
                    defaultValue: "지금 나가면 이 세션의 학습이 저장되지 않아요."
                ))
            }
    }

    // MARK: - Message scroll area

    private var messageScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    // Invisible anchor at the very bottom — always scrollable to
                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM_ANCHOR")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isStreaming) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    Task {
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onChange(of: inputText) {
                // TextView grew — keep bottom in view
                if isInputFocused {
                    scrollToBottom(proxy: proxy)
                }
            }
            .task(id: viewModel.messages.count) {
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    // MARK: - Bottom input area (error + actions + input)

    @ViewBuilder
    private var bottomInputArea: some View {
        VStack(spacing: 0) {
            if let error = viewModel.error {
                ErrorBanner(error: error) {
                    Task { await viewModel.handle(.retry) }
                } onDismiss: {
                    Task { await viewModel.handle(.dismissError) }
                }
            }

            if !viewModel.isStreaming && viewModel.sessionState == .active {
                ActionButtonBar { hint in
                    Task { await viewModel.handle(.sendAction(hint)) }
                }
            }

            if viewModel.sessionState == .active {
                MessageInputBar(
                    text: $inputText,
                    isStreaming: viewModel.isStreaming,
                    isFocused: $isInputFocused,
                    isCodeMode: $isCodeMode
                ) {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    inputText = ""
                    // Turn off code mode after sending so the user isn't stuck in it
                    let wasCodeMode = isCodeMode
                    Task { await viewModel.handle(.sendMessage(text)) }
                    if wasCodeMode {
                        isCodeMode = false
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func handleBackButton() {
        // If already mastered or completed, just pop
        if viewModel.sessionState != .active {
            dismiss()
            return
        }
        // If no messages yet, pop silently (nothing to lose)
        if viewModel.messages.isEmpty {
            dismiss()
            return
        }
        // Otherwise confirm with Duolingo-style dialog
        showExitConfirm = true
    }

    // MARK: - Auto code mode detection

    /// Checks the latest assistant message for code-request keywords and
    /// auto-enables code mode if found. Only toggles once per message to
    /// avoid re-triggering on subsequent state changes.
    private func autoToggleCodeModeIfNeeded() {
        guard let lastAssistant = viewModel.messages.reversed()
            .first(where: { $0.role == .assistant && !$0.isStreaming }) else {
            return
        }
        // Don't re-evaluate the same message
        guard lastAssistant.id != lastAutoToggledMessageID else { return }
        lastAutoToggledMessageID = lastAssistant.id

        let lowered = lastAssistant.content.lowercased()
        let hasRequest = Self.codeRequestKeywords.contains { keyword in
            lowered.contains(keyword.lowercased())
        }

        if hasRequest && !isCodeMode {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCodeMode = true
            }
        }
    }

    // MARK: - Scroll helpers

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        Text("ChatView requires a ChatViewModel with dependencies.")
    }
}
