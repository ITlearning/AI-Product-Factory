# 몽돌 사진첩에서 골라 담기 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

상태 **executing** · 2026-09-23 · 브랜치 `feat/mongdol-day-gift`

**Goal:** 앱 안 촬영 화면 셔터 왼쪽 버튼 → 날짜별(새벽 4시 경계) 직접 만든 선택 화면 → 고른 사진을 촬영 날짜의 하루에 담는다. 이미 열린 조약돌은 다시 칠하지 않는다.

**Spec:** `docs/designs/mongdol-library-import.md` — 아래 두 가지는 계획 단계에서 정했다(과제 6 에서 스펙에 반영):
- **봉인 시점 = 그 하루가 끝나는 때(다음 날 04:00).** `GiftLog` 는 날마다의 증정 시각을 저장하지 않아서 쓸 수 없고, 결과는 같다(오늘 담은 사진은 봉인 전이라 들어가고, 끝난 하루에 담은 사진은 빠진다).
- **새로 담긴 사진이 어디에 보이나**: 하루 상세 시간축(띠·눈금·사진)과 홈 하루 블록의 사진 더미에는 **모든 사진**. 조약돌·조약돌 이름·한 줄 말·홈 배경 번짐·하루 상세 헤더와 배경 번짐·증정은 **봉인된 사진만**.

**Tech Stack:** Swift 5.10 · SwiftUI · iOS 18 · Photos / PhotosUI · XCTest · xcodegen

## Global Constraints

- iOS 18.0 하한, 외부 의존성 0.
- 오늘 사진을 담으면 자정까지 색을 어디에도 보여주지 않는다. 선택 화면에도 색을 그리지 않는다.
- 홈에 버튼을 더하지 않는다. 가로 스크롤 금지. 재촉 문구 금지.
- 잠금화면 확장(`ColorMomentsCapture`)은 Photos 를 쓰지 않는다 — Photos 코드는 **앱 타깃**(`ColorMoments/Library/`)에만. `Shared/` 에는 순수 로직과 데이터 필드만.
- 스크린샷은 선택 화면에 안 나온다. 같은 사진(`assetID`)은 두 번 담기지 않는다.
- 색·글자는 `Tone`/`Face` 만(새 불투명도 값 금지, 단 선택 화면의 「이미 담긴 사진」 흐림 0.35 는 설계값). 주석은 함정만 한 줄.
- 권한 문구(NSPhotoLibraryUsageDescription): 「고른 사진을 몽돌에 담고, 찍은 시각과 장소를 하루에 씁니다. 사진은 기기 밖으로 나가지 않습니다.」
- **테스트는 항상 시간 제한**: `perl -e 'alarm 240; exec @ARGV' xcodebuild test ...`. 멈추면 시뮬레이터 shutdown→boot 후 1회 재시도, 또 멈추면 BLOCKED.
- 시뮬레이터: 메인 트리 `586BD801-ADAD-4A22-B184-451C8B0C91EF`, 병렬 worktree `0E276ADC-03B7-4937-82AF-682DED81DBE4`.

---

### Task 1: 데이터 — 담긴 사진의 필드와 봉인

**Files:** Modify `Color-Moments/Shared/Day/Moment.swift`, `Color-Moments/Shared/Day/DayStore.swift`; Test `Color-Moments/ColorMomentsTests/DayStoreTests.swift`

**Produces:**
- `public struct Place: Codable, Equatable, Sendable { public let latitude, longitude, accuracy: Double; public var name: String?; public init(latitude:longitude:accuracy:name: String? = nil) }` (Moment.swift 안)
- `Moment` 선택 필드: `assetID: String?`, `place: Place?`, `addedAt: Date?`, `batchID: UUID?` — init 끝에 전부 `= nil` 기본값으로
- `Moment.sealDate(for dayKey: String) -> Date?` — 그 하루가 끝나는 때(dayKey 날짜 + 1일, 04:00 현지)
- `DayStore.containsAsset(_ id: String) -> Bool`
- `DayStore.pebbleMoments(on dayKey: String) -> [Moment]` — 규칙:
  1. `addedAt == nil` (카메라) → 들어간다
  2. `addedAt <= sealDate(dayKey)` → 들어간다
  3. 1·2 로 들어간 사진이 **하나도 없으면**: 그 하루의 사진 중 `addedAt` 이 가장 이른 것의 `batchID` 묶음 전체
  4. 촬영 시각순 정렬
- `DayStore.moments(on:)` 는 그대로(모든 사진)

- [ ] **Step 1: 실패하는 테스트** — `DayStoreTests` 끝에:

```swift
    private func imported(_ at: Date, added: Date, batch: UUID, name: String, asset: String? = nil) -> Moment {
        Moment(capturedAt: at, colorHex: "#445566", fileName: name, source: .library,
               assetID: asset ?? name, addedAt: added, batchID: batch)
    }

    func testSealDateIsNextDayAtFour() throws {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        let seal = try XCTUnwrap(Moment.sealDate(for: "2026-09-22"))
        let p = c.dateComponents([.year, .month, .day, .hour], from: seal)
        XCTAssertEqual([p.year, p.month, p.day, p.hour], [2026, 9, 23, 4])
    }

    func testPhotoAddedAfterSealStaysOutOfThePebble() {
        let cam = moment(date(2026, 9, 22, 12, 0), name: "cam.jpg")
        store.add(cam)
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 25, 10, 0), batch: UUID(), name: "late.jpg"))
        XCTAssertEqual(store.pebbleMoments(on: "2026-09-22").map(\.fileName), ["cam.jpg"],
                       "선물로 받은 조약돌을 나중에 다시 칠하지 않는다")
        XCTAssertEqual(store.moments(on: "2026-09-22").count, 2, "시간축에는 보인다")
    }

    func testPhotoAddedBeforeSealCounts() {
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 22, 20, 0), batch: UUID(), name: "sameday.jpg"))
        XCTAssertEqual(store.pebbleMoments(on: "2026-09-22").map(\.fileName), ["sameday.jpg"])
    }

    func testEmptyPastDayIsMadeByItsFirstBatchOnly() {
        let first = UUID(), second = UUID()
        store.add(imported(date(2026, 8, 1, 9, 0), added: date(2026, 9, 23, 10, 0), batch: first, name: "a.jpg"))
        store.add(imported(date(2026, 8, 1, 18, 0), added: date(2026, 9, 23, 10, 0), batch: first, name: "b.jpg"))
        store.add(imported(date(2026, 8, 1, 12, 0), added: date(2026, 9, 24, 10, 0), batch: second, name: "c.jpg"))
        XCTAssertEqual(store.pebbleMoments(on: "2026-08-01").map(\.fileName), ["a.jpg", "b.jpg"],
                       "조약돌 없던 날은 처음 담은 묶음이 하루가 되고, 다음 묶음은 빠진다")
    }

    func testContainsAsset() {
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 22, 20, 0), batch: UUID(), name: "x.jpg", asset: "ASSET-1"))
        XCTAssertTrue(store.containsAsset("ASSET-1"))
        XCTAssertFalse(store.containsAsset("ASSET-2"))
    }

    func testReadsRecordsWithoutLibraryFields() throws {
        let legacy = """
        [{"id":"\\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC","fileName":"old.jpg","source":"app"}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let m = try XCTUnwrap(DayStore(fileURL: tempFile).moments.first)
        XCTAssertNil(m.assetID); XCTAssertNil(m.place); XCTAssertNil(m.addedAt); XCTAssertNil(m.batchID)
    }
```

실행 → 컴파일 실패 확인.

- [ ] **Step 2: 구현**

`Moment.swift` — `Moment` 위에 `Place` 구조체, `Moment` 에 필드 4개(`labels` 다음), init 확장. `Moment` 확장에:

```swift
    static func sealDate(for dayKey: String) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var c = DateComponents(); c.year = parts[0]; c.month = parts[1]; c.day = parts[2]; c.hour = dayBoundaryHour
        guard let start = cal.date(from: c) else { return nil }
        return cal.date(byAdding: .day, value: 1, to: start)
    }
```

`DayStore`:

```swift
    public func containsAsset(_ id: String) -> Bool {
        moments.contains { $0.assetID == id }
    }

    public func pebbleMoments(on dayKey: String) -> [Moment] {
        let all = moments(on: dayKey)
        guard let seal = Moment.sealDate(for: dayKey) else { return all }
        let sealed = all.filter { m in m.addedAt.map { $0 <= seal } ?? true }
        if !sealed.isEmpty { return sealed }
        guard let firstBatch = all.min(by: { ($0.addedAt ?? .distantFuture) < ($1.addedAt ?? .distantFuture) })?.batchID
        else { return all }
        return all.filter { $0.batchID == firstBatch }
    }
```

- [ ] **Step 3:** `DayStoreTests` 통과 → 전체 스위트 → `-scheme ColorMomentsCapture` 빌드.
- [ ] **Step 4: 커밋** `feat(몽돌): 사진첩에서 담은 사진의 필드와 조약돌 봉인`

---

### Task 2: 조약돌 계산을 봉인된 사진으로

**Files:** Modify `Color-Moments/ColorMoments/App/HomeView.swift`, `Color-Moments/Shared/Design/DayBlock.swift`, `Color-Moments/Shared/Day/DayMomentsView.swift`, `Color-Moments/Shared/Day/DayGift.swift`, `Color-Moments/Shared/Day/DayBadge.swift`

**Consumes:** `DayStore.pebbleMoments(on:)`

- [ ] **Step 1: DayBlock** — `init(moments: [Moment], pebbleMoments: [Moment]? = nil, width: CGFloat)`, `private let pebbleMoments: [Moment]` (`pebbleMoments ?? moments`). 사진 더미·날짜·개수 줄은 `moments`, `PebbleView(moments:)` 와 `PebbleNaming.name(for:)` 은 `pebbleMoments`.
- [ ] **Step 2: HomeView** — 배경 번짐 `DayGradientView(moments: store.pebbleMoments(on: key), …)`, 하루 블록 `DayBlock(moments: store.moments(on: key), pebbleMoments: store.pebbleMoments(on: key), width: blockWidth)`.
- [ ] **Step 3: DayMomentsView** — `private var pebbleMoments: [Moment] { store.pebbleMoments(on: dayKey) }` 추가. 배경 번짐 `DayGradientView`, 헤더 `PebbleView` · `PebbleNaming.name(for:)` 은 `pebbleMoments`. 시간축(띠·눈금·사진)·캡션(시간대·개수)은 `moments` 그대로.
- [ ] **Step 4: DayGift** — 증정 `moments: store.pebbleMoments(on: day.id)`. **DayBadge** 줄 — `DayBadgeView(moments: store.pebbleMoments(on: key), size: 84)`.
- [ ] **Step 5:** 전체 스위트(시간 제한) + 캡처 확장 빌드. 이 과제는 UI 배선이라 새 테스트는 없다 — 기존 스위트가 회귀를 잡는다.
- [ ] **Step 6: 커밋** `feat(몽돌): 조약돌·이름·배경 색은 봉인된 사진으로만`

---

### Task 3: 선택 화면 날짜 나누기 (순수 함수)

**Files:** Create `Color-Moments/Shared/Library/LibrarySections.swift`; Test `Color-Moments/ColorMomentsTests/LibrarySectionsTests.swift`

**Produces:**
- `public struct LibrarySection: Equatable, Sendable { public let dayKey: String; public let indices: [Int] }`
- `public enum LibrarySections { public static func make(dates: [Date?], now: Date = Date()) -> [LibrarySection]; public static func title(_ dayKey: String) -> String }`
  - 입력은 **최신순으로 이미 정렬된** 사진들의 촬영 시각(`nil` 은 `now` 로 본다).
  - 하루 경계는 `Moment.dayKey(for:)`. 섹션은 최신 하루가 위, 섹션 안 순서는 입력 순서 유지. 빈 날은 없다.
  - `title("2026-09-22")` → `"9월 22일 (화)"` (ko_KR, `M월 d일 (E)`)

- [ ] **Step 1: 실패하는 테스트**

```swift
import XCTest
@testable import ColorMoments

final class LibrarySectionsTests: XCTestCase {

    private func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var c = DateComponents(); c.year = y; c.month = mo; c.day = day; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        return cal.date(from: c)!
    }

    func testGroupsByMongdolDayBoundaryNewestFirst() {
        let dates: [Date?] = [d(2026, 9, 23, 2, 0), d(2026, 9, 22, 18, 0), d(2026, 9, 22, 5, 0), d(2026, 9, 20, 12, 0)]
        let s = LibrarySections.make(dates: dates)
        XCTAssertEqual(s.map(\.dayKey), ["2026-09-22", "2026-09-20"], "새벽 2시는 전날, 빈 날(21일)은 없다")
        XCTAssertEqual(s[0].indices, [0, 1, 2])
        XCTAssertEqual(s[1].indices, [3])
    }

    func testMissingDateFallsIntoNow() {
        let now = d(2026, 9, 23, 12, 0)
        let s = LibrarySections.make(dates: [nil, d(2026, 9, 22, 12, 0)], now: now)
        XCTAssertEqual(s.map(\.dayKey), ["2026-09-23", "2026-09-22"])
    }

    func testEmpty() { XCTAssertEqual(LibrarySections.make(dates: []), []) }

    func testTitle() { XCTAssertEqual(LibrarySections.title("2026-09-22"), "9월 22일 (화)") }
}
```

`xcodegen generate` 후 실행 → 컴파일 실패.

- [ ] **Step 2: 구현**

```swift
import Foundation

public struct LibrarySection: Equatable, Sendable {
    public let dayKey: String
    public let indices: [Int]
}

public enum LibrarySections {

    public static func make(dates: [Date?], now: Date = Date()) -> [LibrarySection] {
        var order: [String] = []
        var groups: [String: [Int]] = [:]
        for (i, date) in dates.enumerated() {
            let key = Moment.dayKey(for: date ?? now)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(i)
        }
        return order.sorted(by: >).map { LibrarySection(dayKey: $0, indices: groups[$0] ?? []) }
    }

    public static func title(_ dayKey: String) -> String {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dayKey }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        var c = DateComponents(); c.year = parts[0]; c.month = parts[1]; c.day = parts[2]; c.hour = 12
        guard let date = cal.date(from: c) else { return dayKey }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }
}
```

- [ ] **Step 3:** 통과 → 전체 스위트. **Step 4: 커밋** `feat(몽돌): 사진첩 선택 화면의 날짜 나누기 — 새벽 4시 경계`

---

### Task 4: 사진첩 읽기·담기 (앱 타깃)

**Files:** Create `Color-Moments/ColorMoments/Library/LibraryImporter.swift`

**Consumes:** `Moment` 새 필드, `DayStore.add/containsAsset`, `ColorExtractor.symbolicColor(for:)`, `ShotStore.directory`

**Produces:** `@MainActor final class LibraryImporter`:
- `static func fetchOptions() -> PHFetchOptions` — 사진만, 스크린샷 제외, `creationDate` 내림차순, `.typeUserLibrary`
- `static func requestAccess() async -> PHAuthorizationStatus` — `PHPhotoLibrary.requestAuthorization(for: .readWrite)`
- `func importAssets(_ assets: [PHAsset], into store: DayStore) async -> Int` — 담은 장수. 사진마다: 이미 담긴 `localIdentifier` 면 건너뜀 → `PHImageManager.default().requestImageDataAndOrientation`(`isNetworkAccessAllowed = true`, `deliveryMode = .highQualityFormat`, `version = .current`) → `UIImage(data:)?.jpegData(compressionQuality: 0.9)` 로 JPEG → `Shots/library-<FNV-1a(localIdentifier) 16진>.jpg` 저장 → `CIImage(contentsOf:)` 로 색 → `Moment(capturedAt: asset.creationDate ?? now, colorHex:, fileName:, source: .library, assetID:, place: asset.location.map { Place(latitude:, longitude:, accuracy: $0.horizontalAccuracy) }, addedAt: now, batchID: batch)` → `store.add`. 묶음 `batch` 는 호출 한 번에 UUID 하나.

```swift
    static func fetchOptions() -> PHFetchOptions {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(
            format: "mediaType == %d AND !((mediaSubtypes & %d) == %d)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.includeAssetSourceTypes = [.typeUserLibrary]
        return o
    }
```

- 파일 이름 해시는 `WordPicker.fnv1a` 재사용(`String(WordPicker.fnv1a(id), radix: 16)`).
- 실패한 사진은 건너뛰고 계속(0 장이어도 크래시 없음).
- [ ] **Step 1:** 파일 작성 → `xcodegen generate` → 전체 빌드·스위트 통과. (Photos 는 시뮬레이터 테스트에서 권한 대화상자를 띄울 수 없어 이 과제는 단위 테스트를 두지 않는다 — 과제 5 수동 확인과 실기기가 검증.)
- [ ] **Step 2: 커밋** `feat(몽돌): 사진첩 사진 읽기와 담기 — 스크린샷 제외, 같은 사진 두 번 안 담김`

---

### Task 5: 선택 화면 + 입구 + 권한 문구

**Files:** Create `Color-Moments/ColorMoments/Library/LibraryPickerView.swift`; Modify `Color-Moments/Shared/Capture/CaptureScreen.swift`, `Color-Moments/ColorMoments/App/HomeShell.swift`, `Color-Moments/project.yml`

- [ ] **Step 1: CaptureScreen** — `init(engine:onClose:showsDismissHint:onLibrary: (() -> Void)? = nil)`. 셔터 `ZStack` 안에 `HStack { if let onLibrary { 사진첩 버튼 }; Spacer() }` 을 셔터 왼쪽에(`.padding(.leading, 32)`, 오른쪽 더미와 대칭). 버튼: 46×46, radius 9, `Tone.hairline` 1.5 테두리, 안에 SF Symbol `photo.on.rectangle`(18, `Tone.secondary`), `accessibilityLabel("사진첩에서 담기")`. 잠금화면(`ViewFinder`)은 `onLibrary` 를 안 넘기므로 버튼이 없다.
- [ ] **Step 2: HomeShell** — `@State private var pickingLibrary = false`; `CaptureScreen(engine: camera, onClose: { progress = 0 }, onLibrary: { pickingLibrary = true })`; `.fullScreenCover(isPresented: $pickingLibrary) { LibraryPickerView(store: store) { n in if n > 0 { camera?.confirm("담겼어요") } } }` — `CaptureEngine` 에 확인 알약을 띄우는 공개 함수가 없으면 `showConfirmation()` 을 `public func confirm(_ text: String = "담겼어요")` 로 열어 쓴다(기존 호출부는 그대로 동작하게).
- [ ] **Step 3: LibraryPickerView** (`struct LibraryPickerView: View { let store: DayStore; let onDone: (Int) -> Void }`)
  - 등장 시 `LibraryImporter.requestAccess()`:
    - `.authorized` / `.limited` → `PHAsset.fetchAssets(with: LibraryImporter.fetchOptions())` → `LibrarySections.make(dates:)` 로 섹션
    - 그 외 → 가운데 한 줄 「설정에서 사진 접근을 켜 주세요」(`Face.guide`, `Tone.secondary`) + 「설정 열기」 알약(`UIApplication.openSettingsURLString`)
  - 배경 `Tone.pure`. 상단바: 닫기 알약 · 「사진첩」(15 semibold primary) · 「담기 N」 알약(선택 0 이면 `opacity(0.4)` + disabled)
  - `.limited` 면 맨 위에 「사진을 더 보이게 하기」 한 줄(`Face.guide`, `Tone.tertiary`) → `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)` (현재 키 윈도우의 최상위 VC), 끝나면 다시 가져오기
  - `ScrollView { LazyVStack(alignment: .leading, pinnedViews: [.sectionHeaders]) { ForEach(sections) { Section(header: 제목) { LazyVGrid(3열, spacing 2) } } } }` — 섹션 제목은 `LibrarySections.title`, 글자 `Face.caption` + `Tone.tertiary`, 좌우 16 · 위아래 10, 배경 `Tone.pure`(고정 머리가 사진 위에 뜨므로)
  - 칸: 정사각, `PHCachingImageManager` 로 썸네일(칸 크기 × 화면 scale), `.scaledToFill().clipped()`
    - 선택: 누르면 토글, 오른쪽 위 22pt 원 — 선택되면 흰 채움 + 검은 체크(`checkmark` 11 bold), 아니면 흰 테두리 1.5 + 검정 25% 채움
    - 이미 담긴 사진(`store.containsAsset`)은 `opacity(0.35)` + 누를 수 없음
  - 「담기」 → `LibraryImporter().importAssets(selected, into: store)` 동안 버튼 자리에 `ProgressView()`, 끝나면 `onDone(n)` 후 닫기
  - 색은 어디에도 그리지 않는다
- [ ] **Step 4: project.yml** — `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` 을 Global Constraints 의 문구로. `xcodegen generate`.
- [ ] **Step 5:** 전체 스위트(시간 제한) + 캡처 확장 빌드(확장에 Photos 참조가 없어야 한다 — `grep -rn "import Photos" Shared` 결과 0).
- [ ] **Step 6: 시뮬레이터 확인** — 임시 훅: `HomeShell` `.onAppear` 에서 `makeCamera(); progress = 1` 후 1초 뒤 `pickingLibrary = true`. 시뮬레이터 권한은 `xcrun simctl privacy 586BD801-ADAD-4A22-B184-451C8B0C91EF grant photos com.itlearning.colormoments` 로 미리 허용. 스크린샷 `/private/tmp/claude-501/-Users-tabber-AI-Product-Factory/e2c9c186-d007-4b02-a2ca-82140078b1b4/scratchpad/library-picker.png` — 시뮬레이터 기본 사진이 날짜 섹션으로 보이면 된다. 훅 되돌리고 `git diff --stat` 확인.
- [ ] **Step 7: 커밋** `feat(몽돌): 촬영 화면에서 사진첩 열기 — 날짜별로 골라 담기`

---

### Task 6: 문서

- `docs/designs/mongdol-library-import.md`: 상태 → 「구현 (2026-09-23)」; §6 봉인 시점을 「그 하루가 끝나는 때(다음 날 04:00) — GiftLog 는 날마다 시각을 안 남겨 쓰지 않는다」로; 「새 사진은 시간축·홈 사진 더미에 보이고 조약돌·이름·배경 번짐·증정은 봉인된 사진만」 추가.
- `Color-Moments/DESIGN.md` §4.5 진행표에 행 9 「사진첩에서 골라 담기 (docs/designs/mongdol-library-import.md) | ✅ `ColorMoments/Library/`, `Shared/Library/`」.
- `Color-Moments/SPEC.md` §3 에 소절 「사진첩에서 담기」 3~4줄 (입구·날짜 나누기·봉인 규칙).
- 이 계획 상태 → completed. 커밋 `docs(몽돌): 사진첩에서 골라 담기 반영`.

## 수동 확인 (Tabber, 실기기)

- [ ] 촬영 화면 셔터 왼쪽에 사진첩 버튼이 있고, 잠금화면 촬영에는 없다
- [ ] 처음 누르면 권한을 묻고, 문구가 맞다
- [ ] 선택 화면이 날짜(새벽 4시 경계)로 나뉘고, 스크린샷이 없다
- [ ] 「선택한 사진만」 권한에서 「사진을 더 보이게 하기」가 뜨고 동작한다
- [ ] 예전 날 사진을 담으면 그날로 들어가고, 이미 있던 조약돌 색·이름은 그대로다
- [ ] 조약돌이 없던 날에 담으면 홈에 조용히 조약돌이 생긴다
- [ ] 오늘 사진을 담으면 색이 자정까지 안 보인다
- [ ] 같은 사진은 두 번 안 담긴다 (흐리게 보인다)
- [ ] 기본 카메라로 찍은 사진에 위치가 저장된다 (전체 / 선택한 사진만 두 권한 모두)
