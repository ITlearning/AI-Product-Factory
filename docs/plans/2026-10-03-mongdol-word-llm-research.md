# 몽돌 단어 LLM — 조사 결과

작성 2026-10-03 · brief(`2026-10-03-mongdol-word-llm-brief.md`)의 「요확인」과 회의 안건 1·3에 필요한 사실 · 회의 기록은 `2026-10-03-mongdol-word-llm-session-log.md`

공식 문서·WWDC26 세션·약관을 근거로 썼다. 확인하지 못한 것은 **요확인**으로 남겼다.
로컬에서 직접 확인한 것: Xcode 26.3(iOS 26.2 SDK)의 FoundationModels 는 `Transcript.Segment` 가 `text`·`structure` 뿐이다. 이미지 입력이 없다.

## 한눈에

| 길 | 사진이 나가나 | iPhone 13 | 목록에서 고르기 | 목록 밖 제안 | 비용 | 걸림 |
|---|---|---|---|---|---|---|
| **A1** iOS 27 기기 안 모델 (Foundation Models + `Attachment`) | 아니오 | **안 됨** (iPhone 15 Pro 이상 + Apple Intelligence 켬) | 됨 | 됨 | 0 | 문맥 8,192토큰에 사진+후보 ~100개가 드는지 요확인. 1.0 실측의 순서 편향 |
| **A2** 기기 안 매칭 모델 (SigLIP2 B/16, Core ML) | 아니오 | 됨 | 됨 | **안 됨** | 0 | 앱 +69~92MB. 감정·상태 같은 추상어에 약하다 |
| **C** 클라우드 비전 (OpenRouter, 동의한 사람만) | 예 | 됨 | 됨 | 됨 | 사진당 ≈$0.0001 | 동의 화면·처리방침·국외 이전·스토어 표시를 바꿔야 한다 |
| **D** Private Cloud Compute | 예 (Apple 서버, 저장 안 함) | 안 됨 | 됨 (이미지 입력 요확인) | 됨 | 0 (사용자별 하루 한도) | 엔타이틀먼트 신청 |
| **B** 기기 안에서 더 뽑아 글로 보내기 | 아니오 | 됨 | 지금과 같음 | — | — | 라벨의 한계가 그대로라 「대상을 헛짚음」을 못 푼다 |

## 1. A1 — iOS 27 Foundation Models 이미지 입력

- API (모두 iOS 27.0+)
  - `Attachment(_ cgImage: CGImage, orientation:)`, `Attachment(imageURL:orientation:)`. 쓰는 법은 `Prompt { "…"; Attachment(image) }`.
  - `Transcript.Segment.attachment(Transcript.AttachmentSegment)` — 26.2 SDK 에 없던 케이스.
  - `LanguageModelCapabilities.Capability.vision` — "The capability to accept image inputs in prompts".
  - 받는 입력: UIImage, NSImage, CGImage, CoreImage, CVPixelBuffer, 파일 URL. 크기 제한은 없고 클수록 토큰·지연이 는다(세션 241).
- **기기 안에서 처리한다**: WWDC26 가이드 "Multimodal prompts let you pass images alongside text … all on-device".
- **기기 조건**: Apple Intelligence 기기만(iPhone 15 Pro/Pro Max, iPhone 16 이상). 기기 언어와 Siri 언어가 지원 언어(한국어 포함)로 같아야 한다. **iPhone 13 은 안 된다.**
- 답 묶기: `@Generable` 구조체에 `@Guide(.anyOf([...]))`(iOS 26+)로 후보 밖 답을 막는다.
- 문맥 창 8,192토큰(27.0). 사진 한 장이 몇 토큰인지, 후보 ~100개(단어+뜻풀이)와 함께 드는지는 **요확인 — 실측**.
- 1.0 실측(iPhone 16 Pro, iOS 26, 글자만 준 고르기)에서는 순서 편향이 있었고, 바뀐 결과 0, +3초였다. 사진을 보는 모델로 다시 재야 한다.
- 근거: https://developer.apple.com/documentation/foundationmodels/attachment · https://developer.apple.com/documentation/foundationmodels/languagemodelcapabilities/capability · https://developer.apple.com/videos/play/wwdc2026/241/ · https://developer.apple.com/wwdc26/guides/apple-intelligence/ · https://support.apple.com/en-us/121115

## 2. D — Private Cloud Compute

- `PrivateCloudComputeLanguageModel`(iOS 27+). 엔타이틀먼트 `com.apple.developer.private-cloud-compute` 를 신청해야 한다.
- 대상: App Store Small Business Program 가입 개발자, 모든 앱 합쳐 첫 다운로드 200만 미만. 넘으면 6개월 안에 다른 방식으로 옮겨야 한다.
- 개발자 토큰 비용 0. 사용자마다 하루 한도가 있고 iCloud+ 면 늘어난다(`quotaUsage`). 문맥 32K. 네트워크 필요, Apple Intelligence 기기만.
- 세션 319: "user data is never stored. The data is only used for requests".
- 이미지: 세션 319 데모에 「text and images」는 나오지만 문서에 `.vision` 지원 명시는 없다 → **요확인**(런타임 `capabilities.contains(.vision)`).
- App Store 개인정보 표시에 미치는 영향 → **요확인**.
- 근거: https://developer.apple.com/documentation/FoundationModels/adding-server-side-intelligence-with-private-cloud-compute · https://developer.apple.com/videos/play/wwdc2026/319/

## 3. Vision 프레임워크

- 캡션(설명)을 만드는 공개 API 는 없다. 세션 237 도 캡션은 Foundation Models 이미지 입력으로 만들라고 한다.
- iPhone 13(iOS 18)에서도 되는 것: `ClassifyImageRequest`(지금 쓰는 라벨), `CalculateImageAestheticsScoresRequest`, `GenerateImageFeaturePrintRequest`, `RecognizeAnimalsRequest`, 얼굴·사람 요청.
- Visual Intelligence 는 방향이 반대다(시스템이 앱에 물어본다). 앱이 사진 이해를 맡길 길은 없다.
- 근거: https://developer.apple.com/videos/play/wwdc2026/237/ · https://developer.apple.com/videos/play/wwdc2026/297/

## 4. A2 — 기기 안 매칭 모델

목록에서 **고르기만** 하면 되므로 문장을 짓는 모델 대신 CLIP 계열 매칭으로도 된다. 단어마다 영어 시각 묘사 몇 개와 한국어 뜻풀이를 개발 맥에서 임베딩해 평균 벡터 170개(≈0.3MB)만 앱에 넣는다. 앱에는 이미지 인코더만 들어간다.

| 모델 | 이미지 인코더 (fp16 / 압축) | iPhone 지연 | IN-1k 제로샷 | 라이선스 |
|---|---|---|---|---|
| MobileCLIP S0/S2/B | 22.7 / 71.4 / 172.7MB | 1.5 / 3.6 / 10.4ms | 67.8 / 74.4 / 77.2% | 가중치 연구 전용 → **앱에 못 넣음** |
| MobileCLIP2 S0/S2/B | ≈23 / 71 / 173MB, 공식 Core ML 없음 | 같음 | 71.5 / 77.2 / 79.4% | apple-amlr 연구 전용 → **못 넣음** |
| **SigLIP2 B/16 (다국어)** | 184.6 / 8비트 92.5 / 6비트 69.4MB | 요확인 (SigLIP v1 B/16 9.9ms) | 78.2% | **Apache-2.0 → 가능** |
| OpenCLIP DataComp B/32 | ≈172 / 8비트 ≈86MB | 5.9ms | 69.2% | MIT → 가능 |
| FastVLM-0.5B (캡션 VLM) | 전체 ≈1.5GB | 요확인 | — | 연구 전용 → 못 넣음 |
| SmolVLM2-256M/500M | 전체 ≈0.5 / 1.0GB | 요확인 | — | Apache-2.0 → 가능 |

- 지연은 iPhone 12 Pro Max·iOS 17 기준(MobileCLIP 논문). iPhone 13 실측은 요확인.
- 추천은 **SigLIP2 B/16 이미지 인코더 8비트(≈92MB) 또는 6비트(≈69MB)**. 텍스트 인코더(565MB)는 개발 맥에서만 쓴다.
- 함정
  - 추상어에 약하다. CLIP 논문이 직접 적었고, 감정 43종 분류에서 무작위 수준이었다. 단어를 「눈에 보이는 장면」 묘사 여러 개로 풀어 평균하면 낫다(프롬프트 앙상블 +3.5~5%p).
  - 허브 단어: 어떤 사진에서든 1등이 되는 단어가 생긴다. 참조 사진 묶음으로 단어별 평균 점수를 빼서 보정한다(QB-Norm).
  - 사진 속 글자(간판·자막)가 판정을 끌고 간다.
- 앱 용량이 부담이면 Background Assets 로 설치 뒤 모델만 내려받는다. 이때도 사진은 기기 밖으로 나가지 않는다.
- 근거: https://github.com/apple/ml-mobileclip · https://huggingface.co/apple/MobileCLIP2-S2 · https://huggingface.co/google/siglip2-base-patch16-224 · https://huggingface.co/batmac/ViT-B-16-SigLIP2-Image-CoreML · https://arxiv.org/abs/2502.14786 · https://arxiv.org/abs/2103.00020 · https://arxiv.org/abs/2112.12777

## 5. C — 클라우드 비전 비용·보관

기준: 512×384 사진 1장 + 텍스트 600토큰 + 답 30토큰. 값은 2026-10-03 OpenRouter API 에서 받았다.

| OpenRouter ID | 입력/출력 $/1M | 1회 | 지연 p50 | 저장 안 함(ZDR) |
|---|---|---|---|---|
| `openai/gpt-6-luna` | 0.10 / 0.50 | ≈$0.00010 (이미지 토큰 규칙 요확인) | Azure-EU 1.3s, OpenAI 2.5s | Azure 경로만 |
| `google/gemini-3.1-flash-lite` | 0.25 / 1.50 | $0.00048 (low $0.00027) | Vertex 0.78s | Vertex 경로만 |
| `google/gemini-3.5-flash-lite` | 0.30 / 2.50 | $0.00059 | Vertex 0.57s | Vertex 경로만 |
| `mistralai/mistral-small-2603` | 0.15 / 0.60 | $0.00015 | 0.31s | 가능 |
| `google/gemma-4-26b-a4b-it` | 0.0675 / 0.225 | $0.00007 | 0.26s | 가능 |

- 월 비용(하루 5장, 처음 열 때 한 번): 100명 기준 luna $1.5 · Gemma 4 $1.0 · 3.1 Flash-Lite $7. 1,000명 기준 luna $15 · Gemma 4 $10 · 3.1 Flash-Lite $71.
- luna 는 기본 추론이 `medium` 이라 `reasoning effort: none` 을 꼭 준다. 지연은 실측이 필요하다.
- 사진 크기는 512px 로 시작한다(OpenAI `detail: low` 는 어차피 512 안으로 줄인다). 작은 물체를 틀리면 768.
- 보관
  - OpenRouter 는 기본적으로 프롬프트를 저장하지 않는다. 입출력 로깅과 학습 할인은 꺼진 채로 둔다. 익명 표본 분류에 이미지가 드는지는 요확인.
  - OpenAI API 는 학습에 안 쓰지만 남용 감시로 최대 30일 보관한다(ZDR 은 승인제, CSAM 의심 이미지는 ZDR 이어도 보관). Gemini AI Studio 는 55일. Vertex 는 24시간 메모리 캐시만 둔다.
  - 「사진을 저장하지 않는 조건으로만 처리」라고 말하려면 넷 다 지킨다: 요청에 `provider: {zdr: true}`, OpenRouter 로깅·학습 끔, 중계가 본문을 로그·저장소에 안 남김, 「절대 저장 안 됨」이 아니라 「저장하지 않는 조건으로만 처리」로 쓴다.
- 근거: https://openrouter.ai/docs/guides/features/zdr · https://openrouter.ai/docs/guides/privacy/data-collection · https://developers.openai.com/api/docs/guides/your-data · https://ai.google.dev/gemini-api/docs/usage-policies

## 6. 스토어·법 — C 나 D 를 고른다면

- **App Store 개인정보 표시**: 「수집」은 "transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time". 받자마자 버리면 표시하지 않아도 된다. 다만 모델 공급자의 남용 감시 보관이 「수집」인지 Apple 이 밝히지 않았다 → **요확인**. ZDR 강제가 「수집 안 함」을 지킬 가장 단단한 근거다. ZDR 을 강제하지 않으면 「사진 또는 비디오 / 앱 기능 / 연결 안 됨 / 추적 안 함」으로 바꾼다. https://developer.apple.com/app-store/app-privacy-details/
- **App Review 5.1.2(i)** (2025-11-13 추가): "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so." → **켤 때 동의 화면이 필수**다. 5.1.1 은 철회 수단과 처리방침의 보관·삭제 기준을 요구한다. https://developer.apple.com/app-store/review/guidelines/
- **개인정보보호법**: 외부 AI API 연동은 처리위탁이고, 서버가 해외라 국외 이전이다. 제28조의8 ①3(처리방침에 공개)으로 별도 동의 없이 할 수 있다. 2026 처리방침 작성지침 부록1의 예시가 바로 「OpenAI, L.L.C. · 미국 · 결과물 생성 후 즉시 파기」다. 적을 것: 근거, 항목, 국가·시기·방법, 이전받는 자와 연락처, 목적·보유기간, 거부 방법과 효과(학습 활용 여부 권장). 국외 이전 고지를 빠뜨려 적법 근거가 없다고 판단받은 선례가 있다(제2024-010-184호).
  - 요확인: 얼굴 사진이 민감정보가 아니라는 판단(2차 출처만 확인), 저장하지 않는 중계만 운영하는 개인 개발자가 개인정보처리자인지, 재위탁(OpenRouter → OpenAI·Google) 표기.
  - https://www.privacy.go.kr/front/bbs/bbsView.do?bbsNo=BBSMSTR_000000000049&bbscttNo=20885
- **사례**: Apple ChatGPT 확장("you will be asked before any of your information is shared"), Be My Eyes(미국 AI 공급자로 이전, 학습 안 함, 60일 뒤 삭제). 한국 앱 문구는 요확인.

### C 를 고르면 바꿀 것

- 처리방침: 「기기 밖으로 나가지 않음」에 예외 · 처리위탁·국외 이전 절 · 철회 방법
- 스토어 표시와 `PrivacyInfo.xcprivacy`
- 동의 화면: 기본 꺼짐, 켤 때 한 번(누구에게·무엇을·어디로·얼마나 보관), 「동의하고 켜기」/「취소」, 설정에서 언제든 끄기
- 사진·카메라 권한 문구
- 중계: 본문 로그 금지, OpenRouter 로깅 끔, Vercel 리전(기본 iad1 미국, 서울 icn1)

## 7. 조사하지 않은 것

- 「개선에 참여하기」로 **목록 밖 제안 단어**를 보낼 때 스토어 표시가 어떻게 바뀌는지(사진이 아니라 글자·단어 ID 만 보내는 경우). 받을 곳(중계)이 필요하다.
- 1.x 의 최소 iOS(지금 iOS 18)를 올릴지.
