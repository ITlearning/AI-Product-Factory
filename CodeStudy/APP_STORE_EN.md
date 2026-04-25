# CodeStudy — App Store Connect English Metadata

App Store Connect 영문 등록용 카피 모음. 각 필드 char limit 표시. 그대로 복붙 가능.

---

## App Name (30 chars max)

**Recommended (24 chars)**
```
CodeStudy: AI Swift Tutor
```

**Alternates**
- `CodeStudy: Learn Swift` (22 chars)
- `CodeStudy — Swift with AI` (25 chars)
- `Swift Tutor — CodeStudy` (23 chars)

---

## Subtitle (30 chars max)

**Recommended (29 chars)**
```
Learn Swift through dialogue
```

설명: 차별화 포인트(소크라테스식 대화)를 직접 표현. ChatGPT/Duolingo와 구분됨.

**Alternates**
- `Master Swift, one Q at a time` (29 chars)
- `Swift, taught Socratically` (26 chars)
- `Master Swift with an AI tutor` (29 chars) — generic이라 비추

---

## Promotional Text (170 chars max)

이 필드는 **심사 없이 언제든 변경 가능**. 출시 직후엔 영문 launch 강조.

**Launch (English market entry)**
```
Now in English. Master Swift through conversation with an AI that asks questions instead of giving answers — so you actually remember what you learn.
```
(154 chars)

**Cycle 2 features focus**
```
New: revisit any mastered concept's full study journey. Streak shield protects your daily progress. Built for learners who want it to stick.
```
(150 chars)

---

## Description (4000 chars max)

```
ChatGPT gives you answers and you forget them an hour later.
Duolingo is fun but the knowledge doesn't stick.
CodeStudy makes you make the answer — and remember it.

CodeStudy is an AI Swift tutor that teaches with the Socratic method. Instead of dumping code on you, it asks the right questions until you figure it out yourself. The "aha" moment is yours, not the AI's. That's why it sticks.

— How it works —

You start with a Swift concept (variables, optionals, protocols, async/await…) and have a real conversation with the tutor. It probes your understanding, gives analogies, asks you to predict what code does. When you've actually got it, it marks the concept "Mastered" — and only then.

No multiple-choice. No copy-paste. No "great job!" filler. Just genuine back-and-forth until the idea clicks.

— Features —

• 50+ Swift concepts from Beginner to Advanced
• Daily learning rhythm with streaks
• Streak Shield — skip a day, your streak survives
• Full study history — revisit any mastered concept and replay your conversations
• Mastery tracking that actually means something (not "you saw it once")
• Localized for Korean and English
• Anonymous by default — no account, no email, just learn
• Open privacy practices — see PRIVACY.md in our repo

— Who is it for? —

Developers who want to actually learn Swift, not just complete a course.
Bootcamp graduates filling in conceptual gaps.
Self-taught coders who keep getting stuck on the same things.
Anyone who's tired of tutorials they forget by next week.

— What's not in CodeStudy —

No trackers. No analytics SDKs. No ads. No upselling. Just the tutor.

— Built by —

A solo iOS developer who got frustrated with how today's coding tools optimize for the wrong thing (giving answers fast). CodeStudy optimizes for what actually matters: long-term retention.

Try it. Master your first concept in 5 minutes. The dialogue is the lesson.
```

(약 1880 chars)

---

## Keywords (100 chars max, comma-separated)

**Recommended (96 chars)**
```
swift,ios,programming,learn to code,ai tutor,xcode,socratic,coding,developer,swift dev
```

설명:
- `swift`, `ios` — 핵심 검색어
- `programming`, `coding`, `learn to code` — 광범위 카테고리
- `ai tutor` — 차별화
- `xcode`, `swift dev`, `developer` — 기술 타겟
- `socratic` — 진지한 학습자 (positioning 시그널)

영어권에서 "Swift" 검색은 빠르고 가벼운 무언가를 찾는 사람도 들어와서 `programming`/`coding` 함께 노출.

**대안 (more long-tail)**
```
swift programming,ios development,learn swift,ai coding tutor,xcode,beginner programming
```
(89 chars)

---

## What's New (4000 chars max, 1.1.0)

```
🎯 Revisit your learning journey
Tap any mastered concept in History to relive your study sessions and conversations. Never lose track of how you cracked it.

🔥 Streak shield
Skip a day? We'll auto-protect your streak. One freeze per week.

🌍 Now in English
Full English experience. Device language detected automatically.

Plus minor improvements and bug fixes.
```

(약 320 chars — 짧을수록 read-through 높음)

---

## Support URL (필수)

**임시 옵션**
- GitHub Issues: `https://github.com/ITlearning/CodeStudy-iOS/issues`
- (없으면) `https://github.com/ITlearning`
- 또는 본인 트위터 / 이메일 form

App Store는 이 URL이 살아있어야 함. 출시 후 이슈 받을 채널 있어야.

**권장**
한 번에 처리 가능한 GitHub repo issues 페이지 만들기. 5분 작업.

---

## Marketing URL (선택)

비워둬도 됨. 따로 LP 안 만들 거면 skip.

---

## Privacy Policy URL (필수)

기존 한국어 PRIVACY.md를 GitHub Pages로 호스팅하거나 Notion public 페이지로:
```
https://github.com/ITlearning/AI-Product-Factory/blob/main/CodeStudy/PRIVACY.md
```

영문 번역 필요. 출시 전 PRIVACY_EN.md 만들고 같은 패턴으로 host. 또는 한 페이지에 한/영 병기.

---

## Category

**Primary**: Education
**Secondary** (선택): Developer Tools

---

## Age Rating

4+ (no objectionable content, anonymous, no chat with strangers)

---

## App Privacy Details (App Store Connect → "App Privacy")

> ⚠️ **If 1.0.x is set to "Data Not Collected", switch BEFORE submitting 1.1.0.**
> Since Cycle 2 introduces Neon Postgres logging, data is now explicitly "collected"
> per Apple's definition. Mismatch = reject risk.

### How to update

App Store Connect → App Information → **App Privacy** → **"Does this app collect data?"** → Select **Yes**.

### Add 4 data categories

For each, select these common options:
- ☑ **Not linked to user** — anonymous UUID, no identity mapping
- ☑ **Not used for tracking** — no advertising / third-party sharing
- ☑ Purposes: **App Functionality** + **Analytics**

| # | Apple Category Path | Data Collected | Our Implementation |
|---|---|---|---|
| 1 | User Content → **Other User Content** | AI tutor conversation (user input + AI response) | `codestudy_log.raw.userInput`, `aiOutput` |
| 2 | Identifiers → **Device ID** | Anonymous UUID (generated on first launch, NOT Apple's IDFA, reset on reinstall) | `AnonymousID.current` |
| 3 | Usage Data → **Product Interaction** | Mastery progress, session counts, streak, concept IDs studied | `concept_id`, `event='turn'`, `mastered` |
| 4 | Diagnostics → **Performance Data** | Response latency, AI model used, token usage | `latencyMs`, `model`, `prompt_tokens`, `completion_tokens` |

### Retention / handling

When answering App Privacy questionnaire, declare:
- 30-day max retention (matches PRIVACY_EN.md Section 4)
- Not used for advertising or marketing
- Never sold or shared with third parties

### Data NOT Collected (declare explicitly)

Location, contacts, email, photos (only saved), payment info, health data, search history, etc.

The 3 sources of truth must match: `PrivacyInfo.xcprivacy` + `PRIVACY_EN.md` Section 4 + this App Privacy entry.

---

## Screenshots (Tabber 직접 작업)

**필수 사이즈 (iOS 17+ 기준)**
- iPhone 6.9" (1320 × 2868) — Pro Max 14/15/16/17 시리즈
- iPhone 6.5" (1284 × 2778) — Plus 시리즈
- (iPad는 선택, 출시 후 추가해도 됨)

**추천 흐름 (5장)**
1. **Today's lesson 진입 화면** — concept card with start button. Hook: "Daily lesson, structured."
2. **Active conversation (chat in progress)** — Show the Socratic dialogue. Hook: "Teaches by asking, not telling."
3. **Mastery completion** (confetti screen) — "Mastered" badge, streak counter. Hook: "When you've actually got it."
4. **Learning history** — Calendar heatmap + concept list. Hook: "Your streak. Your concepts. Your proof."
5. **Concept history detail** (Cycle 2 신규 ⭐) — sessions list + conversation playback. Hook: "Revisit any concept's full journey."

각 스크린샷에 짧은 영문 captions/headlines 권장 (Apple style).

---

## 준비 체크리스트

**App Store Connect 준비**
- [ ] App Name + Subtitle 입력 (영문 fields)
- [ ] Promotional Text 입력
- [ ] Description 입력
- [ ] Keywords 입력
- [ ] What's New (1.1.0) 입력
- [ ] Privacy Policy URL 영문판 호스팅 + 입력
- [ ] Support URL 입력
- [ ] App Privacy Details 영문판 검토
- [ ] 영문 스크린샷 5장 업로드 (iPhone 6.9" + 6.5")
- [ ] App Privacy details 검토

**Xcode 준비**
- [ ] Version 1.1.0 / Build 3
- [ ] PrivacyInfo.xcprivacy 타겟 추가 확인
- [ ] Localizable.xcstrings + curriculum_*.json 타겟 추가 확인
- [ ] Archive
- [ ] Upload to App Store Connect

**Submit for Review**
- [ ] "Submit for Review" 버튼
- [ ] Apple 심사 통과 후 → Show HN 게시

---

## 톤 가이드 (다음 카피 수정 시)

- **차별화 lead** — ChatGPT/Duolingo 비교를 처음부터 명시. 우회 안 함.
- **Quiet confidence** — "world's best" 같은 hype 금지. 결과로 말함.
- **Builder-to-builder** — 마케팅 carbon copy 아닌 실제 개발자가 쓴 느낌
- **Specific over generic** — "50+ concepts" "Beginner to Advanced" 같이 숫자/범위 명시
- **No emojis in description body** — 가벼워 보임. What's New에만 1-2개 OK.
- **Avoid "delight", "seamless", "powerful"** — Apple-blog cliche

## Updated 2026-04-25
- Cycle 2 (1.1.0) 영어권 launch 카피
- 출시 후 retention 데이터 보고 description 수정 권장
- Promotional Text는 캠페인 시기에 따라 수시 변경 (심사 없이)
