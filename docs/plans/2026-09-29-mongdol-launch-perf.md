# 몽돌 첫 로드 CPU 치솟음 분석 (2026-09-29)

> 상태: 분석 끝, 코드 수정 전. 다음 할 일은 **실기기 Release·디버거 없음 측정**(§7). 그 결과로 §6 우선순위를 확정한다.
> 이 문서는 코드를 한 줄도 바꾸지 않고 읽기·측정만 해서 쓴 것이다. file:line 은 2026-09-29 02:40 KST 작업 트리 기준 — 메인 작업이 진행 중이라 줄 번호가 밀릴 수 있다(심볼 이름으로 다시 찾을 것).

## 1. 결론

- **iPhone 13 Xcode 게이지 CPU 90~115% 는 앱을 켤 때 한 번 치솟는 CPU(launch burst)이고, 디버그 탓으로 볼 근거는 없다.** 시뮬레이터에서 Debug·Release 를 3회씩 재 보니 최고 CPU(Debug 87~91%, Release 92~116%)도, 켤 때 쓴 CPU 총량(Debug 1.42~1.52초, Release 1.33~1.61초)도 반복 오차 안이었다. 3초 뒤로는 둘 다 1% 안팎으로 떨어진다.
- 치솟는 CPU 대부분은 **앱 코드가 아니라 시스템 쪽**이다: SwiftUI AttributeGraph 타입 레이아웃(약 150ms, 백그라운드), 프레임워크 로딩(dyld), 사진 디코딩. 메인 스레드에서 앱 코드가 쓴 시간은 Release 기준 60~80ms 정도다(가장 큰 것은 CKSyncEngine 생성 17ms, `AssetReconcilerObserver.init` 16~20ms).
- 아이폰 13(A15)은 M4 Pro 보다 코어가 약 1.8배 느리다(추정) → 같은 일이 2초쯤 100% 안팎으로 이어져도 정상 범위.
- **끊김 22회·최악 249ms 는 시뮬레이터에서 재현되지 않았다**(Debug, 디버거 없음: 60fps · 끊김 0 · 최악 16.7ms). 기기에서만 있는 조건이 원인일 가능성이 크다.
  - Xcode 디버거 연결: 프레임워크를 새로 불러올 때마다(dlopen) dyld 가 디버거에 동기로 알리며 메인 스레드를 세운다. 같은 종류의 대기를 시뮬레이터에서 `sample` 을 붙였을 때 290~310ms 확인했다(§4).
  - 실제 사진 보관함·iCloud 사진 부하(시뮬레이터엔 없음).
- 앱 코드 쪽 1순위 후보는 **사진 앱 변경 알림마다 화면 썸네일 전체 재요청 + 전체 재조회**(`AssetReconciler.swift:245-262`). 시뮬레이터엔 iCloud 사진이 없어 비용은 재지 못했다(가능성).

## 2. 측정 조건 (재현용)

### 환경

| 항목 | 값 |
|---|---|
| 호스트 | MacBook Pro, Apple M4 Pro (14코어), macOS 26.6.2 (25G83) |
| Xcode | 26.0.1 (17A400), xctrace 26.0 |
| 시뮬레이터 | iPhone 16, iOS 18.0 (22A3351), UDID `7A4E21A9-3FE5-48D5-A972-2DD1D4203195` (메인 에이전트용 `586BD801-…` 은 건드리지 않음) |
| 소스 | HEAD `1094e3f` + 커밋 안 된 작업 트리(2026-09-29 02:12 KST 빌드). `HomeBackdropBlend`·`SoftPebbleView.precompile()` 호출·설정 시트·프레임 측정기 배지 등이 들어간 상태 |
| DerivedData | `/private/tmp/claude-501/-Users-tabber-AI-Product-Factory/18dbafd8-cb15-44e4-9a3f-cbd0001b95c8/scratchpad/perf/dd` |

### 빌드 설정 (`Color-Moments/project.yml`, `ColorMoments.xcodeproj/project.pbxproj`)

| | Debug | Release |
|---|---|---|
| Swift 최적화 | `-Onone`, `ENABLE_TESTABILITY = YES` | `-O`, `SWIFT_COMPILATION_MODE = wholemodule` |
| Metal | `MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE`, `MTL_FAST_MATH = YES` | `MTL_ENABLE_DEBUG_INFO = NO`, `MTL_FAST_MATH = YES` |
| 기타 | 앱 코드가 `ColorMoments.debug.dylib` 에 들어감(프리뷰용 debug dylib) | 실행 파일에 직접 |
| 공통 | `SWIFT_VERSION = 5.10`, `SWIFT_STRICT_CONCURRENCY = minimal`, iOS 18.0 | |

Swift 5.10 모드라 `nonisolated async` 함수(`ShotImage.warmWithRetry` 등)는 전역 실행기에서 돈다 — 트레이스에서 썸네일 경로가 백그라운드 스레드에 잡힌 것으로 확인.

스킴(`ColorMoments.xcscheme` LaunchAction)은 진단 설정을 따로 두지 않았다 → Xcode 기본값(Main Thread Checker 켬, Metal API Validation 켬, GPU Frame Capture 자동)으로 돈다.

### 데이터 (견본)

- 생성기: `scratchpad/perf/fixture/gen.py 180 8 <out>` → 180일 × 하루 8장(오늘은 3장) = **1,435개**.
- 최근 32일 251개: 4032×3024 JPEG(0.5~2.2MB, `ColorMomentsTests/Fixtures/*.jpg` 를 `sips` 로 키운 것). 앱이 첫 실행에서 **스스로 사진 앱에 입양**해 assetID·cloudID 가 붙고 파일은 지워졌다 → 실사용과 같은 "입양 끝난" 상태. 측정은 전부 이 상태에서 했다.
- 나머지 1,184개: `fileName = remote-<id>`, assetID·cloudID 없음(압축 한 줄 행이라 사진을 안 그린다. fileBacked 로 잡혀 매번 입양 시도가 돌지 않도록 바꿈). 최종 파일: `scratchpad/perf/fixture/days-adopted.json`.
- UserDefaults: `didFinishOnboarding`·`didAskArrivalNotice`·`didOfferLibraryOnboarding`·`didSwipeToCamera` = YES, `giftedDayKeys = ["2026-09-27"]`(증정 장면이 안 뜨게).
- 권한: 사진 = 결과적으로 허용 상태(`simctl privacy revoke` 를 했는데도 첫 실행 권한 창 뒤 입양이 돌았다). 알림 = 미결정.
- iCloud: 시뮬레이터에 계정 없음 → CKSyncEngine 이 받아올 게 없다. 대신 `sync-state.json` 이 313KB(올리지 못한 변경 1,435건이 쌓인 상태)라 **실기기와 다르다**.
- 시뮬레이터에 접근성 자동화가 켜져 있어 앱이 AX 번들을 불러온다(`-[UIApplication _accessibilityInit]`) → 실기기(접근성 기능 꺼짐)엔 없는 비용.

### 방법

1. `xcrun xctrace record --template 'Time Profiler' --device <UDID> --time-limit 10s --launch -- <app>` → `time-profile`·`potential-hangs` 표를 XML 로 뽑아 `tp.py` 로 요약. 샘플 간격 1ms, **실행 중인 스레드만** 잡는다(막혀 기다린 시간은 안 보임).
2. 막힘을 보려고 `sample <pid> 3 1` 로 프로세스 시작 직후부터 모든 스레드를 떴다 → `waits.py` 로 메인 스레드의 대기 원인을 모았다.
3. 순수 계산은 호스트에서 `swiftc -Onone` / `-O` 로 따로 벤치(`bench/*.swift`, 앱 코드를 옮긴 사본).
4. 매 측정 전 앱을 끄고 1.5초 쉼. 설치 직후 1회는 예열로 버렸다. 명령은 `scratchpad/perf/run.sh <Debug|Release> <라벨>`.

## 3. 측정 결과

### 3-1. 켤 때 CPU (Time Profiler, 첫 10초)

| 실행 | 설정 | 최고 CPU(500ms 창, 100%=코어 1개) | 총 CPU | 메인 CPU | Hangs 도구 |
|---|---|---|---|---|---|
| d1 | Debug | 90% | 1,465ms | 649ms | 262ms |
| d2 | Debug | 91% | 1,415ms | 577ms | 268ms |
| d3 | Debug | 87% | 1,519ms | 637ms | 없음 |
| r1 | Release | 106% | 1,327ms | 562ms | 없음 |
| r2 | Release | 116% | 1,606ms | 696ms | 495ms |
| r3 | Release | 92% | 1,607ms | 718ms | 485ms |
| dx1 | Debug + Main Thread Checker + Metal API 검증(`MTL_DEBUG_LAYER=1`, `METAL_DEVICE_WRAPPER_TYPE=1`) | 103% | 1,514ms | 694ms | 417ms |
| dm1 | Debug + 프레임 측정기 켬 | 79% | — | — | 278ms. 3초 뒤로 메인 4~5% 계속(측정기 끄면 0~1%) |

- 모양은 모두 같다: 프로세스 시작 뒤 1~2초 동안만 높고, 3초 뒤로는 1% 안팎.
- 치솟는 순간은 백그라운드 스레드가 몰리는 때다(메인 13~37% + 나머지 57~103%).

### 3-2. 주요 경로별 CPU (ms, 메인 / 백그라운드)

| 경로 | d1 (Debug) | r1 (Release) | r2 (Release) |
|---|---|---|---|
| `SoftPebble*` (조약돌 값 계산·body) | 9 / 0 | 2 / 0 | 1 / 0 |
| `CKSyncEngine` 생성 | 18 / 0 | 18 / 0 | 18 / 0 |
| `AssetReconcilerObserver.init` | 12 / 0 | 16 / 0 | 20 / 0 |
| `-[RBLayer display]` (셰이더 레이어 그리기) | 6 / 0 | 8 / 0 | 8 / 0 |
| `CA::Transaction::commit` 전체 | 67 / 0 | 64 / 0 | 85 / 0 |
| `AssetReconciler.existing` (전체 assetID 조회) | 0 / 8 | 0 / 7 | 0 / 9 |
| `ShotImage.thumbnail` (썸네일) | 0 / 15 | 0 / 6 | 0 / 20 |
| `DayStore.readFile` (days.json 디코딩) | 0 / 14 | 0 / 7 | 0 / 7 |

시스템 쪽 상위(Release r1, 백그라운드): dyld `<deduplicated_symbol>` 169ms(`-[NSBundle loadAndReturnError:]` 번들 로딩 — 시뮬레이터 AX 번들이 대부분), `swift_conformsToProtocol…` 152ms(호출자: `AG::LayoutDescriptor::make_layout` ← `TypeDescriptorCache` — SwiftUI 가 뷰 타입 비교 레이아웃을 준비), JPEG 디코딩·vImage 축소 약 100ms.

### 3-3. 순수 계산 벤치 (호스트 M4 Pro, 3회 중 안정값)

| 항목 | -Onone | -O | 배수 |
|---|---|---|---|
| `SoftPebbleUniforms.init` 1개(캐시 미스, floorAnchor + 색표) | 2.5ms (첫 회 10.8ms) | 0.23~0.26ms | 약 10배 |
| └ `floorAnchor` (180방향 × 22회 이분법) | 0.63ms | 0.22ms | 약 3배 |
| └ 색표 `table` (128 × 3줄, SIMD3) | 1.85ms | 0.023ms | 약 80배 |
| `SoftPebbleShape.outline()` 120점(점선 조약돌 Path) | 0.39ms | 0.13~0.2ms | 2~3배 |
| `DateFormatter` 1개 만들어 한 번 쓰기 | 0.03~0.05ms | 같음 | — |
| 시스템 필드 `[String: Data]` JSON 디코딩 500/1,500/3,000건(700B) | 1.6/4.3/8.7ms | 2.4/4.7/9.0ms | 차이 없음(Foundation) |
| days.json 인코딩(`.prettyPrinted, .sortedKeys`) 1,500/3,000개 | 15/26ms | 16/25ms | 차이 없음 |

→ Debug 가 확실히 느려지는 건 앱 모듈의 제네릭·SIMD 계산뿐이고 절대값이 작다. Foundation 이 일하는 JSON 등은 설정과 무관하다.

## 4. Hangs 결과 해석

- xctrace Hangs 가 Debug·Release 가리지 않고 **262~495ms 짜리 멈춤**을 잡았다(3-1 표).
- 그 창의 메인 CPU 는 108~152ms 뿐 → 나머지는 **막혀서 기다린 시간**이다.
- `sample` 로 메인 스레드 대기를 모으면(`waits.py`, Release 2회·Debug 1회) 1위가 매번
  `dyld4::RemoteNotificationResponder::blockOnSynchronousEvent` — **287 / 312 / 254ms**.
- 호출 경로: `-[UIApplication _accessibilityInit]` → `_accessibilityBundlePrincipalClass` → `-[NSBundle loadAndReturnError:]` → `dlopen` → dyld 가 붙어 있는 관찰자(`sample`/Instruments)에게 이미지 로드를 **동기로 알리며 대기**.
- 즉 시뮬레이터 멈춤의 대부분은 "측정 도구가 붙어 있음 + 시뮬레이터 접근성 켜짐" 때문이고 앱 문제가 아니다.
- 기기와의 관계(가능성): Xcode 로 Run 하면 디버거가 붙어 있어 dlopen 마다 같은 종류의 동기 알림이 생긴다. 앱은 Photos·CloudKit·WidgetKit·UserNotifications·LockedCameraCapture 등을 켤 때 처음 부르므로, 홈이 뜬 뒤 끊김 몇 번과 최악 249ms 가 여기서 나왔을 수 있다. **Release·디버거 없음으로 재면 가려진다**(§7).
- 그다음 대기들(작다): `CoalescingWriter.flush()` 의 `queue.sync`(입양이 돈 실행에서 69ms), `-[_MTLCommandBuffer waitUntilScheduled]`(RenderBox 첫 프레임, 6~26ms), `PHPhotoLibraryObserverRegistrar` 동기 XPC(10~16ms), CFPrefs 동기 조회.
- 첫 트레이스(debug1, 권한·입양이 바뀌던 실행)에선 CPU 14ms 짜리 990ms 멈춤도 있었다. 원인은 못 가렸다(권한 창 전환 중이었을 가능성). 이후 안정 상태에선 재현 안 됨.
- 프레임 측정기(`FrameMeterBadge`)는 홈 `onAppear` 부터 센다 → 그 전의 멈춤은 안 세고, 그 뒤 첫 로드 끊김은 센다. 시뮬레이터 Debug(디버거 없음)에선 8초 뒤 **60fps · 끊김 0 · 최악 16.7ms**.

## 5. 시작 경로 작업 표

순서: `ColorMomentsApp.init` → 첫 렌더(로드 전, 행 없음) → 백그라운드 로드 끝 → `.task` 본문 → 350ms 쉬고 CatchUp 한 차례.

| # | 작업 | 위치 | 스레드 | 반복·규모 | 비용 근거 | 판정 |
|---|---|---|---|---|---|---|
| 1 | `ShotImage.assetSource`·`BackgroundHold.install`·DayClosures/GiftLog UserDefaults 읽기 | `ColorMomentsApp.swift:19-27` | 메인 | 1회 | DayClosures.init 3ms(r1) | 확인됨 |
| 2 | days.json 디코딩(`Task.detached`), 끝나면 메인에서 `all = merged` | `DayStore.swift:189-195, 209-227, 704-724` | 백그라운드 → 메인 | 기록 수 | Debug 14 / Release 7ms (1,435개) | 확인됨 |
| 3 | 날짜별 인덱스(dayKey = Calendar + `String(format:)`) | `DayStore.swift:66-77`, `Moment.swift:79-83` | 메인 | 기록 수 | 2~4ms | 확인됨 |
| 4 | 폰트 등록(고운돋움 1.2MB·명조·Plex 서브셋) | `Tokens.swift:59-61` | 메인 | 1회 | 4~7ms | 확인됨 |
| 5 | 셰이더 미리 굽기 `SoftPebbleView.precompile()` | `ColorMomentsApp.swift:47`, `SoftPebbleView.swift:226` | `.task` 안 Task(메인 격리 상속 — 실제 컴파일 스레드는 모름) | 1회 | 트레이스에 따로 안 보임 | 가능성 |
| 6 | CloudSync 생성·시작: 시스템 필드 JSON·동기화 상태 디코딩, CKContainer, CKSyncEngine | `CloudSync.swift:16, 25-37`, `SystemFieldsCache.swift:13-14` | 메인 | 1회. 필드 파일은 기록 수에 비례 | 엔진 생성 17~18ms. 필드 3,000건 9ms(벤치) | 확인됨 (iCloud 계정 있는 기기에선 이벤트 처리가 더 붙는다 — 가능성) |
| 7 | `inbox.loadExisting()` — Shots 폴더 파일마다 `attributesOfItem`·`resourceValues` | `ColorMomentsApp.swift:57`, `CaptureInbox.swift:143` | 메인 | Shots 파일 수 | 파일 251개에서 40ms(Debug). `imported` 는 디버그 화면 `SpikeView.swift:174-211` 에서만 씀 | 확인됨 (기기 파일 수는 모름 — 입양되면 지워지므로 보통 적다) |
| 8 | 사진 변경 감시 등록 `PHPhotoLibrary.shared().register` + 전체 assetID fetch | `AssetReconciler.swift:219-224, 232-243` | 메인(등록, 동기 XPC) + 백그라운드(fetch) | 1회 | 12~20ms 메인 | 확인됨 |
| 9 | CatchUp 첫 차례(350ms 쉼): 위젯·알림 맞추기 ∥ 입양 → 정리 → cloudID | `CatchUp.swift:24, 51-69`, `ColorMomentsApp.swift:28-39` | 메인 격리(무거운 조회는 detached) | 1회(+active 전환마다) | 위젯 스냅샷 4~9ms | 확인됨 |
| 9a | 입양 `adoptAll` — 전체 assetID `existing()` 조회 | `PhotoAssets.swift:373-398` (조회 383) | 백그라운드 | 전체 assetID | 251개 7~9ms. 기록 수에 비례 | 확인됨 / 대규모는 가능성 |
| 9b | 정리 `reconcile` — 같은 전체 조회를 **또** | `AssetReconciler.swift:122-175` (조회 140) | 백그라운드 | 전체 assetID | 같음 | 확인됨 |
| 9c | cloudID `refresh` — 없는 것만 매핑 | `CloudIDMapper.swift:8-28, 72-75` | 메인 필터 + 백그라운드 | 빠진 것만 | 이번 데이터에선 0건 | 확인됨 |
| 10 | 입양 성공마다 `flushAfterLoad` → `CoalescingWriter.flush()` = `queue.sync` | `PhotoAssets.swift:367`, `DayStore.swift:736-740`, `CoalescingWriter.swift:71-76` | **메인이 막힘** | 입양 1건마다 | 251건 입양에서 69ms 막힘(Debug sample). days.json 인코딩 3,000개 25ms(벤치) | 확인됨 (새로 입양할 파일이 있을 때만: 잠금화면 촬영 뒤 등) |
| 11 | 홈 첫 렌더: `store.home()` 캐시·LazyVStack 행·`.onGeometryChange` 로 배경 섞기 | `HomeView.swift:62, 222-251`, `HomeView.swift:500-558` | 메인 | 보이는 행 | HomeView.body 1~3ms | 확인됨 |
| 12 | 썸네일(700px, `.highQualityFormat`, 네트워크 허용, 동시 6개, 실패 시 2·5·15초 재시도) | `ShotThumbnail.swift:44`, `ShotImage.swift:57, 78, 82-93`, `PhotoAssets.swift:9-47` | 백그라운드(요청 스레드는 PhotoKit) | 보이는 카드 × 3장 | 6~20ms + 시스템 JPEG 디코딩 | 확인됨 / 기기 HEIC·iCloud 원본은 더 무거움(가능성) |
| 13 | 조약돌 셰이더 값: `floorAnchor`(180×22) + 색표(128×3) | `SoftPebbleView.swift:37-49, 98-130`, 캐시 `154` | 메인(첫 그림) | 날짜·크기 조합마다 1회(400개 넘으면 비움) | 메인 Debug 9 / Release 1~2ms. 벤치 10배 | 확인됨 |
| 14 | 점선 조약돌 `SoftPebbleOutline.path` — 캐시 없음 | `SoftPebbleView.swift:74-87`, `DayBadge.swift:68-83` | 메인 | 레이아웃마다 | 0.13~0.4ms/회 | 확인됨, 작음 |
| 15 | RenderBox 가 `.colorEffect` 레이어를 CA commit 안에서 그림 | `SoftPebbleView.swift:207-223` | 메인 | 레이어마다(내용 바뀔 때) | 6~8ms, 첫 Metal 제출 대기 6~26ms | 확인됨 |
| 16 | 사진 변경 알림마다: `generation.bump()`(전체) + `refreshFetchResult`(전체 fetch) + `CloudIDMapper.refresh`, 지운 게 있으면 `reconcile` | `AssetReconciler.swift:245-262` | 메인 + 백그라운드 | 알림마다, **묶지 않음** | 시뮬레이터 거의 0(iCloud 사진 없음) | 코드 확인, 비용은 가능성 (기기에서 지속 CPU 후보 1순위) |
| 17 | 배경 blur(60) 전체 화면 2겹, 앞 카드 그림자 반경 38k | `HomeView.swift:579`, `DayBlock.swift:173` | 렌더 서버(GPU) | 계속 | Xcode CPU 게이지 밖. 안 잼 | 가능성 |
| 18 | 프레임 측정기: 매 tick `worstMs = max(...)` → `@Published` 가 매 프레임 발행 | `PebbleLabView.swift:179` | 메인 | 60~120Hz | 켜면 평소 메인 4~5%(끄면 0~1%) | 확인됨 (DEBUG 전용) |
| 19 | 하루 칸 body 마다 `DateFormatter()` | `DayBlock.swift:202-208`, `CompactDayRow.swift:28-34` | 메인 | 행 × body | 0.03~0.05ms/개 | 확인됨, 작음 |
| 20 | `ShotStore.directory` 가 접근마다 `createDirectory` | `ShotStore.swift:4-9` | 부른 곳 | 파일 경로 만들 때마다 | 안 잼 | 가능성, 작음 |

## 6. 고칠 방향 (효과 큰 순)

0. **(코드 전) 실기기 Release·디버거 없음 측정** — §7. 이게 있어야 "디버그 탓"인지 판정된다.

1. **사진 변경 알림 묶기 + 바뀐 사진만 bump** — `AssetReconciler.swift:245-262`
   - 무엇을: 알림마다 `changeDetails(for:)` 에서 changed·inserted 사진 ID 만 모아 `ShotImage.generation.bump(assetID:)`. 300~500ms 조용해진 뒤 한 번만 `refreshFetchResult`·`CloudIDMapper.refresh`. 패턴은 이미 있다: `CloudIDMapper.resolveAfterReceiving`(`CloudIDMapper.swift:49-57`), `HomeWidget.scheduleSync`. 추적 목록이 안 바뀌었으면 전체 재조회 대신 `details.fetchResultAfterChanges` 를 쓴다.
   - 효과: iCloud 사진이 동기화되는 동안 보이는 썸네일 전체의 `.task(id:)` 재시작과, 알림마다 도는 전체 조회 2번이 사라진다.
   - 위험: 중간. 막 내려온 사진이 최대 그 대기 시간만큼 늦게 보인다. `fetchResult == nil` 이면 지금처럼 전체 bump 로 돌아가야 한다. 삭제 판정(`reconcile` 호출 조건)은 그대로 둔다.

2. **시작 때 전체 assetID 조회 3번 → 1번** — `PhotoAssets.swift:383`, `AssetReconciler.swift:140, 237`
   - 무엇을: 한 차례 안에서 조회 결과를 입양·정리·감시가 같이 쓴다.
   - 효과: 백그라운드 CPU 가 기록 수에 비례해 줄어든다(3,000개면 기기에서 수십~백 ms 로 추정).
   - 위험: **중간(삭제 경로)**. `adoptAll` 조회 뒤 새로 입양된 assetID 는 그 결과에 없다 → 그대로 `reconcile` 에 넘기면 방금 입양한 기록을 "사진 앱에서 지운 것"으로 본다. 20% 상한·24시간 예산이 막아 주긴 하지만, **이전 스냅샷에 있던 ID 만 재사용하고 새로 생긴 ID 는 따로 조회**해야 한다. 테스트: `AssetReconcilerTests`, `AssetAdopterTests`.

3. **메인에서 `queue.sync` 로 기다리지 않기** — `CoalescingWriter.flush()` ← `DayStore.flushAfterLoad()`(`DayStore.swift:736`) ← 입양(`PhotoAssets.swift:367, 443`)·잠금화면 가져오기(`CaptureInbox.swift:96`)·정리(`AssetReconciler.swift:169`)
   - 무엇을: `func flushed() async -> Bool` 을 두고 `queue.async { drain(); continuation.resume(!lastWriteFailed) }` 로 기다린다.
   - 효과: 새 사진 입양 때의 메인 멈춤(251건에 69ms, 3,000개 저장소면 1건당 인코딩 25ms+쓰기)이 사라진다.
   - 위험: 낮음~중간. "디스크에 쓴 뒤에만 파일을 지운다·세션을 무효화한다" 순서는 반드시 지켜야 한다. background 전환 때의 `store.flush()`(`ColorMomentsApp.swift:85`)는 동기로 둔다.

4. **`inbox.loadExisting()` 을 시작 경로에서 빼기** — `ColorMomentsApp.swift:57`
   - 무엇을: SpikeView 가 열릴 때 부르거나 `#if DEBUG` 로 감싼다.
   - 효과: Shots 파일 수에 비례하는 메인 작업이 사라진다(파일 251개에서 40ms).
   - 위험: 없음(사용자 화면에 안 쓰임).

5. **조약돌 값 계산을 메인 밖·미리** — `SoftPebbleView.swift:154-164`
   - 무엇을: 로드 직후 보이는 날짜의 `SoftPebbleUniforms` 를 백그라운드에서 만들어 캐시에 넣는다. 점선 조약돌 Path(`SoftPebbleShape.placeholder.outline()`)는 static 으로 한 번만.
   - 효과: Debug 첫 그림 끊김 감소(기기 Debug 조약돌 1개 약 5ms 추정). Release 효과는 작다.
   - 위험: 낮음(캐시가 `@MainActor` 라 채우는 쪽만 메인으로 넘기면 된다).

6. **프레임 측정기는 값이 바뀔 때만 발행** — `PebbleLabView.swift:179`
   - 무엇을: `worstMs` 가 커질 때만 대입하거나 화면 갱신을 2Hz 로.
   - 효과: 측정할 때 섞이는 메인 4~5% 잡음 제거(DEBUG 전용).
   - 위험: 없음.

7. **`DateFormatter` 를 static 으로** — `DayBlock.swift:202-208`, `CompactDayRow.swift:28-34`. 효과는 작고 위험 없음.

권하지 않음: CKSyncEngine 생성·사진 감시 등록을 뒤로 미루기. 각각 17~20ms 인데 `ColorMomentsApp.swift:49, 60` 주석이 밝힌 대로 순서가 중요하다(구독 전 변경, 로드 직후 사진 앱 변경 놓침).

## 7. Tabber 실기기 측정 가이드

1. **Release·디버거 없이 켜기**
   - Product → Profile(⌘I): Release 로 빌드되고 Instruments 가 열린다.
   - 또는 Scheme → Run → Info 에서 Build Configuration = Release, "Debug executable" 끄기.
   - 같은 조건을 **Debug(디버거 연결) / Debug(디버거 없음) / Release** 로 한 번씩 재면 무엇이 차이를 만드는지 갈린다.
2. **템플릿과 볼 지표**
   - App Launch: 첫 프레임까지 시간, 단계별 시간.
   - Time Profiler: CPU 트랙에서 메인 스레드와 전체를 따로 본다. Call Tree 에서 "Hide System Libraries" 켜고 `ColorMoments` 로 거른다. `photoLibraryDidChange`·`refreshFetchResult`·`AssetReconciler.existing`·`CloudIDMapper.refresh` 가 **몇 번** 불리는지 적는다(§6-1 판정 근거).
   - Hangs / Animation Hitches: 250ms 넘는 멈춤, hitch time ratio(ms/s). 켤 때와 스크롤할 때를 따로.
   - Metal System Trace: 배경 blur·카드 그림자·셰이더 조약돌의 GPU 시간(Xcode CPU 게이지엔 안 잡힘).
3. **Debug 에서 기본으로 켜진 진단 끄고 비교**: Scheme → Run → Diagnostics 에서 Main Thread Checker·Thread Performance Checker 끄기, Options 에서 GPU Frame Capture = Disabled, Metal API Validation = Disabled.
4. **프레임 측정기 읽기**: 홈이 뜨고 5초 기다린 뒤 배지를 **탭해 초기화**하고 스크롤 → 켤 때 끊김과 평소 끊김을 가른다. Release 엔 배지가 없으니(`#if DEBUG`) Animation Hitches 로.
5. **조건 기록**: 앱 완전 종료 → 10초 쉼 → 3번씩. 기록 수·하루 수, iCloud 사진 사용 여부, 그때 사진 앱이 동기화 중이었는지, Shots 폴더 파일 수(디버그 화면 "들여온 사진 N").

판정 기준(제안):
- Release·디버거 없음에서 끊김이 거의 사라지면 → 디버거·Debug 비용. 코드는 §6-4~7 정도만.
- Release 에서도 켤 때 멈춤이 남으면 → Time Profiler 메인 상위를 보고 §6-2·3.
- 켜고 몇 초 뒤에도 CPU 가 계속 높고 `photoLibraryDidChange` 가 여러 번 잡히면 → §6-1 먼저.

## 8. 재지 못한 것 · 남은 질문

- 실기기, 디버거가 붙은 상태의 dlopen 대기량(시뮬레이터 `sample` 로 같은 종류 대기만 확인).
- iCloud 계정이 있을 때 CKSyncEngine 이벤트(`fetchedRecordZoneChanges`·`stateUpdate` JSON 인코딩 `CloudSync.swift:199-203`)의 시작 시 비용.
- 실제 사진 보관함(수천~수만 장, HEIC, iCloud 원본)에서 썸네일·`existing()`·변경 알림 빈도.
- GPU(렌더 서버) 비용.
- 셰이더 미리 굽기(`precompile`)가 첫 그림보다 먼저 끝나는지 — 트레이스에 따로 안 보였다.
- 첫 트레이스의 990ms 멈춤(CPU 14ms) 원인 — 권한·입양이 바뀌던 실행이라 제외했다.

## 9. 산출물 · 바뀐 상태

- 전부 `/private/tmp/claude-501/-Users-tabber-AI-Product-Factory/18dbafd8-cb15-44e4-9a3f-cbd0001b95c8/scratchpad/perf/` (세션 임시 폴더라 지워질 수 있다):
  - 트레이스 `d1..d3`, `r1..r3`, `dx1`, `dm1`, `debug1` `.trace` 와 각 `-summary.txt`
  - 샘플 `rel-sample1.txt`, `rel-sample2.txt`, `debug-sample2.txt`
  - 스크립트 `run.sh`(기록+요약), `tp.py`(time-profile 요약), `waits.py`(메인 대기 모으기), `callers.py`(특정 함수 호출자)
  - 벤치 `bench/pebble.swift`, `bench/fields.swift`, `bench/encode.swift`
  - 견본 `fixture/gen.py`, `fixture/days-adopted.json`
- iPhone 16 시뮬레이터(`7A4E21A9-…`) 상태: 견본 사진 251장이 사진 앱에 들어감, 앱 데이터는 입양 끝난 견본, `debugHomeFrameMeter = YES`. 시뮬레이터는 꺼 둠. xctrace·sample 프로세스 남은 것 없음.
- 소스·git 은 건드리지 않았다(이 문서 하나만 새로 만듦).
