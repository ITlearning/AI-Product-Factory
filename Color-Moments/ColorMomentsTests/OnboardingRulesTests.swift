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
                       [.intro, .firstPebble, .birthday, .arrival, .reminder, .cloud, .howTo, .start])
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true, asksPlace: true),
                       [.intro, .firstPebble, .birthday, .place, .arrival, .reminder, .cloud, .howTo, .start],
                       "생일 말은 첫 조약돌 선물 바로 다음, 찍은 곳은 그 뒤")
    }

    func testDeniedOrEmptyLibrarySkipsFirstPebble() {
        XCTAssertTrue(OnboardingFlow.skipsFirstPebble(access: .denied, recentCount: nil))
        XCTAssertTrue(OnboardingFlow.skipsFirstPebble(access: .allowed, recentCount: 0))
        XCTAssertFalse(OnboardingFlow.skipsFirstPebble(access: .allowed, recentCount: 3))
        XCTAssertFalse(OnboardingFlow.skipsFirstPebble(access: .notDetermined, recentCount: nil),
                       "아직 묻지 않았으면 그 단계에서 묻는다")
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: true, asksArrival: true),
                       [.intro, .birthday, .arrival, .reminder, .cloud, .howTo, .start])
    }

    func testCloudRecordsReplaceFirstPebbleWithContinuing() {
        XCTAssertEqual(OnboardingFlow.steps(continuing: true, skipsFirstPebble: false, asksArrival: true),
                       [.intro, .continuing, .birthday, .arrival, .reminder, .howTo, .start])
    }

    func testArrivalStepOnlyWhenNotAsked() {
        XCTAssertFalse(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: false)
            .contains(.arrival))
    }

    func testEveryFlowEndsWithHowToThenStart() {
        for continuing in [false, true] {
            for skips in [false, true] {
                for asks in [false, true] {
                    let steps = OnboardingFlow.steps(continuing: continuing, skipsFirstPebble: skips, asksArrival: asks)
                    XCTAssertEqual(Array(steps.suffix(2)), [.howTo, .start],
                                   "continuing: \(continuing) skips: \(skips) asks: \(asks)")
                    XCTAssertEqual(steps.filter { $0 == .birthday }.count, 1, "생일 장은 어느 길로 와도 한 번")
                    XCTAssertFalse(steps.contains(.widget), "위젯 장은 플래그가 꺼져 있으면 없다")
                }
            }
        }
    }

    // MARK: 1.2 — 여덟 장(위젯 장은 플래그 뒤)

    func testDocumentedOrderWithWidgetStepOn() {
        let steps = OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true, showsWidget: true)
        XCTAssertEqual(steps, [.intro, .firstPebble, .birthday, .arrival, .reminder, .cloud, .howTo, .widget, .start])
        let core = steps.filter { $0 != .reminder }
        XCTAssertEqual(core.count, 8, "몽돌이란 → 첫 조약돌 → 생일 말 → 아침 소식 → iCloud → 찍는 법 → 위젯 → 시작")
    }

    func testWidgetStepOffFlowsSevenSteps() {
        XCTAssertFalse(OnboardingFlow.showsWidgetStep, "위젯(T5)이 들어오기 전엔 꺼져 있어야 한다")
        let steps = OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true)
        XCTAssertEqual(steps.filter { $0 != .reminder }.count, 7)
        XCTAssertEqual(Array(steps.suffix(2)), [.howTo, .start], "찍는 법에서 바로 시작하기로")
        XCTAssertEqual(OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true,
                                            hasCameraButton: true, showsWidget: true).suffix(3),
                       [.cameraButton, .widget, .start])
    }

    func testWidgetAttachNeedsKnownKind() {
        XCTAssertFalse(WidgetAttach.attached(kinds: ["com.itlearning.colormoments.pebble-widget"]),
                       "아직 알아챌 kind 가 없다 — 조약돌 위젯을 「붙었어요」로 치지 않는다")
        XCTAssertTrue(WidgetAttach.attached(kinds: ["a", "word"], wanted: ["word"]))
        XCTAssertFalse(WidgetAttach.attached(kinds: [], wanted: ["word"]))
    }

    // MARK: 생일 말

    @MainActor
    private func birthdayModel(dir: URL?) -> BirthdayWordModel {
        let words = [BirthdayWord(w: "윤슬", m: "햇빛이나 달빛에 비쳐 반짝이는 잔물결", months: []),
                     BirthdayWord(w: "꽃샘", m: "봄꽃이 필 무렵의 추위", months: [3])]
        let model = BirthdayWordModel(now: Date(timeIntervalSince1970: 1_760_000_000),
                                      picks: { dir.map { PickedWords(writer: .app, directory: $0) } },
                                      seed: { "fixed" }, words: { words })
        model.setMonth(3)
        return model
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("birthday-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @MainActor
    func testBirthdayKeepWritesFirstPickedWord() throws {
        let dir = try tempDir()
        let model = birthdayModel(dir: dir)
        model.setMonth(3)
        model.day = 14
        XCTAssertTrue(model.reveal())
        guard case .shown(let pick) = model.phase else { return XCTFail("말이 보여야 한다") }
        XCTAssertEqual(pick.word, "꽃샘")
        XCTAssertTrue(model.keep())
        XCTAssertEqual(model.phase, .kept(pick))
        let lines = PickedWords(writer: .app, directory: dir).livePicks()
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.source, .birthday)
        XCTAssertEqual(lines.first?.meaning, pick.meaning)
        XCTAssertNil(lines.first?.wordID)
        XCTAssertFalse(model.keep(), "두 번 담지 않는다")
        XCTAssertEqual(PickedWords(writer: .app, directory: dir).livePicks().count, 1)
    }

    @MainActor
    func testBirthdayKeepFailureShowsNoPick() throws {
        let file = try tempDir().appendingPathComponent("not-a-dir")
        try Data().write(to: file)
        let model = birthdayModel(dir: file)
        XCTAssertTrue(model.reveal())
        XCTAssertFalse(model.keep(), "쓰기 실패면 받았다고 하지 않는다")
        if case .kept = model.phase { XCTFail("「주웠어요」 상태로 가면 안 된다") }

        let noContainer = birthdayModel(dir: nil)
        XCTAssertTrue(noContainer.reveal())
        XCTAssertFalse(noContainer.keep())
    }

    @MainActor
    func testBirthdaySkipWritesNothingAndMovesOn() throws {
        let dir = try tempDir()
        let model = birthdayModel(dir: dir)
        XCTAssertEqual(model.phase, .ask)
        XCTAssertTrue(PickedWords(writer: .app, directory: dir).livePicks().isEmpty, "건너뛰면 아무것도 쓰지 않는다")
        let steps = OnboardingFlow.steps(continuing: false, skipsFirstPebble: false, asksArrival: true)
        let at = try XCTUnwrap(steps.firstIndex(of: .birthday))
        XCTAssertEqual(steps[at + 1], .arrival, "건너뛰기 → 아침 소식")
    }

    @MainActor
    func testBirthdayDayClampsToMonth() {
        let model = birthdayModel(dir: nil)
        model.setMonth(1)
        model.day = 31
        model.setMonth(2)
        XCTAssertEqual(model.day, 29)
        model.setMonth(4)
        XCTAssertEqual(model.day, 29)
        XCTAssertEqual(BirthdayWordModel.days(in: 4), 30)
    }

    @MainActor
    func testBirthdayWithoutListMovesOn() {
        let model = BirthdayWordModel(picks: { nil }, seed: { "x" }, words: { nil })
        XCTAssertFalse(model.reveal(), "목록을 못 읽으면 조용히 다음 장")
        XCTAssertEqual(model.phase, .ask)
    }

    @MainActor
    func testBirthdayPassingWordsSkipThePick() throws {
        let model = birthdayModel(dir: nil)
        model.day = 14
        XCTAssertTrue(model.reveal())
        XCTAssertFalse(model.passing.isEmpty, "굴림 동안 스쳐 갈 말이 있어야 한다")
        XCTAssertFalse(model.passing.contains("꽃샘"), "고른 말은 스쳐 가지 않는다")
        XCTAssertLessThanOrEqual(model.passing.count, BirthdayReveal.ticks.count)
    }

    func testBirthdayRevealBeats() {
        XCTAssertEqual(BirthdayReveal.land, 1.95, accuracy: 0.001, "웹처럼 0.25초에 굴리기 시작해 1.7초 굴린다")
        let ticks = BirthdayReveal.ticks
        XCTAssertEqual(ticks.first, 0)
        XCTAssertLessThan(ticks.last ?? 9, BirthdayReveal.rollSpan)
        let gaps = zip(ticks.dropFirst(), ticks).map { $0 - $1 }
        XCTAssertEqual(gaps, gaps.sorted(), "갈수록 느려진다")
        XCTAssertNil(BirthdayReveal.tick(at: 0.1, land: BirthdayReveal.land), "카드가 뜨는 동안은 아직 안 굴린다")
        XCTAssertEqual(BirthdayReveal.tick(at: 0.26, land: BirthdayReveal.land), 0)
        XCTAssertNil(BirthdayReveal.tick(at: 1.0, land: 0.9), "눌러서 멈추면 그때 내려앉는다")
        XCTAssertEqual(BirthdayReveal.curve(0), 0, accuracy: 0.001)
        XCTAssertEqual(BirthdayReveal.curve(1), 1, accuracy: 0.001)
        XCTAssertGreaterThan(BirthdayReveal.curve(0.3), 0.6, "앞이 빠른 웹 곡선(0.2, 0.8, 0.2, 1)")
        XCTAssertEqual(BirthdayRevealFollow.shown(t: 0.5, land: BirthdayReveal.land, still: false), 0, "버튼은 내려앉은 뒤에")
        XCTAssertEqual(BirthdayRevealFollow.shown(t: 5, land: BirthdayReveal.land, still: false), 1, accuracy: 0.001)
    }

    func testBirthdayCardSkyFollowsBirthMonth() {
        XCTAssertEqual(BirthdayCardSky.kind(month: 4), .petals)
        XCTAssertEqual(BirthdayCardSky.kind(month: 7), .sun)
        XCTAssertEqual(BirthdayCardSky.kind(month: 10), .leaves)
        XCTAssertEqual(BirthdayCardSky.kind(month: 1), .frost)
    }

    // MARK: 업데이트 안내

    func testUpdatingUserSeesNoticeOnce() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "update-\(UUID())"))
        XCTAssertEqual(UpdateNotice.pages(defaults, showsWidget: true), [.birthday, .widget], "두 장, 생일이 먼저")
        XCTAssertEqual(UpdateNotice.pages(defaults, showsWidget: false), [.birthday], "위젯 장은 플래그 뒤")
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: true, hasRecords: true,
                                                   didAskArrivalNotice: true,
                                                   updatePending: !UpdateNotice.pages(defaults).isEmpty), .update)
        UpdateNotice.markOffered(.birthday, defaults)
        XCTAssertEqual(UpdateNotice.pages(defaults, showsWidget: true), [.widget])
        UpdateNotice.markOffered(.widget, defaults)
        XCTAssertTrue(UpdateNotice.pages(defaults, showsWidget: true).isEmpty, "다시 뜨지 않는다")
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: true, hasRecords: true,
                                                   didAskArrivalNotice: true,
                                                   updatePending: !UpdateNotice.pages(defaults).isEmpty), .none)
    }

    func testUpdateNoticeComesBeforeArrivalAsk() {
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: false, hasRecords: true,
                                                   didAskArrivalNotice: false, updatePending: true), .update)
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: false, hasRecords: true,
                                                   didAskArrivalNotice: false, updatePending: false), .arrivalAskOnly)
        XCTAssertEqual(OnboardingGate.resolve(.update, noticePermission: nil), .update, "알림 권한과 상관없다")
        XCTAssertFalse(OnboardingGate.swipeOpensCamera(.update))
    }

    func testNewUserNeverSeesUpdateNotice() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "new-\(UUID())"))
        XCTAssertEqual(OnboardingGate.presentation(isLoaded: true, didFinishOnboarding: false, hasRecords: false,
                                                   didAskArrivalNotice: false,
                                                   updatePending: !UpdateNotice.pages(defaults).isEmpty), .full,
                       "새 사용자는 온보딩 안에서 생일 장을 본다")
        UpdateNotice.markOnboardingFinished(defaults)
        XCTAssertTrue(UpdateNotice.pages(defaults).isEmpty, "온보딩을 마치면 업데이트 장은 뜨지 않는다")
        XCTAssertEqual(UpdateNotice.pages(defaults, showsWidget: true), [.widget],
                       "위젯 장을 못 본 채 마쳤으면 위젯이 켜진 뒤 그 장만 한 번")
        let shown = try XCTUnwrap(UserDefaults(suiteName: "new-w-\(UUID())"))
        UpdateNotice.markOnboardingFinished(shown, showsWidget: true)
        XCTAssertTrue(UpdateNotice.pages(shown, showsWidget: true).isEmpty)
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

