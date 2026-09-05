import Testing
import Foundation
import SwiftData
@testable import CodeStudy

@MainActor
@Suite("ChatViewModel Tests")
struct ChatViewModelTests {

    // MARK: - Helpers

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema([
            UserProfile.self,
            StudySession.self,
            ChatMessage.self,
            ConceptProgress.self,
            DailyStreak.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Seed a user profile
        let profile = UserProfile(
            hasDevelopmentExperience: false,
            swiftLevel: .beginner,
            preferredLanguage: .korean
        )
        context.insert(profile)
        try context.save()

        return context
    }

    private func makeSUT(
        mockService: MockAIService = MockAIService(),
        modelContext: ModelContext? = nil
    ) throws -> (ChatViewModel, MockAIService, ModelContext) {
        let context = try modelContext ?? makeModelContext()
        let session = StudySession(conceptID: "swift-optionals", conceptTitle: "Optionals")
        context.insert(session)
        try context.save()

        let vm = ChatViewModel(
            aiService: mockService,
            session: session,
            modelContext: context
        )
        return (vm, mockService, context)
    }

    // MARK: - Tests

    @Test("sendMessage adds user and assistant messages")
    func testSendMessageAddsMessages() async throws {
        let mock = MockAIService()
        mock.responses = ["Swift ", "is ", "awesome!"]
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("What are optionals?"))

        #expect(vm.state.messages.count == 2)
        #expect(vm.state.messages[0].role == .user)
        #expect(vm.state.messages[0].content == "What are optionals?")
        #expect(vm.state.messages[1].role == .assistant)
        #expect(vm.state.messages[1].content == "Swift is awesome!")
        #expect(vm.state.isStreaming == false)
        #expect(vm.state.turnCount == 1)
    }

    @Test("mastery detection sets session state to mastered")
    func testMasteryDetection() async throws {
        let mock = MockAIService()
        mock.responses = ["Great job! You've mastered this! [MASTERY]"]
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("I understand optionals"))

        #expect(vm.state.sessionState == .mastered)
    }

    @Test("error surfaces a banner but keeps the session usable")
    func testErrorHandling() async throws {
        let mock = MockAIService()
        mock.shouldError = .networkUnavailable
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("Hello"))

        #expect(vm.state.error == .networkUnavailable)
        // 회귀 방어: 실패는 배너로만 알린다. 세션이 .active를 벗어나면
        // ChatView가 입력창을 통째로 지우고 재시도까지 막힌다.
        #expect(vm.state.sessionState == .active)
        // User message remains, failed assistant placeholder removed
        #expect(vm.state.messages.count == 1)
        #expect(vm.state.messages[0].role == .user)
    }

    @Test("retry actually resends the last user message and succeeds")
    func testRetry() async throws {
        let mock = MockAIService()
        mock.shouldError = .networkUnavailable
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("What are closures?"))
        #expect(vm.state.error == .networkUnavailable)
        #expect(vm.state.messages.count == 1)

        // 연결이 돌아온 상황
        mock.shouldError = nil
        mock.responses = ["Closures are..."]

        await vm.handle(.retry)

        // 사용자 메시지는 중복되지 않고, 이번엔 답이 붙는다.
        #expect(vm.state.error == nil)
        #expect(vm.state.messages.count == 2)
        #expect(vm.state.messages[0].role == .user)
        #expect(vm.state.messages[0].content == "What are closures?")
        #expect(vm.state.messages[1].role == .assistant)
        #expect(vm.state.messages[1].content == "Closures are...")
        #expect(vm.state.sessionState == .active)
    }

    @Test("retry recovers when the opening message was the thing that failed")
    func testRetryAfterInitialMessageFailure() async throws {
        let mock = MockAIService()
        mock.shouldError = .networkUnavailable
        let (vm, _, _) = try makeSUT(mockService: mock)

        // 개념에 막 들어오자마자 첫 인사 스트림이 실패 — user 메시지가 없다.
        await vm.handle(.startInitialMessage)
        #expect(vm.state.error == .networkUnavailable)
        #expect(vm.state.messages.isEmpty)

        mock.shouldError = nil
        mock.responses = ["안녕하세요! 옵셔널을 배워봐요."]

        await vm.handle(.retry)

        // 되돌릴 user 메시지가 없어도 대화가 시작돼야 한다.
        // (수정 전에는 여기서 아무 일도 일어나지 않아 사용자가 나갔다 와야 했다)
        #expect(vm.state.error == nil)
        #expect(vm.state.messages.count == 1)
        #expect(vm.state.messages[0].role == .assistant)
        #expect(vm.state.messages[0].content == "안녕하세요! 옵셔널을 배워봐요.")
    }

    @Test("streaming failure still leaves the session recoverable")
    func testStreamingFailureKeepsSessionActive() async throws {
        let mock = MockAIService()
        mock.shouldError = .connectionInterrupted
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("설명해주세요"))

        #expect(vm.state.error == .connectionInterrupted)
        #expect(vm.state.sessionState == .active)

        // 같은 세션에서 새 메시지를 그냥 이어 보낼 수 있어야 한다.
        mock.shouldError = nil
        mock.responses = ["이어서 설명할게요"]
        await vm.handle(.sendMessage("다시 설명해주세요"))

        #expect(vm.state.messages.last?.content == "이어서 설명할게요")
    }

    @Test("retry replaces a half-received answer instead of stacking a second one")
    func testRetryAfterPartialStreamLeavesOneAnswer() async throws {
        let mock = MockAIService()
        mock.shouldError = .connectionInterrupted
        mock.chunksBeforeInterruption = ["옵셔널은 값이 "]
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("옵셔널이 뭐예요?"))

        // 반쪽짜리 답은 남기지 않는다. 남기면 아래 재시도가 답을 하나 더 붙인다.
        #expect(vm.state.error == .connectionInterrupted)
        #expect(vm.state.messages.count == 1)
        #expect(vm.state.messages[0].role == .user)

        mock.shouldError = nil
        mock.chunksBeforeInterruption = []
        mock.responses = ["옵셔널은 값이 있을 수도, 없을 수도 있는 타입이에요."]

        await vm.handle(.retry)

        // user 하나 + 온전한 assistant 하나. 잘린 답이 끼어들면 안 된다.
        #expect(vm.state.messages.count == 2)
        #expect(vm.state.messages[0].role == .user)
        #expect(vm.state.messages[1].role == .assistant)
        #expect(vm.state.messages[1].content == "옵셔널은 값이 있을 수도, 없을 수도 있는 타입이에요.")
        #expect(vm.state.turnCount == 1)
    }

    @Test("action hint stream failure drops its partial answer too")
    func testActionHintPartialFailureDropsPartial() async throws {
        let mock = MockAIService()
        mock.shouldError = .connectionInterrupted
        mock.chunksBeforeInterruption = ["힌트를 드리자면 "]
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendAction(.hint))

        #expect(vm.state.error == .connectionInterrupted)
        #expect(vm.state.sessionState == .active)
        #expect(vm.state.messages.count == 1)
        #expect(vm.state.messages[0].role == .user)
        #expect(vm.state.turnCount == 0)
    }

    @Test("a cancelled stream is not counted as a finished turn")
    func testCancelledStreamDoesNotCountTurn() async throws {
        let mock = MockAIService()
        mock.shouldCancel = true
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("옵셔널이 뭐예요?"))

        // 취소는 실패가 아니라 배너를 띄우지 않는다. 동시에 빈 응답을
        // 성공으로 저장해 turnCount를 까먹어서도 안 된다.
        #expect(vm.state.error == nil)
        #expect(vm.state.turnCount == 0)
        #expect(vm.state.messages.count == 1)
        #expect(vm.state.messages[0].role == .user)
    }

    @Test("dismissError clears error")
    func testDismissError() async throws {
        let mock = MockAIService()
        mock.shouldError = .rateLimited
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("test"))
        #expect(vm.state.error == .rateLimited)

        await vm.handle(.dismissError)
        #expect(vm.state.error == nil)
    }

    @Test("completeManually sets session state to manualComplete")
    func testManualCompletion() async throws {
        let mock = MockAIService()
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.completeManually)

        #expect(vm.state.sessionState == .manualComplete)
    }

    @Test("sendAction sends action hint message")
    func testSendAction() async throws {
        let mock = MockAIService()
        mock.responses = ["Here's a hint: ..."]
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendAction(.hint))

        // Should have user message (display text) + assistant response
        #expect(vm.state.messages.count == 2)
        #expect(vm.state.messages[0].role == .user)
        #expect(vm.state.messages[0].content == "힌트를 주세요")
        #expect(vm.state.messages[1].role == .assistant)
        #expect(vm.state.messages[1].content == "Here's a hint: ...")
    }

    @Test("turn count increments per exchange")
    func testTurnCount() async throws {
        let mock = MockAIService()
        mock.responses = ["Response"]
        let (vm, _, _) = try makeSUT(mockService: mock)

        await vm.handle(.sendMessage("First"))
        #expect(vm.state.turnCount == 1)

        await vm.handle(.sendMessage("Second"))
        #expect(vm.state.turnCount == 2)
    }

    @Test("messages not sent when session is not active")
    func testInactiveSessionBlocks() async throws {
        let mock = MockAIService()
        mock.responses = ["Mastered! [MASTERY]"]
        let (vm, _, _) = try makeSUT(mockService: mock)

        // Trigger mastery
        await vm.handle(.sendMessage("I know this"))
        #expect(vm.state.sessionState == .mastered)

        let messageCountAfterMastery = vm.state.messages.count

        // Try to send another message — should be blocked
        await vm.handle(.sendMessage("Another message"))
        #expect(vm.state.messages.count == messageCountAfterMastery)
    }
}
