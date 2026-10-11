import XCTest
@testable import ColorMoments

final class ReviewPromptTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "ReviewPromptTests")
        defaults.removePersistentDomain(forName: "ReviewPromptTests")
    }

    func testFirstPebbleDoesNotAsk() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(giftedDays: 1, askedVersion: nil, currentVersion: "1.1.2"),
                       "온보딩 첫 조약돌만 받은 사람에게는 묻지 않는다")
    }

    func testSecondPebbleAsks() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(giftedDays: 2, askedVersion: nil, currentVersion: "1.1.2"))
    }

    func testAskedThisVersionDoesNotAskAgain() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(giftedDays: 5, askedVersion: "1.1.2", currentVersion: "1.1.2"))
    }

    func testNewVersionAsksAgain() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(giftedDays: 5, askedVersion: "1.1.2", currentVersion: "1.2"))
    }

    func testClaimOnlyOncePerVersion() {
        XCTAssertTrue(ReviewPrompt.claim(giftedDays: 2, defaults: defaults, currentVersion: "1.1.2"))
        XCTAssertFalse(ReviewPrompt.claim(giftedDays: 3, defaults: defaults, currentVersion: "1.1.2"))
    }

    func testClaimDoesNotRecordWhenNotAsking() {
        XCTAssertFalse(ReviewPrompt.claim(giftedDays: 1, defaults: defaults, currentVersion: "1.1.2"))
        XCTAssertNil(defaults.string(forKey: ReviewPrompt.askedVersionKey))
    }
}
