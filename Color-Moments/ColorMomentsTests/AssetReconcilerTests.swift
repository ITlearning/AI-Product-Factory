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
}
