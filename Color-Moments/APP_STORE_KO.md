# 몽돌 — App Store Connect 한국어 메타데이터 (1.0.0)

App Store Connect 첫 제출용. 각 칸의 글자 제한을 적어 두었고 그대로 붙여 넣으면 된다.
작성 2026-10-03 · 기준 빌드 1.0.0 (2) · 미리보기 6장은 [`docs/designs/mongdol-appstore-screens.md`](../docs/designs/mongdol-appstore-screens.md).

톤: 해요체, 짧게. 앱의 다섯 제약(색 안 보여 줌 · 격자/스트릭 없음 · 재촉 없음 · 판단 없음 · 결과 공유 권유 없음)을 문구도 지킨다.

---

## 앱 정보 (모든 버전 공통)

### 이름 (30자) — 이미 입력됨

```
몽돌
```

### 부제 (30자)

```
순간의 색이 하루의 조약돌로
```

15자. 미리보기 1장 큰 문구와 같은 말이라 검색 결과에서 이름 → 부제 → 첫 장이 한 문장으로 읽힌다.
다른 안: `찍어 두면, 하루가 조약돌이 돼요` (18자).

### 카테고리

- **기본**: 라이프스타일
- **추가**: 사진 및 비디오

### 콘텐츠 권한

**아니요** — 타사 콘텐츠를 포함·표시·접근하지 않는다. 지도(MapKit)와 날씨(WeatherKit)는 Apple 프레임워크이고 출처 표시(Apple 날씨 마크 + 법적 고지 링크)를 사진 보기에 둔다(`Shared/Day/DayPhotoView.swift`). 번들 글꼴은 SIL OFL.

### 연령 등급 — 설문 전부 「없음 / 아니요」 → 4+

| 묶음 | 답 | 이유 |
|---|---|---|
| 앱 내 제어 (유해 콘텐츠 차단, 나이 확인) | 없음 | 그런 기능이 없다 |
| 제공 기능 — 제한되지 않은 웹 액세스 | 아니요 | 웹 보기 없음 |
| 제공 기능 — 사용자 생성 콘텐츠 | 아니요 | 사진은 본인 기기·본인 iCloud 에만 있고 다른 사용자에게 보이지 않는다 |
| 제공 기능 — 소셜 미디어 · 메시지 및 채팅 · 광고 | 아니요 | 없음 |
| 성적 테마 · 의료/건강 · 성적인 내용 · 폭력 · 우연에 기반한 활동 | 없음 | 없음 |

### 앱 암호화

Info.plist 에 `ITSAppUsesNonExemptEncryption = NO` 가 들어가 있다(커밋 `4261437`). 올릴 문서 없음.

### 사용권 계약

Apple 표준 사용권 계약 그대로.

---

## 버전 정보 (1.0.0)

> ⚠️ **버전 번호 확인**: 지금 App Store 버전이 「1.0」, 빌드는 `1.0.0` 이다. 빌드를 고를 때 안 보이면 App Store 버전 번호를 `1.0.0` 으로 바꾼다.

### 프로모션 텍스트 (170자) — 심사 없이 언제든 바꿀 수 있는 칸

```
이쁜 순간을 찍고, 하루가 끝나면 그날 담은 색들이 조약돌 하나로 와요.
잠금화면에서도, 늘 쓰던 카메라로도 지나가는 순간을 몽돌과 함께 붙잡아 보세요.
```

85자 (Tabber 최종, 2026-10-03).

### 설명 (4000자)

```
이쁜 순간을 찍고, 하루가 끝나면 그날 담은 색들이 조약돌 하나로 와요.
잠금화면에서도, 늘 쓰던 카메라로도 지나가는 순간을 몽돌과 함께 붙잡아 보세요.

몽돌은 지나가다 눈에 걸린 순간을 붙잡고 기억하는 앱이에요.
찍는 순간에는 하루의 색을 보여 주지 않아요.
새벽 4시에 하루가 닫히면, 그날 사진들의 색으로 빚은 조약돌 하나가 도착해요.
조약돌마다 순우리말의 이름과 한 줄 말이 붙어요.
예를 들어, 하늘빛, 저녁놀, 도토리처럼요.

■ 이렇게 담아요
· 잠금화면에서 바로 : 잠금화면이나 제어 센터에 「색 남기기」 컨트롤을 두면 잠금을 풀지 않고 찍어요. iPhone 16 이상은 카메라 컨트롤로도 열 수 있어요.
· 앱 안에서 : 홈 왼쪽 가장자리를 오른쪽으로 쓸거나, 아래 카메라 버튼을 눌러요.
· 늘 쓰던 카메라로 찍은 사진도 : 오늘 찍은 사진을 골라 담고, 지난 사진은 사진첩에서 담아요. 설정에서 켜면 사진 앱에서 하트를 누른 오늘 사진도 담겨요.

■ 하루가 조약돌로
· 새벽 4시가 지나면, 또는 「지금 조약돌로 받기」로 일찍 닫으면 그날의 조약돌이 와요.
· 다음 날 아침, 조약돌이 도착하면 한 번 알려 드려요.

■ 사진마다 한 단어
· 사진을 크게 보면 그 순간에 어울리는 한 단어가 남아 있어요. "해거름, 해가 서쪽으로 넘어가는 무렵."
· 위치를 허용하면 찍은 시각과 동네, 그때 날씨까지 함께 적혀요.

■ 조용히 쌓여요
· 홈에는 담은 하루만 이어져요. 사진 더미와 조약돌로, 하루가 한 덩이씩.
· 모은 조약돌 : 받은 조약돌이 달마다 한 줌씩 모여요.
· 작년 이맘때의 조약돌을 다시 만나고, 마음에 드는 하루는 조약돌 카드로 만들어 간직해요.
· 홈 화면 위젯으로 최근 조약돌을 곁에 둬요.
· 조약돌 모양은 「둥근 돌」과 「반듯한 돌」 중에 골라요.

■ 매일 하지 않아도 괜찮아요
· 연속 기록이나 달성 배지가 없어요. 빈 날은 그냥 빈 날이에요.
· 사진이 없는 날엔 가끔 살짝 알려 드려요. 자주 · 가끔 · 받지 않기 중에 고를 수 있어요.
· 색으로 그날의 기분을 판단하지 않아요.

■ 내 사진은 내 곁에
· 계정이 없어요. 광고도, 추적도 없어요. 몽돌에는 서버가 없어요.
· 몽돌로 찍은 사진은 사진 앱에 저장되고, 기록은 내 iCloud로만 기기 사이에 이어져요.
· 사진에서 한 단어를 고르는 일은 모두 기기 안에서 해요.

iOS 18 이상 · iPhone
날씨 정보 제공: Apple 날씨
```

1,207자 (Tabber 최종). 「유효하지 않은 문자」 오류의 원인으로 보이는 `♥`(U+2665, 이모지 계열)를 「하트」로 바꿨다(미확인). 그래도 거부되면 다음 의심은 `■`.

### 키워드 (100자, 쉼표 구분 · 띄어쓰기 없이)

```
사진일기,감성,감성사진,기록,일기,컬러,색감,색수집,노을,하늘,풍경,수집,잠금화면,카메라,위젯,무드,그라데이션,팔레트,추억,힐링,돌멩이
```

75자 · 21개 · 중복 없음. 이름·부제에 이미 있는 말(몽돌, 순간, 색, 하루, 조약돌)은 Apple 이 따로 색인하므로 넣지 않았다.
뺀 것: `기분`(색으로 기분을 판단하지 않는다는 원칙과 부딪힘), `필름카메라`(필름 앱으로 오해), `데일리`(매일 쓰라는 신호).

### 지원 URL (필수)

```
https://github.com/ITlearning/AI-Product-Factory/issues
```

CodeStudy 와 같은 방식. 개인 연락 페이지가 생기면 바꾼다.

### 마케팅 URL (선택)

비워 둔다. 인스타 서비스 계정을 넣고 싶으면 그 주소.

### 저작권

```
2026 판매자 이름
```

App Store Connect 맨 위에 보이는 판매자 이름과 같게 적는다(© 기호는 Apple 이 붙인다).

### 버전 출시

수동 출시 권장 — 심사 통과 뒤 CloudKit Production·TestFlight 마지막 확인을 하고 직접 연다.

---

## 앱 심사 정보

- **로그인 필요**: 아니요 (계정 없음)
- **연락처**: Tabber 이름 · 전화 · 이메일
- **메모** (영어 — 심사관용):

```
Mongdol does not require an account.

How it works: photos you take are collected into "today" without showing their colors. When the day closes (at 4:00 AM local time, or early with the button below), the colors of that day's photos become one pebble, presented with a short ceremony. Each pebble gets a name and a one-line phrase.

To see a pebble without waiting until 4 AM:
1) During onboarding, the step "지난 두 주 사진으로 첫 조약돌을 받아 볼까요?" lets you pick photos from the library; a pebble is presented right away. Or:
2) Take a photo in the app (on Home, swipe from the left edge to the right, or tap the camera button at the bottom left). Then tap today's block on Home, tap "지금 조약돌로 받기" (Receive the pebble now) and confirm "받기".

Lock Screen capture: the app includes a LockedCameraCapture extension and a control named "색 남기기". Add the control to the Lock Screen or Control Center (or, on iPhone 16 and later, choose Mongdol in Settings > Camera > Camera Control). When the device is unlocked, the control opens the in-app camera directly.

Permissions:
- Camera: taking photos.
- Photos: saving captured photos to the library and picking existing ones.
- Location (optional): place name and weather shown next to a photo.
- Notifications (optional): a morning notice when yesterday's pebble arrives, and occasional reminders on days without photos (Settings: often / sometimes / off).

Weather data is provided by Apple Weather (WeatherKit); attribution is shown in the photo viewer.
Records sync through the user's own iCloud (CloudKit private database). The app has no server, no analytics and no ads.
```

---

## 앱이 수집하는 개인정보

### 개인정보 처리방침 URL (필수)

```
https://github.com/ITlearning/AI-Product-Factory/blob/main/Color-Moments/PRIVACY.md
```

이 브랜치가 main 에 머지돼야 열린다 — **제출 전에 머지 확인**.

### 데이터 수집 — 「아니요, 이 앱에서 데이터를 수집하지 않습니다」

Apple 기준의 「수집」은 기기 밖으로 보내 개발자(또는 제3자)가 실시간 처리 이상으로 접근할 수 있게 하는 것이다. 몽돌은:

| 데이터 | 어디로 | 수집인가 |
|---|---|---|
| 사진 기록(시각·대표 색·한 단어·장소 이름·좌표·날씨) | 사용자 본인 iCloud(CloudKit **개인** 데이터베이스) | 아니다 — 개발자가 열람할 수 없다 |
| 사진 자체 | 기기 사진 앱 (iCloud 사진은 사용자가 켠 Apple 서비스) | 아니다 — 몽돌이 보내지 않는다 |
| 위치 | 장소 이름·날씨를 찾을 때 Apple(지오코딩·WeatherKit)이 그 자리에서 처리 | 아니다 — 개발자 서버 없음 |
| 사진 분석(한 단어·추천) | 기기 안 Vision | 아니다 |
| 알림 | 기기 안 로컬 예약 | 아니다 |

코드 근거: 앱·확장 어디에도 `URLSession`·외부 주소가 없다(2026-10-03 확인). `PrivacyInfo.xcprivacy` 도 수집 데이터 없음 · 추적 없음.

---

## 앱의 손쉬운 사용 (선택)

지원한다고 표시하면 **흔한 작업 전체**에서 지원해야 한다(Apple 기준). 지금 확실한 것만 표시한다.

| 항목 | 표시 | 이유 |
|---|---|---|
| 다크 모드 인터페이스 | ✅ | 다크 전용 앱 |
| 동작 줄이기 | ❌ (나중에) | 8개 파일은 처리하지만 증정 장면(`BadgeCeremony`)의 떠오름·흔들림은 그대로 |
| 더 큰 텍스트 | ❌ | 글꼴이 고정 크기(`.custom(name, size:)`)라 시스템 글자 크기를 따르지 않는다 |
| VoiceOver · 음성 명령 | ❌ (실기기로 확인 뒤) | 손쉬운 사용 라벨이 일부만 있다 |
| 색상 사용 없이 구별 · 충분한 대비 | ❌ (확인 뒤) | 대비는 본문 기준 AA 를 맞췄지만(DESIGN §2.1) 전 화면 확인은 안 했다 |
| 자막 · 오디오 설명 | — | 영상·소리 콘텐츠가 없다 |

---

## 가격 및 사용 가능 여부

- 가격: **무료**
- 국가: **대한민국** 권장 — 앱이 한국어 전용이다. 넓히면 그 나라 언어 설명·스크린샷이 없다.

## 디지털 서비스법 (EU)

이미 「비거래자」로 신고돼 있다. 대한민국만 배포하면 EU 와 무관.

---

## 제출 전 확인

- [ ] PRIVACY.md 가 main 에 있고 위 URL 이 열린다
- [ ] App Store 버전 번호와 빌드(1.0.0) 일치
- [ ] 빌드 선택 — 크래시 수정이 들어간 빌드(2 이상)
- [ ] 6.9인치 스크린샷 6장 (6.5인치는 「6.9 사용」 또는 노치 판)
- [ ] CloudKit Production 스키마 — 최근 필드까지 배포됨(2026-10-01 완료)
- [ ] 연령 등급 설문 · 개인정보(수집 안 함) · 카테고리 · 콘텐츠 권한 저장
- [ ] 심사 메모 · 연락처
