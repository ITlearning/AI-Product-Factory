# CodeStudy Happy Path QA 시나리오

ios-simulator-mcp가 등록된 Claude Code 세션에서 사용. `scripts/qa-happy-path.sh` 실행으로 시뮬레이터 부팅 + 앱 설치까지 끝낸 상태에서 호출한다.

## 사전 조건

- 시뮬레이터 부팅됨 (UDID는 호출 시 전달)
- `com.itlearning.codestudy` 앱 설치됨
- ios-simulator-mcp MCP 서버 등록됨 (`claude mcp list`로 확인)

## 시나리오 — 한국어 사용자 첫 학습 세션

### Step 1. 앱 실행 + 첫 화면 검증
1. `xcrun simctl launch <UDID> com.itlearning.codestudy` 또는 MCP `mobile_launch_app`로 실행
2. 스크린샷 캡처
3. 검증: 홈 화면(개념 카드 목록)이 보여야 함. 화면이 한국어인지 확인

**실패 조건**: 빈 화면, crash, 앱이 완료/온보딩에서 멈춤

### Step 2. 온보딩 처리 (필요 시)
- 첫 실행이면 onboarding이 뜸 → "Swift", "초급" 등 합리적 default로 진행
- 이미 온보딩 완료 상태면 skip

### Step 3. 학습 세션 시작
1. 홈에서 첫 번째 학습 가능한 개념 카드 탭
2. 채팅 화면 진입 확인
3. AI가 첫 번째 메시지(initial message) 보내는지 대기 (최대 30초)
4. 검증: assistant 메시지가 한국어로 표시되어야 함

**실패 조건**: 30초 내 응답 없음, 영어로 응답, 에러 alert

### Step 4. 액션 버튼 동작
1. "더 쉽게" 버튼 탭
2. 사용자 메시지 버블에 "좀 더 쉽게 설명해주세요"가 한국어로 들어가는지 확인
3. AI 응답 받을 때까지 대기
4. "힌트" 버튼 탭 → 동일한 검증

**실패 조건**: 버튼 비활성화, 사용자 메시지가 한국어가 아님 (영어 등 다른 언어로 나옴)

### Step 5. 메시지 전송
1. 텍스트 필드에 "이해했어요" 입력
2. 전송 버튼 탭
3. AI 응답 받기

### Step 6. 세션 수동 완료
1. 화면 우상단 X 버튼 또는 "학습 종료" 탭
2. confirm dialog가 뜨면 "학습 완료" 선택
3. SessionCompleteView 진입 확인
4. "홈으로" 버튼으로 복귀

### Step 7. 진행 상황 반영 검증
1. 홈 화면에서 방금 학습한 개념 카드의 상태가 "학습됨" 또는 마스터 표시로 바뀌었는지 확인
2. 스트릭/일일 학습 카운트가 +1 됐는지 확인 (Settings 또는 홈 상단)

## 영어 사용자 시나리오 (선택적)

위 시나리오를 한 번 끝낸 뒤:

1. Settings 탭 → Language를 **English**로 변경
2. 새 학습 세션 시작
3. AI 첫 메시지가 **영어로** 오는지 확인
4. "Simpler" 버튼 탭 → 사용자 메시지 버블에 `"Could you explain that more simply?"`가 들어가는지 확인 (이게 PR #28의 fix 검증 포인트)
5. AI 응답이 영어로 오는지 확인

## 결과 보고 형식

QA 끝나면 아래 형식으로 보고:

```
## Happy Path QA 결과

- [✅/❌] Step 1. 첫 화면
- [✅/❌] Step 2. 온보딩
- [✅/❌] Step 3. 세션 시작 + initial message
- [✅/❌] Step 4. 액션 버튼 (한국어)
- [✅/❌] Step 5. 메시지 전송
- [✅/❌] Step 6. 세션 완료
- [✅/❌] Step 7. 진행 반영
- [✅/❌] (선택) 영어 액션 버튼

## 발견된 이슈
- (있다면 스크린샷 + 재현 절차)
```

## 주의

- 실제 AI 호출이 일어나므로 비용 발생 (Claude Haiku, 세션당 수 센트)
- 한 happy path 세션은 5~10분 소요
- 백엔드 서버 다운이면 모든 step fail → 그건 별개 인프라 이슈
