# 오늘의 소비 캐릭터

하루 소비 내역을 읽고 `오늘의 소비 캐릭터`를 보여주는 서비스의 MVP 앱 셸입니다.

이 디렉터리는 PRD 문서와 실행 가능한 웹앱 구조가 함께 공존하도록 구성했습니다.

## 현재 포함 범위

- 정적 웹앱 셸
- Vercel 기준 로컬 개발/배포 구조
- 기본 `verify` 스크립트
- 후속 task 를 위한 입력/결과 화면 자리잡기

## 로컬 실행

```bash
cd Spending-Personality
npm run dev
```

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

## 현재 셸 상태

- 소비 내역 입력 영역은 시각적 셸까지만 제공됩니다
- 실제 캐릭터 생성 로직은 아직 연결되지 않았습니다
- 결과 카드는 디자인 기준을 먼저 고정하기 위한 예시 화면입니다
