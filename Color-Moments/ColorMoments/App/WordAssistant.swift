import Foundation
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 규칙이 거른 후보 안에서 Apple Intelligence(온디바이스 모델)가 고른다. 되는 기기만 —
/// iPhone 13·Apple Intelligence 를 끈 기기·모델 준비 전엔 nil 이라 규칙 1순위 그대로.
/// 후보 밖 말은 스키마(anyOf)가 막는다 — 없는 단어를 지어내면 명조 서브셋에 글자도 없다.
enum WordAssistant {
    private static let log = Logger(subsystem: "com.itlearning.colormoments", category: "word")

    /// 기본은 끔 — 2026-10-01 iPhone 16 Pro 실측: 까닭 먼저·두 번 물어 같을 때만 따르게 해도 7개 중 6개가
    /// 순서에 따라 답이 갈려 규칙으로 떨어졌고(바뀐 결과 0), 사진마다 약 3초가 더 걸렸다.
    /// 비교 리포트로 계속 보고, 디버그 화면에서 켤 수 있다.
    static let enabledKey = "wordModelEnabled"

    static func install() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            WordAssist.choose = { input in
                UserDefaults.standard.bool(forKey: enabledKey) ? await choose(input) : nil
            }
        }
        #endif
    }

    /// 디버그 리포트용 — 쓸 수 있는지와 안 되는 이유.
    static var status: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            return "\(model.availability) · 한국어 \(model.supportsLocale(Locale(identifier: "ko_KR")) ? "지원" : "미지원")"
        }
        #endif
        return "iOS 26 미만"
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static var ready: SystemLanguageModel? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(Locale(identifier: "ko_KR")) else { return nil }
        return model
    }

    struct Verdict: Sendable {
        let forward: String?
        let reversed: String?
        let reason: String
        /// 두 번 물어 같은 답일 때만 — 모델은 앞 후보를 고르는 버릇이 있다(2026-10-01 iPhone 16 Pro 실측:
        /// 단어만 고르게 하면 7개 중 5개가 순서를 뒤집자 답이 바뀌었다).
        var agreed: String? { forward == reversed ? forward : nil }
    }

    @available(iOS 26.0, *)
    static func choose(_ input: WordChoice) async -> String? {
        guard let word = await verdict(input)?.agreed else { return nil }
        return input.candidateID(for: word)
    }

    @available(iOS 26.0, *)
    static func verdict(_ input: WordChoice) async -> Verdict? {
        guard let model = ready else { return nil }
        let a = await ask(model, input), b = await ask(model, input.reversed)
        return Verdict(forward: a?.word, reversed: b?.word, reason: a?.reason ?? b?.reason ?? "")
    }

    /// 까닭을 먼저 쓰게 한다 — 단어만 고르게 할 때보다 날씨와 어긋난 후보를 잘 버린다(눈 −2°에 진눈깨비 → 함박눈).
    @available(iOS 26.0, *)
    private static func ask(_ model: SystemLanguageModel, _ input: WordChoice) async -> (word: String, reason: String)? {
        do {
            let root = DynamicGenerationSchema(name: "PhotoWordPick", properties: [
                .init(name: "까닭", schema: DynamicGenerationSchema(type: String.self)),
                .init(name: "단어", schema: DynamicGenerationSchema(name: "PhotoWord", anyOf: input.candidates.map(\.word))),
            ])
            let session = LanguageModelSession(model: model, instructions: WordChoice.instructions)
            let response = try await session.respond(to: input.prompt(), schema: try GenerationSchema(root: root, dependencies: []),
                                                     options: GenerationOptions(sampling: .greedy))
            let word = try response.content.value(String.self, forProperty: "단어")
            guard input.candidateID(for: word) != nil else {
                log.notice("후보 밖 답 — \(word, privacy: .public)")
                return nil
            }
            return (word, (try? response.content.value(String.self, forProperty: "까닭")) ?? "")
        } catch {
            // 사람·모임 사진에서 guardrailViolation 이 나기도 한다 — 규칙 1순위로.
            log.error("단어 고르기 실패 — \(String(describing: error), privacy: .public)")
            return nil
        }
    }
    #endif
}
