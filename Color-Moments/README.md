# 몽돌 (Mongdol)

> 코드베이스·번들 ID 는 `ColorMoments` 그대로다 — 코드네임이고 사용자에게 안 보인다.

하루 사진에서 상징색을 하나씩 뽑아 그라데이션 뱃지로 증정하는 iOS 앱.
설계: [`../docs/designs/color-moments.md`](../docs/designs/color-moments.md)

## 현재 상태 (2026-09-22)

| | 상태 |
|---|---|
| 프로젝트 골격 | 완료. xcodegen, iOS 18.0+ |
| 색 추출기 | **완료.** 회귀 테스트 6/6 통과 |
| 촬영 화면 (앱·확장 공용) | **완료.** 핀치 줌 + 배율 표시 + 겹겹이 쌓이는 더미 + 촬영 확인 문구 |
| 앱 아이콘 | 완료 (하루 색 그라데이션) |
| LockedCameraCapture 확장 | **✅ Gate 0 통과 (2026-09-22 18:13, iPhone 16 Pro / iOS 26.1)** |
| 그라데이션·뱃지 | 미착수 |

## 빌드

```bash
cd Color-Moments
xcodegen generate
open ColorMoments.xcodeproj
```

시뮬레이터 테스트:
```bash
xcodebuild -project ColorMoments.xcodeproj -scheme ColorMoments \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

`DEVELOPMENT_TEAM` 은 `ZMXTCSPNUZ`(CodeStudy와 동일)로 박혀 있다.

## 설정 목록에 뜨기 위한 요구사항 (2026-09-22 실기기에서 배움)

**타깃이 셋 필요하다.** 하나라도 빠지면 증상이 다르게 나타난다 — 2026-09-22 iPhone 16 Pro 실측:

| 빠진 것 | 증상 |
|---|---|
| `CameraCaptureIntent` | 설정 목록에 **아예 안 뜬다** (확인됨) |
| 컨트롤 위젯 타깃 | — |
| 앱 본체의 카메라 | — |

**해결됨.** 네 요소를 다 갖춘 뒤 정상 선택·동작 확인(2026-09-22 18:13).
중간에 "선택 불가" 상태를 한 번 봤는데, 그 시점엔 앱이 기기에서 삭제된 상태였다
(`devicectl device info apps` 로 확인). 즉 **삭제된 앱의 잔재 레코드**였고
플레이스홀더 아이콘이 그 신호였다. 같은 증상을 보면 먼저 설치 여부부터 확인할 것.

애플 문서 「Enhancing your app experience with the Camera Control」:
> To handle capture events from the Capture Control, your app must adopt the
> `AVCaptureEventInteraction` class from the AVKit framework. To launch your app from
> the Camera Control, it needs to adopt the `LockedCameraCapture` framework.

즉 **앱 본체에 실제 카메라 세션과 `AVCaptureEventInteraction` 이 있어야 한다.**
목록 화면만 있는 앱은 카메라 컨트롤 대상이 될 수 없다.

애플 문서(Creating a camera experience for the Lock Screen) 원문:
> Create a control widget that launches the capture extension when the device is locked.
> Include the `CameraCaptureIntent` in your app target, **control widget extension target**,
> and camera capture extension target.

| 요구사항 | 어디에 | 위치 |
|---|---|---|
| LockedCameraCapture 확장 | `ColorMomentsCapture` · `EXExtensionPointIdentifier = com.apple.securecapture` | `Extensions/` |
| **컨트롤 위젯** | `ColorMomentsControl` · `NSExtensionPointIdentifier = com.apple.widgetkit-extension` | `PlugIns/` |
| **`CameraCaptureIntent`** | `Shared/ColorCaptureIntent.swift` → **세 타깃 모두** | — |
| `NSCameraUsageDescription` | 앱과 촬영 확장 양쪽 | — |

인텐트가 제대로 등록됐는지:

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*ColorMoments*" -name "ColorMoments.app" | head -1)
python3 -c "import json;d=json.load(open('$APP/Metadata.appintents/extract.actionsdata'));\
print(d['actions']['ColorCaptureIntent']['systemProtocols'])"
# ['com.apple.link.systemProtocol.CameraCapture'] 가 나와야 한다
# 앱 본체 / PlugIns/ColorMomentsControl.appex / Extensions/ColorMomentsCapture.appex
# 세 곳의 Metadata.appintents 전부에서 나와야 한다
```

## Gate 0 — 잠금화면 촬영 (iPhone 16 이상 필요)

카메라 컨트롤은 하드웨어라 시뮬레이터에 없다. **실기기에서만 확인된다.**

0. **기존 설치본을 지우고** 다시 설치한다 (AppIntents 메타데이터가 캐시될 수 있다)
1. 16 Pro 연결 → Xcode에서 `ColorMoments` 스킴 실행
2. **설정 > 카메라 > 카메라 컨트롤** 에서 「몽돌」 선택
3. 화면 잠그고 **카메라 컨트롤 버튼** 누르기
4. 잠긴 채로 사진 찍기
5. 잠금 풀고 앱 열기

앱의 Gate 화면에 들어온 사진과 수신 로그가 뜨면 통과.

**확인할 것 다섯:**

| | 실패하면 |
|---|---|
| 설정 목록에 뜨는가 | 확장 등록이 안 된 것. `EXExtensionPointIdentifier` 확인 |
| 잠금화면에서 확장이 뜨는가 | 진입 경로가 없다 → A 경로 포기, B(사진첩) 중심으로 재설계 |
| 잠긴 채로 찍히는가 | 촬영 UI 문제. UIImagePickerController → 커스텀 AVCapture 로 교체 검토 |
| 본 앱으로 넘어오는가 | `sessionContentUpdates` 수신 문제 |
| **원본 무효화가 되는가** | 안 되면 같은 사진을 매번 다시 받는다. 로그의 "원본 무효화 완료" 확인 |

### Gate 0 결과 — 통과 (2026-09-22 18:13)

수신 로그 실측:

```
[6:11:33] 수신 시작. 기존 sessionContentURLs 0개
[6:12:45] added 28A51DCA-1654-44C4-8941-8BBAD9DA1EAD
[6:12:45] 들여옴 shot-1790068349.jpg 3572KB
[6:12:45] 원본 무효화 완료
[6:12:45] removed 28A51DCA-1654-44C4-8941-8BBAD9DA1EAD
[6:13:13] (두 번째 촬영도 동일 경로로 통과)
```

다섯 항목 전부 통과. 앱 촬영(A 경로)도 동작하며 `#464445` 추출 확인.
**A 경로가 살아있으므로 재설계 없이 진행한다.**

## 구조

```
ColorMoments/
  App/ColorMomentsApp.swift      진입
  App/SpikeView.swift            Gate 계측 화면 (통과 후 버림)
  Capture/CaptureInbox.swift     확장이 찍은 것 수신 → 앱 저장소 이관 → 원본 무효화
  Color/ColorExtractor.swift     상징색 추출 (어둠컷 + 히스토그램) + 탭 보정
ColorMomentsCapture/
  CaptureExtension.swift         LockedCameraCaptureExtension
  ViewFinder.swift               CaptureScreen 을 sessionContentURL 로 붙임
ColorMomentsControl/
  ColorCaptureControl.swift      제어센터·잠금화면·카메라 컨트롤에 올라가는 컨트롤
Shared/
  ColorCaptureIntent.swift       CameraCaptureIntent — 세 타깃이 함께 포함
  ColorExtractor.swift           상징색 추출 (앱·확장 공용)
  Capture/CaptureEngine.swift    촬영 세션 · 줌 · 더미 상태. 저장 위치를 주입받는다
  Capture/CaptureScreen.swift    촬영 UI. AVCaptureEventInteraction 필수 (확장 생존 조건)

**커스텀 촬영 UI의 제약**: `UIImagePickerController` 를 쓰지 않으면
`AVCaptureEventInteraction` 을 직접 붙여야 한다. 안 그러면 잠긴 확장이 뜨자마자 종료된다.
ColorMomentsTests/
  ColorExtractorTests.swift      회귀 6건
  Fixtures/                      Tabber 사진 11장 (320px)
```
