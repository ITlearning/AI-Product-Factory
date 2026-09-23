# 몽돌 — 사진은 사진 앱에, 몽돌은 에셋 ID만

작성 2026-09-23 · 상태 **구현 (2026-09-23)** · 코드 `Color-Moments/`

몽돌로 찍은 사진을 **사진 앱에 저장하고**, 몽돌은 그 사진의 **에셋 ID만** 기억한다. 사진첩에서 담은 사진도 복사하지 않는다.

> **왜** (Tabber 2026-09-23): 지금은 몽돌 폴더에 JPEG 를 따로 둔다 — 같은 사진이 두 번 저장되고, 쌓일수록 용량·성능이 문제가 된다.
> 사진 앱의 썸네일·원본을 `PHImageManager` 로 받으면 빠르고, 몽돌 저장소는 가벼워진다. iCloud 연동(다음 작업)도 에셋 ID 위에서만 성립한다.

---

## 1. 결정

| | 지금 | 바뀐 뒤 |
|---|---|---|
| 앱 안 촬영 | `Shots/shot-*.jpg` 저장 | **사진 앱에 저장** → `assetID` |
| 잠금화면 촬영 | 세션 폴더 → 앱이 열릴 때 `Shots/` 로 복사(`CaptureInbox`) | 앱이 열릴 때 **사진 앱에 저장** → `assetID`, 세션 파일은 무효화(지금과 같음) |
| 사진첩에서 담기 | `Shots/library-*.jpg` 로 복사 | **복사하지 않음** — 이미 사진 앱에 있다 |
| 화면에 그리기 | 파일에서 읽기 | `PHImageManager` (썸네일·원본) |
| 사진 앱에서 지우면 | 몽돌엔 남음 | **몽돌에서도 지운다.** 그 하루 조약돌은 남은 사진으로 다시 계산, 없으면 조약돌도 사라진다 (Tabber 결정 — 「받은 조약돌을 다시 칠하지 않는다」의 유일한 예외) |

- 색·단어·분류는 **찍을 때 / 담을 때 한 번** 뽑아 `Moment` 에 저장한다(지금과 같음). 사진을 다시 읽지 않고도 조약돌·이름이 그려진다.
- 사진을 몽돌 안에 따로 남기고 싶다는 요구가 생기면 **구독 보관**으로 푼다 — 이번 범위 아님.

## 2. 권한

- 저장만 할 때도 **읽기·쓰기(`.readWrite`)** 를 받는다 — 다시 읽어 화면에 그려야 하므로. 추가 전용(`.addOnly`)으로는 부족하다.
- 권한은 **처음 찍을 때** 묻는다(첫 실행에 묻지 않는다). 거부하면 **지금처럼 몽돌 폴더에 둔다** — 사진 앱 사본이 없으니 두 번 저장이 아니고, 찍은 걸 잃지 않는다. 나중에 권한이 생기면 입양된다.
- **「선택한 사진만」 권한**: 앱이 만든 사진은 그 앱에서 보인다(요확인 — 실기기). 사진첩에서 담은 사진은 사용자가 보이게 한 것만 보인다.
- 잠금화면 확장은 사진 앱에 쓰지 않는다 — 지금처럼 세션 폴더에만 두고, **앱이 열릴 때** 앱이 사진 앱에 저장한다. 확장에 Photos 를 넣지 않아 확장 권한 문제를 피한다.

## 3. 지운 사진 정리 — 가장 조심할 곳

에셋 ID 로 사진을 못 찾는 경우는 둘이다: **지워졌다** / **「선택한 사진만」이라 안 보인다.** 둘을 구분하지 못하면 사용자 몰래 하루를 지우게 된다.

- 정리는 **전체 접근(`.authorized`)일 때만** 한다. 제한 접근에서는 못 찾은 사진을 **지우지 않고** 사진 자리에 그 순간의 색 면을 그린다.
- 정리 시점은 두 갈래로 나뉜다(2026-09-23 최종 검토에서 분리):
  - **앞으로 올 때(폴링)**: `AssetReconciler.reconcile(store:)` 가 아는 assetID 를 전부
    `PHAsset.fetchAssets(withLocalIdentifiers:)` 로 묶어 확인하고, 순수 판정 함수로 지울 것을 고른다.
  - **`PHPhotoLibraryChangeObserver` 가 알릴 때**: 추적 중인 `PHFetchResult` 를 들고
    `changeInstance.changeDetails(for:)?.removedObjects` 로 **명시적으로 지워진 것만** 지운다.
    시스템이 직접 확인해준 삭제라 아래 상한을 적용하지 않는다. 처리 뒤 `PHFetchResult` 를
    저장소 기준으로 다시 세워, 새로 입양된 assetID 도 다음 변경부터 잡히게 한다.
- 순수 판정 함수 `AssetReconciler.missing(ids: Set<String>, found: Set<String>, fullAccess: Bool) -> Set<String>`.
  제한 접근이면 늘 빈 집합. **안전장치(폴링 경로 전용, 2026-09-23 추가)**: `found` 가 통째로
  비어 있으면(사진 앱 조회 자체가 실패한 것일 수 있음) 빈 집합. 지울 개수가
  `max(3, ids.count / 5)`(최소 3개 또는 20%)를 넘으면 그 회차는 건너뛴다 — 한 번의 잘못된
  조회로 기록 전체가 지워지는 걸 막는 덫.
- 지운 뒤 그 하루에 사진이 없으면 홈에서 조약돌이 사라진다. 알림·안내 없음(재촉 금지와 같은 결).

## 4. 코드 구조

```
Shared/Day/Moment.swift        fileName 은 필수값(그대로 둔다) — 입양된 사진은 자리 이름
                                (asset-<fnv1a(assetID)>) 을 넣어 중복 방지가 그대로 동작한다.
                                originalName: String? 은 입양 전 원래 fileName 을 남겨,
                                fileName 이 자리 이름으로 바뀐 뒤에도 재전달 중복을 잡는다.
Shared/Day/ShotImage.swift     그리는 입구 하나 — assetID 가 있고 AssetImageSource 가 있으면
                                에셋, 그 쪽이 못 찾으면(nil) fileName 파일로 한 번 더 시도.
ColorMoments/Library/
  PhotoAssets.swift             PhotoAssetSource(AssetImageSource, PHImageManager.default 로
                                 썸네일·원본) · AssetSaver(Data → PHAssetCreationRequest →
                                 localIdentifier) · AssetAdopter(입양 흐름) 를 한 파일에 모은다
                                 (계획 문서의 3파일 분리는 실제로는 합쳐짐).
  AssetReconciler.swift         지운 사진 찾기 — 순수 판정(missing) + 폴링 조회(reconcile) +
                                 변경 알림 옵저버(AssetReconcilerObserver)
```

- `Shared/` 는 Photos 를 모른다 — `ShotImage` 는 앱 타깃이 꽂아 주는 `AssetImageSource` 프로토콜을 통해서만 에셋을 그린다. 확장은 파일 경로만 쓴다.
- 쓰는 곳 7군데(`ShotThumbnail`, `DayBlock`, `DayPhotoView`, `DayMomentsView`, `PhotoLabeler`, `ShotViewer`, `CaptureScreen` 더미)는 `ShotImage` 만 거치므로 그대로 둔다.

## 4.5 입양(adopt) 흐름

카메라·잠금화면·옛 사진은 모두 「파일로 먼저 저장 → `AssetSaver` 로 사진 앱에 저장 → `DayStore.adopt` 로 assetID 기록 → 파일 삭제」. 파일은 저장과 기록이 **둘 다** 성공했을 때만 지운다.
같은 사진이 두 번 저장되지 않도록 옮기는 중인 사진을 기록해 막는다(`AssetAdopter`).

## 5. 옛 사진 옮기기 (한 번)

- 앱 첫 실행(새 버전) 때, `assetID == nil` 이고 `Shots/` 에 파일이 있는 사진을 사진 앱에 저장하고 `assetID` 를 붙인다. 성공한 파일만 지운다.
- 권한이 없으면 옮기지 않고 파일로 계속 그린다(다음에 권한이 생기면 다시 시도).
- `library-*.jpg`(사진첩에서 담은 복사본)는 이미 `assetID` 가 있으므로 **저장하지 않고** 파일만 지운다.
- 사진 앱에 저장할 때 원래 촬영 시각을 `creationDate` 로 넣는다(사진 앱에서도 그 날짜에 보이게).

## 6. 위치

- 앱 안 촬영: 찍는 순간 위치가 있으면 `PHAssetCreationRequest.location` 에 넣는다(사진 한 단어 3단계와 연결). 위치 권한은 이번 범위가 아니다 — 있으면 쓰고 없으면 뺀다.
- 사진첩에서 담은 사진은 이미 `asset.location` 이 있다.

## 7. 테스트

- `AssetReconciler.missing`: 전체 접근 → 못 찾은 것 반환 · 제한 접근 → 빈 배열 · 전부 찾음 → 빈 배열
- 옛 기록 디코딩(`fileName` 만 있는 JSON) 그대로
- 옮기기 판정: `assetID` 있는 `library-` 파일은 저장하지 않고 지울 대상
- 실기기 수동: 찍으면 사진 앱에 생긴다 · 사진 앱에서 지우면 몽돌에서도 사라진다 · 제한 접근에서 안 보이는 사진은 지워지지 않는다 · 옛 사진이 옮겨지고 몽돌 폴더가 비워진다

## 8. 요확인

1. 「선택한 사진만」 권한에서 앱이 방금 만든 에셋을 다시 읽을 수 있는지
2. 잠금화면 촬영분을 앱이 사진 앱에 저장할 때 원래 촬영 시각이 유지되는지(`creationDate` 지정)
3. 사진 앱 저장 실패(공간 부족 등) 때 촬영물을 어떻게 알릴지 — 지금 안: 「담지 못했어요」 알약.
   **2026-09-23 최종 검토 기준: 아직 구현 안 됨** — 저장이 실패하면 파일이 남아 다음 기회에
   재시도될 뿐, 화면에 아무 알림도 뜨지 않는다. 요확인 그대로 유지.
4. 기기 복원 뒤 에셋 ID 가 바뀌면(iCloud 복원 등) 사진이 비고 기록(색·단어·날짜)은 남는다 —
   `ShotImage` 는 파일로 폴백을 시도하지만 원본 파일이 없는 새 기록(카메라·잠금화면으로
   입양된 사진)은 자리 이름만 남아 결국 빈 자리로 보인다. 지금 범위에서는 풀지 않는다 —
   다음 iCloud 연동 작업에서 `PHCloudIdentifier` 로 assetID 를 재매핑해 푼다.
