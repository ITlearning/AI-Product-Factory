import XCTest
@testable import ColorMoments

final class AssetReconcilerTests: XCTestCase {

    func testFullAccessReturnsMissingIDs() {
        let ids: Set<String> = ["a", "b", "c"]
        let found: Set<String> = ["a"]
        XCTAssertEqual(AssetReconciler.missing(ids: ids, found: found, fullAccess: true), ["b", "c"],
                       "전체 접근이면 사진 앱에서 못 찾은 에셋을 정리 대상으로 돌려줘야 한다")
    }

    func testLimitedAccessAlwaysReturnsEmpty() {
        let ids: Set<String> = ["a", "b", "c"]
        let found: Set<String> = ["a"]
        XCTAssertTrue(AssetReconciler.missing(ids: ids, found: found, fullAccess: false).isEmpty,
                      "제한 접근에서는 못 찾은 사진이라도 지우면 안 된다 — 선택 안 한 사진일 뿐이다")
    }

    func testAllFoundReturnsEmpty() {
        let ids: Set<String> = ["a", "b"]
        let found: Set<String> = ["a", "b"]
        XCTAssertTrue(AssetReconciler.missing(ids: ids, found: found, fullAccess: true).isEmpty,
                      "다 찾았으면 정리할 게 없다")
    }

    func testAllNotFoundSkipsInsteadOfWipingEverything() {
        let ids: Set<String> = ["a", "b", "c"]
        XCTAssertTrue(AssetReconciler.missing(ids: ids, found: [], fullAccess: true).isEmpty,
                      "found 가 통째로 비면 조회 자체가 실패했을 수 있다 — 기록 전체를 지우면 안 된다")
    }

    func testOverCapSkipsThatRound() {
        let ids = Set((0..<10).map { "id\($0)" })
        let found: Set<String> = ["id0"] // 9개가 못 찾은 것 — 상한 max(3, 10/5=2)=3 을 넘는다
        XCTAssertTrue(AssetReconciler.missing(ids: ids, found: found, fullAccess: true).isEmpty,
                      "한 번에 지울 개수가 상한을 넘으면 그 회차는 건너뛰어야 한다")
    }

    func testUnderCapDeletes() {
        let ids = Set((0..<10).map { "id\($0)" })
        let found = Set((0..<8).map { "id\($0)" }) // 2개만 못 찾음 — 상한 3 이하
        let missing = AssetReconciler.missing(ids: ids, found: found, fullAccess: true)
        XCTAssertEqual(missing, ["id8", "id9"], "상한 이하면 정상적으로 지워야 한다")
    }
}
