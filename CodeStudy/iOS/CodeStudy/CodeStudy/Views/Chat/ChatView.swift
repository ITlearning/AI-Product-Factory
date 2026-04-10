import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var showCompletionSheet = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .onChange(of: viewModel.messages.count) {
                    if let lastMsg = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error banner
            if let error = viewModel.error {
                ErrorBanner(error: error) {
                    Task { await viewModel.handle(.retry) }
                } onDismiss: {
                    Task { await viewModel.handle(.dismissError) }
                }
            }

            // Action buttons
            if !viewModel.isStreaming && viewModel.sessionState == .active {
                ActionButtonBar { hint in
                    Task { await viewModel.handle(.sendAction(hint)) }
                }
            }

            // Input bar
            if viewModel.sessionState == .active {
                MessageInputBar(
                    text: $inputText,
                    isStreaming: viewModel.isStreaming,
                    isFocused: $isInputFocused
                ) {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    inputText = ""
                    Task { await viewModel.handle(.sendMessage(text)) }
                }
            }
        }
        .navigationTitle(viewModel.session.conceptTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("[ChatView] .task fired, messages count: \(viewModel.messages.count)")
            await viewModel.handle(.startInitialMessage)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "chat.done", defaultValue: "완료")) {
                    Task { await viewModel.handle(.completeManually) }
                }
                .disabled(viewModel.isStreaming)
            }
        }
        .onChange(of: viewModel.sessionState) { _, newState in
            if newState == .mastered || newState == .manualComplete {
                showCompletionSheet = true
            }
        }
        .sheet(isPresented: $showCompletionSheet) {
            SessionCompleteView(
                isMastered: viewModel.sessionState == .mastered,
                session: viewModel.session
            )
        }
    }
}

#Preview {
    NavigationStack {
        Text("ChatView requires a ChatViewModel with dependencies.")
    }
}
