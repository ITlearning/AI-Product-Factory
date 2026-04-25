# CodeStudy In-App Survey (Cycle 2 / Stage 1)

마스터리 직후 노출되는 demand discovery용 설문. Google Forms 기반.

- **목적**: "누가 왜 CodeStudy를 쓰는지" 1줄로 답할 수 있는 데이터 확보
- **노출 시점**: 사용자가 개념 마스터 후 SessionCompleteView 닫는 순간 (UserDefaults `surveyShown` flag로 1회만)
- **타겟 응답 수**: 5-10건 (Stage 1 success criteria)
- **인센티브**: 추첨 5명 × 스타벅스 5,000원 쿠폰 (총 25,000원, 응답 수와 무관)

---

## Google Forms 설정

### Form Title
```
CodeStudy 사용 경험 짧은 의견
```

### Form Description
```
마스터를 축하드려요! 🎉

더 나은 학습 앱 만들고 싶어서 의견을 듣고 있어요.
1-2분만 시간 내주시면 정말 큰 도움이 됩니다.

✨ 응답해주신 분 중 추첨을 통해 5분께 스타벅스 5,000원 쿠폰을 보내드려요 ☕️
   (이메일 남겨주신 분 한정, Stage 1 종료 후 일주일 내 발송)

— Tabber
```

---

## 질문 (8개: 필수 5 + 선택 3)

### Q1. 직업/학습 상태는 어디에 가까우세요? *

**Type:** Multiple choice (single) — **Required**

- 현직 iOS/Swift 개발자
- 현직 다른 언어/플랫폼 개발자
- 부트캠프 또는 학원 학생
- 컴퓨터공학/전공 대학생
- 비전공자, 독학 중
- 기타

---

### Q2. CodeStudy를 어디서 처음 알게 되셨어요? *

**Type:** Multiple choice (single) — **Required**

- 카카오톡 단톡방
- GeekNews
- Disquiet
- 스레드(Threads)
- App Store 검색
- 친구/지인 추천
- 기타

---

### Q3. 지금까지 학습 경험은 어떠셨나요? *

**Type:** Linear scale 1-5 — **Required**

- 1: 별로
- 5: 아주 좋음

---

### Q4. 한 달 후에도 CodeStudy를 쓰고 있을 것 같으세요? *

**Type:** Multiple choice (single) — **Required**

- 네, 매일 또는 거의 매일
- 가끔 (주 2~3회 정도)
- 가끔이라도 쓸 것 같아요 (월 몇 번)
- 잘 모르겠어요
- 아마 안 쓸 것 같아요

---

### Q5. 가장 도움이 됐던 부분이 뭐예요? *

**Type:** Short answer — **Required**

Placeholder: `한 줄이면 충분해요`

---

### Q6. 가장 아쉬웠던 부분이 있다면? (선택)

**Type:** Paragraph (long answer) — Optional

Placeholder: `솔직하게 적어주시면 다 반영할게요`

---

### Q7. 추가됐으면 하는 기능이 있으세요? (선택)

**Type:** Paragraph (long answer) — Optional

---

### Q8. 이메일 주소를 남겨주세요 (선택)

**Type:** Short answer (Email validation 켜기) — Optional

설명 텍스트:
```
스타벅스 쿠폰 추첨 + 가능하시면 15분 사용자 인터뷰 요청드릴 수도 있어요.
이메일은 쿠폰 발송과 인터뷰 외에는 사용하지 않습니다.
```

---

## 설계 근거

**왜 이 순서?**
- 가벼운 객관식부터 → 마지막에 long-form
- Q1-Q2는 *funnel attribution* (어디서 오는지 측정 → 채널 ROI)
- Q3-Q4는 *retention signal* (만족도 vs 의향 비교 → "재밌다고 했는데 안 쓸 것 같다"는 의외 답변이 인사이트)
- Q5는 *value prop discovery* (사용자 본인 입으로 product promise 검증)
- Q6-Q7은 *roadmap input* (선택, drop-off 허용)
- Q8은 *interview pipeline* (가장 큰 보상 — 진짜 사용자 1명과의 15분 대화 >> 100명 설문)

**왜 추첨?**
- 모두에게 지급: 응답 30명이면 15만 원, 100명이면 50만 원 — 비용 통제 어려움
- 추첨 5명: 응답 수 무관 25,000원 고정 → 예산 안정
- 응답 quality 측면에서도 "쿠폰 받으려고 대충"이 줄어듦 (어차피 추첨이라)

---

## Google Forms 설정 팁

### 1. 응답 수집
- **Responses** 탭 → **Link to Sheets** → 새 스프레드시트 자동 생성
- 모든 응답이 sheet에 누적 (시계열 분석 가능)

### 2. 진행률 표시
- **Settings** → **Presentation** → **Show progress bar** ON
  - "1-2분" 약속 신뢰감 ↑

### 3. 한 번만 응답 (로그인 강제 X)
- **Settings** → **Responses** → **Limit to 1 response** OFF
  - 익명 유지가 더 중요. 우리 앱이 UserDefaults `surveyShown`로 1회 제한 (이중 보호)

### 4. URL 가져와서 앱에 연결
- 우상단 **Send** → 링크 아이콘 → URL 복사
- 형식: `https://docs.google.com/forms/d/e/1FAIpQLSe.../viewform`
- iOS 코드: `Views/Chat/SessionCompleteView.swift`의 `static let googleFormsURL` 자리에 붙여넣기

### 5. (선택) anonymousID 자동 첨부
- Form 만들고 **Get pre-filled link** → entry ID 확인
- iOS에서 URL에 `?entry.123456789={anonymousID}` 추가 가능
- 분석 시 같은 user의 다른 행동(로그)와 매칭 가능 (여전히 누가 누군지는 모름)
- 안 해도 OK — 익명 응답만으로도 패턴 보임

---

## 운영 워크플로우

### 응답 수집 단계 (Cycle 2 Stage 1)
1. Google Forms 만들고 URL을 `SessionCompleteView.googleFormsURL`에 붙여넣기
2. 1.1.0 빌드 + 심사 통과 후 응답 누적 시작
3. Sheet에 응답 5건 모이면 Tabber가 직접 읽고 "누가 왜 쓰는지" 1줄로 정리

### 추첨 단계 (Stage 1 종료 시)
1. Tabber가 유효 응답 필터링 (Q5 또는 Q6, Q7 중 최소 1개 의미있게 작성)
2. 무효 응답 제외 후 이메일 남긴 사용자 풀에서 5명 무작위 추첨
   - Sheet에서 `=INDEX(이메일범위, RANDBETWEEN(1, COUNTA(이메일범위)))` 또는 random.org 사용
3. 카카오톡 선물하기 또는 기프티스타에서 일괄 발송 (스타벅스 5,000원 × 5)
4. 추첨자에게 결과 메일 발송 (선택)

### 무효 응답 기준
- Q5에 "ㅋㅋ", "...", "없음" 등 1단어
- 명백히 봇/장난 응답
- 같은 이메일로 여러 응답 (UserDefaults 우회 가능성)

### 종료 시점
- "누가 왜 쓰는지" 1줄로 답 나오면 (목표 5-10건)
- Tabber 판단으로 Google Forms를 "응답 받지 않음" 상태로 변경
- iOS 앱은 surveyShown 사용자에게 다시 안 띄우니 추가 작업 불필요

---

## SurveyModalView 인트로 카피 (앱 내)

`Views/Onboarding/SurveyModalView.swift` 또는 design doc의 인트로 카피를 다음으로 업데이트:

```
이 개념 마스터한 거 자랑스러워요!
1-2분만 의견 들려주시면 추첨으로 스타벅스 쿠폰 보내드려요 ☕️
더 나은 앱 만들고 싶어서요.

       [응답하기]
       (우상단 X)
```

String Catalog 키 (i18n 대응):
- `survey.intro.heading`: "이 개념 마스터한 거 자랑스러워요!"
- `survey.intro.body.line1`: "1-2분만 의견 들려주시면 추첨으로 스타벅스 쿠폰 보내드려요 ☕️"
- `survey.intro.body.line2`: "더 나은 앱 만들고 싶어서요."

영문 번역 (Lane D 추가 시):
- `survey.intro.heading` (en): "Proud you mastered this concept!"
- `survey.intro.body.line1` (en): "Share 1-2 minutes of feedback for a chance to win a Starbucks gift card ☕️"
- `survey.intro.body.line2` (en): "I want to build a better app."

---

## 비용 예측

| 시나리오 | 응답 수 | 추첨자 | 비용 |
|---------|---------|--------|------|
| 보수 (Stage 1 최소 목표) | 5-10 | 5 | 25,000원 |
| 중간 (확장 시) | 30 | 5 | 25,000원 |
| 적극 (영어권 진출 + Show HN 효과) | 100+ | 5 | 25,000원 |

추첨 방식 = 응답 수 무관 고정 비용. 안전.

---

## Updated 2026-04-25
- Cycle 2 Plan에 따른 demand discovery survey 설계
- 추첨 인센티브 결정 (Tabber 결정, 비용 통제 + 동기부여 양립)
