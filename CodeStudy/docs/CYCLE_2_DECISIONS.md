# Cycle 2 Decisions Log

작성일: 2026-04-25
범위: Cycle 2 implementation 세션 (학습 기록 인터랙티브 + 영어권 진출 + 인앱 설문 + Neon Postgres + TipKit)

이 문서는 Cycle 2 진행 중 내려진 **결정과 그 근거**를 기록. git log는 **무엇을 했는지**를, 이 문서는 **왜 그렇게 했는지** 보존.

---

## 1. 학습 기록 인터랙티브 (Cycle 2 핵심 기능)

### 결정
ProgressDashboardView의 잔디 아래 개념 리스트 → 탭 → 새 화면(`ConceptHistoryView`)에서 모든 학습 세션 + 대화 원본 회고.

### 근거
- Tabber 통찰: "듀오링고의 가장 큰 단점이 공부가 안 된다" → CodeStudy의 promise는 **기억에 남는 학습**
- 회고 기능이 그 promise를 직접 강화. 사용자가 "내가 어떻게 풀었는지" 다시 보면 인지 강화
- 새 schema 0개 (기존 ConceptProgress + StudySession.messages 재사용) — 인디 메이커 효율 사고

### 구현
- ConceptHistoryView (header + statsRow + session list)
- SessionRowView (날짜 + 대화 횟수 + duration + 첫 메시지 미리보기)
- SessionConversationView (MessageBubble 재사용, read-only)
- 진입: ProgressDashboardView의 NavigationLink

### Trade-off 인지
- 데이터 모델에 새 schema 안 만든 결과 → "마스터 안 된 개념의 progress indicator"는 별도 작업 필요 (TODOS.md TODO-6 deferred)
- 100+ 세션 누적 사용자에 대해 list 성능 검증 필요 (current data 부족, future)

---

## 2. 인앱 설문 정책 반전 (중간 변경)

### 처음 결정
신규 마스터자에게만 설문 노출 (기존 사용자는 OneTimeMigration으로 surveyShown=true 자동 설정).

### 변경된 결정
**모든 사용자(기존 + 신규)에게 다음 마스터리에서 설문 1회 노출.**

### 근거 (Tabber pushback)
> "이미 사용한 사람들한테도 받아야 해"

핵심 인사이트: **기존 활성 사용자가 demand discovery의 핵심 시그널**. 진짜 사용 경험 있는 사람들의 응답이 신규 사용자보다 가치 큼. 신규자만 모으면 표본 편향.

### 구현 변경
- `OneTimeMigration.applySurveySuppressionIfNeeded` 함수 + 호출부 제거
- enum은 키 컨테이너로 축소 (다른 마이그레이션 시 재사용 가능)

### 부수 변경
- 인센티브 추가 (진심 부탁 → 추첨 5명 × $5 스타벅스 쿠폰)
- 추첨 = 응답 수 무관 고정 비용 ($25 ceiling). 모두 지급보다 비용 통제 양호.

---

## 3. AppLanguage.systemDefault — 신규 사용자 자동 영어

### 결정
`UserProfile.init`의 `preferredLanguage` 기본값을 `.korean` → `.systemDefault` (디바이스 locale 기반).

### 근거
영어권 디바이스 사용자가 Onboarding부터 영어 경험 받아야 retention 높음. Show HN/Reddit으로 들어올 첫 영어권 사용자가 한글 보면 즉시 이탈.

### 한계
**기존 사용자(기 등록된 UserProfile)는 영향 받지 않음** — Tabber의 테스트 profile도 `.korean`으로 잠겨있어 디바이스 locale 영어로 바꿔도 한글 leak. 해결책: Settings → 언어 → English 명시 토글.

### 미적용 옵션
1.1.0 첫 실행 시 Locale.current 따라 기존 사용자도 마이그레이션 — 위험: 사용자가 한국어 명시 선택했는데 영어로 바뀌면 불만. Skip.

---

## 4. Prompt caching 비활성화 (예상 외 발견)

### 처음 plan
OpenRouter `cache_control: ephemeral` → Anthropic 5분 캐시 → TTFT 9초 → 3-4초

### 발견
배포 후 검증 결과 cache hit 0회 (`cached_tokens: 0`, `cache_write_tokens: 0`).

### 원인
**Claude Haiku 4.5의 캐시 최소 크기 = 2048 토큰**. 우리 시스템 prompt는 1100~1200 토큰. 임계값 미달 → cache_control 헤더 무시됨.

### 결정
Cache 시도 유지 (코드는 그대로) but 활성 안 됨 인지. Cycle 3에서 재평가:
- Sonnet 전환 (1024 임계값, 비용 3-5x ↑)
- 시스템 prompt 늘려 2048 넘기기 (artificial bloat = product 훼손)
- 비용 그대로 + cache 포기 (현재 수준)

현 비용 ~$3/month → cache 없어도 sustainable. **DAU 100+ 시점에 재평가**.

### 부수 발견
OpenRouter usage 객체에 cost 데이터 포함됨 (`cost_details.upstream_inference_cost`). 이걸 `codestudy_log.cost_usd` 컬럼에 저장 → per-request cost tracking 자동.

---

## 5. TipKit 이중 도입 (popoverTip + safeAreaInset)

### 결정
Cycle 2 신규 기능 안내를 두 군데에서:
- `ConceptHistoryTip` — ProgressDashboardView 캘린더 아래 inline TipView
- `HistoryTabTip` — DailyChallengeView 하단 safeAreaInset banner (탭바 위)

### 시도한 것 (실패)
처음에 `Tab` 자체에 `.popoverTip` attach 시도 → iOS 18 Tab API에서 modifier 미지원
다음 NavigationStack 내부에 attach → 컴파일 OK이지만 popover가 탭바 위 좁은 공간에 cramped → 탭바 시각적으로 가림

### 최종 결정
`safeAreaInset(edge: .bottom)` + 인라인 TipView가 위치/크기 100% 컨트롤 가능 + Apple 네이티브 패턴. popoverTip 포기.

### 학습
TipKit popoverTip은 자동 위치 결정이 강해 호스트 view 정확히 핀포인트 가리키기 어려움. 탭바 같이 화면 끝 fixed 영역에 가까이 두려면 safeAreaInset/inline 패턴이 더 안정적.

---

## 6. ConceptHistoryView 상단 클리핑 fix

### 증상
Tabber 시뮬레이터 테스트에서 화면 상단(세션 헤더 + 통계 카드 영역) 잘려 보임.

### 원인
View 본문에 concept title 헤더 + navigationTitle("학습 기록") **이중**. inset-grouped 첫 섹션에서 상단 패딩 충돌.

### 수정
- 본문 `header` 블록 삭제 (개념 title + 마스터 뱃지)
- 개념 title → `navigationTitle(conceptTitle)` (iOS 표준)
- 마스터 뱃지 → `toolbar(placement: .topBarTrailing)`
- 첫 섹션은 statsRow만 시작
- `.listSectionSpacing(.compact)` 적용 (Section 간격 좁힘)

### 학습
SwiftUI의 inset-grouped List에서 첫 섹션에 직접 큰 컨텐츠를 넣으면 nav bar와 상단 충돌 가능성. nav title을 우선 사용하는 게 iOS 네이티브 패턴.

---

## 7. App Privacy 선언 업데이트 (Apple 가이드 위반 수정)

### 문제
1.0.x에서 "Data Not Collected"로 신고. 그러나 Stage 1 console.log 도입 시점부터 Vercel logs로 데이터 흘러가고 있었음. Cycle 2 Neon Postgres 도입으로 명백한 "수집"이 됨.

### 위험
Apple App Privacy 가이드: **declared와 actual collection 일치해야 함**. mismatch는 reject 또는 사후 audit 메일 사유.

### 결정
1.1.0 심사 제출 전 App Store Connect "앱 개인정보 보호" 4 카테고리 추가:
1. 기타 사용자 콘텐츠 (대화 메시지)
2. 식별자 → 디바이스 ID (익명 UUID)
3. 제품 상호 작용 (마스터리/세션/스트릭)
4. 기타 진단 데이터 (latency, model, tokens)

모두: 신원 미연결, 추적 미사용, 목적 = 앱 기능 + 분석.

### 일관성 보장
3 source of truth:
1. PrivacyInfo.xcprivacy (Cycle 2에 추가)
2. PRIVACY.md / PRIVACY_EN.md (4조 익명 로그 명시)
3. App Store Connect 입력 (이번 Cycle 2 심사에서 변경)

---

## 8. Migration runner SQL parser bug

### 증상
첫 실행 시 `relation "codestudy_log" does not exist` 에러. CREATE INDEX 가 CREATE TABLE 전에 실행되는 것처럼 보임.

### 원인
Lane A agent의 migration runner가 `.split(';')` 후 `s.startsWith('--')`로 통째 필터. 첫 statement (CREATE TABLE)가 12줄 주석으로 시작 → 통째로 제거 → 3 statements만 남음.

### 수정
주석 라인 단위 제거 후 statement 검사:
```js
.map((s) =>
  s.split('\n').filter(line => !line.trim().startsWith('--')).join('\n').trim()
)
.filter(s => s.length > 0)
```

`IF NOT EXISTS` 덕분에 부분 실행 후 재실행 안전.

---

## 9. 듀오링고 벤치마킹 — 선별적

### 가져오기로 함 (retention mechanism)
- Streak + Freeze (Cycle 2 적용)
- 일일 학습 리듬 + 알림 (이미 있음)

### 가져오지 않기로 함 (product promise 충돌)
- 객관식 mass quiz — 소크라테스식과 정반대
- 거짓 게이미피케이션 ("축하해요!") — AI 슬롭, 신뢰 깎음
- 광고 모델 — 학습 앱 브랜드 훼손
- 3-heart fail penalty — 학습 압박, 결제 유도

### 진짜 영감 ref
- **Khanmigo (Khan Academy)**: 같은 소크라테스식. 답 안 주고 질문. 학습 깊이 모델 ref
- **GitHub Copilot Chat**: 코딩 + AI 대화. 우리와 다른 점 = 답 줘버림 (우리가 그 약점 공격)

---

## 10. Cycle 3 후보 — 검증 후 결정

Stage 1 demand discovery (~1-2주 데이터) 결과 따라 결정. 미리 확정 X.

### 후보 A — 면접 도우미 모드 (강력 후보)
- 학습 retention 약하면 outcome-focused로 pivot
- 코드 80% 재사용 (chat/mastery/history)
- Pro 구독 정당화 강함 (취업 = 명확한 outcome)

### 후보 B — 위젯 + 학습 깊이 확장
- 학습 retention 강하면 (D7 ≥ 25%) — 현재 product 강화

### 후보 C — Stage 1 결과별 hybrid
- 면접 도우미 = Pro tier
- 학습 = Free 그대로
- 양쪽 시장 동시 공략

### 명시적 reject (Cycle 3 안 함)
- 음성 면접관 — 비용 폭증 + QA 부담. 면접 도우미 텍스트 검증 후 (3-6개월 뒤)
- 다른 직군 확장 — curriculum 작성 cost ↑↑ + Tabber expertise iOS에 집중. iOS 면접 도우미 PMF 후
- 5분 모드 — product promise 모순 (Cycle 2에서 reject 결정 유지)

---

## 11. Cycle 2 Lessons Learned (operational)

### Multi-agent parallel execution 효과적
4 lane (B/C/D iOS + A Backend) 병렬 실행 → 1 hour 안에 모든 코드 작업 완료. 다만 의존성 관리 필수:
- Lane B (신규 파일) + Lane C (기존 수정) + Lane D (i18n) 명확 boundary
- Lane A (Backend) 완전 독립

### SourceKit cache lag = 정상 현상
다중 파일 동시 수정 시 SourceKit가 reindex 못 따라가서 false errors 발생. **xcodebuild 실제 결과**가 truth.

### Privacy 3-source consistency 매번 검증 필요
Code → manifest → policy → store input 4단 일치. Cycle별 변경 시 4곳 다 update.

### Test scheme 미설정
xcodebuild test 액션 미설정 상태. Xcode UI(⌘U)로만 테스트 실행 가능. 출시 후 fix 권장.

### 제출 전 Apple Privacy 재확인
1.0.x도 사실 부정확 declaration이었음을 Cycle 2에서 발견. 이후 cycle 시작 시 first todo로 "App Privacy 입력값 vs 실제 수집 일치 검증".

---

## 12. 참고 외부 자료

- TipKit: https://developer.apple.com/documentation/tipkit
- OpenRouter prompt caching: https://openrouter.ai/docs/features/prompt-caching
- Apple privacy manifest: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Anthropic prompt caching: https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
- TipKit Tab API limitation 검토: 다중 시도 끝에 `safeAreaInset` 패턴이 더 안정 (이 세션 finding)

---

## Updated 2026-04-25
- Cycle 2 implementation 종료, 1.1.0 App Store 심사 제출
- 다음 cycle 결정은 Stage 1 데이터 (1-2주) 후
