# TODOS

작업 중 발견된 TODO 목록. 현재 스프린트 범위 밖이거나 검증 후 결정할 항목들.

---

## [TODO-1] 카테고리별 출력 스키마 실험 (v2)

**What:** 카테고리별로 다른 출력 계약 검토 — 직군 외 카테고리(연인어, 일반어 등) 진입 시
4필드 인시던트 스키마(rewrittenMessage, termExplanations, context, caveat) 대신
`original / translated / why / punch` 등 다른 형태가 더 적합할 수 있음.

**Why:** 현재 스키마는 개발자 인시던트 도메인에서 진화한 형태라 직군 외 카테고리에서
의미가 어색해질 수 있음. MVP에서 확인하고 v2에서 분기.

**Pros:** 카테고리별 최적화된 UX, AI 출력 품질 향상.
**Cons:** API 분기 로직 추가, 테스트 복잡도 증가.
**Context:** plan-eng-review (2026-04-01) 시 Codex outside voice가 지적.
현재 MVP는 공통 스키마로 출시 후 실제 사용 패턴 확인.
`src/engine/schema.js`와 `api/translate.js`가 변경 대상.

**Depends on:** MVP 출시 + 릴스 반응 확인 후 결정.

---

## [TODO-2] 릴스 퍼널 attribution 정밀화

**What:** 릴스별 독립 UTM 파라미터 + 시간범위 기반 campaign attribution 로직 추가.

**Why:** 현재 UTM만으로는 여러 릴스가 동시에 활성화될 때 어떤 릴스에서
클릭이 발생했는지 측정이 어려움.

**Pros:** 카테고리별 ROI 측정, 다음 언어 카테고리 우선순위 결정에 데이터 근거 생김.
**Cons:** 릴스 제작 워크플로우에 UTM 관리 단계 추가.
**Context:** plan-eng-review (2026-04-01) 시 Codex outside voice가 지적.
성공 기준 "댓글 수 ≥ 첫 릴스"는 attribution이 정확해야 의미 있음.
바이오 링크 관리 방식과 함께 검토.

**Depends on:** 두 번째 카테고리 릴스 출시 전 구현 권장.

---

## [TODO-3] Date-Soragodong URL 파라미터 안정성 평가

**What:** 공유 URL에서 결과 값을 인덱스 기반으로 전환할지 검토.
현재: `/result?place=한강&food=편의점+픽닉&...` (값 문자열, encodeURIComponent)
대안: `/result?place=14&food=5&transport=7&budget=1` (카드 배열 인덱스)

**Why:** v1.1에서 카드 데이터를 추가/수정하면 인덱스가 밀려 기존 공유 링크가 다른 결과를 보여줄 수 있음. 값 문자열 방식은 카드 추가/수정에 강하지만 URL이 길어짐. 인덱스 방식은 짧지만 카드 순서 변경에 취약.

**Pros (인덱스 전환):** 짧은 URL, 카카오 링크 미리보기 URL이 더 깔끔.
**Cons (인덱스 전환):** 카드 순서가 깨지면 공유 링크 의미 변경, 마이그레이션 필요.
**Context:** plan-eng-review (2026-04-02) 외부 관점 지적. MVP는 값 문자열로 출시.
v1.1 카드 데이터 변경 전에 URL 전략 결정 권장.

**Depends on:** Date-Soragodong MVP 배포 후, 첫 카드 데이터 변경 요구사항 발생 전.

---

## [TODO-4] Date-Soragodong: NotoSansKR 서브셋 폰트 번들

**What:** OG 이미지 생성에 필요한 Noto Sans KR 서브셋 TTF 파일을 `api/fonts/NotoSansKR-subset.ttf`에 배치.

**Why:** Satori(OG 이미지 렌더러)는 시스템 폰트/Google Fonts에 접근 불가. 폰트가 없으면 `/api/og`가 500을 반환하고 카카오/iMessage 미리보기 이미지가 깨짐. 랜딩 및 결과 페이지 자체는 정상 동작.

**How:** Noto Sans KR 서브셋(한글 기본자모 + ASCII) TTF를 생성하거나 다운로드 후 `Date-Soragodong/api/fonts/NotoSansKR-subset.ttf`에 커밋.
참고: `pyftsubset` (fonttools) 또는 [Google Fonts subset helper](https://fonts.google.com) 사용.

**Depends on:** Vercel 프로젝트 연결 전 완료 권장.

---

## [TODO-5] Date-Soragodong: 다시 뽑기 필터 상태 보존

**What:** 결과 페이지의 "다시 뽑기"가 메인 페이지에서 선택한 필터를 무시하고 전체 풀에서 뽑는 현상.

**Why:** 결과 URL(`/result?place=...`)에 필터 선택 정보가 포함되지 않음. `redrawCourse(course)` 호출 시 `filters` 인자가 없어 전체 카드에서 재추첨됨. 사용자가 "카페만" 선택했어도 다시 뽑기하면 다른 장소가 나올 수 있음.

**Options:**
- URL에 필터 파라미터 추가 (`?placeFilter=카페,공원&...`)
- 세션 스토리지에 필터 상태 저장
- 현재 동작을 "필터 없는 확장 재추첨"으로 명시 (의도적 기능으로 문서화)

**Context:** adversarial review (2026-04-03) Finding 10. MVP는 현재 동작으로 출시. 사용자 피드백 후 결정.

**Depends on:** MVP 출시 후 사용자 피드백 수집.

---

## [TODO-6] CodeStudy: 마스터 안 된 개념의 progress indicator

**What:** ProgressDashboardView 또는 ConceptHistoryView에서 "마스터하려면 N회 더 학습"같은 progress indicator 추가.

**Why:** 현재 사용자는 "내가 어떻게 마스터하지?" 답을 못 얻음. 마스터 기준이 불투명해서 학습 동기가 떨어질 수 있음. 듀오링고가 강력한 이유 중 하나가 progression visibility.

**Pros:** 학습 동기 강화, "다음 목표" 명확화, retention 기여.
**Cons:** 마스터 기준이 동적(품질 + 양)이라 단순 카운터로 표현 어려움. 사용자 기대 관리 신중 필요.
**Context:** plan-design-review (2026-04-25) Cycle 2 unresolved decision U1. Cycle 2 stage 1 데이터 수집 후 결정.

**Depends on:** 마스터 기준의 user-facing 표현 방식 결정.

---

## [TODO-7] CodeStudy: SettingsView에 freeze 사용 이력 섹션

**What:** SettingsView에 현재 freeze 잔여 개수 + 최근 사용 이력 표시.

**Why:** Cycle 2에 streak freeze 기능 추가했는데 사용자가 "내 freeze 몇 개 남았지?" "언제 썼지?" 확인할 곳이 없음. 토스트만으로는 신뢰감 부족. 듀오링고는 streak 화면에 freeze 표시.

**Pros:** 투명성 ↑, 사용자가 freeze 시스템 이해 → 행동 변화. 신뢰 build.
**Cons:** SettingsView UI 변경. freeze 발급/사용 로그 데이터 모델 필요.
**Context:** plan-design-review (2026-04-25) Cycle 2 unresolved decision U2. Cycle 2는 freeze 자동 적용만 포함, 이력 화면은 deferred.

**Depends on:** Cycle 2 streak freeze 안정 운영 확인.

---

## [TODO-9] 청년월세 체커: 다른 기기 결과 보기 (이메일 매직링크)

**What:** 결과 페이지 cookie-bound 정책으로 다른 기기 접근 차단. v2에서 이메일 매직링크로 다른 기기 접근 가능하게.

**Why:** v1은 같은 기기/브라우저에서만 결과 재방문 가능. 사용자가 회사에서 봤다가 집에서 다시 보고 싶을 때 못 봄. 이메일 옵트인 폼은 v1에 이미 있으니, v2에서 그 이메일로 매직링크 발송 → 다른 기기 접근.

**Pros:** 사용자 retention ↑. "결과 잃어버림" 불만 해소.
**Cons:** 이메일 SMTP/SES 셋업, 매직링크 토큰 보안 (TTL, single-use). DB 스키마 추가.
**Context:** plan-eng-review (2026-04-30) Issue 1A 결정. cookie-bound가 P3 차별점에 정합한데, 다른 기기 접근 가치도 무시 못 함. v2에서 매직링크로 균형.

**Depends on:** v1 출시 후 사용자 피드백 ("다른 기기에서 못 봐요" 빈도).

---

## [TODO-10] 청년월세 체커: 카카오 SDK 직접 공유

**What:** v1 "친구에게도 공유하기"는 Web Share API + URL 복사. v1.5에서 Kakao JavaScript SDK로 카톡 공유 시 머리이미지+제목+설명 카드 포함.

**Why:** 한국 트래픽의 절반 이상이 카톡 공유 → URL만 보내는 것보다 카드 형태가 클릭률 5~10배. 카톡에서 OG 이미지가 미리보기로 안 뜨는 경우(SPA + first-load) 직접 SDK가 안전.

**Pros:** 공유 클릭률 ↑. 카톡 첫인상 개선.
**Cons:** Kakao 디벨로퍼스 앱 등록 + 도메인 검증. SDK 번들 ~30KB 추가.
**Context:** plan-eng-review (2026-04-30) NOT in scope. 5/5 데드라인에 우선순위 낮음.

**Depends on:** v1 출시 + 카톡 공유 비중 측정.

---

## [TODO-11] 청년월세 체커: 다른 공공 프로그램 확장성 hook 검증

**What:** P2 "platform seed" 가설 = JSON 데이터 + TypeScript evaluator 한 쌍 추가로 다른 프로그램 추가 가능. 실제 검증 = 청년도약계좌 또는 행복주택 또는 국토부 한시지원 새 차수 공고 올라왔을 때 1주 안에 추가 가능한지 측정.

**Why:** office-hours에서 platform 가설을 wedge로 깎았지만, hook은 살림. 그 hook이 진짜 살아있는지 확인하지 않으면 platform 미신.

**Pros:** Platform seed 가설 검증/기각. Tabber의 "공공정보 파서" 비전 진위 확인.
**Cons:** v1 트래픽 결과에 따라 우선순위 결정. 트래픽 X면 platform 시험도 의미 X.

**Context:** office-hours (2026-04-30) Q1 demand reality에서 솔직하게 platform 가설 후퇴. P2 premise = "확장성 hooks만, 다른 프로그램은 v2." plan-eng-review (2026-04-30) Issue 1B에서 JSON + TS evaluator 한 쌍 패턴 채택.

**Depends on:** v1 출시 후 트래픽 1만+ 도달 + 다음 공공 프로그램 공고 release.

---

## [TODO-8] CodeStudy: ConceptHistoryView "학습 계속하기" CTA

**What:** ConceptHistoryView 하단에 "이 개념 다시 학습" 또는 "관련 개념 학습" CTA 버튼 추가.

**Why:** 사용자가 history 보다가 "지금 또 학습하고 싶다"는 동기 발생 — 현재는 뒤로 가서 메인 탭에서 다시 시작해야 해서 마찰. CTA가 그 자리에서 학습 진입 가능하게 함.

**Pros:** session count ↑, "기억하고 또 학습" loop 강화. Product promise 직접 강화.
**Cons:** 학습 진입 트리거 로직 추가. 마스터한 개념 재학습 시 mastery 재계산 정책 결정 필요.
**Context:** plan-design-review (2026-04-25) Cycle 2 unresolved decision U4. 핵심 화면 신규라 우선 read-only로 출시.

**Depends on:** Cycle 2 ConceptHistoryView 출시 + retention 데이터.
