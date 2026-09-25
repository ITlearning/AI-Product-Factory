# 노래갈피 — Design Tokens

Generated from mockup **variant-B** (approved 2026-09-16).
Direction: **늦은 밤** — 따뜻한 near-black, 앨범아트가 화면의 유일한 채도.

> 구현 착수 시 프로젝트 루트에 복사: `Norae-Galpi/DESIGN.md`
> 승인 목업: `~/.gstack/projects/ITlearning-AI-Product-Factory/designs/norae-galpi-feed-20260916/variant-B.png`

---

## Tone

밤에 침대에서 폰으로 읽는 화면. 조용하고 따뜻하다. 명랑하지 않고, 기업스럽지 않고, 임상적이지 않다.

**콘텐츠는 이미지가 아니라 남이 쓴 세 줄이다.** 본문 타이포그래피가 곧 제품이다.
그 세 줄이 읽고 싶게 생기지 않으면 제품이 없다.

색은 거의 쓰지 않는다. **앨범아트가 화면에서 유일하게 채도를 가진 것**이고, 나머지는 전부 무채에 가깝다.
어둠 속에서 커버만 빛나는 구조가 이 제품의 시각적 앵커다.

---

## Color Palette

```css
:root {
  /* Ground — 파랑기 없는 따뜻한 검정. 순흑(#000)을 쓰지 않는다 */
  --color-bg:            #0e0d0c;
  --color-surface:       #161413;   /* 곡 카드 */
  --color-surface-raised:#1e1b19;   /* 팝업·시트 */
  --color-line:          #2a2624;   /* 기억 사이 헤어라인, 카드 경계 */

  /* Text — 순백을 쓰지 않는다. 항상 따뜻한 오프화이트 */
  --color-text:          #f0ebe4;   /* 기억 본문·곡 제목 */
  --color-text-secondary:#a89f95;   /* 가수명·보조 문장 */
  --color-text-tertiary: #8d8379;   /* 계절·시절 라벨, 캡션 */

  /* Accent — 기본값 없음. 앨범아트가 액센트다.
     아래는 포커스·선택 등 기능적 용도에만 쓰는 최소 액센트 */
  --color-accent:        #d9a441;   /* 따뜻한 앰버 */
  --color-accent-dim:    #6b5426;

  /* State */
  --color-danger:        #d96a5a;   /* PII 경고·신고 */
}
```

**대비 (계산값, 실측 검증 필요 `요확인`)**

| 조합 | 추정 비율 | 기준 |
|---|---|---|
| `--color-text` on `--color-bg` | 약 16:1 | ✓ 본문 4.5:1 |
| `--color-text-secondary` on `--color-bg` | 약 7.5:1 | ✓ |
| `--color-text-tertiary` on `--color-bg` | 약 5.1:1 | ✓ (여유 적음 — 더 어둡게 내리지 말 것) |
| `--color-text-tertiary` on `--color-surface` | 약 4.6:1 | ✓ 아슬함 |

`--color-text-tertiary`보다 어두운 회색을 새로 만들지 않는다. 계절 라벨은 **정보이지 장식이 아니다.**

**어두운 표면 위 보조 텍스트는 회색이 아니라 그 표면의 색조에서 나온다.** 위 tertiary가 순회색(#808080)이 아니라
따뜻한 쪽으로 기운 이유다.

---

## Typography

```css
--font-family: 'Pretendard Variable', Pretendard, -apple-system,
               BlinkMacSystemFont, 'Apple SD Gothic Neo', system-ui, sans-serif;
```

한글 본문은 **행간이 넉넉해야 한다.** 작은 크기에 좁은 행간은 읽기 어려울 뿐 아니라 무정하게 읽힌다.

```css
/* 기억 본문 — 이 제품의 주인공 */
/* 17px / 400 / line-height 1.75 / letter-spacing -0.003em */

/* 곡 제목      15px / 600 / 1.35 */
/* 가수명       13px / 400 / 1.4  / --color-text-secondary */
/* 계절·시절     12px / 400 / 1.4  / letter-spacing 0.01em / --color-text-tertiary */
/* 워드마크      15px / 700 / -0.01em */
/* 필터 pill    13px / 500 */
/* 빈 상태 문장  16px / 400 / 1.7 */
/* 버튼         15px / 600 */
```

**본문은 16px 아래로 내려가지 않는다.** 기억 본문 17px이 하한이다.

**측정폭** — 한글 한 줄 **32~38자**. 모바일 375px에서는 자연히 맞고,
데스크톱에서는 컨테이너 `max-width: 600px`으로 강제한다(아래 Layout 참조).

---

## Spacing & Shape

```css
/* 4px 기반 스케일 */
--space-1: 4px;  --space-2: 8px;   --space-3: 12px;
--space-4: 16px; --space-5: 24px;  --space-6: 32px;  --space-8: 48px;

/* Radius */
--radius-card:  14px;   /* 곡 카드 */
--radius-thumb: 6px;    /* 앨범아트 */
--radius-pill:  999px;  /* 필터만. 다른 곳에 pill을 쓰지 않는다 */
--radius-sheet: 18px;   /* 팝업 */
```

**모든 요소에 같은 큰 라운드를 두르지 않는다.** 카드·썸네일·팝업이 각각 다른 값을 갖는 이유다.

**헤딩 위 여백이 아래보다 넓다.** 곡 제목 위 `--space-5`, 아래 `--space-3`.
읽는 사람이 제목을 그 아래 내용의 것으로 묶어 보게 된다.

**그림자를 장식으로 쓰지 않는다.** 이 다크 테마에서 깊이는 `--color-surface`의 밝기 차로 낸다.
팝업에만 오프셋 있는 그림자를 허용한다: `0 8px 24px rgba(0,0,0,.5)`.

---

## Layout

```css
--layout-measure: 600px;   /* 피드 컨테이너 최대 폭 */
--touch-min: 44px;         /* 모든 탭 대상의 최소 치수 */
```

**v1은 뷰포트와 무관하게 가운데 한 줄이다.** 모바일에서는 전체 폭, 데스크톱에서는 600px로 고정하고 양옆을 비운다.
카드 내부 구성은 두 경우가 동일하다.

데스크톱 전용 레이아웃(좌측 고정 플레이어 + 우측 피드)은 **v2**로 미룬다.

**터치 타깃** — ♡와 필터 pill은 시각적으로 작아도 히트 영역이 44×44px 이상이어야 한다.
목업의 하트는 그리기용 크기이지 탭 영역이 아니다.

---

## Browser Surfaces

다크 테마에서 이걸 안 하면 흰 스크롤바와 파란 선택 색이 튀어나와 **"디자인한 페이지"가 아니라 "조립한 페이지"로 보인다.**
탐지기가 못 잡고 가장 자주 빠지는 항목이다.

```css
:root { color-scheme: dark; }

::selection {
  background: var(--color-accent-dim);
  color: var(--color-text);
}

:root { scrollbar-color: var(--color-line) transparent; }

textarea, input { caret-color: var(--color-accent); }

:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 2px;
  border-radius: 4px;
}

a { text-underline-offset: 0.2em; text-decoration-thickness: 1px; }

/* 날짜·연도가 표에 들어갈 때 자릿수가 흔들리지 않게 */
time, .tabular { font-variant-numeric: tabular-nums; }
```

방문 링크 색 구분은 이 제품에 링크 목록이 없어 해당 없음. 생기면 그때 정의한다.

---

## Motion

> **rev.2 (2026-09-17) — Tabber 결정으로 확대.** 원래 이 절은 "연출된 순간은 하나뿐"이었고
> ♡ 에 바운스를 금지했다. 실제 화면을 만들어 보니 모션이 네 곳(pill 색·♡ 색·플레이어·시트)뿐이라
> 전부 컷으로 끊겨 투박하게 읽혔다. GetStream `purposeful-ios-animations` 의 분류를 대보고
> **일을 하는 모션 7가지**를 넣기로 했다. 판단 기준은 그대로다 — 장식은 여전히 넣지 않는다.

**모션은 일을 할 때만 넣는다.** 장식으로는 넣지 않는다. 모든 섹션에 같은 등장 효과를 주지 않고,
모든 요소에 호버를 걸지 않는다.

```css
--ease-out: cubic-bezier(0.22, 1, 0.36, 1);
--dur-enter: 240ms;
--dur-quick: 120ms;

/* 스프링 — "iOS 같다"는 느낌의 거의 전부가 여기서 온다.
   ease-out 은 목표에 도달하고 멈추지만 스프링은 살짝 지나쳤다가 자리를 잡는다.
   CSS linear() 로 곡선을 직접 쓴다. JS 애니메이션 라이브러리를 들이지 않는다. */
--ease-spring: linear(0, 0.006, …, 1.017 63.9%, 1.001 79%, 1);
--ease-spring-soft: linear(…);   /* 오버슈트가 더 큰 쪽. ♡ 에만 쓴다 */
--dur-spring: 520ms;
```

`linear()` 를 모르는 브라우저에는 `@supports` 밖에 둔 `cubic-bezier` 폴백이 간다 —
커스텀 속성은 값 검증을 하지 않아서 그냥 넣으면 `ease` 로 떨어진다.

### 넣은 것 일곱

| | 무엇 | 하는 일 |
|---|---|---|
| A | 곡 카드 → ⑥ 앨범아트가 이어진다 (FLIP) | 연속성·방향감. iOS `matchedGeometryEffect` |
| B | 로딩 스켈레톤 | Neon 콜드스타트가 실재한다. 레이아웃이 안 튀고 기다림이 짧게 느껴진다 |
| C | ♡ 눌림 (420ms, `--ease-spring-soft`) | 손끝 피드백 |
| D | 정렬 인디케이터 슬라이드 | 내가 방금 무엇을 바꿨는지가 남는다 |
| E | 더 보기 높이 보간 | 읽던 자리를 잃지 않는다 |
| F | 시트 스프링 + 백드롭 페이드 | 어디서 왔는지 보인다 |
| G | 스프링 이징 토큰 | A·D·E·F 가 전부 이 위에 얹힌다 |

- 이미 보이는 기본 상태에서 나간다. **콘텐츠가 애니메이션 타이밍 뒤에 숨지 않는다** —
  모션이 실패해도 글은 즉시 읽을 수 있어야 한다. A 는 도착 화면이 이미 그려진 뒤에 되감는다.
- 피드 카드에는 스크롤 등장 애니메이션을 넣지 않는다. 읽는 흐름을 끊는다.
- **C 는 트위터처럼 파티클을 튀기지 않는다.** 이 제품은 좋아요 개수를 숨기므로
  요란해지면 거짓말이 된다. 되돌리기(실패) 때는 튀기지 않는다.
- 안 넣은 것 — 폭죽·컨페티(Intrinsic Motivation), 누적 박수(Express Gratitude),
  Duolingo 식 바운스(Delight/Whimsy). 새벽에 울면서 들었다는 글에 폭죽이 터지면 안 되고,
  누적 리액션은 개수를 숨기는 설계와 정면으로 부딪힌다.

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
    /* 반복 횟수를 같이 끊지 않으면 shimmer 처럼 infinite 인 애니메이션이
       0.01ms 마다 다시 도는 바쁜 루프가 된다. */
    animation-iteration-count: 1 !important;
  }
  .sk { animation: none; background: var(--color-surface-raised); }
}
```

---

## Component Inventory

| 컴포넌트 | 구성 | 비고 |
|---|---|---|
| 공통 헤더 | 워드마크(왼쪽) + 🔖 내 갈피(오른쪽) | **일곱 화면 전부.** 워드마크가 항상 홈으로 |
| 정렬 필터 | pill 3개 — `지금 계절`(기본) / `최신` / `오래 남은` | 선택된 것만 `--color-text`. `지금 계절`은 필터가 아니라 우선순위 — 해당 계절 글 아래로 나머지가 최신순으로 이어지고 경계에 구분선 하나 |
| 곡 카드 | 썸네일 + 곡 제목/가수 + 기억 2~3편 + `나도 적기` | **피드에는 플레이어가 없다** |
| 기억 블록 | 본문 + (`더 보기`) + 계절·시절 라벨 + ♡ | ♡ 옆에 **숫자를 절대 표시하지 않는다** |
| 입력창 | 곡을 크게(앨범아트+제목+가수) + 빈 텍스트박스 | **칩도 예시도 없다.** 실측에서 글 5편 중 0편이 칩으로 시작하지 않았다 |
| 라벨 칩 | 계절 4 + 시절 6 (어릴 때·학창시절·대학 때·군생활·사회 초년·요즘) | 전부 선택 사항. 올리기 버튼 바로 위 |
| 공개 확인 시트 | "이 글은 공개됩니다" + **PII 경고(있을 때)** | **팝업은 한 번뿐.** 둘을 합친다 |
| 상단 고정 플레이어 | 유튜브 iframe, 최소 200×200px | ⑥에만. 위에 아무것도 덮지 않는다 |
| 빈 상태 | 문장 + 1순위 행동 + `다른 계절 보기 →` | 사용자가 계절 탭을 직접 눌러 0편일 때만. 기본 홈은 우선순위 정렬이라 비지 않는다 |

---

## Key Design Notes

- **♡만 있고 싫어요는 없다. 개수는 어디에도 노출하지 않는다.** 누군가의 진심이 `♡ 0`으로 박히면 안 된다.
  개수는 DB에만 있고 `오래 남은` 정렬에만 쓴다.
- **재생은 ⑥ 곡 상세에서만.** 유튜브 RMF가 200×200px 미만 플레이어를 금지해 하단 미니 플레이어가 불가능하다.
  피드에는 iframe을 하나도 깔지 않는다.
- **복구 코드는 전용 화면을 만들지 않는다.** 올라간 내 글 옆에 조용히 둔다.
  방금 기억을 내놓은 여운 안에 암호 같은 문자열을 들이밀면 장르가 깨진다.
- **빈 상태는 기능이다.** "아직 이번 가을의 기억이 없어요 / 첫 사람이 되어볼래요?" + 다른 계절로 나가는 길.
- **로딩** — 재방문자는 localStorage의 지난 피드를 즉시 그리고 조용히 갱신한다.
  첫 방문자에게는 서비스 자체 카피를 한 줄씩 띄운다. **가사는 쓰지 않는다**(KOMCA 관리 저작물).
- **스크린리더** — ♡에 `aria-pressed`와 "좋아요 / 좋아요 취소" 레이블, 유튜브 iframe에 `title`,
  계절·시절 라벨은 장식이 아니라 정보로 읽히게 한다.
