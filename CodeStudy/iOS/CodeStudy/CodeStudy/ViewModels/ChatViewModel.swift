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

    // MARK: - State

    struct State {
        var messages: [ChatMessageUI] = []
        var isStreaming = false
        var error: AIServiceError?
        var sessionState: SessionState = .active
        var turnCount = 0
    }

    // MARK: - Actions (TCA-friendly)

    enum Action {
        case sendMessage(String)
        case sendAction(ActionHint)
        case completeManually
        case retry
        case dismissError
    }

    enum SessionState: Equatable {
        case active
        case mastered
        case manualComplete
        case error
    }

    // MARK: - Published State

    private(set) var state = State()

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
        case .sendMessage(let text):
            await sendMessage(text)
        case .sendAction(let hint):
            await sendActionMessage(hint)
        case .completeManually:
            await completeSession(type: .manual)
        case .retry:
            state.error = nil
            if let lastUserMsg = state.messages.last(where: { $0.role == .user }) {
                await sendMessage(lastUserMsg.content, isRetry: true)
            }
        case .dismissError:
            state.error = nil
        }
    }

    // MARK: - Private Methods

    private func sendMessage(_ text: String, isRetry: Bool = false) async {
        // Guard: session must be active
        guard state.sessionState == .active else { return }

        // Guard: turn limit
        guard state.turnCount < AppConstants.maxTurnsPerSession else {
            state.error = .sessionTurnLimitExceeded
            return
        }

        // 1. Append user message (skip if retrying, message already exists)
        if !isRetry {
            let userMessage = ChatMessageUI(role: .user, content: text)
            state.messages.append(userMessage)
        }

        // 2. Create placeholder assistant message
        let assistantIndex = state.messages.count
        let assistantMessage = ChatMessageUI(role: .assistant, content: "", isStreaming: true)
        state.messages.append(assistantMessage)

        // 3. Set streaming state
        state.isStreaming = true

        // 4. Build conversation context
        let context = buildConversationContext()

        // 5. Stream response from AI service
        do {
            let stream = aiService.sendMessage(text, context: context)
            for try await chunk in stream {
                state.messages[assistantIndex].content += chunk
            }

            // 6. Mark streaming complete
            state.messages[assistantIndex].isStreaming = false
            state.isStreaming = false
            state.turnCount += 1
            session.turnCount = state.turnCount

            // 7. Check for mastery marker
            let fullResponse = state.messages[assistantIndex].content
            if fullResponse.contains("[MASTERY]") {
                await completeSession(type: .mastered)
            }

            // 8. Persist messages to SwiftData
            persistMessages()

        } catch let serviceError as AIServiceError {
            state.messages[assistantIndex].isStreaming = false
            state.isStreaming = false
            state.error = serviceError
            state.sessionState = .error
            // Remove the empty assistant placeholder on error
            if state.messages[assistantIndex].content.isEmpty {
                state.messages.remove(at: assistantIndex)
            }
        } catch {
            state.messages[assistantIndex].isStreaming = false
            state.isStreaming = false
            state.error = .streamingFailed
            state.sessionState = .error
            if state.messages[assistantIndex].content.isEmpty {
                state.messages.remove(at: assistantIndex)
            }
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
        state.messages.append(userMessage)

        // Send the action-tagged message to AI (includes hint metadata)
        await sendMessageWithActionHint(actionText, hint: hint)
    }

    private func sendMessageWithActionHint(_ text: String, hint: ActionHint) async {
        guard state.sessionState == .active else { return }
        guard state.turnCount < AppConstants.maxTurnsPerSession else {
            state.error = .sessionTurnLimitExceeded
            return
        }

        let assistantIndex = state.messages.count
        let assistantMessage = ChatMessageUI(role: .assistant, content: "", isStreaming: true)
        state.messages.append(assistantMessage)

        state.isStreaming = true

        let context = buildConversationContext(actionHint: hint)

        do {
            let stream = aiService.sendMessage(text, context: context)
            for try await chunk in stream {
                state.messages[assistantIndex].content += chunk
            }

            state.messages[assistantIndex].isStreaming = false
            state.isStreaming = false
            state.turnCount += 1
            session.turnCount = state.turnCount

            let fullResponse = state.messages[assistantIndex].content
            if fullResponse.contains("[MASTERY]") {
                await completeSession(type: .mastered)
            }

            persistMessages()

        } catch let serviceError as AIServiceError {
            state.messages[assistantIndex].isStreaming = false
            state.isStreaming = false
            state.error = serviceError
            state.sessionState = .error
            if state.messages[assistantIndex].content.isEmpty {
                state.messages.remove(at: assistantIndex)
            }
        } catch {
            state.messages[assistantIndex].isStreaming = false
            state.isStreaming = false
            state.error = .streamingFailed
            state.sessionState = .error
            if state.messages[assistantIndex].content.isEmpty {
                state.messages.remove(at: assistantIndex)
            }
        }
    }

    private func completeSession(type: CompletionType) async {
        session.completion = type
        session.endedAt = Date()

        switch type {
        case .mastered:
            state.sessionState = .mastered
            updateConceptProgress(mastered: true)
            updateStreak()
        case .manual:
            state.sessionState = .manualComplete
            updateConceptProgress(mastered: false)
            updateStreak()
        case .abandoned:
            break
        }

        persistMessages()

        do {
            try modelContext.save()
        } catch {
            state.error = .streamingFailed
        }
    }

    private func buildConversationContext(actionHint: ActionHint? = nil) -> ConversationContext {
        // Build profile snapshot from SwiftData
        let profileSnapshot = fetchUserProfileSnapshot()

        // Build message history
        let previousMessages: [MessageSnapshot] = state.messages
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
        for (index, uiMessage) in state.messages.enumerated() {
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
