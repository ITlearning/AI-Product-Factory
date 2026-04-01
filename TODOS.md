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
