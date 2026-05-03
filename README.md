# AI-Product-Factory

작은 AI 제품·서비스 실험들을 모아둔 모노레포다. 각 서비스는 독립 디렉터리에 위치하며, 공통 운영 규칙은 [`docs/process/`](docs/process/)에 정의되어 있다.

이 저장소는 [Claude Code](https://claude.com/claude-code) 기반 6단계 프로세스 시퀀스로 운영된다.

---

## Services

| 경로 | 설명 | 상태 |
|------|------|------|
| [`IBAD/app`](IBAD/app) | 한국어 거절 메시지 웹 앱 | active |
| [`Translate-Developer`](Translate-Developer) | 개발자 언어 → 일반 한국어 번역 웹 앱 | active |
| [`Spending-Personality`](Spending-Personality) | 소비 성격 진단 웹 앱 | active |
| [`Date-Soragodong`](Date-Soragodong) | 커플 데이트 코스 뽑기 웹 앱 | active |
| [`CodeStudy/iOS`](CodeStudy/iOS) | 코드 학습 iOS 앱 (CodeStudy) | active (1.2.1 출시) |
| [`Seoul-Youth-Rent-Checker`](Seoul-Youth-Rent-Checker) | 서울 청년월세지원 자격 체커 v0.1 | active |
| `UGGK` | 초기 단계 (디렉토리 미생성) | spec-first |

각 서비스는 독립 `package.json`/빌드 파이프라인을 가지며, 다른 서비스의 코드를 import하지 않는다 (cross-cutting 명시 시에만 예외).

---

## Process (작업 시작 방법)

새 PRD나 기능을 시작할 때는 [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md)의 6단계를 따른다.

```text
[1] INTAKE → [2] DISCOVERY → [3] PRD DRAFT → [4] PARALLEL REVIEW → [5] DECOMPOSITION → [6] EXECUTION
```

- 입구는 1줄 아이디어 또는 1쪽 brief 두 가지를 모두 받는다 ([`INTAKE.md`](docs/process/INTAKE.md))
- 단계마다 Tabber 승인 ([1] INTAKE는 자동 분기 + 신호 충돌 시 1회 확인)
- [4] PARALLEL REVIEW에서 3 에이전트 동시 리뷰 (CEO / Eng / Design)
- [6] EXECUTION에서 독립 PR을 멀티 에이전트 병렬로 dispatch + 각 PR 안에서 ralph loop

상세는 [`docs/process/CHARTER.md`](docs/process/CHARTER.md) Execution Contract를 본다. 다른 프로젝트 시드용으로 [`docs/process/COMMON.md`](docs/process/COMMON.md)를 가져갈 수 있다.

---

## Verification

서비스 변경 시 검증 명령:

| 서비스 | 명령 |
|--------|------|
| [`IBAD/app`](IBAD/app) | `cd IBAD/app && npm run verify` |
| [`Translate-Developer`](Translate-Developer) | `cd Translate-Developer && npm run verify` |
| [`Spending-Personality`](Spending-Personality) | `cd Spending-Personality && npm run verify` |
| [`Date-Soragodong`](Date-Soragodong) | `cd Date-Soragodong && npm run verify` |
| [`CodeStudy/iOS`](CodeStudy/iOS) | Xcode build (서비스 README 참고) |
| [`Seoul-Youth-Rent-Checker`](Seoul-Youth-Rent-Checker) | `cd Seoul-Youth-Rent-Checker && npm run verify` |
| docs/planning 파일만 변경 | [`docs/process/DOC_LINT.md`](docs/process/DOC_LINT.md) 수동 체크리스트 |

`main`에 직접 커밋하지 않는다. 브랜치에서 작업 후 PR로 handoff 한다.

---

## Documentation

| 영역 | 문서 |
|------|------|
| 에이전트 진입점 / 라우팅 | [`AGENTS.md`](AGENTS.md) |
| 기술 아키텍처 | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| 프로세스 헌장 + 실행 경로 | [`docs/process/CHARTER.md`](docs/process/CHARTER.md) |
| 6단계 시퀀스 본문 | [`docs/process/SEQUENCE.md`](docs/process/SEQUENCE.md) |
| PRD 11필드 양식 | [`docs/process/PRD_TEMPLATE.md`](docs/process/PRD_TEMPLATE.md) |
| 계획 관리 규칙 | [`docs/PLANS.md`](docs/PLANS.md) |
| 리뷰 점수 참고값 | [`docs/QUALITY_SCORE.md`](docs/QUALITY_SCORE.md) |
| 신뢰성 기준 | [`docs/RELIABILITY.md`](docs/RELIABILITY.md) |
| 보안 기준 | [`docs/SECURITY.md`](docs/SECURITY.md) |
| 제품 감각 가이드 | [`docs/PRODUCT_SENSE.md`](docs/PRODUCT_SENSE.md) |

---

## CodeRabbit

PR 자동 리뷰가 [`.coderabbit.yaml`](.coderabbit.yaml)로 설정되어 있다.

- 모든 PR / 후속 커밋 자동 리뷰
- 한국어로 응답
- 생성된 `dist/**` 출력은 리뷰 대상에서 제외
- 초기 리뷰 프로필은 `chill`

---

## Conventions

- PR 제목/본문, 커밋 메시지는 기본적으로 **한국어**로 작성한다 (이슈에서 영어를 명시적으로 요구한 경우에만 영어).
- 토큰 / API 키 / 자격증명을 리포에 저장하지 않는다.
- `origin`은 SSH 또는 credential helper 기반 remote를 사용한다.
- 새 서비스를 추가하면 이 README와 [`AGENTS.md`](AGENTS.md) Source of Truth 표를 같이 갱신한다.
