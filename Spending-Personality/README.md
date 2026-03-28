# 오늘의 소비 캐릭터

하루 소비 내역을 읽고 `오늘의 소비 캐릭터`를 보여주는 서비스의 MVP 앱 셸입니다.

이 디렉터리는 PRD 문서와 실행 가능한 웹앱 구조가 함께 공존하도록 구성했습니다.

## 현재 포함 범위

- 정적 웹앱 셸
- 소비 문장 파싱 및 캐릭터 결과 계약
- 샘플 입력 기반 캐릭터 미리보기 렌더링
- Vercel 기준 로컬 개발/배포 구조
- 기본 `verify` 스크립트
- 후속 task 를 위한 입력/결과 화면 자리잡기

## 로컬 실행

```bash
cd Spending-Personality
npm install
npm run dev
```

기본 로컬 주소:

```text
http://127.0.0.1:4173
```

메모:

- 이 브랜치가 아직 `main` 에 머지되지 않았다면, 로컬에서도 이 이슈 브랜치를 checkout 한 상태여야 합니다.
- 기존 `vercel dev` 전역 설치가 없어도 `npm run dev` 만으로 실행됩니다.

## 검증

```bash
cd Spending-Personality
npm run verify
```

## 배포 메모

Vercel 프로젝트 설정:

- Root Directory: `Spending-Personality`
- Framework Preset: `Other`
- Build Command: `npm run build`
- Output Directory: `dist`

Vercel bootstrap:

```bash
cd /path/to/AI-Product-Factory
node scripts/bootstrap-vercel-project.mjs --service-dir Spending-Personality
```

이 명령은 Vercel 프로젝트 생성/재사용, `Spending-Personality` 루트 디렉터리 설정, `npm run build` / `dist` 설정 동기화, 로컬 link 와 development settings pull 을 함께 처리합니다.

Production deploy:

```bash
cd /path/to/AI-Product-Factory
vercel deploy --prod --yes --scope itlearnings-projects
```

현재 기본 프로덕션 도메인 alias 는 `https://spending-personality.vercel.app` 입니다. 커스텀 도메인은 별도 설정이 필요합니다.

## 현재 셸 상태

- 소비 내역 입력 영역은 시각적 셸까지만 제공됩니다
- 샘플 소비 내역과 메모는 실제 캐릭터 생성 엔진에 연결되어 결과 카드를 렌더링합니다
- 결과 계약은 `success / needs-more-data / parse-failed` 상태를 검증합니다
- 다음 task 에서 실제 입력 상태와 버튼 동작을 이 계약에 연결하면 됩니다
