import Foundation
import SwiftData

// MARK: - Chat Message UI

struct ChatMessageUI: Identifiable {
    let id: UUID
    let role: MessageRole
    var content: String
    let createdAt: Date
    var isStreaming: Bool

    init(role: MessageRole, content: String = "", isStreaming: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.isStreaming = isStreaming
    }
}

// MARK: - ChatViewModel

@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Actions (TCA-friendly)

    enum Action {
        case startInitialMessage
        case sendMessage(String)
        case sendAction(ActionHint)
        case completeManually
        case abandon    // 중도 포기 — 스트릭/진행 카운트 안 됨
        case retry
        case dismissError
    }

    enum SessionState: Equatable {
        case active
        case mastered
        case manualComplete
        case error
    }

    // MARK: - Observed State (top-level for SwiftUI Observation compatibility)

    var messages: [ChatMessageUI] = []
    var isStreaming = false
    var error: AIServiceError?
    var sessionState: SessionState = .active
    var turnCount = 0

    /// Backwards-compat alias so existing `viewModel.state.xxx` reads still work.
    var state: StateSnapshot {
        StateSnapshot(
            messages: messages,
            isStreaming: isStreaming,
            error: error,
            sessionState: sessionState,
            turnCount: turnCount
        )
    }

    struct StateSnapshot {
        let messages: [ChatMessageUI]
        let isStreaming: Bool
        let error: AIServiceError?
        let sessionState: SessionState
        let turnCount: Int
    }

    // MARK: - Dependencies

    private let aiService: AIService
    let session: StudySession
    private let modelContext: ModelContext

    init(
        aiService: AIService,
        session: StudySession,
        modelContext: ModelContext
    ) {
        self.aiService = aiService
        self.session = session
        self.modelContext = modelContext
    }

    // MARK: - Action Handler

    func handle(_ action: Action) async {
        switch action {
        case .startInitialMessage:
            await sendInitialMessage()
        case .sendMessage(let text):
            await sendMessage(text)
        case .sendAction(let hint):
            await sendActionMessage(hint)
        case .completeManually:
            await completeSession(type: .manual)
        case .abandon:
            await completeSession(type: .abandoned)
        case .retry:
            error = nil
            if let lastUserMsg = messages.last(where: { $0.role == .user }) {
                await sendMessage(lastUserMsg.content, isRetry: true)
            }
        case .dismissError:
            error = nil
        }
    }

    /// Sends an empty context request so the AI produces the first message.
    /// Called once when ChatView appears. Guards against double-starting.
    @MainActor
    private func sendInitialMessage() async {
        print("[ChatVM] sendInitialMessage called. messages=\(messages.count) state=\(sessionState)")
        // Only start if there are no messages yet
        guard messages.isEmpty else {
            print("[ChatVM] skip: messages not empty")
            return
        }
        guard sessionState == .active else {
            print("[ChatVM] skip: session not active")
            return
        }
        print("[ChatVM] starting initial message stream")

        // Create placeholder assistant message
        
        let assistantIndex = messages.count
        let assistantMessage = ChatMessageUI(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        isStreaming = true

        let context = buildConversationContext()

        do {
            // Send a special "start" trigger so the backend knows to produce
            // an opening message. The backend treats an empty message array
            // + this trigger as "greet and introduce the concept".
            print("[ChatVM] calling aiService.sendMessage(__START__)")
            let stream = aiService.sendMessage("__START__", context: context)
            print("[ChatVM] stream created, awaiting chunks...")
            var chunkCount = 0
            for try await chunk in stream {
                chunkCount += 1
                if chunkCount <= 3 {
                    print("[ChatVM] chunk #\(chunkCount): \(chunk.prefix(40))")
                }
                // Re-assign the full array so @Observable triggers SwiftUI updates.
                // Nested mutation (messages[i].content += ...) is not observed.
                var updatedMessages = messages
                updatedMessages[assistantIndex].content += chunk
                messages = updatedMessages
            }
            print("[ChatVM] stream ended. total chunks=\(chunkCount)")

            // Mark streaming complete — also via full re-assign
            var finalMessages = messages
            finalMessages[assistantIndex].isStreaming = false

            // Check for mastery marker (unlikely on first message, but safe)
            if finalMessages[assistantIndex].content.contains("[MASTERY]") {
                finalMessages[assistantIndex].content = finalMessages[assistantIndex].content
                    .replacingOccurrences(of: "[MASTERY]", with: "")
            }
            messages = finalMessages
            isStreaming = false

            persistMessages()
        } catch let serviceError as AIServiceError {
            print("[ChatVM] AIServiceError: \(serviceError.localizedDescription)")
            messages.removeLast()
            isStreaming = false
            self.error = serviceError
        } catch {
            print("[ChatVM] unknown error: \(error)")
            messages.removeLast()
            isStreaming = false
            self.error = .invalidResponse
        }
    }

    // MARK: - Private Methods

    private func sendMessage(_ text: String, isRetry: Bool = false) async {
        // Guard: session must be active
        guard sessionState == .active else { return }

        // Guard: turn limit
        guard turnCount < AppConstants.maxTurnsPerSession else {
            error = .sessionTurnLimitExceeded
            return
        }

        // 1. Append user message (skip if retrying, message already exists)
        if !isRetry {
            let userMessage = ChatMessageUI(role: .user, content: text)
            messages.append(userMessage)
        }

        // 2. Create placeholder assistant message
        let assistantIndex = messages.count
        let assistantMessage = ChatMessageUI(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        // 3. Set streaming state
        isStreaming = true

        // 4. Build conversation context
        let context = buildConversationContext()

        // 5. Stream response from AI service
        do {
            let stream = aiService.sendMessage(text, context: context)
            for try await chunk in stream {
                // Re-assign the full array so @Observable triggers SwiftUI updates.
                var updatedMessages = messages
                updatedMessages[assistantIndex].content += chunk
                messages = updatedMessages
            }

            // 6. Check for mastery marker + strip from displayed text
            var finalMessages = messages
            finalMessages[assistantIndex].isStreaming = false
            let mastered = finalMessages[assistantIndex].content.contains("[MASTERY]")
            if mastered {
                finalMessages[assistantIndex].content = finalMessages[assistantIndex].content
                    .replacingOccurrences(of: "[MASTERY]", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            messages = finalMessages
            isStreaming = false
            turnCount += 1
            session.turnCount = turnCount

            // 7. Persist and complete if mastered
            persistMessages()
            if mastered {
                await completeSession(type: .mastered)
            }

        } catch let serviceError as AIServiceError {
            var updatedMessages = messages
            updatedMessages[assistantIndex].isStreaming = false
            messages = updatedMessages
            isStreaming = false
            error = serviceError
            sessionState = .error
            // Remove the empty assistant placeholder on error
            if messages[assistantIndex].content.isEmpty {
                messages.remove(at: assistantIndex)
            }
        } catch {
            var updatedMessages = messages
            updatedMessages[assistantIndex].isStreaming = false
            if updatedMessages[assistantIndex].content.isEmpty {
                updatedMessages.remove(at: assistantIndex)
            }
            messages = updatedMessages
            isStreaming = false
            self.error = .streamingFailed
            sessionState = .error
        }
    }

    private func sendActionMessage(_ hint: ActionHint) async {
        let actionText: String
        switch hint {
        case .simpler:
            actionText = "[ACTION:simpler] 좀 더 쉽게 설명해주세요"
        case .hint:
            actionText = "[ACTION:hint] 힌트를 주세요"
        case .quiz:
            actionText = "[ACTION:quiz] 퀴즈를 내주세요"
        }

        // Append visible user message with friendly text
        let displayText: String
        switch hint {
        case .simpler:
            displayText = "좀 더 쉽게 설명해주세요"
        case .hint:
            displayText = "힌트를 주세요"
        case .quiz:
            displayText = "퀴즈를 내주세요"
        }

        let userMessage = ChatMessageUI(role: .user, content: displayText)
        messages.append(userMessage)

        // Send the action-tagged message to AI (includes hint metadata)
        await sendMessageWithActionHint(actionText, hint: hint)
    }

    private func sendMessageWithActionHint(_ text: String, hint: ActionHint) async {
        guard sessionState == .active else { return }
        guard turnCount < AppConstants.maxTurnsPerSession else {
            error = .sessionTurnLimitExceeded
            return
        }

        let assistantIndex = messages.count
        let assistantMessage = ChatMessageUI(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        isStreaming = true

        let context = buildConversationContext(actionHint: hint)

        do {
            let stream = aiService.sendMessage(text, context: context)
            for try await chunk in stream {
                var updatedMessages = messages
                updatedMessages[assistantIndex].content += chunk
                messages = updatedMessages
            }

            var finalMessages = messages
            finalMessages[assistantIndex].isStreaming = false
            let mastered = finalMessages[assistantIndex].content.contains("[MASTERY]")
            if mastered {
                finalMessages[assistantIndex].content = finalMessages[assistantIndex].content
                    .replacingOccurrences(of: "[MASTERY]", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            messages = finalMessages
            isStreaming = false
            turnCount += 1
            session.turnCount = turnCount

            persistMessages()
            if mastered {
                await completeSession(type: .mastered)
            }

        } catch let serviceError as AIServiceError {
            messages[assistantIndex].isStreaming = false
            isStreaming = false
            error = serviceError
            sessionState = .error
            if messages[assistantIndex].content.isEmpty {
                messages.remove(at: assistantIndex)
            }
        } catch {
            var updatedMessages = messages
            updatedMessages[assistantIndex].isStreaming = false
            if updatedMessages[assistantIndex].content.isEmpty {
                updatedMessages.remove(at: assistantIndex)
            }
            messages = updatedMessages
            isStreaming = false
            self.error = .streamingFailed
            sessionState = .error
        }
    }

    private func completeSession(type: CompletionType) async {
        session.completion = type
        session.endedAt = Date()

        switch type {
        case .mastered:
            sessionState = .mastered
            updateConceptProgress(mastered: true)
            updateStreak()  // 마스터리만 스트릭 카운트
        case .manual:
            sessionState = .manualComplete
            updateConceptProgress(mastered: false)
            // 수동 완료는 스트릭 카운트 안 함 (마스터리만 카운트 규칙)
        case .abandoned:
            // 중도 포기 — 스트릭도 진행도 업데이트 안 함
            break
        }

        persistMessages()

        do {
            try modelContext.save()
        } catch {
            self.error = .streamingFailed
        }
    }

    private func buildConversationContext(actionHint: ActionHint? = nil) -> ConversationContext {
        // Build profile snapshot from SwiftData
        let profileSnapshot = fetchUserProfileSnapshot()

        // Build message history
        let previousMessages: [MessageSnapshot] = messages
            .filter { !$0.isStreaming }
            .map { MessageSnapshot(role: $0.role.rawValue, content: $0.content) }

        return ConversationContext(
            conceptID: session.conceptID,
            conceptTitle: session.conceptTitle,
            userProfile: profileSnapshot,
            previousMessages: previousMessages,
            actionHint: actionHint
        )
    }

    private func fetchUserProfileSnapshot() -> UserProfileSnapshot {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        guard let profile = profiles.first else {
            return UserProfileSnapshot(
                hasDevelopmentExperience: false,
                swiftLevel: SwiftLevel.beginner.rawValue,
                preferredLanguage: AppLanguage.korean.rawValue
            )
        }
        return UserProfileSnapshot(
            hasDevelopmentExperience: profile.hasDevelopmentExperience,
            swiftLevel: profile.swiftLevel,
            preferredLanguage: profile.preferredLanguage
        )
    }

    private func persistMessages() {
        // Sync UI messages to SwiftData ChatMessage models
        let existingIDs = Set(session.messages.map(\.id))
        for (index, uiMessage) in messages.enumerated() {
            if !existingIDs.contains(uiMessage.id) && !uiMessage.isStreaming {
                let chatMessage = ChatMessage(
                    role: uiMessage.role,
                    content: uiMessage.content,
                    orderIndex: index
                )
                // Overwrite the auto-generated ID to match UI
                chatMessage.id = uiMessage.id
                chatMessage.session = session
                session.messages.append(chatMessage)
                modelContext.insert(chatMessage)
            }
        }

        try? modelContext.save()
    }

    private func updateConceptProgress(mastered: Bool) {
        let conceptID = session.conceptID
        let descriptor = FetchDescriptor<ConceptProgress>(
            predicate: #Predicate { $0.conceptID == conceptID }
        )

        if let progress = try? modelContext.fetch(descriptor).first {
            progress.studiedCount += 1
            progress.lastStudiedAt = Date()
            if mastered {
                progress.masteredCount += 1
                progress.isMastered = true
            }
        } else {
            let progress = ConceptProgress(
                conceptID: session.conceptID,
                conceptTitle: session.conceptTitle,
                category: ""  // Category set by curriculum service
            )
            progress.studiedCount = 1
            progress.lastStudiedAt = Date()
            if mastered {
                progress.masteredCount = 1
                progress.isMastered = true
            }
            modelContext.insert(progress)
        }
    }

    private func updateStreak() {
        let descriptor = FetchDescriptor<DailyStreak>()
        let streak: DailyStreak

        if let existing = try? modelContext.fetch(descriptor).first {
            streak = existing
        } else {
            streak = DailyStreak()
            modelContext.insert(streak)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = streak.lastStudyDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if lastDay == today {
                // Already recorded today
                return
            } else if calendar.date(byAdding: .day, value: 1, to: lastDay) == today {
                // Consecutive day
                streak.currentStreak += 1
            } else {
                // Streak broken
                streak.currentStreak = 1
            }
        } else {
            streak.currentStreak = 1
        }

        streak.lastStudyDate = today
        if streak.currentStreak > streak.longestStreak {
            streak.longestStreak = streak.currentStreak
        }
    }
}
