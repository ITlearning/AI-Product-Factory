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

    // MARK: 아침 소식 질문

    func testArrivalAskOnlyWhenPermissionUndetermined() {
        XCTAssertEqual(ArrivalAsk.decision(.notDetermined), .ask)
        XCTAssertEqual(ArrivalAsk.decision(.allowed), .skip(syncs: true), "허락한 기기는 묻지 않고 예약만 맞춘다")
        XCTAssertEqual(ArrivalAsk.decision(.denied), .skip(syncs: false))
    }

    func testArrivalAskOverlayWaitsForPermissionAndSkipsWhenDecided() {
        XCTAssertEqual(OnboardingGate.resolve(.arrivalAskOnly, noticePermission: nil), .undecided,
                       "권한을 읽기 전엔 띄우지 않는다 — 떴다 사라지지 않게")
        XCTAssertEqual(OnboardingGate.resolve(.arrivalAskOnly, noticePermission: .notDetermined), .arrivalAskOnly)
        XCTAssertEqual(OnboardingGate.resolve(.arrivalAskOnly, noticePermission: .allowed), .none)
        XCTAssertEqual(OnboardingGate.resolve(.arrivalAskOnly, noticePermission: .denied), .none)
        XCTAssertEqual(OnboardingGate.resolve(.full, noticePermission: nil), .full, "전체 온보딩은 그대로")
        XCTAssertEqual(OnboardingGate.resolve(.none, noticePermission: .notDetermined), .none)
    }

    // MARK: 카메라 컨트롤로 열렸을 때

    func testSwipeOpensCameraOnlyWithoutGuideLayer() {
        XCTAssertTrue(OnboardingGate.swipeOpensCamera(.none))
        XCTAssertTrue(OnboardingGate.swipeOpensCamera(.undecided), "로드 전엔 아무것도 덮고 있지 않다")
        XCTAssertFalse(OnboardingGate.swipeOpensCamera(.full), "온보딩의 옆으로 넘기기와 겹친다")
        XCTAssertFalse(OnboardingGate.swipeOpensCamera(.arrivalAskOnly))
    }

    // MARK: 단계

    func testFullFlow() {
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true),
                       [.intro, .firstPebble, .arrival, .reminder, .cloud, .howTo, .collection, .start])
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true, asksPlace: true),
                       [.intro, .firstPebble, .place, .arrival, .reminder, .cloud, .howTo, .collection, .start],
                       "찍은 곳은 첫 조약돌을 본 바로 뒤 — 사진 옆에 무엇이 붙는지 이어서 보여 준다")
    }

    func testDeniedOrEmptyLibrarySkipsFirstPebble() {
        XCTAssertTrue(OnboardingFlow.skipsFirstPebble(access: .denied, recentCount: nil))
        XCTAssertTrue(OnboardingFlow.skipsFirstPebble(access: .allowed, recentCount: 0))
        XCTAssertFalse(OnboardingFlow.skipsFirstPebble(access: .allowed, recentCount: 3))
        XCTAssertFalse(OnboardingFlow.skipsFirstPebble(access: .notDetermined, recentCount: nil),
                       "아직 묻지 않았으면 그 단계에서 묻는다")
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: true, asksArrival: true),
                       [.intro, .arrival, .reminder, .cloud, .howTo, .collection, .start])
    }

    func testCloudRecordsReplaceFirstPebbleWithContinuing() {
        XCTAssertEqual(OnboardingFlow.steps(continuing: true, skipsFirstPebble: false, asksArrival: true),
                       [.intro, .continuing, .arrival, .reminder, .howTo, .collection, .start])
    }

    func testArrivalStepOnlyWhenNotAsked() {
        XCTAssertFalse(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: false)
            .contains(.arrival))
    }

    func testEveryFlowEndsWithHowToThenCollectionThenStart() {
        for continuing in [false, true] {
            for skips in [false, true] {
                for asks in [false, true] {
                    let steps = OnboardingFlow.steps(continuing: continuing, skipsFirstPebble: skips, asksArrival: asks)
                    XCTAssertEqual(Array(steps.suffix(3)), [.howTo, .collection, .start],
                                   "continuing: \(continuing) skips: \(skips) asks: \(asks)")
                    XCTAssertEqual(steps.filter { $0 == .collection }.count, 1)
                }
            }
        }
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

    // MARK: 받기 결과 문구

    func testReceivedCopyForGift() {
        XCTAssertEqual(ReceivedCopy.text(.gift("2026-09-20"), addedCount: 3, dayGifted: false),
                       .init(title: "첫 조약돌을 받았어요", detail: "홈에서 언제든 다시 볼 수 있어요."))
    }

    func testReceivedCopyForAddedToGiftedDay() {
        XCTAssertEqual(ReceivedCopy.text(.added, addedCount: 4, dayGifted: true),
                       .init(title: "4장 더 담겼어요", detail: "이미 받은 하루라 조약돌 색은 그대로예요"))
        XCTAssertEqual(ReceivedCopy.text(.added, addedCount: 2, dayGifted: false),
                       .init(title: "2장 더 담겼어요", detail: nil), "받기 전 하루엔 색이 그대로라고 말하지 않는다")
        XCTAssertEqual(ReceivedCopy.text(.added, addedCount: 0, dayGifted: true).title, "사진이 담겼어요",
                       "몇 장인지 못 세면 장 수를 적지 않는다")
    }

    func testReceivedCopyForTodayOnly() {
        XCTAssertEqual(ReceivedCopy.text(.todayOnly, addedCount: 2, dayGifted: false),
                       .init(title: "오늘 진행 중에 담겼어요", detail: "색은 자정에 열려요"))
    }

    func testReceivedFocusDayPrefersLatestPastDay() {
        let today = "2026-09-22"
        XCTAssertEqual(ReceivedCopy.focusDay(importedDayKeys: ["2026-09-19", "2026-09-21", today], today: today),
                       "2026-09-21")
        XCTAssertEqual(ReceivedCopy.focusDay(importedDayKeys: [today], today: today), today)
        XCTAssertNil(ReceivedCopy.focusDay(importedDayKeys: [], today: today))
    }

    func testStartPebbleIsLatestGiftedDayOnly() {
        XCTAssertEqual(StartScene.latestGiftedDay(dayKeys: ["2026-09-22", "2026-09-21", "2026-09-20"],
                                                  isGifted: { $0 <= "2026-09-21" }), "2026-09-21")
        XCTAssertNil(StartScene.latestGiftedDay(dayKeys: ["2026-09-22"], isGifted: { _ in false }),
                     "받은 조약돌이 없으면 점선 빈 돌")
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

    func testLayoutAppendsInArrivalOrderWithoutMovingShownCells() {
        XCTAssertEqual(SuggestionScore.layout(shown: ["a", "b"], arriving: "c", score: 0.9, maxShown: 4),
                       ["a", "b", "c"], "점수가 높아도 앞에 끼어들지 않고 뒤에 붙는다")
        XCTAssertEqual(SuggestionScore.layout(shown: [], arriving: "a", score: -0.8, maxShown: 4), ["a"])
    }

    func testLayoutSkipsUtilityDuplicatesAndOverflow() {
        XCTAssertEqual(SuggestionScore.layout(shown: ["a"], arriving: "u", score: nil, maxShown: 4), ["a"],
                       "실용 사진(점수 없음)은 붙이지 않는다")
        XCTAssertEqual(SuggestionScore.layout(shown: ["a", "b"], arriving: "a", score: 0.5, maxShown: 4), ["a", "b"])
        XCTAssertEqual(SuggestionScore.layout(shown: ["a", "b", "c"], arriving: "d", score: 0.5, maxShown: 3),
                       ["a", "b", "c"], "상한을 넘으면 붙이지 않는다")
    }

    func testCloudPileRisesAndStaysDeterministic() {
        let slots = (0..<CloudPile.maxVisible).map(CloudPile.slot)
        for (a, b) in zip(slots, slots.dropFirst()) { XCTAssertGreaterThan(b.rise, a.rise, "한 알씩 조금 더 위") }
        XCTAssertTrue(slots.allSatisfy { abs($0.angle) <= 6 })
        XCTAssertLessThan(CloudPile.rise, 16, "앞 돌과 겹칠 만큼만 올라간다")
        XCTAssertEqual(Set(slots.map(\.x)).count, slots.count, "좌우로 엇갈린다")
    }
}
