# CodeStudy Roadmap

작성일: 2026-04-26
범위: 트랙/curriculum 확장 + Variation 전략

---

## 검증된 자산 (현재 시점)

```
swift-study (CLI 스킬, validated)
  └─ → CodeStudy iOS Swift 트랙 (50 concepts, 1.0.x → 1.1.0 출시)

study-backend (CLI 스킬, validated by 백엔드 dev)
  └─ → CodeStudy iOS Backend 트랙 (50 concepts, 1.2.0 시점에 ship)
```

소크라테스식 메커니즘이 도메인 간 cross-validated. 같은 패턴 반복 가능:
**CLI 스킬로 빠르게 검증 → community 만족도 확인 → 모바일 앱 트랙으로 port.**

---

## 트랙 확장 전략

### 단기 (1.2.0 — Cycle 3, 이번 PR 범위)

- ✅ **Backend 트랙** 50 concepts 추가
  - Kotlin Basics + Advanced + Spring Core/Web/Data/Security + DB + Architecture + Testing + DevOps
  - 한국 + 영어 store 동시 출시

### 중기 (Cycle 3.5 — 별도 PR, ★ 가장 cheap한 확장)

- **Android 트랙** 추가 (~65 concepts, but 신규 작성 ~50개만)
  - **Kotlin Core 15 concepts 재사용** (val/var, null safety, data class, coroutines, Flow, scope functions, collections, sealed class, when, extensions)
  - **Android-only 50 concepts 신규**:
    - Compose 기초 (Composable, State, recomposition, side effects)
    - Architecture (ViewModel, LiveData/StateFlow, Hilt)
    - Navigation (Compose Navigation, deep links)
    - Persistence (Room, DataStore)
    - Networking (Retrofit, OkHttp)
    - Background work (WorkManager, foreground service)
    - Permission, lifecycle, configuration changes
  - **마케팅 강점**: iOS 개발자 → Android 호기심 = 자연스러운 cross-sell. Swift 사용자가 Kotlin Android로 confidence build 가능
  - **비용**: ~1일 작업 (Kotlin Core 카피 + Android 신규 50)

### 중기 (Cycle 4 — Curriculum depth 확장)

- **각 트랙 50 → 80 concepts** 확장
  - Swift 50 → 80 (Stage 1 데이터 기반으로 가장 자주 막힌 영역 보강)
  - Backend 50 → 80
  - Android 65 → 80
  - **Total: 240 concepts**
  - 마케팅: "Master 200+ concepts across iOS, Backend, Android"

### 장기 (Cycle 5+)

- 트랙 추가 후보 (CLI 스킬로 먼저 검증):
  - **Frontend** (React/TypeScript) — 시장 가장 큼
  - **Python Backend** (Django/FastAPI) — Kotlin과 다른 백엔드 vertical
  - **Data/ML** (Python + ML basics) — 인기 분야
  - **DevOps/Infra** (Docker, K8s, CI/CD 깊이)

각 트랙은 검증 파이프라인 거침:
1. CLI 스킬 작성 (Tabber 1-2일)
2. `npx skills add` 친구/community 공유, 만족도 확인
3. 만족 시그널 강하면 → 앱 트랙으로 port (50 concepts, 1주일)

---

## Variation 전략 (한 번 만든 자산 재사용)

### Kotlin 자산 = Backend + Android

Kotlin core 15 concepts는 **언어 자체** 학습이라 platform 무관:
- val/var, null safety, data class, sealed class
- coroutines, Flow, suspend
- scope functions (let, run, apply, also, with)
- collections, lambdas, extension functions

→ Backend / Android 양쪽에 그대로 사용. 50% 효율 향상.

### TypeScript 자산 = Frontend + Backend (Node.js)

미래 추가 시 동일 패턴:
- TypeScript core (~15 concepts: types, generics, async/await, modules)
- React-only (~50)
- Node.js Backend-only (~50)
- → 두 트랙 신규 비용 65씩

### Python 자산 = Backend + ML/Data

- Python core (~15)
- Django/FastAPI Backend-only (~50)
- ML/Data-only (~50)

---

## 카테고리 확장 backlog (50 → 80, 트랙별 +30)

### Backend 트랙 80 시 추가될 30개 (잠정)

| 카테고리 | 추가 |
|---|---|
| Kotlin Basics | +4 (lambdas deep, 상속, infix/operator overloading, generic basics) |
| Kotlin Advanced | +4 (channels, Flow operators 심화, exception handling, coroutine testing) |
| Spring Core | +3 (lifecycle hooks, conditional config, custom annotations) |
| Spring Web | +4 (validation 심화, async controllers, WebFlux 입문, content negotiation) |
| Spring Data | +4 (JPA listener, soft delete, audit, optimistic locking) |
| Spring Security | +3 (OAuth2 server, role hierarchy, method security) |
| Database | +3 (lock 종류, partition, replication 기초) |
| Architecture | +3 (event-driven, CQRS basics, saga pattern) |
| Testing | +1 (testcontainers) |
| DevOps | +1 (CI/CD basics) |
| **Total** | **+30** |

### Swift 트랙 80 시 추가될 30개 (잠정 — Stage 1 데이터 기반 결정)

대기. Stage 1 데이터로 "사용자가 가장 자주 막힌 영역" 식별 후 결정.

---

## 마케팅 메시지 진화

| 시점 | Pitch | 신뢰도 |
|---|---|---|
| 1.0.x (현재) | "AI Swift Tutor (Socratic method)" | 1 트랙, niche |
| 1.2.0 (Cycle 3) | "Master Swift + Backend with AI dialogue" | 2 트랙, 100 concepts |
| 1.3.0 (Cycle 3.5) | "Multi-track AI tutor: Swift, Backend, Android" | 3 트랙, 165 concepts |
| 1.4.0 (Cycle 4) | "Master 240+ coding concepts across 3 tracks" | 3 트랙, 240 concepts |

각 단계 marketing 메시지 강화 → Show HN/Reddit 재 노출 가능.

---

## Decision principles

1. **CLI 스킬 검증 → 앱 port 순서 지킴**. CLI에서 community 만족 신호 없는 트랙은 앱 추가 X.
2. **Variation 활용 우선**. Kotlin → Backend + Android 같이 한 번 작성으로 두 시장 공략.
3. **50 concepts MVP, 80 후 깊이 확장**. 첫 출시는 50으로 빠르게, 데이터 보고 80으로.
4. **트랙 추가 시 모바일 UX 검증부터**. CLI 만족 ≠ 모바일 만족. 1-2주 retention 데이터 본다.
5. **트랙 간 streak/daily limit 통합**. 학습 습관이 핵심, 어느 트랙이든 학습 = 진도.

---

## Updated 2026-04-26
- Cycle 3 진행 중에 Tabber가 "Kotlin → Android 변형 cheap" 인사이트 제시 → 별도 문서화
- 50 → 80 확장은 Cycle 4로 보류 (현재는 50 + 트랙 다양화 우선)
