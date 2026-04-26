# Cycle 3 — Backend Track 추가

작성일: 2026-04-26
브랜치: `feat/backend-track`
상태: planning + sample curriculum 단계

## Why

Tabber의 검증 파이프라인:
- `swift-study` CLI 스킬 → iOS 개발자 community 검증 → CodeStudy iOS Swift 트랙
- `study-backend` CLI 스킬 → Kotlin/Spring 백엔드 dev 검증 → ★ 이번 cycle에서 iOS 앱 트랙으로 port

소크라테스식 메커니즘이 도메인 간 cross-validated 됨. CodeStudy 앱을 단일 언어 학습 → 멀티 도메인 코딩 학습 플랫폼으로 진화.

브랜드 그대로, infra 80% 재사용, 시장 ~5x 확장.

## Scope

### in scope
1. `curriculum_backend_ko.json` / `curriculum_backend_en.json` — 50 concepts, 기존 Concept 스키마와 동일
2. iOS `TrackType` enum (`.swift` | `.backend`) — UserProfile에 추가
3. iOS Onboarding에 Track 선택 단계 추가
4. iOS Settings에 Track switcher
5. iOS `ConceptCurriculum` loader — track + locale 기반 분기
6. Backend `Socratic prompt` track-aware variant (Swift 어법 vs Kotlin/Spring 어법)
7. iOS `APIProvider` → Backend로 track 전달 (`X-CodeStudy-Track` 헤더 또는 body field)
8. 기존 사용자 마이그레이션: `preferredTrack = .swift` 기본값 (현재 경험 보존)

### out of scope
- 트랙 간 교차 마스터리 (Swift + Backend 동시 학습 진도)
- 트랙별 별도 streak (현재 streak는 통합)
- 트랙 추가 (Python/JS 등) — Stage 1 데이터 보고 다음 cycle에 결정
- 음성 면접관 모드 — 별개 vertical, 추후 검토

## Schema 매핑

기존 `Concept` 스키마 그대로 재사용. backend track의 concept 예시:

```json
{
  "id": "kotlin-null-safety",
  "level": "beginner",
  "category": "Kotlin",
  "order": 1,
  "title_ko": "Null 안전성",
  "title_en": "Null Safety",
  "tip_ko": "Kotlin은 컴파일 타임에 null을 잡아줘요. ?와 !!의 차이를 정확히 알면 NPE에서 자유로워집니다.",
  "tip_en": "Kotlin catches null at compile time. Master the difference between ? and !! to leave NPE behind.",
  "teaching_hints_ko": {
    "what": "변수 타입에 ?를 붙여 null 가능 여부를 명시. String? vs String 차이.",
    "why": "Java NPE 방지. 컴파일러가 null 체크를 강제해 런타임 오류 감소.",
    "how": "val name: String? = nullable 가능 / val safe: String = non-null. 안전 호출 ?.은 null이면 null 반환.",
    "watchOut": "!! 연산자는 null이면 NPE 발생. 사용 자제. ?. 와 ?: 조합으로 안전하게."
  },
  "teaching_hints_en": { ... },
  "analogies_ko": ["편지봉투에 '내용 없을 수 있음' 도장. 받는 사람이 미리 알고 열어봄.", "..."],
  "analogies_en": [...],
  "simpler_fallback": "Java NPE 처음 본 사람"
}
```

## 50 concepts 카테고리 구성

| Category | 비중 | Levels | 핵심 토픽 |
|---|---|---|---|
| **Kotlin Basics** | 8 | beginner~basic | null safety, data class, sealed class, extension functions, scope functions, collections |
| **Kotlin Advanced** | 6 | intermediate~advanced | coroutines, Flow, suspend, channels, structured concurrency |
| **Spring Core** | 7 | beginner~intermediate | IoC/DI, Bean lifecycle, component scanning, configuration, profiles |
| **Spring Web** | 6 | basic~intermediate | MVC, REST controller, exception handler, filters/interceptors |
| **Spring Data** | 6 | basic~intermediate | JPA basics, entity 매핑, JpaRepository, QueryDSL, fetch strategies |
| **Spring Security** | 4 | intermediate~advanced | Authentication, JWT, OAuth2, role-based authorization |
| **Database** | 5 | basic~advanced | normalization, indexing, transactions/ACID, isolation levels, deadlock |
| **Architecture** | 4 | intermediate~advanced | caching (Redis), message queue (Kafka), microservices basics |
| **Testing** | 3 | basic~intermediate | JUnit5 + MockK, integration tests, test slices |
| **DevOps** | 1 | basic | Docker basics |

총 50 concepts. 진도는 order 1~50.

### Level distribution
- beginner: 1-15 (15개) — first principles, 첫 backend
- basic: 16-30 (15개) — CRUD 앱 만들기
- intermediate: 31-42 (12개) — production 패턴
- advanced: 43-50 (8개) — system design

## Architecture changes

### Models/UserProfile.swift
```swift
@Model final class UserProfile {
    // 기존 필드들...
    var preferredTrack: String = TrackType.swift.rawValue  // 기본값 swift (기존 사용자 보존)
    
    var track: TrackType {
        get { TrackType(rawValue: preferredTrack) ?? .swift }
        set { preferredTrack = newValue.rawValue }
    }
}

enum TrackType: String, Codable, CaseIterable {
    case swift
    case backend
    
    var displayName_ko: String {
        switch self {
        case .swift: return "Swift / iOS"
        case .backend: return "Backend / Spring"
        }
    }
    var displayName_en: String { ... }
}
```

### Services/ConceptCurriculum.swift
```swift
static func loadConcepts(track: TrackType = .swift) -> [Concept] {
    let langSuffix = preferredLanguageSuffix()  // _ko or _en
    let filename = "curriculum_\(track.rawValue)\(langSuffix)"
    // load from bundle, fallback to bilingual swift
}
```

### Backend/api/tutor.js
- Request body에 `track` field 추가 (`'swift'` | `'backend'`)
- `buildSystemPrompt`에 track 전달
- track-specific Socratic instruction injection

### Backend/src/prompts/socratic-rules.js
- 공통 Socratic 원칙 (질문 던지기, 답 안 주기 등) → 그대로
- 트랙별 어법:
  - swift track: "Swift / SwiftUI / iOS / async-await Swift 식 어법"
  - backend track: "Kotlin / Spring Boot / JVM 식 어법"
- `[MASTERY]` 태그 등 시스템 마커는 트랙 공통

### Onboarding TrackStepView (신규)
```swift
struct TrackStepView: View {
    let onSelect: (TrackType) -> Void
    
    var body: some View {
        // "무엇을 학습하고 싶으세요?" 카드 2개
        // [Swift / iOS]    [Backend / Spring]
    }
}
```

Onboarding 흐름: Experience → SwiftLevel → **Track ← 신규** → Notification

`SwiftLevel`은 사실상 generic level이므로 track 무관하게 사용.

### Settings 트랙 switcher
```
설정 → 학습 트랙 → [Swift] [Backend] picker
```

기존 사용자가 트랙 바꾸면 진도 reset 안 함, 트랙별 ConceptProgress가 분리되어야 한다는 의사결정 필요. 옵션:
- **A**: 트랙별 분리 progress (ConceptProgress.track 컬럼 추가)
- **B**: 통합 progress (concept ID prefix로 swift- / kotlin- 구분)

**Recommend: A** — 트랙 전환 후에도 진도 보존. 다만 모델 마이그레이션 필요.

## Migration plan

### iOS (SwiftData lightweight migration)
- `UserProfile.preferredTrack` 추가, default `.swift`
- `ConceptProgress.track` 추가 (옵션 A 선택 시), default `.swift`
- 기존 사용자: 1.2.0 첫 실행 시 모든 ConceptProgress가 swift 트랙으로 마이그레이션됨
- 영향: 0 (기존 학습 데이터 보존)

### Backend
- request body schema 호환성: `track` 누락 시 default `'swift'` (구버전 클라이언트 호환)
- `codestudy_log.raw`에 `track` 자동 포함 (raw가 JSONB라 schema drift 안전)

## 단계별 작업

### Phase 1: Curriculum 생성 (이번 PR 시작점)
- [ ] `curriculum_backend_ko.json` 50 concepts 생성 (sample 5개 → Tabber 리뷰 → bulk)
- [ ] `curriculum_backend_en.json` 동일 구조

### Phase 2: iOS architecture
- [ ] `Models/Track.swift` (TrackType)
- [ ] `Models/UserProfile.swift` 수정 (preferredTrack 필드)
- [ ] `Models/ConceptProgress.swift` 수정 (track 필드)
- [ ] `Services/ConceptCurriculum.swift` track-aware loader
- [ ] `ViewModels/DailyChallengeViewModel.swift` track 사용
- [ ] `Views/Onboarding/TrackStepView.swift` 신규
- [ ] `Views/Onboarding/OnboardingView.swift` step 추가
- [ ] `Views/Main/SettingsView.swift` track switcher

### Phase 3: Backend
- [ ] `Backend/api/tutor.js` track 필드 처리
- [ ] `Backend/src/prompts/socratic-rules.js` track-aware variants
- [ ] iOS `APIProvider` track 전송

### Phase 4: i18n + 마무리
- [ ] xcstrings에 track 관련 키 추가
- [ ] xcodebuild + tests
- [ ] PR 생성, main으로 머지

## Verification 기준

- [ ] 빌드 성공 (Swift + Backend tests pass)
- [ ] 신규 사용자 Onboarding에서 Swift / Backend 선택 가능
- [ ] 기존 사용자(1.0.x → 1.1.x → 1.2.0): 자동으로 Swift 트랙. 학습 데이터 보존
- [ ] Settings에서 Backend 트랙으로 전환 → DailyChallenge에 backend 개념 노출
- [ ] Backend 트랙에서 마스터한 개념은 ConceptHistoryView에 backend 컨텍스트로 표시
- [ ] 영어 locale에서 backend 트랙 선택 → 모든 backend concept 영문

## Open questions (Tabber decide)

1. **Settings에서 트랙 전환 가능?** YES (UX 친화) / NO (의도적 구속)
   - YES 권장. 사용자가 두 트랙 다 학습 가능
2. **트랙별 streak 분리?** YES / NO (통합)
   - NO 권장 (통합) — 매일 학습 습관이 핵심, 어느 트랙이든 학습 = streak 유지
3. **Daily limit (5문제) 트랙별 분리?** YES / NO (통합)
   - NO 권장 (통합) — DAU 한도 일관성
4. **마스터한 개념 ConceptHistoryView에서 트랙 라벨 표시?** YES / NO
   - YES 권장 — "이건 Backend 트랙에서 마스터한 거" 명시

## 시간 예측

| Phase | 작업 | CC 추정 | Tabber 리뷰 |
|---|---|---|---|
| 1 (Curriculum) | sample 5 + bulk 45 + bilingual | 30분 | 1-2시간 (50 concept 검증) |
| 2 (iOS arch) | Track enum, UserProfile, Curriculum, Onboarding, Settings | 1-2시간 | 30분 (시뮬레이터 QA) |
| 3 (Backend) | tutor.js, socratic-rules.js | 30분 | 15분 (테스트) |
| 4 (i18n + 마무리) | xcstrings + 빌드 | 30분 | 30분 |
| **합계** | | **~3시간 CC** | **~3시간 Tabber** |

총 1일 work. 1.2.0 출시 가능 시점은 1.1.0 심사 결과 + Stage 1 데이터 본 후.

## Updated 2026-04-26
