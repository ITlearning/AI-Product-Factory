import XCTest
@testable import ColorMoments

final class OnboardingRulesTests: XCTestCase {

    // MARK: 보여 줄지

    func testNewUserSeesFullOnboarding() {
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: false, hasRecords: false,
                                                   didAskArrivalNotice: false), .full)
    }

    func testUndecidedBeforeLoad() {
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: false, didFinishOnboarding: false, hasRecords: false,
                                                   didAskArrivalNotice: false), .undecided,
                       "로드 전엔 기록이 0개처럼 보인다 — 판정하지 않는다")
    }

    func testExistingUserWithRecordsOnlyGetsArrivalAskOnce() {
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: false, hasRecords: true,
                                                   didAskArrivalNotice: false), .arrivalAskOnly)
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: false, hasRecords: true,
                                                   didAskArrivalNotice: true), .none,
                       "한 번 답했으면 다시 묻지 않는다")
    }

    func testFinishedUserSeesNothing() {
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: true, hasRecords: false,
                                                   didAskArrivalNotice: true), .none)
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: true, hasRecords: true,
                                                   didAskArrivalNotice: true), .none)
    }

    // MARK: 단계

    func testFullFlow() {
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true),
                       [.intro, .firstPebble, .arrival, .cloud, .howTo, .start])
    }

    func testDeniedOrEmptyLibrarySkipsFirstPebble() {
        XCTAssertTrue(OnboardingFlow.skipsFirstPebble(access: .denied, recentCount: nil))
        XCTAssertTrue(OnboardingFlow.skipsFirstPebble(access: .allowed, recentCount: 0))
        XCTAssertFalse(OnboardingFlow.skipsFirstPebble(access: .allowed, recentCount: 3))
        XCTAssertFalse(OnboardingFlow.skipsFirstPebble(access: .notDetermined, recentCount: nil),
                       "아직 묻지 않았으면 그 단계에서 묻는다")
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: true, asksArrival: true),
                       [.intro, .arrival, .cloud, .howTo, .start])
    }

    func testCloudRecordsReplaceFirstPebbleWithContinuing() {
        XCTAssertEqual(OnboardingFlow.steps(continuing: true, skipsFirstPebble: false, asksArrival: true),
                       [.intro, .continuing, .arrival, .howTo, .start])
    }

    func testArrivalStepOnlyWhenNotAsked() {
        XCTAssertFalse(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: false)
            .contains(.arrival))
    }

    func testRemoteDayCountExcludesImported() {
        XCTAssertEqual(OnboardingFlow.remoteDayCount(dayKeys: ["2026-09-20", "2026-09-21", "2026-09-22"],
                                                     importedDayKeys: ["2026-09-22"]), 2)
        XCTAssertEqual(OnboardingFlow.remoteDayCount(dayKeys: [], importedDayKeys: []), 0)
    }

    func testImportOutcome() {
        let today = "2026-09-22"
        XCTAssertEqual(OnboardingFlow.outcome(existingRecordsWereEmpty: true,
                                              importedDayKeys: ["2026-09-20", today], today: today),
                       .gift("2026-09-20"))
        XCTAssertEqual(OnboardingFlow.outcome(existingRecordsWereEmpty: true, importedDayKeys: [today], today: today),
                       .todayOnly, "오늘만 담으면 증정 없이 진행 중으로")
        XCTAssertEqual(OnboardingFlow.outcome(existingRecordsWereEmpty: false,
                                              importedDayKeys: ["2026-09-20"], today: today), .added)
        XCTAssertEqual(OnboardingFlow.outcome(existingRecordsWereEmpty: true, importedDayKeys: [], today: today),
                       .nothing)
    }

    // MARK: 추천 점수

    func testUtilityPhotosAreExcluded() {
        XCTAssertNil(SuggestionScore.combine(overall: 0.9, isUtility: true, labels: ["sky"]))
    }

    func testScenicLabelsAddBonusUpToCap() {
        let plain = SuggestionScore.combine(overall: 0.1, isUtility: false, labels: ["laptop"])!
        let sky = SuggestionScore.combine(overall: 0.1, isUtility: false, labels: ["sky", "laptop"])!
        let many = SuggestionScore.combine(overall: 0.1, isUtility: false,
                                           labels: ["sky", "sunset_sunrise", "ocean", "beach"])!
        XCTAssertEqual(plain, 0.1, accuracy: 1e-6)
        XCTAssertEqual(sky, 0.1 + SuggestionScore.labelBonus, accuracy: 1e-6)
        XCTAssertEqual(many, 0.1 + SuggestionScore.maxLabelBonus, accuracy: 1e-6, "라벨 가산에는 상한이 있다")
    }

    func testMissingAestheticsFallsBackToLabels() {
        XCTAssertEqual(SuggestionScore.combine(overall: nil, isUtility: false, labels: ["sky"])!,
                       SuggestionScore.labelBonus, accuracy: 1e-6)
    }

    func testLayoutFollowsRankingUntilFrozen() {
        let d = Date(timeIntervalSince1970: 1_000)
        let ranked = [("c", 0.9), ("a", 0.5), ("b", 0.4)].map { SuggestionScore.Candidate(id: $0.0, score: $0.1, capturedAt: d) }
        XCTAssertEqual(SuggestionScore.layout(shown: ["a", "b"], frozen: false, ranked: ranked, limit: 2, maxShown: 4),
                       ["c", "a"], "고르기 전엔 점수 순")
    }

    func testFrozenLayoutKeepsCellsAndAppendsNew() {
        let d = Date(timeIntervalSince1970: 1_000)
        let ranked = [("c", 0.9), ("d", 0.8), ("a", 0.5), ("b", 0.4)]
            .map { SuggestionScore.Candidate(id: $0.0, score: $0.1, capturedAt: d) }
        XCTAssertEqual(SuggestionScore.layout(shown: ["a", "b"], frozen: true, ranked: ranked, limit: 2, maxShown: 4),
                       ["a", "b", "c", "d"], "보이던 칸은 제자리, 새 상위는 뒤에")
        XCTAssertEqual(SuggestionScore.layout(shown: ["a", "b"], frozen: true, ranked: ranked, limit: 2, maxShown: 3),
                       ["a", "b", "c"], "뒤에 붙이는 것도 상한까지만")
    }

    func testRankingIsStable() {
        let d0 = Date(timeIntervalSince1970: 1_000), d1 = Date(timeIntervalSince1970: 2_000)
        let a = SuggestionScore.Candidate(id: "a", score: 0.5, capturedAt: d0)
        let b = SuggestionScore.Candidate(id: "b", score: 0.5, capturedAt: d1)
        let c = SuggestionScore.Candidate(id: "c", score: 0.9, capturedAt: d0)
        let d = SuggestionScore.Candidate(id: "d", score: 0.5, capturedAt: d1)
        let expected = ["c", "b", "d", "a"]
        XCTAssertEqual(SuggestionScore.ranked([a, b, c, d], limit: 10).map(\.id), expected)
        XCTAssertEqual(SuggestionScore.ranked([d, c, b, a], limit: 10).map(\.id), expected,
                       "들어온 순서가 달라도 같은 줄")
        XCTAssertEqual(SuggestionScore.ranked([a, b, c, d], limit: 2).map(\.id), ["c", "b"])
    }
}
