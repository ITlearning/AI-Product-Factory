# AGENTS.md — CodeStudy 프로젝트 가이드

이 파일은 CodeStudy 코드베이스에 들어오는 AI 에이전트(Claude Code, Cursor, Copilot 등)와 신규 contributor를 위한 컨텍스트 문서입니다. 빠르게 작업 시작할 수 있도록 핵심 정보만 담음.

`CLAUDE.md`가 monorepo 루트에 존재하면 그게 우선 적용됨. 이 파일은 CodeStudy sub-project specific 가이드.

---

## Project at a glance

| 항목 | 값 |
|---|---|
| Product | AI Swift 튜터 (소크라테스식, 묻고 답하며 가르침) |
| Differentiator | "ChatGPT는 답을 준다. CodeStudy는 답을 만들게 한다" |
| Stack | iOS (Swift/SwiftUI/SwiftData) + Backend (Vercel Functions, Node.js ESM) + Neon Postgres |
| Min iOS | 17 (deployment target 26.0) |
| LLM | OpenRouter → Claude Haiku 4.5 (default) |
| App Store | KR live (1.0.x), 1.1.0 in review (KR + EN) |
| Repo | `ITlearning/AI-Product-Factory` (monorepo, CodeStudy is one product) |
| Maintainer | Tabber (1인 indie maker) |

---

## Repository layout

```
AI-Product-Factory/
├── CodeStudy/
│   ├── iOS/CodeStudy/CodeStudy/   ← iOS app source
│   │   ├── App/                    ← @main, RootView, OneTimeMigration
│   │   ├── Models/                 ← @Model SwiftData (UserProfile, StudySession, ChatMessage, ConceptProgress, DailyStreak)
│   │   ├── ViewModels/             ← @Observable VMs (DailyChallenge, ChatVM, Progress, Settings, Onboarding)
│   │   ├── Views/                  ← SwiftUI views (Chat/, Main/, Onboarding/, Shared/)
│   │   ├── Services/               ← APIProvider, AIService, ConfigService, StreakManager, ConceptCurriculum, AnonymousID
│   │   ├── Tips/                   ← TipKit Tip structs
│   │   ├── Resources/              ← Localizable.xcstrings, curriculum_ko.json, curriculum_en.json (legacy curriculum.json fallback)
│   │   └── PrivacyInfo.xcprivacy   ← App Store privacy manifest
│   ├── Backend/                    ← Vercel Functions
│   │   ├── api/                    ← endpoints: tutor, daily-concept, health, config
│   │   ├── src/                    ← logger, validation, llm/(provider, openrouter, claude, gemini), prompts
│   │   ├── migrations/             ← Neon SQL + runner
│   │   └── tests/                  ← node:test
│   ├── PRIVACY.md / PRIVACY_EN.md ← Privacy policy (KR + EN)
│   ├── APP_STORE_KO.md / APP_STORE_EN.md ← Store metadata guides
│   ├── SURVEY.md / SURVEY_EN.md   ← In-app survey content
│   └── AGENTS.md                   ← (this file)
└── TODOS.md                        ← Cross-product TODOs
```

---

## iOS architecture (MVVM + @Observable)

- **MVVM** with `@Observable` (iOS 17+) instead of legacy `ObservableObject`. **Not Combine.** TCA-friendly, deps 0.
- **State flow**: View → calls VM action → VM mutates state → View reactively re-renders
- **SwiftData** for local persistence. `ModelContainer` configured in `CodeStudyApp`. Inject via `.modelContainer(...)`.
- **No 3rd-party deps**. Native frameworks only: `SwiftUI`, `SwiftData`, `Foundation`, `WebKit`, `Photos`, `TipKit`, `Observation`. Hackle SDK was added (analytics) but minimally used.

### Data model

```
UserProfile (1)
  └── preferredLanguage: ko | en (AppLanguage)
  └── swiftLevel: beginner|basic|intermediate|advanced
  └── dailySessionCount, lastSessionCountResetDate

StudySession (N) ─── ConceptProgress (1 per concept)
  ├── conceptID, conceptTitle, startedAt, completion
  └── messages: [ChatMessage]

DailyStreak (1)
  ├── currentStreak, longestStreak, lastStudyDate
  └── freezeCount, lastFreezeGrantDate (Cycle 2)
```

### View tree

```
CodeStudyApp (@main)
  └── RootView
      ├── OnboardingView (if no UserProfile)
      └── MainTabView
          ├── Tab "Learn" → DailyChallengeView → ChatView → SessionCompleteView
          │                                                 └── (if mastered) SurveyModalView
          ├── Tab "History" → ProgressDashboardView → ConceptHistoryView → SessionConversationView
          └── Tab "Settings" → SettingsView
```

---

## Backend architecture (Vercel Functions, ESM)

- **Stack**: Node.js 18+ ESM (`"type": "module"`), Vercel Functions Route Handler pattern (named GET/POST exports)
- **Provider abstraction**: `src/llm/provider.js` routes to `openrouter` (default), `claude`, or `gemini`
- **Streaming**: SSE for tutor endpoint. Format: `data: {"t":"text"}\n\n`, final `data: {"done":true,"mastered":bool}\n\n`
- **Logger**: `logConversation(entry)` → Neon Postgres INSERT, fallback to console.log on failure
- **Config**: `/api/config` exposes runtime toggles (survey URL/enabled). Edge cached 5min stale-while-revalidate 10min
- **Tests**: `node:test` (built-in, no Jest/Vitest dep)

### Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/tutor` | POST | SSE streaming AI response. Validates request, applies rate limit, calls provider |
| `/api/daily-concept` | GET | Returns next concept for user's level |
| `/api/health` | GET | Liveness check |
| `/api/config` | GET | Runtime config (survey URL/enabled) — schemaVersion 2 |

### Env vars (Vercel)

```
OPENROUTER_API_KEY           ← LLM
OPENROUTER_MODEL              ← default model override
ANTHROPIC_API_KEY             ← if provider=claude
DATABASE_URL                  ← Neon Postgres (auto-injected by Vercel-Neon integration)
SURVEY_URL                    ← Korean Google Forms URL
SURVEY_URL_EN                 ← English Google Forms URL (optional, fallback to SURVEY_URL)
SURVEY_ENABLED                ← "true"/"false"
```

---

## Coding conventions

### Swift

- **Strings**: `String(localized: "key.in.dot.notation", defaultValue: "한글 default")` — never literal Korean as key (legacy AIService.swift has 8 violations, see TODOS)
- **Colors**: `Color.deepBlue` / `Color.warmOrange` from `Views/Shared/ColorExtension.swift`. Defined in Asset Catalog with light/dark pairs
- **Naming**: descriptive Korean comments OK for non-trivial logic. Method/property names English
- **Imports**: framework-only. Never import 3rd party except via Apple-distributed SwiftPM
- **Tests**: Swift Testing (`@Test`, `#expect`) for new tests. XCTest grandfathered for older tests
- **i18n**: dual lookup — `concept.title(for: profile.language)` etc. View reads `language` from UserProfile via `@Query`. ConceptCurriculum loader uses `Locale.current` (acceptable inconsistency since both files contain bilingual fields)

### Backend (Node.js)

- **ESM only**: `import`/`export`. No CommonJS
- **Native fetch**: Node 18+ global fetch. No axios
- **Async/await**: never `.then()` chains
- **Logger fail-soft**: any logging error → console.log fallback, never throws to caller
- **Tests**: dependency injection (e.g., `_setSqlClient`) over module mocks. Match existing patterns

---

## Build & test

### iOS

```bash
cd CodeStudy/iOS/CodeStudy
xcodebuild -project CodeStudy.xcodeproj -scheme CodeStudy \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build
```

Tests: Xcode UI (⌘U) — scheme not configured for `xcodebuild test` action.

### Backend

```bash
cd CodeStudy/Backend
npm test           # node:test runs all *.test.js (26 tests)
node --env-file=.env.local migrations/run.js   # one-time DB migration
```

### Deploy

```bash
cd CodeStudy/Backend
vercel --prod      # ~30s cold deploy
```

iOS: Xcode → Product → Archive → Distribute → App Store Connect.

---

## Privacy & data posture

3개 source-of-truth가 일관해야 함 (변경 시 셋 다 동기화):

1. **`PrivacyInfo.xcprivacy`** — Apple manifest (요구 API + tracking declaration)
2. **`PRIVACY.md` / `PRIVACY_EN.md`** — 사용자에게 공개되는 정책 (App Store URL)
3. **App Store Connect "앱 개인정보 보호"** — 4 카테고리: 기타 사용자 콘텐츠, 디바이스 ID, 제품 상호 작용, 기타 진단 데이터

**핵심 원칙**:
- 익명 UUID (Apple IDFA 무관, 재설치 시 reset)
- 30일 자동 삭제 (Vercel Cron 또는 Neon scheduled task)
- 광고 0개, 트래커 0개, 제3자 공유 0개
- 회원가입 없음, 이메일 없음 (단, 인앱 설문에서 자발적 입력만 — 추첨/인터뷰 용도, 90일 후 삭제)

---

## Differentiator (product 본질)

```
ChatGPT는 답을 준다. 한 시간 후엔 잊힌다.
유튜브 강의는 듣고 나면 머리에 남지 않는다.
CodeStudy는 답을 만들게 한다. 그래서 기억에 남는다.
```

이 차별화가 모든 product 결정의 검증 기준:
- ✅ 소크라테스식 대화 (질문으로 가르침)
- ✅ 마스터리는 진짜로 이해했을 때만 표시 (객관식 X)
- ✅ 학습 기록 회고 (Cycle 2 신규) — "내가 어떻게 풀었는지" 다시 봄
- ❌ 거짓 게이미피케이션 ("축하해요!" 빈말)
- ❌ 5분 모드 (Cycle 2 plan에서 reject — product promise 모순)

새 기능 추가 시 이 promise와 정렬되는지 검증 필수.

---

## Cycle history

| Cycle | 기간 | 핵심 성과 |
|---|---|---|
| Cycle 0 | ~2026-04-15 | MVP iOS 앱 (Onboarding, Daily, Chat, Mastery, Streak, Settings) |
| Cycle 1 | 2026-04-18 | 1.0.x 출시 (한국 App Store) |
| Cycle 1.5 | 2026-04-22 | 5 UX 버그 fix + 이미지 저장 + Stage 1 console.log 로깅 (1.0.1) |
| Cycle 2 | 2026-04-25 | 학습 기록 인터랙티브 + Streak Freeze + i18n + 영문 진출 + Neon Postgres + TipKit + 인앱 설문 (1.1.0 심사 중) |
| Cycle 3 | TBD (Stage 1 데이터 후) | Stage 1 demand discovery 결과 따라 결정. 후보: 면접 도우미 모드, Pro 구독, 위젯 |

---

## Test plan files (gstack)

- `~/.gstack/projects/ITlearning-AI-Product-Factory/ceo-plans/2026-04-25-codestudy-cycle2.md` — Cycle 2 CEO plan
- `~/.gstack/projects/ITlearning-AI-Product-Factory/tabber-main-design-20260425-cycle2.md` — Cycle 2 design doc
- `~/.gstack/projects/ITlearning-AI-Product-Factory/tabber-main-eng-review-test-plan-20260425.md` — Cycle 2 eng review

새 cycle 시작 시 `/plan-ceo-review` → `/plan-eng-review` → `/plan-design-review` 순서.

---

## When stuck

- iOS 빌드 안 됨 → SourceKit 캐시 lag 가능성 ↑. `xcodebuild` 실제 결과로 판단
- Backend 배포 후 캐시 → `/api/config` 5분 edge cache. 변경 즉시 반영 원하면 다른 endpoint
- TipKit tip 안 뜸 → datastore 영구 dismiss 가능성. 앱 삭제 + 재설치 또는 `Tips.resetDatastore()`
- 한글 leak → User Profile.language vs Locale.current 불일치 가능. App Settings → 언어 토글로 강제 동기화

---

## Updated 2026-04-25 (Cycle 2 finalize)
