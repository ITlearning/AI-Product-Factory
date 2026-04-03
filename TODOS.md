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
