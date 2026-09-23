# 몽돌 — 사진첩에서 골라 담기

작성 2026-09-23 · 상태 **설계 검토 대기** · 코드 `Color-Moments/`

평소 iOS 카메라로 찍은 사진을 몽돌에 **골라서** 담는다. 사진첩 전체를 자동으로 가져오지 않는다.

> **왜 자동이 아니라 고르기인가** (Tabber 2026-09-23): 전부 가져오면 「그 순간을 골라 담는다」가 사라진다.
> 고르는 일이 곧 담는 일이다. 예전 사진을 올리고 싶을 수도 있다.
> 기본 카메라 사진에는 촬영 시각·위치가 이미 있어서, 잠금화면 촬영이 위치를 못 받는 문제(사진 한 단어 3단계)를 피한다.

앱 안 카메라·잠금화면 카메라는 **그대로 둔다.** 잠금화면 확장은 애플 규칙상 직접 만든 뷰파인더가 필요하고, 한 장마다 확인 화면이 뜨는 기본 카메라는 「툭툭 담기」와 맞지 않는다.

---

## 1. 이 설계가 지키는 것

| 제약 | 이 기능에서 |
|---|---|
| SPEC §2-1 오늘 색은 안 보여준다 | 오늘 찍은 사진을 올리면 오늘에 들어가고 **자정까지 색이 숨는다**. 선택 화면·올린 뒤 화면 어디에도 색을 보여주지 않는다 |
| 선물로 받은 조약돌을 다시 칠하지 않는다 | **이미 열린 하루**에 사진을 더하면 사진은 시간축에만 보이고, 조약돌 색·이름·하루 그라데이션은 그대로 |
| 증정은 자정에 하루 한 번 | 조약돌이 없던 지난 날에 올리면 **조용히** 홈에 조약돌이 생긴다. 증정 화면 없음 |
| 홈에 버튼이 없다 (DESIGN §1.2) | 입구는 **앱 안 촬영 화면 셔터 왼쪽**. 홈은 그대로 |
| 가로 스크롤 금지 (DESIGN §1.3) | 선택 화면은 세로 스크롤만 |
| 사진은 기기 밖으로 나가지 않는다 | 그대로 — 가져온 사진은 몽돌 저장소에 복사해 기기 안에서만 쓴다 |

> **격자에 대해**: SPEC §2-2 「격자로 깔지 않는다」는 **하루들**(조약돌)을 두고 한 말이다 — 빈 날이 구멍으로 보이면 스트릭이 된다.
> 선택 화면은 사진첩을 고르는 도구라 사진 격자를 쓴다. 날짜 머리는 **사진이 있는 날만** 나온다(빈 날을 그리지 않는다).

## 2. 비목표

- 사진첩 자동 가져오기 · 백그라운드 가져오기
- 동영상 · 라이브 포토의 움직임 (라이브 포토는 정지 사진으로)
- 잠금화면 촬영 확장에서 사진첩 열기 (확장은 사진첩에 접근 못 한다)
- 이미 열린 조약돌 다시 계산

## 3. 흐름

```
앱 안 촬영 화면
  셔터 왼쪽 [사진첩] 버튼 (44pt, 최근 사진 한 장 썸네일 — 권한 전에는 아이콘)
    → 권한 (처음 한 번): PHPhotoLibrary.requestAuthorization(for: .readWrite)
        · 전체 / 선택한 사진만 → 선택 화면
        · 거부 → 「설정에서 사진 접근을 켜 주세요」 한 줄 + 설정 열기
    → 선택 화면 (직접 만든 것, 전체 화면, 배경 pure)
        날짜별 섹션 · 여러 장 선택 · 「담기 N」
    → 담기: 사진마다 복사 → 색 추출 → Moment 저장
    → 촬영 화면으로 돌아와 「담겼어요」 알약 (촬영과 같은 확인)
```

## 4. 선택 화면

```
상단바   닫기 · 「사진첩」 · 담기 N (고른 게 없으면 흐림)
섹션     「9월 22일 (월)」  12 rounded tertiary · 사진 있는 날만
격자     3열, 간격 2, 정사각 썸네일, 최신이 위
선택     누르면 오른쪽 위 원형 체크(흰 테두리 + 채움) · 다시 누르면 해제
이미 담긴 사진   흐리게(opacity 0.35) + 누를 수 없음
선택한 사진만 권한일 때   맨 위 한 줄 「사진을 더 보이게 하기」 → presentLimitedLibraryPicker
```

**「쿼리」 — `PHFetchOptions`**

```swift
let o = PHFetchOptions()
o.predicate = NSPredicate(
    format: "mediaType == %d AND !((mediaSubtypes & %d) == %d)",
    PHAssetMediaType.image.rawValue,
    PHAssetMediaSubtype.photoScreenshot.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
o.includeAssetSourceTypes = [.typeUserLibrary]   // 공유 앨범·iCloud 공유 제외
let assets = PHAsset.fetchAssets(with: o)
```

- **스크린샷은 뺀다** — 하루의 색이 아니다.
- 날짜 나누기는 **몽돌의 하루 경계(새벽 4시)** 로 — `Moment.dayKey(for: asset.creationDate)`. 달력 날짜가 아니다. 새벽 2시 사진은 전날 섹션에 들어간다.
- 섹션 나누기는 가져온 `PHFetchResult` 를 한 번 훑어 `[dayKey: [index]]` 로 — 수천 장이어도 PHAsset 메타데이터만 읽어 가볍다.
- 썸네일은 `PHCachingImageManager` 로 보이는 칸 앞뒤만 미리.
- 사진첩이 바뀌면(`PHPhotoLibraryChangeObserver`) 다시 가져온다.

## 5. 담기

사진마다:
1. `PHImageManager.requestImageDataAndOrientation` 으로 원본 데이터 → 몽돌 `Shots/` 에 `library-<식별자 해시>.jpg` 로 복사 (HEIC 는 JPEG 로 변환)
2. 색 추출 — 기존 `ColorExtractor.symbolicColor` (카메라 경로와 같은 함수)
3. `Moment(capturedAt: asset.creationDate, colorHex:, fileName:, source: .library)` + 새 필드
   - `assetID: String?` — `asset.localIdentifier`. **같은 사진 두 번 담기 방지**
   - `place: Place?` — `asset.location` 이 있으면 좌표·정확도 (사진 한 단어 3단계가 이 필드를 그대로 쓴다)
   - `addedAt: Date?` — 담은 시각
4. `DayStore.add` (파일 이름 중복은 이미 막고 있다)

- 다 담기까지 선택 화면에 머물고, 끝나면 닫힌다. 10장 넘게 고르면 진행 막대 한 줄.
- `creationDate` 가 없는 사진(드묾)은 담은 시각으로.

## 6. 이미 열린 조약돌은 그대로

조약돌·이름·하루 그라데이션은 **「그 하루가 열린 시점까지 있던 사진」** 으로만 계산한다.

- 하루가 열리는 시점 = 그 하루의 자정 증정 시각(`GiftLog`), 증정 기록이 없으면(지난 날) 그 하루 경계(다음 날 04:00).
- `addedAt` 이 그 시점 **뒤** 인 사진은 조약돌 계산에서 뺀다. 하루 상세 시간축·사진 한 단어에는 들어간다.
- 조약돌이 없던 지난 날은 열린 시점 전에 사진이 없으므로, 처음 담긴 사진들로 조약돌을 만든다 — 그 뒤에 더한 사진부터 빠진다.
  - 한 번의 「담기」로 같은 날에 여러 장이 들어가면 **그 묶음 전체**가 조약돌을 만든다 (묶음 id 로 판정).
- 계산 함수 하나(`DayStore.pebbleMoments(on:)`)로 모으고, 조약돌·이름·그라데이션·홈 배경이 모두 이 함수를 쓴다.

## 7. 권한 문구

- `NSPhotoLibraryUsageDescription`: 「고른 사진을 몽돌에 담고, 찍은 시각과 장소를 하루에 씁니다. 사진은 기기 밖으로 나가지 않습니다.」 (문구는 Tabber 확정)
- 권한은 사진첩 버튼을 처음 누를 때만 묻는다. 첫 실행에 묻지 않는다.

## 8. 테스트

- 날짜 섹션: 새벽 4시 경계, 최신순, 빈 날 없음 (순수 함수 `LibrarySections.make(dates:)`)
- 중복: 같은 `assetID` 두 번 → 한 번만
- 열린 조약돌 고정: 열린 뒤 `addedAt` 사진은 `pebbleMoments` 에서 빠지고 `moments(on:)` 에는 남는다 · 증정 기록 없는 지난 날은 첫 묶음으로 만든다
- 옛 기록 디코딩(`assetID`·`place`·`addedAt` 없는 JSON)
- 실기기 수동: 전체/선택한 사진만 두 권한, 위치 있는 사진의 `place`, 오늘 사진의 색 숨김

## 9. 요확인

1. 「선택한 사진만」 권한에서 `asset.location` 이 읽히는지 — 실기기
2. 색 추출을 담기 시점에 동기로 할지(장당 수십 ms 예상) — 20장 실측 후 결정
3. 비트 연산 predicate(`mediaSubtypes & …`)가 이 iOS 버전에서 그대로 먹는지 — 첫 구현 때 스크린샷 한 장으로 확인
4. `library-` 파일 이름 규칙과 기존 `ShotStore` 정리 로직(`removeAll`)의 충돌 여부
