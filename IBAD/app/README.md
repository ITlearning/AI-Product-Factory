# 이번엔 안 돼

관계와 상황에 맞춰, 예의는 지키되 여지를 남기지 않는 거절 답장을 생성하는 웹앱입니다.

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

## 배포 동작 방식

- 정적 프론트엔드 출력: `dist/`
- 서버리스 함수: `api/generate-reply.js`
- 브라우저는 `/api/generate-reply`만 호출하고, OpenAI API 키는 서버에서만 사용합니다.

## 주의

- `OPENAI_API_KEY`가 없으면 API는 `500`을 반환합니다.
- 현재 MVP 지원 범위는 친구/지인 대상의 약속·부탁 거절입니다.
- 연인, 가족, 직장/상사, 후속 답장 시나리오는 현재 제한 응답으로 처리합니다.
