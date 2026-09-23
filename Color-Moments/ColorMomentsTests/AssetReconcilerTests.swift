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

    // MARK: 옵저버(removedObjects) 경로 상한

    func testObserverRemovalOverCapIsSkipped() {
        let removed = Set((0..<10).map { "id\($0)" })
        XCTAssertTrue(AssetReconciler.cappedRemoval(removed, tracked: 10).isEmpty,
                      "iCloud 사진 끄기처럼 한 번에 전부 빠지면 그 삭제가 모든 기기로 번진다 — 그 회차는 건너뛴다")
    }

    func testObserverRemovalUnderCapPasses() {
        let removed: Set<String> = ["a", "b", "c"]
        XCTAssertEqual(AssetReconciler.cappedRemoval(removed, tracked: 4), removed, "상한 max(3, n/5) 이하면 그대로 지운다")
        let many = Set((0..<20).map { "id\($0)" })
        XCTAssertEqual(AssetReconciler.cappedRemoval(many, tracked: 100), many)
        XCTAssertTrue(AssetReconciler.cappedRemoval(Set((0..<21).map { "id\($0)" }), tracked: 100).isEmpty)
    }

    // MARK: 폴링 정리 — cloudID 로 다시 찾기

    func testRelocatedAssetIsReassignedNotRemoved() {
        let ids = Set((0..<10).map { "id\($0)" })
        let found = ids.subtracting(["id8", "id9"])
        let plan = AssetReconciler.plan(ids: ids, found: found, relocated: ["id8": "new8"], fullAccess: true)
        XCTAssertEqual(plan.reassign, ["id8": "new8"], "cloudID 로 다시 찾은 사진은 지우지 않고 ID 만 바꿔 끼운다")
        XCTAssertEqual(plan.remove, ["id9"])
    }

    func testRestoredLibraryWithAllIDsChangedReassignsEverything() {
        let ids: Set<String> = ["a", "b", "c", "d", "e"]
        let relocated = Dictionary(uniqueKeysWithValues: ids.map { ($0, $0 + "'") })
        let plan = AssetReconciler.plan(ids: ids, found: [], relocated: relocated, fullAccess: true)
        XCTAssertEqual(plan.reassign, relocated, "복원 뒤 로컬 ID 가 전부 바뀌어도 cloudID 로 다시 찾는다")
        XCTAssertTrue(plan.remove.isEmpty)
    }

    func testRelocationToSameIDCountsAsMissing() {
        let ids = Set((0..<10).map { "id\($0)" })
        let found = ids.subtracting(["id9"])
        let plan = AssetReconciler.plan(ids: ids, found: found, relocated: ["id9": "id9"], fullAccess: true)
        XCTAssertTrue(plan.reassign.isEmpty)
        XCTAssertEqual(plan.remove, ["id9"])
    }

    func testRelocationKeepsCapForTheRest() {
        let ids = Set((0..<10).map { "id\($0)" })
        let found: Set<String> = ["id0"]
        let plan = AssetReconciler.plan(ids: ids, found: found, relocated: ["id1": "n1"], fullAccess: true)
        XCTAssertEqual(plan.reassign, ["id1": "n1"])
        XCTAssertTrue(plan.remove.isEmpty, "다시 찾고 남은 8개는 여전히 상한을 넘는다 — 지우지 않는다")
    }

    func testPlanDoesNothingWithoutFullAccess() {
        let plan = AssetReconciler.plan(ids: ["a", "b"], found: ["a"], relocated: ["b": "b2"], fullAccess: false)
        XCTAssertTrue(plan.reassign.isEmpty)
        XCTAssertTrue(plan.remove.isEmpty)
    }
}
