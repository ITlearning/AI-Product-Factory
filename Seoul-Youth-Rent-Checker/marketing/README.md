# 마케팅 콘텐츠 자동 렌더 시스템

HTML template → Chrome headless → PNG. AI가 디자인하고 Chrome이 그림 생성.
Tabber 직접 Canva/Figma 안 만져도 됨.

## 디렉토리

```
marketing/
├── README.md          (이 파일)
├── render.sh          (Chrome headless 렌더 스크립트)
├── templates/         (HTML 디자인 — DESIGN.md 토큰 사용)
│   ├── _shared.css    (공통 폰트/색상/레이아웃)
│   ├── carousel-1.html ~ carousel-5.html  (인스타 캐러셀 5장)
│   └── (story-*.html / twitter-*.html 추가 가능)
└── output/            (.gitignore — PNG 결과물)
    └── carousel-1.png ~ carousel-5.png
```

## 사용

### 인스타 캐러셀 5장 (default)
```bash
cd Seoul-Youth-Rent-Checker
./marketing/render.sh
```
→ `marketing/output/carousel-1.png ~ carousel-5.png` (1080×1080)

### 단일 template 렌더
```bash
./marketing/render.sh carousel-3
./marketing/render.sh story-1   # → 1080×1920 (인스타 스토리)
./marketing/render.sh twitter-1 # → 1200×675 (트위터 카드)
```

이름 prefix로 자동 사이즈 결정:
- `story-*` → 1080×1920 (9:16 인스타 스토리/Reels 썸네일)
- `twitter-*` → 1200×675 (트위터 카드)
- 그 외 → 1080×1080 (정사각 인스타 피드/캐러셀)

## 새 콘텐츠 추가하는 법

1. `templates/{name}.html` 작성:
```html
<!doctype html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<link rel="stylesheet" href="_shared.css">
<style>
  /* 자유롭게 디자인 */
</style>
</head>
<body>
<div class="slide">  <!-- 또는 .story -->
  ...
</div>
</body>
</html>
```

2. 렌더:
```bash
./marketing/render.sh {name}
```

3. `output/{name}.png` 확인 → 인스타 업로드.

## DESIGN.md 토큰 (자동 사용)

`_shared.css`가 이미 정의:
- `var(--bg)` `#faf9f7` (오프-화이트)
- `var(--text)` `#1a1a1a` (차콜)
- `var(--accent)` `#ef4444` (빨강 — 강조)
- Pretendard CDN 자동 로드

→ 어떤 새 template이든 `class="badge"`, `class="footer"` 등 재사용 가능.

## 폰트 로드 안 될 때

Chrome headless가 CDN 폰트 fetch 못 하면 `--virtual-time-budget`을 더 늘려.
`render.sh`의 `--virtual-time-budget=10000` 값 — 10초. 느린 네트워크면 30000 (30초).

## 카루셀 인스타 업로드

5장 한 번에 게시하려면:
1. 인스타 앱 → 새 게시물
2. **여러 장 선택** (왼쪽 아래 아이콘) → 5장 순서대로 (1, 2, 3, 4, 5)
3. 캡션 + 해시태그 (CONTENT_CALENDAR.md 참조)
