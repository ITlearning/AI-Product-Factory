# 청년월세 체커 — Design Tokens

Generated from `landing-mockups.html` Variant A (approved 2026-04-30).
Direction: 따뜻한 오프-화이트 (Toss 결).

> 출시 시 프로젝트 루트에 복사: `Seoul-Youth-Rent-Checker/DESIGN.md`

---

## Tone

차분하고 신뢰 가는 톤. 정부스러운 답답함 X, SaaS 제너릭 X. 한국 핀테크(Toss/카뱅) 정수. 텍스트 무게 + 1개 강한 액센트로 위계.

## Color Palette

```css
/* Backgrounds */
--color-bg: #faf9f7;            /* 오프-화이트, 따뜻한 톤 */
--color-surface: #ffffff;       /* 카드/입력 */
--color-surface-border: #e5e3df;

/* Text */
--color-text-primary: #1a1a1a;  /* 차콜 (헤드라인/CTA) */
--color-text-secondary: #525252; /* sub/body */
--color-text-tertiary: #71717a; /* 라벨 */
--color-text-quaternary: #a1a1aa; /* footnote */

/* Action / Urgent */
--color-accent: #ef4444;        /* 산호 빨강 — 240만원, D-day 숫자 */
--color-accent-soft: #fef2f2;   /* hover/highlight bg */

/* Status */
--color-success: #16a34a;
--color-warning: #ea580c;
--color-danger: #dc2626;

/* Shadows */
--shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
--shadow-md: 0 4px 12px rgba(0,0,0,0.06);
```

## Typography

```css
--font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif;

/* Scale */
/* Hero h1:   32px / 800 weight / 1.25 line-height / -0.02em letter */
/* Section h2: 24px / 700 / 1.3 */
/* Body lg:   17px / 500 (CTA text) */
/* Body:      15px / 400 (sub) */
/* Body sm:   14px / 400 */
/* Label:     13px / 500 */
/* Caption:   12px / 400 */
```

## Spacing & Shape

```css
/* Radius */
--radius-button: 14px;
--radius-card: 16px;
--radius-input: 12px;
--radius-pill: 999px;     /* badge */

/* Spacing scale (Tailwind compatible) */
/* 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64 */
```

## Component Inventory

| Component | Description |
|-----------|-------------|
| App shell | max-width 430px on mobile, full-bleed bg `#faf9f7` |
| Trust badge | pill with red dot, `#fff` bg, `#525252` text, 12px font |
| Hero headline | 32px/800, 차콜, 핵심 단어 (240만원) `--color-accent` |
| D-day card | white card with thin border, label left + countdown right (red 숫자) |
| Primary CTA | 차콜 (`#1a1a1a`) bg, white text, 14px radius, full-width on mobile |
| Footnote | 12px tertiary text, center-aligned |
| Form input (TBD for /check) | white bg, `#e5e3df` border, `#1a1a1a` focus border |
| Progress bar (TBD for /check) | `#e5e3df` track, `#ef4444` fill |
| Result hero (TBD for /r/) | 자격 OK/NO 한 줄 큰 typography (40px+) |

## Key Design Notes

- **Light-first 의도적.** 다크 모드 대응 필요시 별도 팔레트 (v2).
- **Mobile-first**: 375px 기준. 768px+에서는 max-width 430px + center.
- **Pretendard 우선**, fallback Apple SD Gothic Neo. Google Fonts CDN 또는 jsdelivr 서브셋.
- **카드는 반드시 자기 일을 해야 함**: D-day 카드만 카드. CTA는 풀-너비 버튼.
- **모션:** 페이지 로드 시 fade-in 200ms (헤드라인 → sub → D-day → CTA staggered). hover/focus는 시스템 기본.
- **OG 카드** (도구 공유용): 같은 팔레트 + 헤드라인 핵심 한 줄. 결과 OG는 ❌ (P3 도구 공유 원칙).

## 계승 규칙 (Form + Result 페이지)

**`/check` 폼 페이지:**
- 같은 bg/색상 팔레트
- 한 화면당 1~2 질문 (덜 중요한 건 1단계에 묶지 말 것)
- 진행 progress bar 상단 고정 (`#ef4444` fill)
- 입력 필드는 16px 폰트 (모바일 자동 줌 방지)
- '다음' 버튼은 primary CTA 스타일, '뒤로'는 텍스트 버튼
- 분기 전환은 페이드 + 슬라이드 200ms

**`/r/[uuid]` 결과 페이지:**
- 자격 OK/NO를 헤드라인보다 더 큰 typography (40~48px)
- 자격 OK: 차콜 텍스트 + ✅ (이모지 디자인 X, 인라인 SVG체크)
- 자격 NO: 차콜 텍스트 + 사유 부드럽게 ('연령 미달이에요' 톤). 다른 프로그램 1~2개 추천 카드.
- 4구간 추첨 비율: D-day 카드 같은 형식. "1구간 / 35% 추첨" 큰 숫자.
- 서류 체크리스트: 4개 collapsible item, 발급처 링크 inline.
- "친구에게도 공유하기" 버튼은 secondary 스타일 (outline + 차콜 텍스트).

## AI Slop 회피 (실수 방지 체크리스트)

- ❌ 보라/인디고 그라데이션
- ❌ 3컬럼 피처 카드 그리드
- ❌ 컬러 동그라미 안에 아이콘
- ❌ 모든 요소 가운데 정렬
- ❌ 모든 라운드 같은 큰 값
- ❌ 데코 블롭/플로팅 서클
- ❌ 이모지를 디자인 요소로 (✓ ✗는 SVG 또는 텍스트)
- ❌ 컬러 좌측 보더 카드
- ❌ 'Welcome to' / 'Unlock the power' 같은 영어 generic
- ❌ 모든 섹션 같은 높이 쿠키커터
