# 몽돌 — iCloud 연동 (기록만, 사진은 사진 앱이)

작성 2026-09-23 · 상태 **설계 (Tabber 대화 승인, 문서 검토 대기)** · 코드 `Color-Moments/`

몽돌 기록(색·단어·날짜·장소·마무리·증정)을 **CloudKit 개인 DB**로 동기화한다. 사진은 올리지 않는다 — 사진은 iCloud 사진이 옮기고, 몽돌은 `PHCloudIdentifier` 로 그 사진을 다시 찾는다.

> **왜** (Tabber 2026-09-23): 「아이클라우드에는 사진이 올라가는게 아니라 에셋 ID나 조약돌 조합정도만 올라가도 어디서든지 가능할 것 같아.」
> 풀 상황은 **둘 다** — 폰을 바꾸거나 다시 깔아도 그대로, 그리고 여러 기기에서 동시에.

선행: `docs/designs/mongdol-photo-assets.md`(사진은 사진 앱에). 그 문서 §8-4(복원 뒤 에셋 ID가 바뀌는 문제)를 이 작업이 푼다.

---

## 1. 방식

**CloudKit 개인 DB + `CKSyncEngine`(iOS 17+), 사진 한 장당 기록 하나.**

| 버린 안 | 이유 |
|---|---|
| `NSUbiquitousKeyValueStore` | 1MB 한도 — 몇 년 치 기록이면 넘친다 |
| iCloud Drive 에 `days.json` 통째로 | 두 기기가 동시에 쓰면 파일 전체가 부딪친다 |
| SwiftData/Core Data + CloudKit | 저장소를 갈아엎어야 한다. 지금 JSON 저장소는 잘 돈다 |

## 2. 무엇을 올리나

| CloudKit 기록 | 필드 | 올리지 않는 것 |
|---|---|---|
| `Moment` (recordName = `Moment.id`) | capturedAt, colorHex, source, word, labels, place, addedAt, batchID, **cloudID** | 사진 파일, `assetID`(이 기기 전용), `fileName`·`originalName`(이 기기 파일 이름) |
| `Day` (recordName = dayKey) | closedAt(마무리 시각, 없으면 nil), gifted(Bool) | — |

- 기기별 표시(`didSeeFirstRun`, `didSwipeToCamera`)는 올리지 않는다. 새 기기에서 안내를 한 번 더 보는 게 자연스럽다.
- 권한이 없어 파일로만 남은 사진은 기록(색·단어)만 올라간다. 다른 기기에선 그 순간의 색 면으로 보인다.
- iCloud 계정이 없거나 꺼져 있으면 지금처럼 로컬로만 돈다. 설정 화면은 만들지 않는다(몽돌엔 설정이 없다 — 끄기는 iOS 설정에서).
- **처음 켤 때 양쪽에 기록이 있으면 합친다.** 같은 `cloudID` 면 하나만 남기고 `capturedAt` 이 이른 기록을 기준으로 한다(같으면 `id` 문자열이 작은 쪽 — 결정적이어야 두 기기가 같은 답을 낸다).
- 받은 `Moment` 에는 `fileName` 이 없으므로 받는 기기가 자리 이름을 만든다: cloudID 가 있으면 `Moment.assetFileName(for: cloudID)`, 없으면 `"remote-" + id`.

## 3. 지우기가 번지는 규칙 — 가장 조심할 곳

아이패드가 사진을 못 찾는 이유는 여럿이다: 지워졌다 / iCloud 사진이 꺼져 있다 / 아직 안 내려왔다 / 「선택한 사진만」. 못 찾음을 삭제로 올리면 **아이폰의 기록까지 지워진다.**

1. **이 기기에서 실제로 본 사진만 지운다.** `Moment.assetID`(이 기기 에셋 ID)는 기기에만 남고 올라가지 않는다. 받은 기록은 `cloudID` 를 이 기기 에셋 ID로 찾았을 때만 `assetID` 가 채워진다. `AssetReconciler` 는 지금도 `assetID` 있는 기록만 보므로, 한 번도 찾은 적 없는 사진은 구조적으로 정리 대상이 아니다.
2. 기존 안전장치 그대로: 전체 접근(`.authorized`)일 때만 · 조회가 통째로 비면 안 지움 · 한 번에 `max(3, 20%)` 넘으면 그 회차 건너뜀 · 옵저버는 `removedObjects` 만.
3. 이 기기의 정리가 기록을 지우면 그 `Moment` 기록의 **CloudKit 삭제를 올린다.**
4. **다른 기기에서 온 삭제는 따른다** — 그 기기가 1·2 를 통과했다는 뜻이다.
5. 다시 깔거나 새 기기: 기록 단위 동기화라 빈 저장소가 전체를 덮지 않는다. 받은 기록은 `cloudID` 로 에셋을 다시 찾는다(복원 뒤 에셋 ID가 바뀐 경우도 같은 길 — photo-assets §8-4 해결).
6. 못 찾은 받은 기록은 색 면으로 그리고, **앱이 앞으로 올 때 · 사진 앱이 바뀔 때** 다시 찾는다(iCloud 사진이 늦게 내려오는 경우).

## 4. 부딪칠 때 (같은 기록을 두 기기가 고침)

| 필드 | 규칙 |
|---|---|
| word · labels | **먼저 붙은 쪽이 이긴다** — 이미 word 가 있는 기록은 다시 뽑지 않는다. 받은 쪽에 word 가 있고 내 쪽에 없으면 받은 쪽 |
| Day.closedAt | 더 이른 시각 |
| Day.gifted | 한 번 true 면 true (OR) |
| 나머지 | 찍을 때 정해지고 안 바뀐다 — 서버 쪽 그대로 |
| cloudID | 있는 쪽 (nil 은 모름일 뿐) |

## 5. 하루 경계와 증정

- dayKey(4시 경계)는 **보는 기기의 시간대**로 계산한다(지금 그대로). 시간대가 다른 두 기기에서 새벽 사진이 다른 날로 보일 수 있다 — 드물어 그대로 둔다.
- **증정은 어느 기기에서든 한 번만** (Tabber 결정). `GiftLog` 을 「마지막 하루(`lastGiftedDayKey`)」에서 **받은 하루 집합**으로 바꾸고 `Day.gifted` 로 동기화한다.
  - 옮기기: 옛 `lastGiftedDayKey` 가 있으면 그 날 이하의 모든 기존 dayKey 를 받은 것으로.
  - `GiftSchedule.pending` 은 집합을 본다. 다른 기기에서 받은 하루는 조용히 열린 하루로 보인다.
  - 두 기기가 동시에 같은 하루를 여는 경합은 둘 다 장면이 뜰 수 있다 — 허용.
- 마무리(`DayClosures`)도 `Day.closedAt` 으로 동기화한다 — 아이폰에서 마무리하면 아이패드에서도 닫힌다.

## 6. 코드 구조

`Shared/` 는 CloudKit·Photos 를 모른다(잠금화면 확장이 컴파일한다). 동기화는 앱 타깃 `ColorMoments/Sync/` 에만.

```
Shared/Day/Moment.swift          cloudID: String? 추가 (옛 JSON 은 nil 로 읽힌다)
Shared/Day/DayStore.swift        변경 알림(추가·수정·삭제된 id) — 로컬 쓰기만 알린다
                                  applyRemote(upserts:deletes:) — 받은 변경 반영, 다시 알리지 않음
                                  setCloudID / resolveAsset(id, assetID)
Shared/Day/GiftSchedule.swift    GiftLog → 받은 하루 집합 + 옮기기
Shared/Day/DayClosures.swift     변경 알림 · applyRemote
ColorMoments/Sync/
  SyncRecords.swift              Moment·Day ↔ CKRecord 변환 + 합치기 규칙(§4)·중복 합치기(§2) — 순수 함수
  CloudSync.swift                CKSyncEngine 위임자: 보낼 변경 모으기, 받은 변경 적용,
                                  엔진 상태 직렬화(Documents/sync-state.data), 계정 변화 처리
  CloudIDMapper.swift            Photos: localIdentifier → PHCloudIdentifier (담기·입양 때),
                                  cloudID → localIdentifier (받을 때·다시 찾기)
                                  PHPhotoLibrary.cloudIdentifierMappings / localIdentifierMappings
ColorMoments/Library/
  AssetReconciler.swift          지운 뒤 CloudSync 에 삭제 알림(이미 DayStore 변경 알림으로 흐르면 추가 없음)
project.yml                      iCloud(CloudKit) capability, 컨테이너 iCloud.com.itlearning.colormoments,
                                  remote-notification 백그라운드 모드
```

- 로컬 저장은 지금 `days.json` 그대로. CloudKit 은 그 위의 복제본일 뿐이다 — 동기화가 멈춰도 앱은 로컬로 돈다.
- `CKSyncEngine` 의 보낼 목록은 DayStore·DayClosures·GiftLog 의 변경 알림으로 채운다.

## 7. 테스트

자동(XCTest, CloudKit 없이 순수 함수·저장소):
- 기록 변환 왕복 · `cloudID` 없는 옛 JSON 읽힘
- 합치기: word 먼저 붙은 쪽 · closedAt 이른 쪽 · gifted OR
- 같은 cloudID 두 기록 → 하나(결정적 선택)
- `applyRemote` 는 변경 알림을 내지 않는다 (되돌아 올라가지 않음)
- 받은 기록(assetID nil)은 `AssetReconciler.reconcile` 대상이 아니다
- GiftLog 옮기기 · 받은 하루는 pending 이 아니다

실기기(Tabber):
- [ ] 아이폰에서 찍으면 아이패드에 조약돌·사진이 뜬다 (둘 다 iCloud 사진 켬)
- [ ] iCloud 사진이 꺼진 기기는 색 면으로 보이고 아무것도 안 지워진다
- [ ] 앱을 지웠다 다시 깔면 기록과 사진 연결이 돌아온다 (기기 하나로도 확인 가능)
- [ ] 한쪽에서 받은 증정은 다른 쪽에서 다시 안 뜬다 · 마무리도 따라간다
- [ ] 사진 앱에서 지우면 양쪽에서 사라진다

## 8. 요확인

1. 자동 서명으로 CloudKit 컨테이너가 만들어지는지 — 안 되면 Tabber 가 개발자 계정에서 컨테이너 생성
2. `PHCloudIdentifier` 매핑이 「선택한 사진만」 권한에서 동작하는지
3. CloudKit 스키마: 개발 환경에서 기록 타입을 만든 뒤 출시 전 운영 환경으로 배포해야 한다(Tabber, CloudKit Console)
4. 개인정보: 장소(좌표)가 iCloud 에 올라간다 — 사용자 본인 개인 DB 라 개발자는 못 본다. 개인정보 라벨은 「수집 안 함」 유지 가능 (요확인)
