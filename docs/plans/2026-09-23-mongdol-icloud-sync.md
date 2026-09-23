# 몽돌 iCloud 연동 · 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

상태 **completed** · 2026-09-23 · 브랜치 `feat/mongdol-day-gift`

**Goal:** 몽돌 기록(색·단어·날짜·장소·마무리·증정)을 CloudKit 개인 DB로 기기 사이에 동기화하고, 사진은 `PHCloudIdentifier` 로 각 기기에서 다시 찾는다.

**Architecture:** 로컬 `days.json` 이 원본이고 CloudKit 은 그 복제본이다. `DayStore`·`DayClosures`·`GiftLog` 가 로컬 쓰기마다 변경을 알리고, 앱 타깃의 `CloudSync`(`CKSyncEngine` 위임자)가 그 변경을 올리고 받은 변경을 `applyRemote` 로 되돌려 넣는다. 합치기 규칙은 `Shared/` 의 순수 함수(`MomentMerge`)라 CloudKit 없이 테스트된다.

**Tech Stack:** Swift 5.10, SwiftUI, iOS 18, CloudKit `CKSyncEngine`, PhotoKit `PHCloudIdentifier`, XCTest, xcodegen.

**Spec:** `docs/designs/mongdol-icloud-sync.md` (Tabber 대화 승인 2026-09-23)

## Global Constraints

- iOS 18.0, 외부 의존성 0. `Shared/` 는 **Photos·CloudKit 을 import 하지 않는다**(잠금화면 확장이 컴파일한다). 동기화 코드는 앱 타깃 `ColorMoments/Sync/` 만.
- 사진 파일·`assetID`·`fileName`·`originalName` 은 **절대 올리지 않는다.**
- 지우기는 이 기기에서 `assetID` 가 채워진(실제로 본) 사진만. 기존 `AssetReconciler` 안전장치(`.authorized`만 · 빈 조회 안 지움 · `max(3, 20%)` 상한 · 옵저버는 `removedObjects`만)를 바꾸지 않는다.
- 다른 기기에서 온 변경(`applyRemote`)은 변경 알림을 내지 않는다 — 되돌아 올라가지 않는다.
- 합치기: word·labels 는 **서버에 word 가 있으면 서버, 없으면 이 기기** · `closedAt` 는 이른 쪽 · `gifted` 는 OR · 같은 cloudID 두 기록은 `capturedAt` 이른 쪽, 같으면 `id.uuidString` 작은 쪽.
- 증정은 어느 기기에서든 한 번. 후보는 「가장 최근 자연히 끝난 하루 하나」와 「마무리한 오늘」뿐(밀린 날을 줄줄이 증정하지 않는다 — `GiftSchedule.pending` 규칙은 바꾸지 않는다).
- `DayStore.init` 은 `closures` 기본값이 없다 — 테스트는 `DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)` 를 넘긴다.
- iCloud 계정이 없으면 로컬로만 돈다. 설정 화면·안내 없음.
- CloudKit 컨테이너 `iCloud.com.itlearning.colormoments`, 존 이름 `Mongdol`, 레코드 타입 `Moment`(recordName `m-<uuid>`) · `Day`(recordName `d-<yyyy-MM-dd>`).
- 테스트는 `perl -e 'alarm 240; exec @ARGV' xcodebuild test -project ColorMoments.xcodeproj -scheme ColorMoments -destination 'platform=iOS Simulator,id=586BD801-ADAD-4A22-B184-451C8B0C91EF'` (worktree 는 `0E276ADC-03B7-4937-82AF-682DED81DBE4`). 멈추면 shutdown→boot 1회, 또 멈추면 BLOCKED. 새 파일을 만들면 먼저 `xcodegen generate`. 시뮬레이터 스크린샷·실기기 설치 금지.
- 코드 주석은 함정만 한 줄(한국어). 단계마다 커밋, 경로 지정 `git add`, 끝줄 `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. `.env` 는 건드리지 않는다.

## Review Focus

1. **테스트 호스트에서 CloudKit 이 뜨는 경우** — 유닛 테스트는 앱을 호스트로 띄운다. `CKContainer(identifier:)` 는 권한(entitlement)이 없으면 크래시한다. 테스트 실행 중에는 `CloudSync` 를 만들지 않아야 한다 → Task 5 에 가드 + 스위트가 그대로 통과하는지.
2. **같은 사진을 두 기기가 따로 담았는데 cloudID 가 나중에 붙는 경우** — 받을 때는 아직 cloudID 가 없어 중복 판정을 못 하고, 이 기기에서 `setCloudID` 할 때 겹친다. `setCloudID` 도 중복을 합쳐야 한다 → Task 1 테스트.
3. **받은 기록이 옛 입양 흐름(`adoptAll`)에 잡히는 경우** — 받은 기록은 `assetID == nil` 이라 지금 `fileBacked` 에 들어가 없는 파일을 사진 앱에 저장하려 한다. `fileBacked` 에서 자리 이름(`asset-`·`remote-`)을 빼야 한다 → Task 1 테스트.
4. **iCloud 계정 로그아웃·전환** — 로컬 기록은 그대로 남아야 하고 지워지면 안 된다. 엔진 상태만 버린다 → Task 5 코드(테스트 불가, 실기기 목록).
5. **다른 기기에서 받은 증정·마무리가 되돌아 올라가는 경우** — `applyRemote` 가 `onLocalChange` 를 부르면 두 기기가 같은 기록을 끝없이 주고받는다 → Task 1·2 테스트(`testApplyRemoteDoesNotNotify`, `testGiftLogNotifiesLocalOnlyAndPersists`).

---

### Task 1 (Shared): Moment.cloudID · 합치기 규칙 · DayStore 변경 알림과 받기

**Files:**
- Modify: `Color-Moments/Shared/Day/Moment.swift`
- Create: `Color-Moments/Shared/Day/MomentMerge.swift`
- Modify: `Color-Moments/Shared/Day/DayStore.swift`
- Test: `Color-Moments/ColorMomentsTests/MomentMergeTests.swift`(새), `Color-Moments/ColorMomentsTests/DayStoreTests.swift`

**Interfaces:**
- Produces:
  - `Moment.cloudID: String?` (init 끝에 `cloudID: String? = nil`)
  - `Moment.receivedFileName(cloudID: String?, id: UUID) -> String`
  - `enum StoreChange: Equatable, Sendable { case upsert(Moment.ID), delete(Moment.ID) }`
  - `MomentMerge.merge(local:remote:) -> Moment`, `MomentMerge.keeps(_:over:) -> Bool`, `MomentMerge.syncedEqual(_:_:) -> Bool`
  - `DayStore.onLocalChange: (([StoreChange]) -> Void)?`
  - `DayStore.applyRemote(upserts: [Moment], deletes: Set<Moment.ID>) -> [StoreChange]` (@discardableResult — 되돌려 올릴 변경)
  - `DayStore.setCloudID(_ id: Moment.ID, _ cloudID: String)`
  - `DayStore.resolveAsset(_ id: Moment.ID, assetID: String)`
  - `DayStore.unresolved: [Moment]` (cloudID 있고 assetID 없음)
  - `DayStore.moment(_ id: Moment.ID) -> Moment?`

- [ ] **Step 1: 실패하는 테스트 — MomentMergeTests.swift**

```swift
import XCTest
@testable import ColorMoments

final class MomentMergeTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private let word = PhotoWord(wordID: "w1", word: "윤슬", meaning: "햇빛에 반짝이는 잔물결")

    private func m(id: UUID = UUID(), at: Date? = nil, word: PhotoWord? = nil, labels: [String]? = nil,
                   assetID: String? = nil, cloudID: String? = nil, file: String = "f.jpg") -> Moment {
        Moment(id: id, capturedAt: at ?? t0, colorHex: "#112233", fileName: file, source: .app,
               word: word, labels: labels, assetID: assetID, cloudID: cloudID)
    }

    func testServerWordWinsWhenPresent() {
        let id = UUID()
        let local = m(id: id, word: PhotoWord(wordID: "w2", word: "노을", meaning: "x"), labels: ["sky"])
        let remote = m(id: id, word: word, labels: ["water"])
        let merged = MomentMerge.merge(local: local, remote: remote)
        XCTAssertEqual(merged.word, word)
        XCTAssertEqual(merged.labels, ["water"])
    }

    func testLocalWordKeptWhenServerHasNone() {
        let id = UUID()
        let merged = MomentMerge.merge(local: m(id: id, word: word, labels: ["water"]), remote: m(id: id))
        XCTAssertEqual(merged.word, word)
        XCTAssertEqual(merged.labels, ["water"])
    }

    func testDeviceOnlyFieldsStayLocal() {
        let id = UUID()
        let merged = MomentMerge.merge(local: m(id: id, assetID: "LOCAL/1", file: "asset-abc"),
                                       remote: m(id: id, cloudID: "CLOUD", file: "remote-x"))
        XCTAssertEqual(merged.assetID, "LOCAL/1")
        XCTAssertEqual(merged.fileName, "asset-abc")
        XCTAssertEqual(merged.cloudID, "CLOUD")
    }

    func testKeepsIsDeterministic() {
        let a = m(at: t0), b = m(at: t0.addingTimeInterval(1))
        XCTAssertTrue(MomentMerge.keeps(a, over: b))
        XCTAssertFalse(MomentMerge.keeps(b, over: a))
        let x = m(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let y = m(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        XCTAssertTrue(MomentMerge.keeps(x, over: y))
        XCTAssertFalse(MomentMerge.keeps(y, over: x))
    }

    func testSyncedEqualIgnoresDeviceOnlyFields() {
        let id = UUID()
        XCTAssertTrue(MomentMerge.syncedEqual(m(id: id, assetID: "A", file: "a"), m(id: id, assetID: nil, file: "b")))
        XCTAssertFalse(MomentMerge.syncedEqual(m(id: id), m(id: id, word: word, labels: ["x"])))
    }
}
```

`PhotoWord` 의 실제 init 인자 이름은 `Shared/Word/` 에서 확인해 맞춘다.

- [ ] **Step 2: 실행 — 컴파일 실패(`cloudID`·`MomentMerge` 없음) 확인**

Run: `xcodegen generate && perl -e 'alarm 240; exec @ARGV' xcodebuild test ... -only-testing:ColorMomentsTests/MomentMergeTests 2>&1 | tail -20`
Expected: FAIL (`cannot find 'MomentMerge'`)

- [ ] **Step 3: Moment.cloudID + receivedFileName**

`Moment.swift` — 필드 `public var cloudID: String?` 를 `originalName` 아래에, init 마지막 인자 `cloudID: String? = nil`. 확장에:

```swift
    /// 다른 기기에서 받은 기록의 자리 이름 — 파일은 없다. cloudID 가 있으면 사진 기준이라 기기마다 같다.
    static func receivedFileName(cloudID: String?, id: UUID) -> String {
        cloudID.map { "asset-" + String(WordPicker.fnv1a($0), radix: 16) } ?? "remote-\(id.uuidString)"
    }
```

`DayStore.adopt` 가 `Moment(...)` 를 새로 만들 때 `cloudID: m.cloudID` 를 넘긴다(빠뜨리면 입양 때 cloudID 가 사라진다).

- [ ] **Step 4: MomentMerge.swift**

```swift
import Foundation

public enum StoreChange: Equatable, Sendable {
    case upsert(Moment.ID)
    case delete(Moment.ID)
}

public enum MomentMerge {

    /// remote = 서버. fileName·assetID·originalName 은 이 기기 전용이라 local 것을 쓴다.
    public static func merge(local: Moment, remote: Moment) -> Moment {
        let useRemoteWord = remote.word != nil
        return Moment(id: remote.id, capturedAt: remote.capturedAt, colorHex: remote.colorHex,
                      fileName: local.fileName, source: remote.source,
                      word: useRemoteWord ? remote.word : local.word,
                      labels: useRemoteWord ? remote.labels : (local.labels ?? remote.labels),
                      assetID: local.assetID, place: remote.place ?? local.place,
                      addedAt: remote.addedAt ?? local.addedAt, batchID: remote.batchID ?? local.batchID,
                      originalName: local.originalName, cloudID: remote.cloudID ?? local.cloudID)
    }

    /// 같은 사진이 두 기록일 때 a 를 남기나. 두 기기가 따로 계산해도 같은 답이어야 한다.
    public static func keeps(_ a: Moment, over b: Moment) -> Bool {
        if a.capturedAt != b.capturedAt { return a.capturedAt < b.capturedAt }
        return a.id.uuidString < b.id.uuidString
    }

    public static func syncedEqual(_ a: Moment, _ b: Moment) -> Bool {
        a.id == b.id && a.capturedAt == b.capturedAt && a.colorHex == b.colorHex && a.source == b.source
            && a.word == b.word && a.labels == b.labels && a.place == b.place && a.addedAt == b.addedAt
            && a.batchID == b.batchID && a.cloudID == b.cloudID
    }
}
```

- [ ] **Step 5: MomentMergeTests 통과 확인** — Expected: PASS 5

- [ ] **Step 6: DayStore 실패 테스트 추가 (DayStoreTests.swift)**

```swift
    func testLocalWritesNotifyChanges() {
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        let a = moment(date(2026, 9, 20, 12))
        store.add(a)
        store.setLabels(a.id, ["sky"])
        store.remove(assetIDs: [])  // 아무것도 안 지우면 알림 없음
        XCTAssertEqual(got, [.upsert(a.id), .upsert(a.id)])
    }

    func testRemoveByAssetNotifiesDelete() {
        var got: [StoreChange] = []
        let a = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-1",
                       source: .library, assetID: "L/1")
        store.add(a)
        store.onLocalChange = { got += $0 }
        store.remove(assetIDs: ["L/1"])
        XCTAssertEqual(got, [.delete(a.id)])
    }

    func testApplyRemoteDoesNotNotify() {
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        let r = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111",
                       fileName: "remote-x", source: .app, cloudID: "C1")
        store.applyRemote(upserts: [r], deletes: [])
        store.applyRemote(upserts: [], deletes: [r.id])
        XCTAssertTrue(got.isEmpty)
        XCTAssertTrue(store.moments.isEmpty)
    }

    func testApplyRemoteKeepsLocalAssetAndReturnsPushWhenLocalKnowsMore() {
        let a = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-1",
                       source: .app, word: PhotoWord(wordID: "w", word: "윤슬", meaning: "m"),
                       labels: ["water"], assetID: "L/1")
        store.add(a)
        let server = Moment(id: a.id, capturedAt: a.capturedAt, colorHex: a.colorHex,
                            fileName: "remote-x", source: .app, cloudID: "C1")
        let push = store.applyRemote(upserts: [server], deletes: [])
        let now = store.moment(a.id)!
        XCTAssertEqual(now.assetID, "L/1")
        XCTAssertEqual(now.cloudID, "C1")
        XCTAssertEqual(now.word?.word, "윤슬")
        XCTAssertEqual(push, [.upsert(a.id)], "서버에 없는 단어를 이 기기가 알고 있으면 다시 올린다")
    }

    func testSameCloudIDKeepsEarlierAndDeletesLoser() {
        let early = date(2026, 9, 20, 12), late = date(2026, 9, 20, 12, 1)
        let local = Moment(capturedAt: late, colorHex: "#111111", fileName: "asset-1",
                           source: .library, assetID: "L/1", cloudID: "C1")
        store.add(local)
        let remote = Moment(capturedAt: early, colorHex: "#111111", fileName: "asset-c",
                            source: .library, cloudID: "C1")
        let push = store.applyRemote(upserts: [remote], deletes: [])
        XCTAssertEqual(store.moments.map(\.id), [remote.id])
        XCTAssertEqual(store.moments.first?.assetID, "L/1", "이긴 기록도 이 기기 에셋 연결은 이어받는다")
        XCTAssertEqual(push, [.delete(local.id)])
    }

    func testSetCloudIDMergesDuplicate() {
        let early = date(2026, 9, 20, 12), late = date(2026, 9, 20, 12, 1)
        let received = Moment(capturedAt: early, colorHex: "#111111", fileName: "asset-c",
                              source: .library, cloudID: "C1")
        store.applyRemote(upserts: [received], deletes: [])
        let mine = Moment(capturedAt: late, colorHex: "#111111", fileName: "asset-1",
                          source: .library, assetID: "L/1")
        store.add(mine)
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        store.setCloudID(mine.id, "C1")
        XCTAssertEqual(store.moments.map(\.id), [received.id])
        XCTAssertEqual(store.moments.first?.assetID, "L/1")
        XCTAssertEqual(got, [.delete(mine.id), .upsert(received.id)])
    }

    func testReceivedMomentsAreNotFileBackedAndResolveLater() {
        let r = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111",
                       fileName: Moment.receivedFileName(cloudID: "C1", id: UUID()), source: .app, cloudID: "C1")
        let orphan = Moment(capturedAt: date(2026, 9, 20, 13), colorHex: "#111111",
                            fileName: Moment.receivedFileName(cloudID: nil, id: UUID()), source: .app)
        store.applyRemote(upserts: [r, orphan], deletes: [])
        XCTAssertTrue(store.fileBacked.isEmpty, "받은 기록은 이 기기에 파일이 없다 — 입양 대상 아님")
        XCTAssertEqual(store.unresolved.map(\.id), [r.id])
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        store.resolveAsset(r.id, assetID: "L/9")
        XCTAssertEqual(store.moment(r.id)?.assetID, "L/9")
        XCTAssertTrue(store.unresolved.isEmpty)
        XCTAssertTrue(got.isEmpty, "assetID 는 이 기기 전용 — 올릴 것 없음")
    }

    func testOldJSONWithoutCloudIDStillLoads() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-20T03:00:00Z","colorHex":"#111111",
          "fileName":"shot-1.jpg","source":"app"}]
        """
        try Data(json.utf8).write(to: tempFile)
        let reloaded = DayStore(fileURL: tempFile, closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        XCTAssertEqual(reloaded.moments.count, 1)
        XCTAssertNil(reloaded.moments.first?.cloudID)
    }
```

- [ ] **Step 7: 실행 — 실패 확인**

- [ ] **Step 8: DayStore 구현**

- `public var onLocalChange: (([StoreChange]) -> Void)?` — `@ObservationIgnored` 를 붙인다(클로저는 관찰 대상 아님).
- `add` 성공 시 `onLocalChange?([.upsert(moment.id)])`. `assignWord`·`setLabels` 가 실제로 바꾸면 `.upsert(id)`. `adopt` 는 알리지 않는다(바뀌는 필드가 이 기기 전용). `remove(assetIDs:)` 는 지운 기록들의 `.delete(id)`. `removeAll` 은 알리지 않는다(로컬 디버그 초기화 전용).
- `public func moment(_ id: Moment.ID) -> Moment? { moments.first { $0.id == id } }`
- `fileBacked`:

```swift
    /// 이 기기에 원본 파일이 있는 기록만 — 자리 이름(asset-·remote-)은 파일이 없다.
    public var fileBacked: [Moment] {
        moments.filter { $0.assetID == nil && !$0.fileName.hasPrefix("asset-") && !$0.fileName.hasPrefix("remote-") }
    }

    public var unresolved: [Moment] { moments.filter { $0.assetID == nil && $0.cloudID != nil } }
```

- `resolveAsset(_:assetID:)` — `adopt` 와 같은 재구성(fileName 을 `Moment.assetFileName(for: assetID)` 로, cloudID 유지)을 하되 조건은 `assetID == nil`. `save()`, 알림 없음. adopt 와 공통 부분은 private 함수 하나로.
- `setCloudID`:

```swift
    public func setCloudID(_ id: Moment.ID, _ cloudID: String) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].cloudID == nil else { return }
        moments[i].cloudID = cloudID
        if let j = moments.firstIndex(where: { $0.id != id && $0.cloudID == cloudID }) {
            let (winner, loser) = MomentMerge.keeps(moments[i], over: moments[j]) ? (i, j) : (j, i)
            let merged = MomentMerge.merge(local: moments[loser], remote: moments[winner])
            let loserID = moments[loser].id
            moments[winner] = merged
            moments.remove(at: loser)
            save()
            onLocalChange?([.delete(loserID), .upsert(merged.id)])
            return
        }
        save()
        onLocalChange?([.upsert(id)])
    }
```

  `merge(local: loser, remote: winner)` 는 id·동기화 필드를 winner 로, 이 기기 전용 필드를 loser 로 가져간다 — 그런데 winner 가 이 기기 쪽(assetID 있음)이면 assetID 가 사라진다. 그러니 winner 가 assetID 를 갖고 있으면 그대로 두고, loser 만 assetID 를 갖고 있을 때만 merge 하도록: `let merged = moments[winner].assetID != nil ? moments[winner] : MomentMerge.merge(local: moments[loser], remote: moments[winner])`.

- `applyRemote`:

```swift
    @discardableResult
    public func applyRemote(upserts: [Moment], deletes: Set<Moment.ID>) -> [StoreChange] {
        var push: [StoreChange] = []
        var changed = false
        if !deletes.isEmpty {
            let before = moments.count
            moments.removeAll { deletes.contains($0.id) }
            changed = moments.count != before
        }
        for remote in upserts {
            if let i = moments.firstIndex(where: { $0.id == remote.id }) {
                let merged = MomentMerge.merge(local: moments[i], remote: remote)
                if merged != moments[i] { moments[i] = merged; changed = true }
                if !MomentMerge.syncedEqual(merged, remote) { push.append(.upsert(merged.id)) }
            } else if let cid = remote.cloudID, let j = moments.firstIndex(where: { $0.cloudID == cid }) {
                if MomentMerge.keeps(remote, over: moments[j]) {
                    let loser = moments[j]
                    moments[j] = MomentMerge.merge(local: loser, remote: remote)
                    push.append(.delete(loser.id))
                    changed = true
                } else {
                    push.append(.delete(remote.id))
                }
            } else {
                moments.append(remote)
                changed = true
            }
        }
        if changed { save() }
        return push
    }
```

- [ ] **Step 9: 전체 스위트 통과 + 잠금화면 확장 빌드**

Run: 전체 `xcodebuild test` 그리고 `perl -e 'alarm 240; exec @ARGV' xcodebuild build -project ColorMoments.xcodeproj -scheme ColorMomentsCapture -destination 'generic/platform=iOS Simulator'` (스킴 이름은 `xcodebuild -list` 로 확인)
Expected: 0 failures, BUILD SUCCEEDED

- [ ] **Step 10: 커밋** — `feat(몽돌): 기록에 cloudID · 합치기 규칙 · 저장소 변경 알림과 받기`

---

### Task 2 (Shared): 마무리·증정의 변경 알림과 받기

선행: 「오늘 마무리하기」 검토 수정(2026-09-23)에서 `GiftLog` 는 이미 **받은 하루 집합**(`giftedDayKeys`, 옛 `lastGiftedDayKey` 는 읽기 전용 호환)이 되었고 `GiftSchedule.pending(dayKeys:today:isGifted:hasSealedMoments:isFinished:)` 도 바뀌었다. 이 과제는 동기화용 입구만 더한다. 시작 전에 `Shared/Day/GiftSchedule.swift` 의 실제 API 이름을 확인하고 아래를 맞춘다.

**Files:**
- Modify: `Color-Moments/Shared/Day/GiftSchedule.swift`(GiftLog), `Color-Moments/Shared/Day/DayClosures.swift`
- Test: `Color-Moments/ColorMomentsTests/GiftScheduleTests.swift`, `Color-Moments/ColorMomentsTests/DayClosuresTests.swift`

**Interfaces:**
- Produces:
  - `GiftLog.onLocalChange: ((String) -> Void)?` (`@ObservationIgnored`), `GiftLog.applyRemote(gifted dayKey: String)`, `GiftLog.isGifted(_:) -> Bool`(이미 있음)
  - `DayClosures.onLocalChange: ((String) -> Void)?` (`@ObservationIgnored`), `DayClosures.applyRemote(dayKey: String, closedAt: Date)`

- [ ] **Step 1: 실패하는 테스트**

GiftScheduleTests 에:

```swift
    func testGiftLogNotifiesLocalOnlyAndPersists() {
        let d = UserDefaults(suiteName: UUID().uuidString)!
        let log = GiftLog(defaults: d)
        var got: [String] = []
        log.onLocalChange = { got.append($0) }
        log.markGifted("2026-09-21")
        log.markGifted("2026-09-21")
        log.applyRemote(gifted: "2026-09-22")
        XCTAssertEqual(got, ["2026-09-21"], "다른 기기에서 온 증정은 되돌려 올리지 않는다")
        let again = GiftLog(defaults: d)
        XCTAssertTrue(again.isGifted("2026-09-21"))
        XCTAssertTrue(again.isGifted("2026-09-22"))
    }
```

DayClosuresTests 에:

```swift
    func testApplyRemoteTakesEarlierAndDoesNotNotify() {
        let d = UserDefaults(suiteName: UUID().uuidString)!
        let c = DayClosures(defaults: d)
        var got: [String] = []
        c.onLocalChange = { got.append($0) }
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        c.close("2026-09-22", at: t)
        c.applyRemote(dayKey: "2026-09-22", closedAt: t.addingTimeInterval(60))
        XCTAssertEqual(c.closedAt("2026-09-22"), t)
        c.applyRemote(dayKey: "2026-09-22", closedAt: t.addingTimeInterval(-60))
        XCTAssertEqual(c.closedAt("2026-09-22"), t.addingTimeInterval(-60))
        XCTAssertEqual(got, ["2026-09-22"])
        XCTAssertEqual(DayClosures(defaults: d).closedAt("2026-09-22"), t.addingTimeInterval(-60))
    }
```

- [ ] **Step 2: 실행 — 실패 확인**

- [ ] **Step 3: 구현**

`GiftLog`: `@ObservationIgnored public var onLocalChange: ((String) -> Void)?`. `markGifted` 가 실제로 새로 기록했을 때만 `onLocalChange?(dayKey)`.

```swift
    public func applyRemote(gifted dayKey: String) {
        guard !isGifted(dayKey) else { return }
        giftedDays.insert(dayKey)   // 실제 저장 프로퍼티 이름에 맞춘다
        persist()
    }
```

`DayClosures`: `@ObservationIgnored public var onLocalChange`, `close` 가 실제로 기록하면 `onLocalChange?(dayKey)`.

```swift
    public func applyRemote(dayKey: String, closedAt: Date) {
        if let mine = closedDays[dayKey], mine <= closedAt { return }
        closedDays[dayKey] = closedAt
        persist()
    }
```

- [ ] **Step 4: 전체 스위트 통과**

- [ ] **Step 5: 커밋** — `feat(몽돌): 마무리·증정 변경 알림과 받기`

---

### Task 3 (앱): CloudKit 기록 변환

**Files:**
- Create: `Color-Moments/ColorMoments/Sync/SyncRecords.swift`
- Test: `Color-Moments/ColorMomentsTests/SyncRecordsTests.swift`

**Interfaces:**
- Consumes: `Moment`(cloudID 포함), `Moment.receivedFileName(cloudID:id:)`, `PhotoWord`, `Place`
- Produces:
  - `enum SyncRecords` — `static let zoneID: CKRecordZone.ID` (`zoneName: "Mongdol"`)
  - `static func recordID(moment id: UUID) -> CKRecord.ID` (`"m-" + uuidString`), `static func recordID(day key: String) -> CKRecord.ID` (`"d-" + key`)
  - `enum Ref { case moment(UUID), day(String) }`, `static func ref(_ id: CKRecord.ID) -> Ref?`
  - `static func fill(_ record: CKRecord, with m: Moment)` · `static func moment(from record: CKRecord) -> Moment?`
  - `struct DayState: Equatable { let dayKey: String; let closedAt: Date?; let gifted: Bool }`
  - `static func fill(_ record: CKRecord, with d: DayState)` · `static func day(from record: CKRecord) -> DayState?`

- [ ] **Step 1: 실패하는 테스트**

```swift
import CloudKit
import XCTest
@testable import ColorMoments

final class SyncRecordsTests: XCTestCase {

    func testMomentRoundTripDropsDeviceOnlyFields() {
        let m = Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000), colorHex: "#A1B2C3",
                       fileName: "asset-abc", source: .locked,
                       word: PhotoWord(wordID: "w1", word: "윤슬", meaning: "잔물결"), labels: ["water", "sky"],
                       assetID: "LOCAL/1", place: Place(latitude: 37.5, longitude: 127, accuracy: 20, name: "한강"),
                       addedAt: Date(timeIntervalSince1970: 1_790_000_100), batchID: UUID(),
                       originalName: "session-1.jpg", cloudID: "CLOUD/1")
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        XCTAssertNil(r["assetID"]); XCTAssertNil(r["fileName"]); XCTAssertNil(r["originalName"])
        let back = SyncRecords.moment(from: r)!
        XCTAssertEqual(back.id, m.id)
        XCTAssertTrue(MomentMerge.syncedEqual(back, m))
        XCTAssertNil(back.assetID)
        XCTAssertEqual(back.fileName, Moment.receivedFileName(cloudID: "CLOUD/1", id: m.id))
    }

    func testMomentWithoutOptionalsRoundTrips() {
        let m = Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000), colorHex: "#000000",
                       fileName: "shot-1.jpg", source: .app)
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        let back = SyncRecords.moment(from: r)!
        XCTAssertTrue(MomentMerge.syncedEqual(back, m))
        XCTAssertTrue(back.fileName.hasPrefix("remote-"))
    }

    func testDayRoundTripAndRefs() {
        let d = SyncRecords.DayState(dayKey: "2026-09-22", closedAt: Date(timeIntervalSince1970: 1_790_000_000), gifted: true)
        let r = CKRecord(recordType: "Day", recordID: SyncRecords.recordID(day: d.dayKey))
        SyncRecords.fill(r, with: d)
        XCTAssertEqual(SyncRecords.day(from: r), d)
        let id = UUID()
        guard case .moment(let got) = SyncRecords.ref(SyncRecords.recordID(moment: id)) else { return XCTFail() }
        XCTAssertEqual(got, id)
        guard case .day(let key) = SyncRecords.ref(SyncRecords.recordID(day: "2026-09-22")) else { return XCTFail() }
        XCTAssertEqual(key, "2026-09-22")
        XCTAssertNil(SyncRecords.ref(CKRecord.ID(recordName: "x", zoneID: SyncRecords.zoneID)))
    }

    func testMalformedMomentIsSkipped() {
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: UUID()))
        XCTAssertNil(SyncRecords.moment(from: r), "필수 필드가 없으면 버린다 — 크래시 금지")
    }
}
```

- [ ] **Step 2: 실행 — 실패 확인** (`xcodegen generate` 먼저)

- [ ] **Step 3: 구현**

```swift
import CloudKit

enum SyncRecords {
    static let zoneID = CKRecordZone.ID(zoneName: "Mongdol", ownerName: CKCurrentUserDefaultName)
    static let momentType = "Moment"
    static let dayType = "Day"

    enum Ref { case moment(UUID), day(String) }

    struct DayState: Equatable {
        let dayKey: String
        let closedAt: Date?
        let gifted: Bool
    }

    static func recordID(moment id: UUID) -> CKRecord.ID { CKRecord.ID(recordName: "m-" + id.uuidString, zoneID: zoneID) }
    static func recordID(day key: String) -> CKRecord.ID { CKRecord.ID(recordName: "d-" + key, zoneID: zoneID) }

    static func ref(_ id: CKRecord.ID) -> Ref? {
        let name = id.recordName
        if name.hasPrefix("m-"), let uuid = UUID(uuidString: String(name.dropFirst(2))) { return .moment(uuid) }
        if name.hasPrefix("d-") { return .day(String(name.dropFirst(2))) }
        return nil
    }

    static func fill(_ r: CKRecord, with m: Moment) {
        r["capturedAt"] = m.capturedAt
        r["colorHex"] = m.colorHex
        r["source"] = m.source.rawValue
        r["wordID"] = m.word?.wordID
        r["word"] = m.word?.word
        r["meaning"] = m.word?.meaning
        r["labels"] = m.labels
        r["latitude"] = m.place?.latitude
        r["longitude"] = m.place?.longitude
        r["accuracy"] = m.place?.accuracy
        r["placeName"] = m.place?.name
        r["addedAt"] = m.addedAt
        r["batchID"] = m.batchID?.uuidString
        r["cloudID"] = m.cloudID
    }

    static func moment(from r: CKRecord) -> Moment? {
        guard case .moment(let id) = ref(r.recordID),
              let capturedAt = r["capturedAt"] as? Date,
              let colorHex = r["colorHex"] as? String,
              let source = (r["source"] as? String).flatMap(Moment.Source.init(rawValue:)) else { return nil }
        let word: PhotoWord? = {
            guard let wid = r["wordID"] as? String, let w = r["word"] as? String,
                  let meaning = r["meaning"] as? String else { return nil }
            return PhotoWord(wordID: wid, word: w, meaning: meaning)
        }()
        let place: Place? = {
            guard let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double,
                  let acc = r["accuracy"] as? Double else { return nil }
            return Place(latitude: lat, longitude: lon, accuracy: acc, name: r["placeName"] as? String)
        }()
        let cloudID = r["cloudID"] as? String
        return Moment(id: id, capturedAt: capturedAt, colorHex: colorHex,
                      fileName: Moment.receivedFileName(cloudID: cloudID, id: id), source: source,
                      word: word, labels: r["labels"] as? [String], place: place,
                      addedAt: r["addedAt"] as? Date,
                      batchID: (r["batchID"] as? String).flatMap(UUID.init(uuidString:)), cloudID: cloudID)
    }

    static func fill(_ r: CKRecord, with d: DayState) {
        r["closedAt"] = d.closedAt
        r["gifted"] = d.gifted ? 1 : 0
    }

    static func day(from r: CKRecord) -> DayState? {
        guard case .day(let key) = ref(r.recordID) else { return nil }
        return DayState(dayKey: key, closedAt: r["closedAt"] as? Date, gifted: (r["gifted"] as? Int ?? 0) != 0)
    }
}
```

`PhotoWord`·`Place` 의 실제 init 인자·필드 이름을 확인해 맞춘다. 로컬에서 "word 가 있는데 labels 가 nil" 이면 `DayStore.load()` 가 word 를 버리므로, `moment(from:)` 도 labels 가 nil 이면 word 를 nil 로 둔다(같은 규칙).

- [ ] **Step 4: 통과 확인** — PASS 4

- [ ] **Step 5: 커밋** — `feat(몽돌): CloudKit 기록 변환 — 이 기기 전용 필드는 올리지 않는다`

---

### Task 4 (앱): 사진 cloudID 붙이기와 다시 찾기

**Files:**
- Create: `Color-Moments/ColorMoments/Sync/CloudIDMapper.swift`
- Modify: `Color-Moments/ColorMoments/Library/LibraryImporter.swift`, `Color-Moments/ColorMoments/Library/PhotoAssets.swift`(AssetAdopter.adopt 성공 뒤), `Color-Moments/ColorMoments/Library/AssetReconciler.swift`(옵저버 — 변경 뒤 다시 찾기)

**Interfaces:**
- Consumes: `DayStore.setCloudID`, `DayStore.resolveAsset`, `DayStore.unresolved`
- Produces: `enum CloudIDMapper { @MainActor static func assignMissing(store: DayStore) async; @MainActor static func resolve(store: DayStore) async; @MainActor static func refresh(store: DayStore) async  // assignMissing + resolve }`

- [ ] **Step 1: 구현** (Photos — 단위 테스트 없음. 매핑 호출은 동기·느릴 수 있어 백그라운드에서)

```swift
import Photos

enum CloudIDMapper {

    /// assetID 는 있는데 cloudID 가 없는 기록에 사진 앱의 cloudID 를 붙인다(담기·입양 뒤, 옛 기록).
    @MainActor
    static func assignMissing(store: DayStore) async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite).allowsRead else { return }
        let pending = store.moments.filter { $0.assetID != nil && $0.cloudID == nil }
        guard !pending.isEmpty else { return }
        let locals = pending.compactMap(\.assetID)
        let found: [String: String] = await Task.detached(priority: .utility) {
            let map = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: locals)
            return map.compactMapValues { try? $0.get().stringValue }
        }.value
        for m in pending {
            if let local = m.assetID, let cloud = found[local] { store.setCloudID(m.id, cloud) }
        }
    }

    /// 다른 기기에서 받은 기록의 cloudID 를 이 기기 에셋으로 찾는다. 못 찾으면 그대로 둔다(다음 기회).
    @MainActor
    static func resolve(store: DayStore) async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite).allowsRead else { return }
        let pending = store.unresolved
        guard !pending.isEmpty else { return }
        let clouds = pending.compactMap(\.cloudID)
        let found: [String: String] = await Task.detached(priority: .utility) {
            let ids = clouds.map { PHCloudIdentifier(stringValue: $0) }
            let map = PHPhotoLibrary.shared().localIdentifierMappings(for: ids)
            var out: [String: String] = [:]
            for (cloud, result) in map { if let local = try? result.get() { out[cloud.stringValue] = local } }
            return out
        }.value
        for m in pending {
            if let cloud = m.cloudID, let local = found[cloud] { store.resolveAsset(m.id, assetID: local) }
        }
    }

    @MainActor
    static func refresh(store: DayStore) async {
        await assignMissing(store: store)
        await resolve(store: store)
    }
}

private extension PHAuthorizationStatus {
    var allowsRead: Bool { self == .authorized || self == .limited }
}
```

- [ ] **Step 2: 호출부**
  - `LibraryImporter.importAssets` 끝(담은 뒤 한 번): `await CloudIDMapper.assignMissing(store: store)`
  - `AssetAdopter.adopt` 에서 `store.adopt` 가 true 를 돌려준 뒤: `await CloudIDMapper.assignMissing(store: store)`. `adoptAll` 은 루프 끝에 한 번만.
  - `AssetReconcilerObserver.photoLibraryDidChange` 의 MainActor 블록 끝(`refreshFetchResult()` 뒤): `Task { await CloudIDMapper.refresh(store: self.store) }` — iCloud 사진이 늦게 내려와도 여기서 잡힌다.
  - 앱 시작·앞으로 올 때는 Task 5 에서 연결한다.

- [ ] **Step 3: 빌드 + 전체 스위트 통과**

- [ ] **Step 4: 커밋** — `feat(몽돌): 사진에 cloudID 붙이고 받은 기록은 이 기기 사진으로 다시 찾는다`

---

### Task 5 (앱): CKSyncEngine 연결 · 권한 · 앱에 꽂기

**Files:**
- Create: `Color-Moments/ColorMoments/Sync/CloudSync.swift`
- Modify: `Color-Moments/project.yml`, `Color-Moments/ColorMoments/App/ColorMomentsApp.swift`

**Interfaces:**
- Consumes: Task 1~4 전부
- Produces: `@MainActor final class CloudSync: CKSyncEngineDelegate` — `init(store: DayStore, closures: DayClosures, gifts: GiftLog)`, `func start()`

- [ ] **Step 1: project.yml**

`ColorMoments` 타깃에:

```yaml
    entitlements:
      path: ColorMoments/ColorMoments.entitlements
      properties:
        com.apple.developer.icloud-container-identifiers: [iCloud.com.itlearning.colormoments]
        com.apple.developer.icloud-services: [CloudKit]
        aps-environment: development
```

settings 에 `INFOPLIST_KEY_UIBackgroundModes: remote-notification`. `xcodegen generate` 뒤 빌드된 앱의 Info.plist 에 `UIBackgroundModes` 가 들어갔는지 `plutil -p <DerivedData>/.../ColorMoments.app/Info.plist | grep -A2 UIBackgroundModes` 로 확인. 안 들어가면 xcodegen `info:` 로 `UIBackgroundModes: [remote-notification]` 을 넣는다. (없어도 동기화는 앱을 열 때 돈다 — 알림은 즉시성만 준다.) `ColorMoments.entitlements` 파일은 커밋한다.

- [ ] **Step 2: CloudSync.swift**

```swift
import CloudKit
import os

@MainActor
final class CloudSync: CKSyncEngineDelegate {

    private let store: DayStore
    private let closures: DayClosures
    private let gifts: GiftLog
    private var engine: CKSyncEngine?
    private let log = Logger(subsystem: "com.itlearning.colormoments", category: "sync")

    private static let container = "iCloud.com.itlearning.colormoments"
    private let stateURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("sync-state.json")
    private let systemFieldsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("sync-records.json")
    /// recordName → 서버가 준 시스템 필드(변경 태그). 없으면 새 기록으로 올려 충돌 한 번을 더 치른다.
    private var systemFields: [String: Data] = [:]

    init(store: DayStore, closures: DayClosures, gifts: GiftLog) {
        self.store = store
        self.closures = closures
        self.gifts = gifts
    }

    func start() {
        guard engine == nil else { return }
        let state = (try? Data(contentsOf: stateURL))
            .flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
        systemFields = (try? Data(contentsOf: systemFieldsURL))
            .flatMap { try? JSONDecoder().decode([String: Data].self, from: $0) } ?? [:]
        let db = CKContainer(identifier: Self.container).privateCloudDatabase
        let engine = CKSyncEngine(CKSyncEngine.Configuration(database: db, stateSerialization: state, delegate: self))
        self.engine = engine

        store.onLocalChange = { [weak self] changes in self?.enqueue(changes) }
        closures.onLocalChange = { [weak self] key in self?.enqueueDay(key) }
        gifts.onLocalChange = { [weak self] key in self?.enqueueDay(key) }

        if state == nil { enqueueEverything() }
    }

    // MARK: 보낼 것

    private func enqueue(_ changes: [StoreChange]) {
        engine?.state.add(pendingRecordZoneChanges: changes.map {
            switch $0 {
            case .upsert(let id): .saveRecord(SyncRecords.recordID(moment: id))
            case .delete(let id): .deleteRecord(SyncRecords.recordID(moment: id))
            }
        })
    }

    private func enqueueDay(_ key: String) {
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(SyncRecords.recordID(day: key))])
    }

    /// 처음 켤 때 — 이 기기 기록을 전부 올린다. 서버에 이미 있는 기록은 충돌로 돌아와 합쳐진다.
    private func enqueueEverything() {
        engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncRecords.zoneID))])
        enqueue(store.moments.map { .upsert($0.id) })
        for key in store.dayKeys where closures.closedAt(key) != nil || gifts.isGifted(key) { enqueueDay(key) }
    }

    private func dayState(_ key: String) -> SyncRecords.DayState {
        SyncRecords.DayState(dayKey: key, closedAt: closures.closedAt(key), gifted: gifts.isGifted(key))
    }

    private func record(for id: CKRecord.ID) -> CKRecord? {
        guard let ref = SyncRecords.ref(id) else { return nil }
        let r = cachedRecord(id, type: { if case .moment = ref { SyncRecords.momentType } else { SyncRecords.dayType } }())
        switch ref {
        case .moment(let uuid):
            guard let m = store.moment(uuid) else { return nil }
            SyncRecords.fill(r, with: m)
        case .day(let key):
            SyncRecords.fill(r, with: dayState(key))
        }
        return r
    }

    private func cachedRecord(_ id: CKRecord.ID, type: String) -> CKRecord {
        if let data = systemFields[id.recordName],
           let coder = try? NSKeyedUnarchiver(forReadingFrom: data) {
            coder.requiresSecureCoding = true
            defer { coder.finishDecoding() }
            if let r = CKRecord(coder: coder) { return r }
        }
        return CKRecord(recordType: type, recordID: id)
    }

    private func remember(_ r: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        r.encodeSystemFields(with: coder)
        coder.finishEncoding()
        systemFields[r.recordID.recordName] = coder.encodedData
    }

    private func forget(_ id: CKRecord.ID) { systemFields[id.recordName] = nil }

    private func persistSystemFields() {
        guard let data = try? JSONEncoder().encode(systemFields) else { return }
        try? data.write(to: systemFieldsURL, options: .atomic)
    }

    // MARK: 받은 것

    private func apply(modified: [CKRecord], deleted: [CKRecord.ID]) {
        var upserts: [Moment] = []
        for r in modified {
            remember(r)
            if let m = SyncRecords.moment(from: r) { upserts.append(m) }
            else if let d = SyncRecords.day(from: r) { applyDay(d) }
        }
        var deletes = Set<UUID>()
        for id in deleted {
            forget(id)
            if case .moment(let uuid) = SyncRecords.ref(id) { deletes.insert(uuid) }
        }
        let push = store.applyRemote(upserts: upserts, deletes: deletes)
        enqueue(push)
        persistSystemFields()
        if !upserts.isEmpty { Task { await CloudIDMapper.resolve(store: store) } }
    }

    private func applyDay(_ d: SyncRecords.DayState) {
        if let at = d.closedAt { closures.applyRemote(dayKey: d.dayKey, closedAt: at) }
        if d.gifted { gifts.applyRemote(gifted: d.dayKey) }
        // 이 기기가 더 이른 마무리나 받은 기록을 알고 있으면 다시 올린다.
        if dayState(d.dayKey) != d { enqueueDay(d.dayKey) }
    }

    // MARK: CKSyncEngineDelegate

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await MainActor.run { self.handle(event) }
    }

    private func handle(_ event: CKSyncEngine.Event) {
        switch event {
        case .stateUpdate(let e):
            if let data = try? JSONEncoder().encode(e.stateSerialization) { try? data.write(to: stateURL, options: .atomic) }
        case .accountChange(let e):
            switch e.changeType {
            case .signIn:
                enqueueEverything()
            case .signOut, .switchAccounts:
                // 로컬 기록은 절대 지우지 않는다 — 동기화 상태만 버리고 다음 계정에 다시 올린다.
                systemFields = [:]
                persistSystemFields()
                try? FileManager.default.removeItem(at: stateURL)
                engine = nil
                start()
            @unknown default:
                break
            }
        case .fetchedRecordZoneChanges(let e):
            apply(modified: e.modifications.map(\.record), deleted: e.deletions.map(\.recordID))
        case .fetchedDatabaseChanges(let e):
            if e.deletions.contains(where: { $0.zoneID == SyncRecords.zoneID }) {
                // 사용자가 iCloud 설정에서 몽돌 데이터를 지웠다 — 로컬은 두고 다시 올리지도 않는다.
                systemFields = [:]
                persistSystemFields()
            }
        case .sentRecordZoneChanges(let e):
            e.savedRecords.forEach(remember)
            e.deletedRecordIDs.forEach(forget)
            for failure in e.failedRecordSaves {
                let id = failure.record.recordID
                switch failure.error.code {
                case .serverRecordChanged:
                    if let server = failure.error.serverRecord {
                        apply(modified: [server], deleted: [])
                        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
                    }
                case .zoneNotFound:
                    engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncRecords.zoneID))])
                    forget(id)
                    engine?.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
                case .unknownItem:
                    forget(id)
                    engine?.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                     .notAuthenticated, .operationCancelled, .requestRateLimited:
                    break  // 엔진이 알아서 다시 시도한다
                default:
                    log.error("save failed \(id.recordName, privacy: .public): \(failure.error.localizedDescription, privacy: .public)")
                }
            }
            persistSystemFields()
        default:
            break
        }
    }

    nonisolated func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                               syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { id in
            await MainActor.run { self.record(for: id) }
        }
    }
}
```

주의(함정):
- `record(for:)` 가 nil 을 돌려주면(로컬에서 이미 지운 기록 저장 요청) 엔진이 그 변경을 버린다 — 정상.
- `CKSyncEngine.RecordZoneChangeBatch(pendingChanges:recordProvider:)` 의 클로저가 async 를 받지 않는 SDK 라면 `MainActor.assumeIsolated` 대신 배치를 만들기 전에 `await MainActor.run` 으로 `[CKRecord.ID: CKRecord]` 를 미리 만들어 넘긴다. 실제 SDK 시그니처를 확인하고 맞춘다.
- 스위치의 `.switchAccounts` 등 enum 이름·연관값은 실제 SDK 에 맞춘다.
- `SWIFT_STRICT_CONCURRENCY: minimal` 이라 Sendable 경고는 무시되지만 빌드 에러는 고친다.

- [ ] **Step 3: ColorMomentsApp 에 꽂기**

```swift
    @State private var sync: CloudSync?
    ...
    // 앱 .task 안, reconcilerObserver 설정 뒤:
    // 유닛 테스트는 앱을 호스트로 띄운다 — 권한 없는 CKContainer 는 크래시하므로 테스트 중엔 켜지 않는다.
    if sync == nil, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
        let s = CloudSync(store: store, closures: closures, gifts: gifts)
        s.start()
        sync = s
    }
    await CloudIDMapper.refresh(store: store)
```

`scenePhase == .active` 분기에도 `Task { await CloudIDMapper.refresh(store: store) }`. `gifts` 는 지금 `@State private var gifts = GiftLog()` — 그대로 쓴다.

- [ ] **Step 4: 빌드(앱·캡처 확장·컨트롤 위젯) + 전체 스위트 통과** — 테스트 호스트가 크래시하지 않는지가 핵심.

- [ ] **Step 5: 커밋** — `feat(몽돌): iCloud 연동 — CKSyncEngine 으로 기록 올리고 받기`

---

### Task 6: 문서

- `docs/designs/mongdol-icloud-sync.md` 상태 → **구현 (2026-09-23)**, 구현하며 달라진 곳이 있으면 해당 절에 한 줄.
- `docs/designs/mongdol-photo-assets.md` §8-4 끝에 「→ iCloud 연동(`mongdol-icloud-sync.md`)의 cloudID 다시 찾기로 해결」.
- `Color-Moments/DESIGN.md` §4.5 진행표에 행 「iCloud 연동 (docs/designs/mongdol-icloud-sync.md) | ✅ 실기기 확인 대기」.
- 이 계획 → **completed**.
- 커밋 `docs(몽돌): iCloud 연동 반영`.

## 병렬

- Task 1 ∥ Task 2 — 파일이 겹치지 않는다. Task 2 는 worktree(시뮬레이터 `0E276ADC-…`). `project.pbxproj` 가 둘 다 바뀌면 합칠 때 `xcodegen generate` 로 다시 만든다.
- Task 3 ∥ Task 4 — 둘 다 Task 1 뒤. 3 은 새 파일 둘, 4 는 새 파일 + Library 세 파일. Task 4 는 worktree.
- Task 5 는 1~4 뒤 혼자. Task 6 은 마지막.
- 모델: Task 1·2·3·4·6 은 sonnet, Task 5(CKSyncEngine SDK 시그니처 맞추기)는 opus. 최종 전체 검토는 opus.

## 수동 확인 (Tabber, 실기기)

사전: Xcode 에서 서명 탭에 iCloud(CloudKit) 가 붙고 컨테이너 `iCloud.com.itlearning.colormoments` 가 만들어졌는지. 안 되면 개발자 계정에서 컨테이너 생성.

- [ ] 앱을 지웠다 다시 깔면 기록(조약돌·단어·마무리)이 돌아오고 사진도 다시 보인다 (기기 하나로 확인 가능)
- [ ] 다시 깐 뒤 지난 하루의 증정 장면이 다시 뜨지 않는다
- [ ] (기기 둘) 아이폰에서 찍으면 다른 기기에 조약돌·사진이 뜬다 — 둘 다 iCloud 사진 켬
- [ ] (기기 둘) iCloud 사진이 꺼진 기기는 색 면으로 보이고 아무것도 안 지워진다
- [ ] (기기 둘) 한쪽에서 마무리하면 다른 쪽도 닫힌다 · 한쪽에서 받은 증정은 다른 쪽에서 안 뜬다
- [ ] 사진 앱에서 지우면 (다른 기기에서도) 몽돌에서 사라진다
- [ ] iCloud 에서 로그아웃해도 몽돌 기록은 그대로다
