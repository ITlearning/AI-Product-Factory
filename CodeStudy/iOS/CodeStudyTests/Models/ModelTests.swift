import Testing
import SwiftData
@testable import CodeStudy

@Suite("Model Tests")
struct ModelTests {
    @Test func userProfileDefaults() {
        let profile = UserProfile()
        #expect(profile.level == .beginner)
        #expect(profile.language == .korean)
        #expect(profile.dailySessionCount == 0)
    }

    @Test func studySessionInit() {
        let session = StudySession(conceptID: "swift-optionals", conceptTitle: "Optionals")
        #expect(session.conceptID == "swift-optionals")
        #expect(session.turnCount == 0)
        #expect(session.completion == nil)
    }

    @Test func chatMessageInit() {
        let msg = ChatMessage(role: .user, content: "Hello", orderIndex: 0)
        #expect(msg.messageRole == .user)
        #expect(msg.content == "Hello")
    }

    @Test func dailyStreakDefaults() {
        let streak = DailyStreak()
        #expect(streak.currentStreak == 0)
        #expect(streak.longestStreak == 0)
        #expect(streak.lastStudyDate == nil)
    }

    @Test func completionTypeRawValues() {
        #expect(CompletionType.mastered.rawValue == "mastered")
        #expect(CompletionType.manual.rawValue == "manual")
        #expect(CompletionType.abandoned.rawValue == "abandoned")
    }

    @Test func swiftLevelDisplayNames() {
        #expect(SwiftLevel.beginner.displayName_ko == "처음")
        #expect(SwiftLevel.beginner.displayName_en == "Beginner")
    }
}
