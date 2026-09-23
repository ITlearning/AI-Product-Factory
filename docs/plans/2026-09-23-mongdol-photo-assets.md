# 몽돌 — 사진은 사진 앱에, 몽돌은 에셋 ID만 · 구현 계획

상태 **completed** · 2026-09-23 · 브랜치 `feat/mongdol-day-gift` · 설계 `docs/designs/mongdol-photo-assets.md` (Tabber 승인)

## 계획 단계에서 정한 것

- **입양(adopt) 하나로 모은다.** 카메라·잠금화면·옛 사진은 모두 「파일로 먼저 저장 → 사진 앱에 저장 → Moment 에 assetID · 파일 삭제」. 같은 함수 `AssetAdopter.adopt(_ moment:)` 를 찍은 직후·잠금화면 가져온 직후·앱 시작 때(옛 사진) 부른다.
- **권한이 없으면 파일로 남긴다** (설계 §2 「촬영물은 버린다」를 바꿈). 권한이 없으면 사진 앱 사본이 없으니 두 번 저장이 아니고, 찍은 걸 잃지 않는다. 다음에 권한이 생기면 입양된다. 설계 문서는 과제 6에서 고친다.
- `Moment.fileName` 은 **그대로 둔다(필수 값)** — 입양된 사진은 `asset-<fnv1a(assetID) 16진>` 이라는 자리 이름을 넣는다. `DayStore.add` 의 중복 막기가 그대로 동작한다.
- 사진첩에서 담기는 **복사하지 않는다** — `assetID` 와 자리 이름으로 바로 Moment.
- 홈 후속 두 가지(스크럽 중 카메라 스와이프 끄기 · 담은 뒤 스크롤을 닫힘 뒤로)를 과제 5 로 함께.

## Global Constraints

- iOS 18.0, 외부 의존성 0. `Shared/` 는 Photos 를 import 하지 않는다(잠금화면 확장이 컴파일한다). 앱 타깃만 Photos.
- 사진 앱 권한은 `.readWrite`. 첫 실행에 묻지 않는다 — 처음 찍거나 담을 때.
- **지운 사진 정리는 전체 접근(`.authorized`)일 때만.** 제한 접근에서 못 찾은 사진은 지우지 않는다.
- 색·단어·분류는 기록된 값을 쓴다 — 조약돌을 그리려고 사진을 다시 읽지 않는다.
- 옛 기록(파일만 있는 Moment)은 그대로 읽히고 그려진다.
- 테스트는 `perl -e 'alarm 240; exec @ARGV' xcodebuild test ...`, 멈추면 shutdown→boot 1회, 또 멈추면 BLOCKED. 시뮬레이터 스크린샷 금지(Tabber 실기기).
- 단계마다 커밋. 커밋 끝줄 `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

---

### Task 1 (Shared): 그리는 입구를 Moment 기준으로 · 저장소 동작 추가

**Files:** `Shared/Day/ShotImage.swift`, `Shared/Design/ShotThumbnail.swift`, `Shared/Word/PhotoLabeler.swift`, `Shared/Day/DayPhotoView.swift`, `Shared/Day/DayStore.swift`, `Shared/Day/Moment.swift`; tests `ColorMomentsTests/ShotImageTests.swift`, `ColorMomentsTests/DayStoreTests.swift`

**Produces:**
- `public protocol AssetImageSource: Sendable { func image(assetID: String, maxPixel: CGFloat) -> UIImage? }` — 동기(백그라운드에서 부른다), 못 찾으면 nil
- `ShotImage.assetSource: AssetImageSource?` (앱이 시작할 때 꽂는다, 기본 nil)
- `ShotImage.full(_ m: Moment)`, `thumbnail(_ m: Moment, maxPixel:)`, `peek(_ m: Moment, maxPixel:)`, `warm(_ m: Moment, maxPixel:)` — `m.assetID` 가 있고 `assetSource` 가 있으면 에셋, 아니면 지금처럼 `m.fileName` 파일. 캐시 키는 assetID 또는 fileName. 기존 fileName 판 함수는 내부용으로만 남긴다.
- `PhotoLabeler.labels(for m: Moment) -> [String]?` (기존 `labels(forShot:)` 대체)
- 세 호출부(ShotThumbnail, PhotoLabeler, DayPhotoView)를 Moment 판으로.
- `Moment.assetFileName(for assetID: String) -> String` = `"asset-" + String(WordPicker.fnv1a(assetID), radix: 16)`
- `DayStore.adopt(_ id: Moment.ID, assetID: String)` — 그 Moment 의 `assetID` 를 채우고 `fileName` 을 자리 이름으로 바꾼다(다른 필드 그대로). 이미 assetID 가 있으면 아무것도 안 함.
- `DayStore.remove(assetIDs: Set<String>)` — 해당 assetID 를 가진 Moment 들을 지운다.
- `DayStore.fileBacked: [Moment]` — `assetID == nil` 인 것들
- 테스트: adopt 가 필드를 보존하고 두 번째는 무시 · remove 뒤 그 하루가 없어지면 `dayKeys` 에서도 빠짐 · 가짜 `AssetImageSource` 를 꽂으면 assetID 있는 Moment 는 그쪽에서, 없는 Moment 는 파일에서.

### Task 2 (앱): 사진 앱 읽기·저장

**Files:** create `ColorMoments/Library/PhotoAssets.swift`; modify `ColorMoments/App/ColorMomentsApp.swift`

- `final class PhotoAssetSource: AssetImageSource` — `PHImageManager.default().requestImage(for:targetSize:contentMode: .aspectFit/.aspectFill, options:)` 를 `isSynchronous = true`, `deliveryMode = .highQualityFormat`, `isNetworkAccessAllowed = true`, `resizeMode = .fast` 로. 에셋은 `PHAsset.fetchAssets(withLocalIdentifiers:)`.
- `enum AssetSaver { static func save(fileURL: URL, creationDate: Date, location: CLLocation?) async -> String? }` — `PHPhotoLibrary.shared().performChanges { PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL:, options:); request.creationDate = …; request.location = … }` 의 placeholder `localIdentifier`. 실패하면 nil.
- `enum AssetAdopter { @MainActor static func adopt(_ m: Moment, store: DayStore) async }` — 권한이 `.authorized`/`.limited` 일 때만: 파일 URL(`ShotImage.url(m.fileName)`) → `AssetSaver.save` → `store.adopt` → 파일 삭제. 권한 없으면 아무것도 안 함. `static func adoptAll(store:)` 는 `store.fileBacked` 를 차례로 (단 `library-` 로 시작하는 파일은 저장하지 말고 `assetID` 가 이미 있으니 파일만 지운다).
- `ColorMomentsApp` 시작 때 `ShotImage.assetSource = PhotoAssetSource()`, 그리고 권한이 이미 있으면 `AssetAdopter.adoptAll`.
- 단위 테스트 없음(Photos) — 빌드·스위트 통과만.

### Task 3 (앱): 찍기·잠금화면·사진첩 담기를 입양 흐름으로

**Files:** `ColorMoments/App/HomeShell.swift`(camera onRecorded), `ColorMoments/Capture/CaptureInbox.swift`(record 뒤), `ColorMoments/Library/LibraryImporter.swift`

- 앱 카메라: `onRecorded: { m in store.add(m); Task { await AssetAdopter.adopt(m, store: store) } }`. 권한이 `.notDetermined` 면 처음 찍을 때 `PHPhotoLibrary.requestAuthorization(for: .readWrite)` 한 번.
- 잠금화면 가져오기: `record` 로 `store.add` 한 직후 같은 입양.
- 사진첩 담기: 원본을 파일로 쓰지 않는다. 이미지 데이터로 색(`ColorExtractor`)만 뽑고 `Moment(fileName: Moment.assetFileName(for: id), assetID: id, …)`. 이미 있는 `library-*.jpg` 는 Task 2 `adoptAll` 이 지운다.
- 빌드·스위트·캡처 확장 빌드.

### Task 4 (앱): 지운 사진 정리

**Files:** create `ColorMoments/Library/AssetReconciler.swift`; test `ColorMomentsTests/AssetReconcilerTests.swift`; modify `ColorMoments/App/ColorMomentsApp.swift` 또는 `HomeShell.swift`(앞으로 올 때)

- `enum AssetReconciler { static func missing(ids: Set<String>, found: Set<String>, fullAccess: Bool) -> Set<String> }` — `fullAccess` 가 아니면 늘 빈 집합. 테스트 3개(전체 접근 / 제한 접근 / 다 찾음).
- 실제 정리: 앱이 앞으로 올 때와 `PHPhotoLibraryChangeObserver` 가 알릴 때, `.authorized` 면 모든 assetID 를 `fetchAssets(withLocalIdentifiers:)` 로 확인 → `store.remove(assetIDs:)`.
- 알림·안내 없음.

### Task 5: 홈 후속 두 가지

**Files:** `ColorMoments/App/HomeView.swift`, `ColorMoments/App/HomeShell.swift`

- 스크럽 중에는 카메라 스와이프를 끈다: HomeView 가 `scrubbing` 을 바인딩(또는 콜백)으로 알리고 HomeShell 의 `swipe` 가 그동안 무시. 틀린 주석(`highPriorityGesture` 가 이긴다)을 고친다.
- 담은 뒤 스크롤: 선택 화면이 **닫힌 뒤**(fullScreenCover `onDismiss`)에 `focusDay` 를 넣는다.

### Task 6: 문서

- `docs/designs/mongdol-photo-assets.md`: 상태 → 구현, §2 「거부하면 촬영물은 버린다」 → 「거부하면 지금처럼 몽돌 폴더에 둔다(사진 앱 사본이 없으니 두 번 저장이 아니다). 권한이 생기면 입양」, §4 에 입양 흐름 한 단락.
- `Color-Moments/DESIGN.md` §4.5 행 10 「사진은 사진 앱에 (docs/designs/mongdol-photo-assets.md) | ✅」.
- 이 계획 → completed.

## 병렬

- Task 1 ∥ Task 5 (파일 안 겹침: 1은 Shared, 5는 HomeView/HomeShell 의 스크럽·focusDay 부분만). Task 5 를 **worktree** 에서.
- Task 2 → Task 3 ∥ Task 4 (3 은 HomeShell onRecorded·CaptureInbox·LibraryImporter, 4 는 새 파일 + 앱 시작부). Task 3 이 HomeShell 을 건드리므로 Task 5 가 먼저 합쳐진 뒤 시작.

## 수동 확인 (Tabber, 실기기)

- [ ] 앱에서 찍으면 사진 앱 「최근 항목」에 생기고, 몽돌 하루에도 보인다
- [ ] 잠금화면에서 찍은 사진도 앱을 열면 사진 앱에 들어간다 (촬영 시각 유지)
- [ ] 옛 사진이 사진 앱으로 옮겨진다 (앱 시작 한 번)
- [ ] 사진 앱에서 지우면 몽돌에서도 사라지고, 그 하루에 사진이 없으면 조약돌도 없어진다
- [ ] 「선택한 사진만」 권한에서는 안 보이는 사진이 지워지지 않는다
- [ ] 권한을 거부해도 찍은 사진이 몽돌에 남는다
- [ ] 알약을 끄는 동안 카메라가 안 열린다 · 담은 뒤 홈 스크롤이 닫힌 다음에 움직인다
