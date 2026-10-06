# 몽돌 배포 자동화

Fastlane 기반 TestFlight 업로드. 한 명령으로 빌드 번호 결정 → 아카이브 → TestFlight 업로드까지 처리한다.
구성은 `CodeStudy/iOS/CodeStudy/fastlane` 과 같고, 몽돌만의 차이는 아래 「CodeStudy 와 다른 점」에 있다.

> 이 파일이 정본 가이드다. `fastlane/README.md` 는 만들지 않는다(Fastfile 의 `skip_docs`).

## 최초 1회 셋업

```bash
cd Color-Moments
bundle install          # 사용자 bundle 설정(path vendor/bundle)대로 Color-Moments/vendor/bundle 에 깔린다
cp fastlane/.env.default fastlane/.env
```

`fastlane/.env` 에 App Store Connect API key 값을 채운다. CodeStudy 와 **같은 키**(`AuthKey_HZACY773DV.p8`)가
몽돌 앱에도 통한다(2026-10-02 `fastlane latest` 로 확인). `.env` 는 gitignore 돼 커밋되지 않는다.

```env
ASC_KEY_ID=...
ASC_ISSUER_ID=...
ASC_KEY_PATH=/Users/tabber/AI-Product-Factory/.appstoreconnect/AuthKey_HZACY773DV.p8
```

키체인에 Apple Distribution 인증서는 필요 없다. 대신 **Xcode → Settings → Accounts 에 팀 계정이 로그인돼 있어야** 한다(아래 서명 참고).

## 매 배포

```bash
cd Color-Moments
bundle exec fastlane latest       # 마지막 TestFlight 빌드 번호만 본다 (아무것도 안 올림)
bundle exec fastlane beta         # 마지막 + 1 로 아카이브 → TestFlight 업로드
```

- 테스터 메모(「테스트할 항목」)는 `fastlane/notes/<버전>-<빌드>.txt` 이다. **올리기 전에 먼저 쓴다** — 없으면 `beta` 가 멈춘다.
  빌드 번호는 `fastlane latest` 가 알려 주는 다음 번호. 사람이 읽는 말로, 바뀐 것과 확인할 것을 적는다.
- 이미 올라간 빌드에 메모만 붙이거나 고칠 때: `bundle exec fastlane notes build:3` (버전은 `project.yml` 값, 다르면 `version:1.1.0`).
- 업로드 뒤 App Store Connect 처리에 5~15분 걸린다.

### 맥스튜디오에서 돌릴 때

맥스튜디오는 `/usr/bin/ruby`(2.6, bundler 1.17)와 Homebrew ruby 3.4 가 섞여 `bundle exec` 가 gem 을 못 찾는다.
Homebrew ruby 와 bundler 2.6 으로 맞춰 돌린다. `Gemfile.lock` 의 `BUNDLED WITH` 가 바뀌면 되돌린다(다른 맥은 1.17).

```bash
export PATH=/opt/homebrew/opt/ruby/bin:$PATH BUNDLER_VERSION=2.6.2 BUNDLE_PATH=vendor/bundle
bundle install && bundle exec fastlane latest; git checkout Gemfile.lock
```

API 키는 맥마다 따로다 — 맥스튜디오는 `~/.appstoreconnect/private_keys/AuthKey_A8H33DUY68.p8` (`.env` 의 `ASC_KEY_PATH`).

## 빌드만 검증 (업로드 X)

```bash
bundle exec fastlane build_only   # build/ColorMoments.ipa
bundle exec fastlane test         # 시뮬레이터 단위 테스트 (기본 iPhone 16 Pro, device:"..." 로 바꾼다)
```

## CodeStudy 와 다른 점

| | 몽돌 | 이유 |
|---|---|---|
| 빌드 번호 | `CURRENT_PROJECT_VERSION` 을 **xcodebuild 인자로만** 넘긴다. 파일은 안 고친다 | pbxproj 는 `project.yml` 에서 xcodegen 으로 만든다. 파일에 쓰면 다음 생성 때 사라지고, 인자로 넘겨야 앱·잠금화면 확장·컨트롤 위젯이 같은 번호를 받는다 |
| 마케팅 버전 | `project.yml` 의 `MARKETING_VERSION` 을 고치고 `xcodegen generate` | Xcode 의 General 탭에서 바꾸면 커밋되지 않은 pbxproj 수정으로만 남는다 |
| 서명 | Xcode 클라우드 관리 배포 인증서. `-allowProvisioningUpdates` 로 **Xcode 에 로그인된 계정**이 서명한다 | 키체인에 Apple Distribution 이 없다. API 키를 xcodebuild 에 넘기면 `Cloud signing permission error` — 키 권한이 클라우드 인증서에 못 닿는다(2026-10-02 확인). API 키는 빌드 번호 조회·업로드에만 쓴다 |

확장 두 개(`ColorMomentsCapture`, `ColorMomentsControl`)의 Info.plist 도 `$(MARKETING_VERSION)` · `$(CURRENT_PROJECT_VERSION)`
을 쓴다. 그 전엔 xcodegen 기본값 `1.0` (1) 이 박혀 있어서, 1.0.0 (1) 은 확장만 `1.0` 으로 올라갔다.

## 트러블슈팅

| 증상 | 원인 / 해결 |
|------|-------------|
| `환경변수 ASC_* 가 설정되지 않았습니다` | `fastlane/.env` 누락 또는 값 비어 있음 |
| `Cloud signing permission error` · `No signing certificate "iOS Distribution" found` | Xcode → Settings → Accounts 에 팀 계정이 로그인돼 있는지 확인. xcodebuild 에 `-authenticationKey*` 를 넘기지 말 것 |
| `option '-authenticationKeyPath' may only be provided once` | gym 은 `xcargs` 를 내보내기에도 붙인다 — `export_xcargs` 에 같은 플래그를 또 넣지 말 것 |
| 업로드는 됐는데 빌드가 안 보임 | App Store Connect 처리 중. `skip_waiting_for_build_processing` 이라 기다리지 않는다 |
