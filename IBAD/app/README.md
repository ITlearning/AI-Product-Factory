# 이번엔 안 돼

상대 메시지를 받고도 답장을 못 보내는 사람을 위해,
지금 바로 보낼 첫 거절문 1개를 추천하고 대안 2개를 함께 보여주는 웹앱입니다.

## Vercel 배포

이 앱은 `IBAD/app` 디렉터리를 기준으로 배포합니다.

### 1. Git 리포지토리를 Vercel에 연결하는 경우

Vercel 프로젝트 설정에서 아래처럼 맞추면 됩니다.

- Root Directory: `IBAD/app`
- Framework Preset: `Other`
- Build Command: `npm run build`
- Output Directory: `dist`

`vercel.json`에 `outputDirectory`가 이미 설정되어 있어서, 보통 Output Directory는 자동으로 잡힙니다.

### 2. 로컬에서 바로 배포하는 경우

```bash
cd IBAD/app
npx vercel
```

프로덕션 배포는 아래 명령을 사용합니다.

```bash
cd IBAD/app
npx vercel --prod
```

## 환경 변수

필수:

- `OPENAI_API_KEY`

선택:

- `OPENAI_MODEL`
  - 기본값: `gpt-4.1-mini`

## 로컬 확인

```bash
cd IBAD/app
npm install
npm run verify
```

Vercel 로컬 서버:

```bash
cd IBAD/app
npx vercel dev
```

## 현재 MVP 입력/출력

입력:

- 받은 메시지 또는 지금 상황 설명
- 요청 타입 선택: `약속` / `부탁`
- 막히는 이유 선택:
  - `미안해서 시작이 안 돼요`
  - `너무 차갑게 보일까 걱정돼요`
  - `말이 길어질까 봐 걱정돼요`

출력:

- 추천 시작 문장 1개
- 대안 2개
- 짧은 가이드 메모 1개
- 피해야 할 표현 1개

모든 결과는 바로 복사해서 보낼 수 있는 짧은 답장 형태로 제공됩니다.

## 배포 동작 방식

- 정적 프론트엔드 출력: `dist/`
- 서버리스 함수: `api/generate-reply.js`
- 브라우저는 `/api/generate-reply`만 호출하고, OpenAI API 키는 서버에서만 사용합니다.
- 추천 톤과 가이드 메모는 `blockerType`에 따라 제품 로직에서 고정합니다.

## 주의

- `OPENAI_API_KEY`가 없으면 API는 `500`을 반환합니다.
- 현재 MVP 지원 범위는 친구/지인 대상의 `약속` / `부탁` 거절입니다.
- 추천 구조는 `첫 거절문 추천 + 대안 2개`에 맞춰 고정되어 있습니다.
- 연인, 가족, 직장/상사, 애매한 호감 정리, 반복적으로 들이대는 연락, 후속 답장 시나리오는 현재 제한 응답으로 처리합니다.
