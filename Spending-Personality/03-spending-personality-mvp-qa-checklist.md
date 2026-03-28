# Spending-Personality MVP QA Checklist

Related Linear issue: `AI-17`

## Purpose

This checklist defines the MVP QA pass for `오늘의 소비 캐릭터`.
It is meant to be executed once a candidate branch or PR includes the
functional scope from:

- `AI-13` 붙여넣기 중심 입력 화면 구현
- `AI-15` 결과 화면 및 공유 카드 구현
- `AI-16` 최근 캐릭터 히스토리 MVP 구현

## Current blocker

As of `2026-03-28`, `main` does not expose a QA-able MVP flow yet.
The current app still renders a shell where the input is read-only and the
generate button is disabled, so this checklist is preparatory until a real
candidate branch exists.

## Preconditions

- A candidate branch or PR is available for the MVP flow.
- The candidate includes real input, result, share-card, and recent-history
  behavior.
- The service verify command passes before manual QA starts.

## Environment

```bash
cd Spending-Personality
npm run verify
npm run dev -- --port 4176
```

Open `http://127.0.0.1:4176`.

## Core QA matrix

### 1. Happy path generation

Use this input:

```text
07:42 편의점 4,800원
12:15 회사 근처 샐러드 11,900원
18:34 택시 14,200원
21:08 배달 디저트 9,500원
```

Optional note:

```text
야근하고 돌아오는 길, 오늘은 조금 지친 날
```

Expected:

- The user can paste the text without format friction.
- The generate action is available when the minimum input condition is met.
- A result is rendered with:
  - character name
  - one-line summary
  - three tags
  - two to three evidence items
  - one pattern observation
  - one next move
- The result reads as observational, not judgmental.

### 2. Loading and transition

Expected:

- The UI exposes a generating state or prevents double-submit.
- The transition from input to result is clear.
- Stale previous output does not remain on screen in a confusing way.

### 3. Needs-more-data state

Use this input:

```text
07:42 편의점 4,800원
```

Expected:

- The app does not crash.
- A `needs-more-data` style message appears.
- The user gets a concrete hint about adding more spending lines.

### 4. Parse-failed state

Use this input:

```text
오늘은 그냥 좀 바빴다
택시를 탔다
```

Expected:

- The app does not pretend to succeed.
- A parse-failed message is shown.
- The UI offers an example format such as `07:42 편의점 4,800원`.

### 5. Result screen quality

Expected:

- The character name and summary are immediately visible.
- Evidence items explain why the result appeared.
- The next move is short, practical, and non-preachy.
- The observational disclaimer is present.

### 6. Tone review

Allowed:

- observational language
- light wit
- tentative phrasing such as `보여요`, `읽혀요`, `가까웠어요`

Reject:

- blame
- mockery
- moral judgment
- clinical or pathological framing
- overconfident claims about the user

### 7. Share card

Expected:

- A visually separate card-like result area exists for save/share use.
- The card preserves the key information hierarchy:
  - character name
  - summary
  - supporting tags or evidence
- The card remains readable in a screenshot-sized viewport.

### 8. Recent character re-entry

Expected:

- A recently generated character can be reopened.
- Re-entering a recent item keeps the core result intact.
- The feature stays at shallow MVP history scope and does not expand into a
  full analytics product.

## Suggested execution notes

When this checklist is run for real, record:

- candidate branch or PR URL
- verify result
- pass/fail by checklist item
- concrete bugs or tone issues
- whether the issue should stay in `Human Review` or move to `Rework`

## Manual QA record template

```text
Candidate:
Verify:

Happy path:
Loading and transition:
Needs-more-data:
Parse-failed:
Result screen quality:
Tone review:
Share card:
Recent character re-entry:

Key findings:
Next state:
```
