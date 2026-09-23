# 몽돌 — 담은 뒤 홈으로 · 짧은 하루 시간축 · 쌓인 하루 찾기

상태 **completed** (후속: 스크럽 중 카메라 스와이프 끄기 · 담은 뒤 스크롤 순서) · 2026-09-23 · 브랜치 `feat/mongdol-day-gift` · Tabber 실기기 피드백(IMG_6360·6361)

## 결정 (Tabber 2026-09-23)

1. **사진첩에서 담으면 홈으로 돌아와 그 하루를 보여준다.** 선택 화면과 카메라를 함께 닫고(`progress = 0`), 가장 최근에 담긴 사진(`addedAt` 최댓값)의 하루로 스크롤. 오늘이면 맨 위.
2. **시간축 높이를 장수에 맞춘다.** 1장이면 띠 없이 눈금 하나 + 사진. 2장 이상이면 `min(360, 사진높이 × 1.5 × (장수 − 1))`. 정규화(`DayGradient.positions`)는 그대로 — 몰아 찍은 날/고른 날의 차이는 줄어든 높이 안에서 유지.
3. **쌓인 하루 찾기 = A + B 둘 다.**
   - **A 연월 알약 끌기**: 스크롤 중(그리고 멈춘 뒤 1.2초) 오른쪽 가장자리 28pt 띠를 잡고 위아래로 끌면 달 단위로 홈이 따라간다. 알약이 손가락 높이에 붙고, 달이 바뀔 때마다 햅틱 한 번(`Haptics.tickPassed()`). 띠 밖·스크롤 안 할 때는 아무것도 가로채지 않는다.
   - **B 한 달 지난 하루는 작게**: 오늘 기준 30일보다 오래된 하루는 사진 더미 없이 한 줄 — 조약돌(높이 52) + 이름(명조 17) + 날짜·개수(caption). 줄 사이 20. 누르면 하루 상세. 가장 최근 30일은 지금 블록 그대로.
   - DESIGN §1.1 「1일차에도 1년차에도 구성이 같다」의 예외로 기록. 세로 반복 · 오늘은 줄에 없음은 그대로라 §4 「손대면 안 된다」는 넘지 않는다.

## Global Constraints

- iOS 18.0, 외부 의존성 0. 가로 스크롤 금지. 홈에 버튼 추가 금지. 오늘 색 숨김 유지.
- 조약돌·이름은 `store.pebbleMoments(on:)`, 사진 더미·시간축은 `store.moments(on:)` (사진첩 담기 규칙).
- 색·글자는 `Tone`/`Face` 만 — 새 글자 크기는 `Face` 토큰으로 추가(`Face.nameCompact = serif(17)`). 명조 글자는 조약돌 이름뿐이라 서브셋 변경 없음.
- 테스트는 `perl -e 'alarm 240; exec @ARGV' xcodebuild test ...`. 멈추면 shutdown→boot 후 1회, 또 멈추면 BLOCKED.
- 시뮬레이터 스크린샷은 하지 않는다 — Tabber 실기기 확인.

---

### Task A: 하루 상세 시간축 높이 (Shared/Day/DayMomentsView.swift, Shared/Day/DayTimeline.swift, ColorMomentsTests/DayTimelineTests.swift)

- `DayTimeline.axisHeight(count: Int, photoHeight: CGFloat, maxHeight: CGFloat = 360) -> CGFloat` — 0/1장 → 0, 그 외 `min(maxHeight, photoHeight * 1.5 * CGFloat(count - 1))`.
- 테스트: 1장 0 · 2장 190.5(photoHeight 127) · 10장 360 · 0장 0.
- `DayMomentsView.timeline`: 고정 `axisHeight` 대신 위 함수. 높이 0이면 띠(`DayGradientView` 캡슐)를 그리지 않는다. 컨테이너 높이 = 축 높이 + 사진 높이.
- 전체 스위트 + 캡처 확장 빌드. 커밋 `fix(몽돌): 사진이 적은 날 시간축을 장수에 맞게`.

### Task B: 홈 — 담은 뒤 이동 · 연월 알약 끌기 · 오래된 하루 작게 (ColorMoments/App/HomeShell.swift, ColorMoments/App/HomeView.swift, Shared/Design/CompactDayRow.swift(새), Shared/Design/Tokens.swift)

1. `HomeView` 에 `@Binding var focusDay: String?` (HomeShell 이 소유). `ScrollViewReader` 로 감싸고 각 하루 블록에 `.id(key)`. `focusDay` 가 바뀌면 `proxy.scrollTo(key, anchor: .top)` 후 nil 로. 오늘이면 맨 위(`scrollTo` 최상단 앵커용 id `"top"`).
2. `HomeShell` — `LibraryPickerView(store: store) { n in … }` 에서 n > 0 이면 `progress = 0` 과 `focusDay = store.moments.filter { $0.addedAt != nil }.max { $0.addedAt! < $1.addedAt! }?.dayKey`.
3. `CompactDayRow(pebbleMoments:moments:)` — HStack: `PebbleView(moments: pebbleMoments, height: 52)` · VStack(이름 `Face.nameCompact` primary / 날짜·개수 `Face.caption` tertiary). `HomeView` 는 `key < Self.compactCutoff` (오늘 − 30일의 dayKey) 인 하루를 이 줄로, 그 전은 `DayBlock`. 두 영역은 한 `LazyVStack` 안에서 spacing 을 자리마다 준다(블록 64 / 줄 20).
4. 연월 알약 끌기 — `@State scrubbing`, `@State pillY`. 오른쪽 가장자리 `Color.clear.frame(width: 28).contentShape(Rectangle())` 에 `DragGesture(minimumDistance: 0)` — `scrolling || lingering` 일 때만 `allowsHitTesting(true)`. 끌 때 y 비율 → 월 목록(`days` 에서 뽑은 고유 "yyyy-MM", 최신이 위) 인덱스 → 그 달의 첫(가장 최근) 하루로 `proxy.scrollTo(anchor: .top)`, 월이 바뀔 때 햅틱. 알약은 `pillY` 에 붙어 뜬다. 스크롤·끌기가 끝나고 1.2초 뒤 `lingering = false`.
   - `HomeShell` 의 좌→우 카메라 스와이프와 겹치지 않게: 끌기 띠는 오른쪽 가장자리이고 세로 끌기다. `HomeShell` 스와이프가 수평 판정 전에 이 띠를 가로채지 않는지 확인하고, 필요하면 띠 위에서는 `.highPriorityGesture`.
5. DESIGN.md §1.1 아래 한 줄: 「예외: 30일 지난 하루는 한 줄로 작게(쌓인 하루 찾기 — 2026-09-23 Tabber)」, §1.4 에 「알약을 잡고 끌면 달 단위로 훑는다」.
6. 전체 스위트 + 캡처 확장 빌드. 커밋 두 개: `feat(몽돌): 사진첩에서 담으면 홈으로 · 오래된 하루는 한 줄로 · 연월 알약 끌기`, `docs(몽돌): 홈 예외 두 가지 기록`.

## 수동 확인 (Tabber, 실기기)

- [ ] 사진첩에서 담으면 홈으로 돌아와 그 하루가 보인다
- [ ] 1장인 날: 띠 없이 사진 하나 / 2장인 날: 사이가 적당하다
- [ ] 스크롤하다 오른쪽 알약을 잡고 끌면 달 단위로 훑는다, 달이 바뀔 때 톡
- [ ] 30일 지난 하루는 한 줄로 작게 보이고 누르면 상세가 열린다
- [ ] 홈에서 좌→우로 쓸면 카메라가 여전히 잘 열린다 (알약 끌기와 안 부딪힌다)
