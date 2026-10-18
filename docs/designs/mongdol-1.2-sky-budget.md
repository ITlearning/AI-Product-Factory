# 몽돌 1.2 — 하늘 렌더 예산

상태: 초안(엔지니어링 리뷰 대상) · 2026-10-17 · 브랜치 `preview/mongdol-1.2` (b9080aa)

## 문제

하늘(Metal)을 1~10차에 걸쳐 증상마다 고쳤다. 고칠 때마다 다른 데서 문제가 나왔다: 스크롤 끊김을 잡자 구운 판 캐시가 넘쳐 구름이 안 나오고(10차), 그걸 잡자 메모리 상한이 사실상 없어졌고, 이번엔 16 Pro가 「전부」 스크롤 시험 뒤 매우 뜨거워졌다. 원인은 하나다 — **하늘이 얼마나 자주, 몇 장을, 얼마나 밝게, 얼마나 큰 메모리로 그려도 되는지(예산)를 정한 적이 없다.** 이 문서는 그 예산을 정하고, 예산을 지키는 구조로 한 번에 고친다.

목표: 「말」 칸을 1분 넘게 써도(스크롤·가만히 둠 모두) 16 Pro와 iPhone 13이 손에 뜨겁다고 느껴지지 않을 것, 그러면서 지금 그림 품질(9~10차 판정)은 유지.

비목표: 셰이더 그림 자체(구름·해·달·입자 모양) 변경, 장면 추가, 위젯 그림.

## 지금 구조 (코드에서 확인)

```
「말」 칸 (WordsView)
  ├─ 오늘의 한 장  WordSceneCard(.hero)  ── SceneSky(quality: .hero)
  └─ 목록 카드 ×N  WordCardSlot → WordSceneCard(.row) ── SceneSky(quality: .card)
                    animating = active && (seen || shown) && !SkyScroll.holds   (WordsView.swift:529)

SceneSky (SceneSky.swift:24)
  ├─ 늘: 구운 정지 그림 SkyStills (메인 밖 굽기, NSCache 64MB)
  └─ moves 이면: SkyView(MTKView, SkyViewPool 에서 빌림, 풀 상한 8)
        └─ Coordinator.draw (SkyView.swift ~1435)
              ├─ budget(for:) = SkyBudget(quality, tier, thermal, lowPower, live)
              ├─ fps = quality.fps (hero/full 120, card 30) — 장면 무관
              ├─ EDR: 모든 풀 뷰 wantsExtendedDynamicRangeContent = true, headroom ≤ 4
              └─ renderer.encode(...) — 뷰마다 하늘 전체 파이프라인을 따로 돈다
                    (하늘 합성 · 구운 구름 판 샘플 or 실시간 레이마칭 · 별·달·해 · 입자 · 블룸 · 마무리)

SkyCloudBank: 장면×모양×단계별 구운 구름 판, capBytes = max(40MB, 띠 판 6장)
              + 2초 안에 쓴 판은 상한을 넘어도 안 버림(10차) → 사실상 상한 없음
```

현재 예산 값(SkyView.swift:103-215):

| 항목 | 지금 |
|---|---|
| fps | hero·full 120 (최상·상), 60 (중·하) / card 30. 장면의 움직임과 무관 |
| 동시에 움직이는 뷰 | 화면에 보이는 카드 전부(멈춘 뒤) — 실측 최대 10 |
| 유휴 | 없음. 화면에 보이면 손을 안 대도 계속 그림 |
| EDR | 모든 움직이는 뷰(카드 포함), headroom 최대 4 |
| 발열 | serious·critical 에서만 단계 하나 내리고 30fps. fair 는 아무것도 안 함 |
| 저전력 | 최대 60fps (EDR 그대로) |
| GPU 메모리 | 구운 판 40MB+(사실상 무제한) · 정지 그림 64MB · 뷰마다 drawable 3장(rgba16F) + 블룸·구름 중간 텍스처 |

## 실측 (Tabber, iPhone 16 Pro, 2026-10-17 스크롤 시험, 카드 37장, 약 1,290프레임/회)

| 구조 | 놓침 | 끊김 | 최악 | 하늘 그리기 최악 | 동시 뷰 |
|---|---|---|---|---|---|
| 옛(8차) 최상 | 19 | 16 | 25.0ms | 15.0ms | 12 |
| 새(10차) 최상 | 6 | 5 | 25.0ms | 10.5ms | 10 |
| 새 상 | 5 | 5 | 19.4ms | 2.0ms | 10 |
| 새 중 | 8 | 7 | 25.0ms | 2.0ms | 10 |
| 새 하 | 2 | 2 | 16.1ms | 1.9ms | 10 |

「전부」(6회 연속) 뒤 기기가 매우 뜨거움. 전력·온도는 재지 않았다(계측 없음).

## 예산 원칙

1. **장면이 실제로 움직이는 만큼만 그린다.** 구름은 초당 수 pt, 별은 5~10초 주기 — 30fps면 눈에 차이 없다. 빠른 입자(비·눈·꽃잎·낙엽·바람)만 60. 120은 「펼친 말」처럼 한 장을 오래 들여다보는 화면에서만.
2. **눈이 머무는 곳만 움직인다.** 동시에 움직이는 하늘은 오늘의 한 장 + 화면 가운데에 가까운 카드 몇 장. 나머지는 구운 정지 그림(이미 있음).
3. **가만히 두면 내려간다.** 손을 떼고 시간이 지나면 박자를 낮추고, 더 지나면 멈춘다. 다시 만지면 바로 돌아온다.
4. **EDR은 한 장에만.** 화면 흰색보다 밝은 빛은 화면 밝기를 올려 전력을 쓴다 — 오늘의 한 장·펼친 말·전체 화면만.
5. **발열에 일찍 반응한다.** fair부터 한 단계 낮추고, critical이면 전부 멈춘다.
6. **메모리는 고정 상한.** 상한을 넘기는 예외를 두지 않는다. 대신 한 화면에 필요한 판 수가 상한 안에 들어오게 판 크기·개수를 정한다.
7. **숫자로 본다.** 초당 그린 프레임 합계·GPU ms/초·동시 뷰 수·발열 상태·GPU 메모리를 디버그 계측에 늘 띄우고, 유휴 시험을 스크롤 시험 옆에 둔다.

## 제안 예산

| 항목 | 제안 |
|---|---|
| fps (장면 박자) | 고요한 장면(맑은 낮·맑은 밤·흐린 밤·새벽·노을·안개·서리) 30 / 입자 장면(비·가는 비·눈·꽃잎·낙엽·바람) 60 / 펼친 말·전체 화면(live)은 그 두 배까지(최대 120, ProMotion일 때) |
| 동시 움직임 | 최대 3 (오늘의 한 장 + 화면 가운데에 가까운 카드 2) |
| 유휴 | 마지막 터치·스크롤 뒤 20초: 박자 절반(최소 15). 60초: 오늘의 한 장만 15fps, 나머지 정지. 앱이 비활성(scenePhase ≠ active)이면 전부 정지 |
| EDR | 오늘의 한 장·펼친 말·전체 화면만. 카드는 SDR(headroom 1). 저전력·발열(fair 이상)이면 끔 |
| 발열 | nominal 그대로 / fair: 120→60, 단계 하나 내림 / serious: 단계 둘 내림·30fps·동시 1 / critical: 전부 정지(정지 그림) |
| 저전력 | 최대 30fps, EDR 끔, 동시 1 |
| GPU 메모리 | 하늘 전체 상한(최상 64MB, 상 56MB, 중 40MB, 하 24MB). 구운 판은 엄격 LRU(유예 없음), 판 크기는 단계 상한에 맞춤. 카드 drawable 2장 |

## 바꿀 것 (제안)

1. `SkyBudget`에 장면 박자(`motionClass`)·유휴·EDR·동시 상한을 넣고, fps를 `quality.fps` 대신 예산에서 정한다. (SkyView.swift)
2. 「움직여도 되는 카드」를 고르는 조정자 하나(`SkyConductor`, 메인 액터): 보이는 카드 중 화면 가운데에 가까운 순으로 상한까지 허락, 유휴·발열·저전력·scenePhase 반영. `WordCardSlot`·`SceneSky`는 허락을 받아야 움직인다. (WordsView.swift, SceneSky.swift, 새 파일 1)
3. EDR을 뷰 쓰임새별로: 풀에서 빌릴 때 hero/full/live만 `wantsExtendedDynamicRangeContent`. (SkyView.swift — 풀이 두 종류가 되거나 빌릴 때 설정)
4. `SkyCloudBank`의 2초 유예 제거, 단계별 고정 상한 + LRU. 상한 안에 한 화면 판이 들어오도록 판 크기 조정. (SkyCloudBank.swift)
5. 계측: 초당 그린 프레임 합계, GPU ms/초 합계, 동시 뷰 수, thermalState, 하늘 GPU 메모리 합계. 「유휴 시험」(60초 손 안 댐) 추가, 결과는 Documents/sky/scroll.txt에. (SkyScrollTest.swift, SkyGalleryView.swift)

예상 변경: 수정 6파일 + 새 파일 1(조정자) + 테스트 1~2.

## 검증

- 단위: 예산 표(장면×쓰임새×단계×발열×저전력×유휴)가 위 표와 같은지, 조정자가 상한·가운데 우선·scenePhase를 지키는지, 구운 판 메모리가 상한을 넘지 않는지.
- 시뮬레이터: 스크롤 시험·유휴 시험 수치(초당 프레임 합계·동시 뷰·메모리).
- 실기기(Tabber): 16 Pro·iPhone 13에서 「말」 칸 3분 사용(스크롤 1분 + 가만히 2분) 뒤 손 온도 체감, thermalState 기록, 스크롤 시험·유휴 시험 결과 파일.

## 열린 질문

- 동시 움직임 3장이 「살아 있는 목록」 느낌에 충분한가(Tabber 판단).
- 120fps를 펼친 말에만 남기는 게 맞는가, 아예 60 상한이 나은가.
- 유휴 시간(20초·60초) 값.

---

## Eng Review (/plan-eng-review, 2026-10-17)

도구 상태: gstack 업그레이드 뒤 bun 이 없어 learnings 검색·reality rows 자동 점검·review-log 가 돌지 않음 — 아래 reality rows 는 손으로 확인. Codex 인증 만료 → 외부 시각은 독립 에이전트(native fallback).

### Scope Challenge
- 변경 규모: 수정 6 + 새 파일 1(조정자) — 8파일·새 클래스 2 미만이라 복잡도 질문 생략.
- [S1] (confidence 9/10) `SkyView.swift:1192` `public final class SkyScroll` — 스크롤 상태(`moving`·`holds`·`cap`)를 이미 들고 있는 전역 관찰 객체. 새 `SkyConductor` 대신 이걸 `SkyActivity`(스크롤·유휴·발열·저전력·scenePhase·움직임 허락)로 넓히면 새 파일 0, 상태 원천 하나. [Layer 1: 이미 있는 것 재사용]
- [S2] (confidence 8/10) 발열 원인이 「렌더링 양」이라는 전제는 **측정되지 않았다**(전력·온도 계측 없음, 문서 「실측」 절). 예산 값을 정하기 전에 계측(바꿀 것 5)을 먼저 넣고 전후를 같은 시험으로 잰다.

### Reality rows (손 점검)
- premise-table: 동시 뷰 10(`SkyScrollTest` 표·`WordsView.swift:529` `animating: active && (seen || shown) && !SkyScroll.shared.holds`) 확인 · fps 장면 무관(`SkyView.swift:118` `public var fps: Int { self == .card ? 30 : 120 }`) 확인 · EDR 전 뷰(`SkyView.swift:1273` `layer.wantsExtendedDynamicRangeContent = true`) 확인 · 유휴 없음(SkyView·SceneSky 에 scenePhase/idle 없음, grep 0) 확인 · 판 캐시 상한 무력(`SkyCloudBank.swift:17` `static let inUse = 2.0`, `:119` `where total > cap && old !== p && now - old.lastUse > Self.inUse`) 확인 · **발열=렌더링 양: unverified**. unverified=1
- already-done: pass — main(7cc5eb2)·다른 브랜치에 예산 작업 없음.
- surface-check: pass — `onScrollVisibilityChange`(iOS 18, 최소 18.0), `ProcessInfo.thermalState`, `CAMetalLayer.wantsExtendedDynamicRangeContent`, `MTKView.preferredFramesPerSecond`(120 은 `CADisableMinimumFrameDurationOnPhone` 켜짐) 모두 있음.
- binding-decisions: **finding** — Tabber 는 「16 Pro니까 120Hz 해야겠네」(2026-10-16)로 120fps 를 원했다. 제안의 「120은 펼친 말만」은 이 결정을 뒤집는다 → Tabber 결정 필요(D1).
- numbers: finding — 동시 3·유휴 20/60초·메모리 상한(64/56/40/24MB)은 근거 없는 제안값. 계측 뒤 조정 가능한 상수로.
- deferred-asks: pass — Tabber 「최상·상 최적화 아니면 제거」는 9차에서 구조로 답함, 이번 문서는 발열.
- pr-count: n/a — preview 에 합친 뒤 1.2 최종 PR 하나.
- units(perf): pass — fps·ms·MB 로 통일.
- perf-table(perf): finding — 전후 비교는 스크롤 놓침뿐, 전력·온도 기준선 없음(S2).

### 1. Architecture
- [P1] (confidence 9/10) `SkyView.swift:1273` — 풀의 모든 MTKView 에 EDR. 카드 30fps × 최대 9장이 EDR 레이어면 화면이 HDR 모드로 머물러 밝기·전력이 오른다. 쓰임새별(hero/full/live만)로.
- [P1] (confidence 8/10) `WordsView.swift:529` — 보이는 카드가 전부 움직인다(실측 10). 허락 상한이 없다.
- [P2] (confidence 8/10) SkyView·SceneSky 에 scenePhase 처리가 없다 — 제어 센터·알림 센터를 내려 앱이 inactive 여도 화면에 보이는 하늘은 계속 그린다(백그라운드에선 디스플레이 링크가 멈추지만 inactive 에선 돈다).
- [P2] (confidence 7/10) `SkyView.swift:1427` — 발열·저전력은 매 프레임 `ProcessInfo` 를 읽어 반영하지만, 멈춘(정지 그림) 뷰는 다시 그려지지 않아 상태가 바뀌어도 반응 시점이 다음 그리기까지 늦다. 알림(`thermalStateDidChangeNotification`·`NSProcessInfoPowerStateDidChange`)을 받아 허락을 다시 계산.
- 실패 경우: critical 발열에서도 30fps 로 계속 그림(`SkyView.swift:205` `if hot { fps = 30 }`) — 멈춰야 한다.

### 2. Code quality
- [P2] (confidence 8/10) `SkyView.swift:186-213` — `SkyBudget.init` 이 단계별 switch 에 상수가 흩어져 있다. 장면 박자·유휴·발열 층이 더해지면 읽기 어려워진다 → 박자(fps)·허락(동시·EDR)은 별도 순수 함수(`SkyPace`)로, 그림 무게(걸음·옥타브)만 `SkyBudget` 에.
- [P2] (confidence 9/10) `SkyCloudBank.swift:119` — 2초 유예가 상한을 무력화(10차에 「구름이 안 나옴」 고치려 넣음). 원인은 한 화면 장면 수(8) > 판 상한(6). 유예 대신 「지금 허락된 뷰가 쓰는 판」만 고정하고 나머지는 엄격 LRU — 동시 3이면 판도 최대 3+α.

### 3. Tests
```
CODE PATHS                                         USER FLOWS
[+] SkyPace(장면, 쓰임새, 단계, 발열, 저전력, 유휴)   [+] 「말」 칸 3분(스크롤 1분 + 가만히 2분)
  ├── [GAP] 고요/입자 장면 30/60                      ├── [GAP][실기기] 손 온도·thermalState 기록
  ├── [GAP] live 만 120(D1 결과)                       ├── [GAP] 20초 뒤 박자 절반, 60초 뒤 hero 만
  ├── [GAP] fair/serious/critical 단계                 └── [GAP] 터치하면 즉시 원래 박자
  └── [GAP] 저전력 30·EDR 끔                         [+] 제어 센터 내림(inactive) → 정지
[+] SkyActivity 허락                                  [+] 펼친 말 → 120(또는 60) 유지
  ├── [GAP] 보이는 카드 중 가운데 가까운 순 상한까지
  ├── [GAP] 허락 바뀔 때 정지 그림과 이어짐(튐 없음) — 기존 SkyScrollTests 확장
  └── [GAP] scenePhase·알림으로 재계산
[+] SkyCloudBank
  ├── [★★ TESTED] 판 번호·한 프레임 한 줄 — SkyScrollTests
  └── [GAP] 상한 초과 없음(유예 제거 뒤), 허락된 뷰 판은 안 버림
[+] 계측
  └── [GAP] 초당 프레임 합계·GPU ms/초·메모리 합계가 결과 파일에
COVERAGE: 1/13
```
회귀(CRITICAL): 10차 「구름이 안 나옴」(판끼리 밀어냄)이 유예 제거로 돌아오면 안 된다 → 한 화면 8장면 목록에서 허락된 카드의 구름이 다 보이는지(기존 `testUnbakedPlateIsNeverRead`·스크롤 덤프 확장).

### 4. Performance
- [P1] (confidence 7/10) `SkyView.swift:1257-1290` — 풀에 쉬는 MTKView 최대 8개가 drawable(기본 3장, rgba16Float)을 잡은 채로 남는다. hero 크기면 장당 약 6MB(1062×696×8B) × 3. `maximumDrawableCount = 2` + 쉴 때 `releaseDrawables()`.
- [P2] (confidence 6/10, Medium — 실측 필요) 뷰마다 블룸·구름 샘플 중간 텍스처를 따로 가진다. 동시 3이면 문제 작음.
- 계측 근거 없음 — 전력은 MetricKit 이 하루 단위라 개발 중엔 쓸모 적다. 프록시: 초당 GPU ms 합계(`MTLCommandBuffer.gpuStartTime/gpuEndTime`, 이미 hero 계측에 있음) + thermalState 시계열.

### Outside Voice (독립 에이전트 — Codex 인증 만료로 native fallback)
제 리뷰와 겹치지 않는, 반영할 지적:
- **O1 측정 먼저 (7/10)** 상·중·하 「하늘 그리기 최악」이 2ms 남짓이라 하늘 GPU 주범 근거가 약하다. 다른 후보: (A) 정지 그림 캐시 64MB(`SceneSky.swift:78`)에 카드 37장(seed 마다 다른 키)이 다 안 들어가 스크롤마다 다시 굽기 — 굽기마다 GPU 렌더 + `waitUntilCompleted` + CIContext 변환, 이미 있는 `SkyStats` `stills`/`stillMs` 계측을 표에 안 씀 (B) 메인 스레드 draw 마다 달 나이·SkyFrame·라벨 문자열·통계 배열(초당 ~420회) (C) hero 기울기 CoreMotion 30Hz (D) 120fps 뷰 하나가 패널 전체를 120Hz 로 묶음, 시험 자체 6분. → 대조 실험(하늘 정지 vs 지금) + stills 카운터 + thermalState 시계열.
- **O2 메모리 최대 항목 누락 (8/10)** drawable rgba16F 3장 × 뷰(카드 한 장 ~18MB, 10뷰 ~180MB), 쉬는 풀 뷰가 drawable 을 쥘 수 있음(`SkyViewPool.give` 는 releaseDrawables 없음). → 풀 상한 = 동시 상한, `releaseDrawables()`, `maximumDrawableCount = 2`(이미 inFlight≥2 건너뜀), 상한을 「drawable+중간+판+정지 그림」 전체로.
- **O3 카드 해상도·포맷 (7/10)** 카드는 구름만 0.34배, 합성·블룸은 3배 그대로. 카드 MTKView `contentScaleFactor` 1.5~2 + SDR 카드는 bgra8 → 채우기·메모리 2~4배 절감, 눈 차이 거의 없음.
- **O4 허락이 바뀌면 튄다 (8/10)** 정지 그림은 `stillPhase` 고정, 새 Coordinator 는 그 시각부터 → 허락 잃을 때 되감김. 「가운데 가까운 순」은 조금만 스크롤해도 바뀜. → 히스테리시스(최소 유지 시간·순위 차) + 멈출 땐 뷰 유지 `isPaused`(마지막 프레임). EDR↔정지 그림 밝기 튐 → headroom 을 0.5초에 걸쳐 내림.
- **O5 EDR (6/10)** hero 가 EDR 이면 카드를 SDR 로 해도 백라이트 비용은 거의 그대로. 「말」 목록 hero 는 headroom ≤1.5~2, 큰 EDR 은 펼친 말·전체 화면만. 메모리 상한은 발열과 무관하게 plateTier 에 묶을 것(뜨거울 때 재굽기 몰림 방지).
- **O6 엄격 LRU 는 10차 회귀 (7/10)** 백그라운드 정지 그림 굽기도 `plate()` 를 부름 → 보이는 판을 밀어냄. 시간 유예 대신 움직이는 뷰가 쥔 판은 참조 카운트로 고정, 나머지만 LRU. 동시 3이면 판 3~4장.
- **O7 실패 경우 (6/10)** 정지 카드는 draw 가 안 돌아 발열·저전력 회복을 모름 → 알림 구독(임의 스레드 → 메인). inactive 정지 때 `clock.set(running:false)` 같이(복귀 시 점프). 별똥별 30fps 계단 가능성, 유휴 15fps 대신 정지. 장기: CADisplayLink 하나로 허락된 뷰만 몰아 그리기(이번엔 보류 권장).
- **가장 큰 위험**: 측정 없이 조정자·EDR·LRU 를 한꺼번에 바꿔 9~10차 반복. → 순서: 1) 대조 측정 2) 싸고 확실한 것(카드 해상도·포맷, releaseDrawables, 풀 상한, 정지 그림 캐시) 3) 조정자(히스테리시스·되감김 방지).

리뷰어 합의: S2(측정 없음)·O1, P1 EDR·O5, 판 캐시(P2)·O6 는 두 리뷰가 같은 곳을 짚음. 서로 다른 점: 외부는 「엄격 LRU」를 반대(참조 고정) — 채택.

## Decision ledger
- **D1 120fps 범위** — State: approved. Actual answer: 「큰 카드는 120 유지」(2026-10-17 Tabber). Accepted scope: 「말」 칸 오늘의 한 장·펼친 말·전체 화면은 지금 박자(최상·상 120) 유지. 카드는 장면 박자(고요 30 / 입자 60)를 넘지 않음. 발열 절감은 해상도·버퍼·동시 장수·유휴에서.
- **D2 동시에 움직이는 하늘** — State: approved. Actual answer: 「5장」. Accepted scope: 오늘의 한 장 + 화면 가운데에 가까운 카드 4장, 히스테리시스(최소 유지 시간)·되감김 없음(O4). 풀 상한도 5(O2).
- **D3 가만히 둘 때** — State: approved. Actual answer: 「멈추지 않고 느리게만」. Accepted scope: 마지막 터치·스크롤 20초 뒤 박자 절반(120→60, 60→30, 30→15 — 아래로는 15). 정지는 하지 않음. 단 앱 비활성(제어 센터·알림 센터·전환기, scenePhase ≠ active)이면 정지 + `clock.set(running:false)`(O7).
- **D4 진행 순서** — State: approved. Actual answer: 「측정→확실한 것→조정」. Accepted scope: 단계마다 preview 에 올리고 Tabber 폰 확인 뒤 다음 단계.

## 확정 실행 계획 (D1~D4 반영)
**1단계 — 측정 (먼저, 동작 변화 없음)**
- 디버그 「하늘 정지」 스위치(모든 하늘을 정지 그림으로) → 같은 시험을 켬/끔으로 대조(O1).
- 결과 파일에 초당 그린 프레임 합계·GPU ms/초 합계·동시 뷰·풀 쉬는 뷰·정지 그림 굽기 수/ms(`stills`)·구운 판 수·하늘 GPU 메모리 추정 합계·thermalState 시계열(10초 간격) 추가.
- 「유휴 시험」(손 안 대고 120초) 추가.
**2단계 — 확실한 절감 (1단계 수치 확인 뒤)**
- 카드 MTKView `contentScaleFactor` 2(@3x 기기), 카드는 SDR + bgra8 포맷(O3). hero 는 그대로 rgba16F·EDR(D1).
- 모든 하늘 레이어 `maximumDrawableCount = 2`, 풀에 돌려줄 때 `releaseDrawables()`, 풀 상한 5(O2·D2).
- 정지 그림 캐시 상한을 카드 크기 기준으로 다시 정하고, 넘치면 「화면에서 먼 것부터」(O1-A).
- 구운 판: 2초 유예 → 움직이는 뷰가 쥔 판 참조 고정 + 나머지 LRU, 상한은 plateTier 에 묶음(O5·O6). 10차 회귀(구름 안 나옴) 테스트 유지.
**3단계 — 조정 (2단계 확인 뒤)**
- `SkyScroll` 을 `SkyActivity` 로 넓혀(S1, 새 파일 없음) 움직임 허락: 동시 5(가운데 가까운 순, 최소 유지 2초·순위 차 2 이상일 때만 교체), 장면 박자(카드 고요 30 / 입자 60), 유휴 20초 박자 절반(D3), scenePhase 비활성 정지, 발열 알림·저전력 알림 구독(O7 — 메인으로).
- 발열: fair 120→60 / serious 단계 하나 내림·30 / critical 30·동시 1(정지는 안 함 — D3 취지). EDR: 카드 없음, hero 는 「말」 목록에서 headroom ≤ 2, 펼친 말·전체 화면만 4(O5). 발열·저전력 진입 시 headroom 을 0.5초에 걸쳐 내림(O4).
- 멈출 때 뷰를 떼지 않고 `isPaused`(마지막 프레임 유지) — 되감김 없음(O4).
**보류(NOT in scope)**: CADisplayLink 하나로 몰아 그리기(O7 장기안), 셰이더 그림 변경.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|---|---|---|---|---|---|
| Eng Review | /plan-eng-review | 하늘 발열·땜질 반복 → 렌더 예산 | 1 | DONE_WITH_CONCERNS | Arch 4 · Quality 2 · Test 13 gaps · Perf 2 · Scope 2 |
| Outside Voice | native fallback (Codex 인증 만료) | 독립 반박 | 1 | DONE | 7 (O1~O7) |

**VERDICT:** 계획 승인(D1~D4) — 3단계로 실행, 단계마다 실기기 확인.
**OUTSIDE COVERAGE / CROSS-MODEL:** Codex 없음(인증 만료) — 같은 모델 계열 독립 에이전트로 대체, 교차 모델 검증은 아님.
**CONCERNS:** 발열 원인 미측정(1단계로 해소 예정) · gstack bun 없음으로 learnings/reality rows/review-log 자동 도구 미사용(손 점검).
**UNRESOLVED DECISIONS:**
NO UNRESOLVED DECISIONS
