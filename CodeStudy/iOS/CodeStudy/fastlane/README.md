# CodeStudy 배포 자동화

Fastlane 기반 TestFlight 자동 업로드. 한 명령으로 빌드 번호 증가 → 아카이브 → TestFlight 업로드까지 처리한다.

## 최초 1회 셋업

### 1. Ruby 의존성 설치

```bash
cd CodeStudy/iOS/CodeStudy
bundle install
```

> 시스템 Ruby로 충분하다. rbenv/asdf로 별도 Ruby를 쓰고 있다면 해당 환경에서 실행.

### 2. App Store Connect API key 발급 (1회)

자동화 인증의 표준 방식. Apple ID + 2FA를 우회해서 안정적으로 동작.

1. [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access** → **Integrations** → **Keys**
2. **Generate API Key** 클릭
3. Name: `CodeStudy Fastlane` (자유), Access: **App Manager** 또는 **Admin**
4. **Download API Key** — `.p8` 파일을 받는다 (단 1회만 다운로드 가능)
5. 받은 파일을 안전한 위치에 보관 (예: `~/.appstoreconnect/AuthKey_XXXXXXXXXX.p8`)
6. 화면에 표시되는 **Key ID**와 **Issuer ID**를 메모

### 3. `.env` 파일 작성

```bash
cp fastlane/.env.default fastlane/.env
```

`fastlane/.env`를 열어서 위에서 받은 값 채우기:

```env
ASC_KEY_ID=ABC1234567
ASC_ISSUER_ID=12345678-1234-1234-1234-123456789012
ASC_KEY_PATH=/Users/tabber/.appstoreconnect/AuthKey_ABC1234567.p8
```

> `.env`는 `.gitignore`되어 있어 커밋되지 않는다.

## 매 배포마다

```bash
cd CodeStudy/iOS/CodeStudy
bundle exec fastlane beta
```

자동으로 처리되는 것:
- App Store Connect의 마지막 빌드 번호 + 1로 자동 증가
- Release 구성으로 archive
- TestFlight 업로드
- 최근 10개 commit 메시지를 changelog로 첨부

업로드 후 App Store Connect에서 처리(processing) 완료까지 5~15분 정도 걸리고, 완료되면 테스터에게 자동/수동 배포할 수 있다.

## 마케팅 버전 (1.x → 1.y) 올릴 때

빌드 번호는 자동이지만 **마케팅 버전은 수동**으로 올린다 (의도적 결정 — 큰 릴리즈에만 올리는 게 자연스러움):

1. Xcode에서 CodeStudy target → General → **Version** 수정 (예: 1.1.0 → 1.2.0)
2. 커밋
3. `bundle exec fastlane beta`

## 빌드만 검증하고 싶을 때 (업로드 X)

```bash
bundle exec fastlane build_only
```

`build/CodeStudy.ipa`가 생성됨. App Store Connect에는 아무것도 올라가지 않음.

## 트러블슈팅

| 증상 | 원인 / 해결 |
|------|-------------|
| `환경변수 ASC_* 가 설정되지 않았습니다` | `fastlane/.env` 누락 또는 값 비어있음 |
| `No signing certificate "iOS Distribution" found` | Xcode → Settings → Accounts에서 Apple ID 로그인 + 자동 시그닝 활성화 확인 |
| `Could not find Xcode project` | `CodeStudy/iOS/CodeStudy` 디렉터리에서 실행 중인지 확인 |
| TestFlight 업로드 후 "Missing Compliance" | App Store Connect에서 수동 답변 필요 (1회) |

## CI 자동화 (후속 과제)

현재는 로컬 실행만 지원. GitHub Actions로 main push 시 자동 배포하려면:
- `.p8` 키를 base64 인코딩해서 GitHub Secret에 저장
- macOS runner에서 `bundle exec fastlane beta` 실행
- 별도 PR로 추가 예정
