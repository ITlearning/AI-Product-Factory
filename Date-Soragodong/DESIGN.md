# Date-Soragodong Design Tokens

Generated from `finalized.html` (soragodong-landing, 2026-04-02).
Source mockup: 별자리 달빛 (variant-AC, approved 2026-04-02).

---

## Color Palette

```css
/* Background gradient */
--color-bg-top: #0f0d2e;         /* deep indigo */
--color-bg-mid: #1a1060;         /* dark navy */
--color-bg-bottom: #6b3fa0;      /* purple */
--color-bg-footer: #c97fd8;      /* pink-lavender */

/* Cards */
--color-card-bg: rgba(255, 255, 255, 0.08);
--color-card-border: rgba(255, 255, 255, 0.18);
--color-card-hover: rgba(255, 255, 255, 0.14);

/* Text */
--color-title: #ffffff;
--color-subtitle: rgba(255, 255, 255, 0.80);
--color-card-label: #ffffff;

/* CTA */
--color-cta-from: #ff6b35;       /* coral */
--color-cta-to: #ffa726;         /* orange-gold */

/* Decorative */
--color-star: rgba(255, 255, 255, 0.75);
--color-gold: #ffd700;
--color-gold-glow: rgba(255, 200, 50, 0.4);
```

## Typography

```css
--font-family: 'Noto Sans KR', -apple-system, sans-serif;

/* Scale */
/* Hero title:   28px / 900 weight */
/* Subtitle:     14px / 400 weight */
/* Card label:   14px / 500 weight */
/* CTA button:   17px / 700 weight */
/* Status bar:   15px / 600 weight */
```

## Spacing & Shape

```css
--radius-card: 20px;
--radius-btn: 50px;       /* pill */
--spacing-card-gap: 12px;
--shadow-card: 0 4px 24px rgba(0, 0, 0, 0.25);
```

## Component Inventory

| Component       | Description                                      |
|-----------------|--------------------------------------------------|
| App shell       | max-width 430px, full-bleed gradient bg          |
| Star field      | 60 procedural stars, twinkle animation           |
| Constellation   | SVG lines connecting 11 star points              |
| Hero shell      | 🐚 emoji with 4 concentric golden glow rings     |
| Category card   | Glassmorphism 2×2 grid, toggle selected state    |
| CTA button      | Full-width pill, coral→orange gradient           |
| Decorative      | 🌙 crescent moon (top-right), 🌸 petals (top-left) |

## Key Design Notes

- **Dark-first**: intentionally dark. Don't override with light mode.
- **Mobile-first**: 375px base, max-width 430px. Works on desktop with
  centered card and rounded corners at ≥768px.
- **Glassmorphism cards**: `backdrop-filter: blur(12px)` — requires
  HTTPS or localhost in Chrome (no file://).
- **Emoji rendering**: 🐚 shell and card icons are emoji (no SVG assets).
  Golden ring effect is pure CSS `border + box-shadow`.
- **Font**: Noto Sans KR from Google Fonts. Bundle subset for OG API
  (Satori cannot access network fonts).
