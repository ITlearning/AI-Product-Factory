# 몽돌 간직하기 네 가지 · 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

상태 **completed** · 2026-09-24 · 브랜치 `feat/mongdol-keepsakes` (`feat/mongdol-day-gift` 에서 분기)

**Goal:** 첫날 지난 일주일 담기 · 조약돌 카드 · 작년 이맘때와 한 달 한 줌 · 조약돌 건네기 — 몽돌이 쌓일수록 다시 꺼내 보고 밖으로 건넬 수 있게 한다.

**포지션 (Tabber 2026-09-24, 원문):** 「순간을 남기고 싶을 때 사용하고, 이 앱으로 남겼다면 소소한 수집도 가능하다」, 「매일 밤 하루를 덮는 앱 이런 포지션이 아니야」. 네 기능 모두 **매일 쓰게 만들지 않는다** — 알림 없음, 빈칸 없음, 재촉 문구 없음.

**Spec:** 이 대화의 설계(Tabber 승인 2026-09-24), 요지는 아래 각 과제 머리.

## Global Constraints

- iOS 18.0, 외부 의존성 0. `Shared/` 는 Photos·CloudKit·WidgetKit·UserNotifications 를 import 하지 않는다(잠금화면 캡처 확장·위젯 확장이 컴파일). 공유 시트·이미지 렌더링(`ImageRenderer`, `ShareLink`)은 앱 타깃.
- 색·글자는 `Tone`/`Face` 토큰만. **명조(`Face.serif…`)는 조약돌 이름에만** — 명조 서브셋 폰트는 113자뿐이라 새 글자가 필요하면 깨진다. 「작년 이맘때」「9월의 한 줌」 등은 SF(`Face.line`/`caption`).
- 홈에 버튼을 추가하지 않는다(DESIGN §1.2). 진입은 길게 누르기·하루 상세·목록 안 머리글.
- 아직 안 받은 하루(색 숨김)는 카드·한 줌·작년 이맘때 어디에도 색을 내지 않는다 — `gifts.isGifted(dayKey)` 인 하루만.
- 카드는 **사진이 주인공** — 사용자가 고른 사진 한 장 + 그날 그라데이션 틀 + 조약돌. 장소·단어는 넣지 않는다(2026-09-24 Tabber).
- 테스트 `perl -e 'alarm 280; exec @ARGV' xcodebuild test ...`, 멈추면 shutdown→boot 1회, 또 멈추면 BLOCKED. 시뮬레이터 스크린샷·실기기 금지. 단계마다 커밋, 끝줄 `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **색 노출** — 받지 않은 하루가 한 줌·작년 이맘때·카드 진입점에 섞여 색이 먼저 보이는 경우 → Task 2·3 테스트.
2. **첫날 증정이 두 번 뜨거나 안 뜨는 경우** — 온보딩 첫 담기 뒤 증정 한 번, 그 뒤 옛 규칙(지난 날 담기는 조용히) 그대로 → Task 1 테스트.
3. **카드 이미지가 비거나 잘리는 경우** — `PebbleView` 의 `drawingGroup`/CoreImage 질감이 `ImageRenderer` 에서 빈 이미지가 되는지(실기기 확인 항목) → Task 2 에서 렌더 결과 크기·비어 있지 않음 테스트.
4. **작년 이맘때 경계** — 윤년(2/29), 연초·연말 3일 범위, 받은 돌이 여러 개면 가장 가까운 날 → Task 3 테스트.
5. **한 줌에 돌이 많을 때** — 31개도 한 손 안에 겹쳐 보이고 레이아웃이 넘치지 않는다 → Task 3 배치 함수 테스트(개수별 크기·겹침 범위).

---

### Task 1: 첫날 지난 일주일 담기

- `HomeView` 의 `EmptyDayBlock` 자리(기록 0개일 때만)에 한 줄 「지난 며칠 사진으로 먼저 받아 볼까요?」(SF, `Tone.secondary`) — 누르면 기존 사진첩 담기 화면(`LibraryPickerView`, HomeShell 이 띄우는 그 경로). 기록이 생기면 사라지고 다시 안 나온다(`@AppStorage("didOfferLibraryOnboarding")` 는 **보여준 뒤가 아니라 기록이 처음 생겼을 때** true).
- 사진첩 선택 화면은 이미 날짜별 최신순이라 최근 7일이 맨 위 — 추가 필터 없음.
- **첫 담기 증정 한 번**: 기록이 0개였던 상태에서 사진첩 담기로 처음 기록이 생기면, 담긴 날 중 가장 최근(오늘 제외) 하루를 한 번 증정 후보로 만든다. 구현: `GiftSchedule` 판정은 그대로 두고, `DayGiftPresenter` 에 "첫 담기 하루" 한 개를 넘겨 그 하루가 `!isGifted` 면 `hasSealedMoments` 조건을 건너뛰고 증정(한 번 뒤엔 markGifted 로 끝). 첫 담기 하루는 UserDefaults `"onboardingGiftDay"` 에 저장했다가 증정 뒤 지운다.
- 오늘만 담았으면 증정 없음(오늘은 진행 중 블록).
- 테스트: 첫 담기 하루 고르기 순수 함수(오늘 제외 가장 최근, 오늘만이면 nil, 기존 기록 있으면 nil).

### Task 2: 조약돌 카드 + 건네기

- `Shared/Keepsake/PebbleCard.swift`: 9:16 카드 SwiftUI 뷰 — 배경 `DayGradientView(pebbleMoments)` 흐림, 가운데 `PebbleView`, 이름 `Face.nameDay`, 날짜(SF, "2026년 9월 23일"), 아래 작은 "몽돌"(`Face.caption`, `Tone.tertiary`). 사진·장소·단어 없음.
- 앱 타깃 `ColorMoments/Keepsake/CardExporter.swift`: `ImageRenderer(content: PebbleCard(...).frame(width: 1080/3, height: 1920/3)) scale 3` → `UIImage`. 렌더 결과가 nil 이거나 전부 투명이면 nil(공유 안 함).
- 진입: 하루 상세(`DayMomentsView`) 상단 작은 공유 아이콘(SF Symbol `square.and.arrow.up`, `Tone.secondary`) — 받은 하루일 때만. 홈 하루 블록·한 줄에 `.contextMenu` 「카드로 만들기」 — 받은 하루만.
- 공유: `ShareLink(item: Image, preview:)` 또는 `UIActivityViewController`. **건네기 문구**: 설정값 `Keepsake.appStoreURL: URL?`(지금 nil) — 있으면 공유 항목에 텍스트 「〈이름〉을 건네요. 나도 몽돌 받아 보기 → URL」 추가, 없으면 카드만.
- 테스트: 받지 않은 하루는 카드 진입 불가(판정 함수), 공유 텍스트는 URL 있을 때만, 렌더 결과 크기 1080×1920(시뮬레이터에서 가능하면; 안 되면 판정 함수만).

### Task 3: 작년 이맘때 · 한 달 한 줌

- `Shared/Keepsake/Memories.swift` 순수 함수:
  - `lastYear(today: String, giftedDays: [String]) -> String?` — 오늘 dayKey 의 1년 전 ±3일 안에서 받은 하루 중 1년 전 날에 가장 가까운 것(같으면 이른 날). 2/29 는 2/28 기준.
  - `months(giftedDays: [String], today: String) -> [String]` — 이번 달 제외, 받은 하루가 있는 달("yyyy-MM") 최신순.
  - `handfulLayout(count: Int, seed: UInt64) -> [(x, y, rotation, scale)]` — 한 손(원 안) 겹쳐 쌓기, FNV 시드로 결정적. 1개~31개.
- `HomeView`: 오늘 줄(또는 진행 중 블록) 아래 `lastYear` 가 있으면 한 줄 「작년 이맘때 · 〈이름〉」(SF + 이름만 명조) — 누르면 그 하루 상세. 없으면 아무것도 없음.
- `HomeView` 목록: 지난 달 경계에 작은 머리글 「9월의 한 줌」(SF caption) — 누르면 `HandfulView`(전체 화면): 그 달 받은 돌들의 `PebbleView` 를 `handfulLayout` 으로 겹쳐 그림, 아래 달 이름, 오른쪽 위 카드 만들기(Task 2 의 CardExporter 재사용 — 한 줌 판 카드 뷰 `HandfulCard`).
- 받지 않은 하루는 어디에도 안 들어간다.
- 테스트: lastYear(정확히 1년 전, ±3 경계, 윤년, 없음), months(이번 달 제외, 받은 날만), handfulLayout(개수만큼, 원 안, 같은 시드 같은 결과).

### Task 4: 문서

- `Color-Moments/DESIGN.md` §4.5 행 15~17, 규칙 두 줄(「카드는 사용자가 직접 누를 때만, 사진 없음」「한 줌은 격자가 아니다」).
- 이 계획 → completed.

## 병렬

- Task 1(HomeView 빈 상태·HomeShell 담기·DayGift) ∥ Task 2(Shared/Keepsake/PebbleCard, 앱 Keepsake, DayMomentsView 공유, HomeView contextMenu) — HomeView 가 겹친다. Task 2 는 worktree 에서, 합칠 때 HomeView 충돌은 수동 정리.
- Task 3 은 Task 2 뒤(CardExporter 재사용, HomeView).
- 모델: 전부 sonnet, 최종 전체 검토 opus.

## 수동 확인 (Tabber, 실기기)

- [ ] 앱을 지우고 새로 깔면(또는 기록 0개에서) 홈에 「지난 며칠 사진으로 먼저 받아 볼까요?」가 보이고, 담으면 증정이 한 번 뜬다
- [ ] 받은 하루 상세의 공유 표시·홈에서 길게 누르기로 카드가 만들어지고, 인스타 스토리·사진 저장이 된다 — 조약돌 질감이 카드에서도 보인다
- [ ] 받지 않은 하루(오늘 진행 중)에는 카드 만들기가 없다
- [ ] (1년 치가 없으면 확인 불가) 작년 이맘때 줄
- [ ] 지난 달 머리글 「N월의 한 줌」을 누르면 돌들이 한 손에 모인 장면, 그 장면도 카드로
