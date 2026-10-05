import Accelerate
import CoreML
import UIKit

/// 학생 모델 = TinyCLIP 인코더(Core ML) + 고르기 층(행렬). 앱 타깃에만 — 확장이 부르면 메모리 한도에 걸린다.
enum WordModel {
    enum LoadError: Error { case badHead, idMismatch, testHead }

    struct Head: Sendable {
        let ids: [String], dim: Int, mean: [Float], std: [Float], bias: [Float], weights: [Float]
        var isTest = false

        static var isDebugBuild: Bool {
            #if DEBUG
            true
            #else
            false
            #endif
        }

        /// 시험용 층(test: true)은 출시 빌드에서 깨진 모델과 같다 — 규칙으로 간다.
        static func isUsable(isTestHead: Bool, isDebug: Bool) -> Bool { !isTestHead || isDebug }

        static func load(json: Data, bin: Data, expected: [String], isDebug: Bool = isDebugBuild) throws -> Head {
            struct Meta: Decodable {
                let dim: Int; let ids: [String]; let mean: [Float]; let std: [Float]; let bias: [Float]; let test: Bool?
            }
            let m = try JSONDecoder().decode(Meta.self, from: json)
            guard isUsable(isTestHead: m.test ?? false, isDebug: isDebug) else { throw LoadError.testHead }
            guard m.ids == expected else { throw LoadError.idMismatch }
            guard bin.count == m.ids.count * m.dim * MemoryLayout<Float16>.size, m.mean.count == m.dim,
                  m.std.count == m.dim, m.bias.count == m.ids.count else { throw LoadError.badHead }
            var half = [Float16](repeating: 0, count: m.ids.count * m.dim)
            _ = half.withUnsafeMutableBytes { bin.copyBytes(to: $0) }
            return Head(ids: m.ids, dim: m.dim, mean: m.mean, std: m.std, bias: m.bias, weights: half.map(Float.init),
                        isTest: m.test ?? false)
        }

        var scorableIDs: Set<String> { Set(ids.indices.filter { bias[$0] > -1e3 }.map { ids[$0] }) }

        /// 학습 때 한 번도 정답이 아니었던 단어(bias -1e4)는 아예 빼서 뽑히지 않게 한다.
        func scores(_ embedding: [Float]) -> [String: Float] {
            guard embedding.count == dim else { return [:] }
            let x = zip(zip(embedding, mean), std).map { ($0.0 - $0.1) / $1 }
            var out = [Float](repeating: 0, count: ids.count)
            vDSP_mmul(weights, 1, x, 1, &out, 1, vDSP_Length(ids.count), 1, vDSP_Length(dim))
            var result: [String: Float] = [:]
            for i in ids.indices where bias[i] > -1e3 { result[ids[i]] = out[i] + bias[i] }
            return result
        }
    }

    actor Engine {
        private let loader: @Sendable () throws -> (MLModel, Head)
        private var loaded: (MLModel, Head)?
        private var broken = false

        init(loader: @escaping @Sendable () throws -> (MLModel, Head) = Engine.bundled) { self.loader = loader }

        /// 번들 파일은 실행 중에 바뀌지 않는다 — 한 번 못 읽으면 다시 읽지 않고 계속 broken.
        func load() throws -> (MLModel, Head) {
            if let loaded { return loaded }
            if broken { throw WordScorer.Failure.broken }
            do {
                let l = try loader()
                loaded = l
                return l
            } catch {
                broken = true
                throw WordScorer.Failure.broken
            }
        }

        static func bundled() throws -> (MLModel, Head) {
            guard let enc = Bundle.main.url(forResource: "WordEncoder", withExtension: "mlmodelc"),
                  let json = Bundle.main.url(forResource: "WordHead", withExtension: "json"),
                  let bin = Bundle.main.url(forResource: "WordHead", withExtension: "bin") else { throw WordScorer.Failure.broken }
            let config = MLModelConfiguration(); config.computeUnits = .cpuAndNeuralEngine
            let model = try MLModel(contentsOf: enc, configuration: config)
            let h = try Head.load(json: Data(contentsOf: json), bin: Data(contentsOf: bin), expected: BundledWordSource.cached.map(\.id))
            return (model, h)
        }

        // actor 라 예측은 한 번에 하나 — 2초 한도에 버려진 느린 추론 위로 ↻ 가 쌓여도 동시에 돌지 않는다.
        func scores(for image: CGImage) throws -> [String: Float] {
            let (model, head) = try load()
            guard let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
                throw WordScorer.Failure.broken
            }
            guard let input = WordImage.input(from: image) else { throw WordScorer.Failure.unavailable }
            let value = try MLFeatureValue(cgImage: input, constraint: constraint, options: nil)
            let out = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": value]))
            guard let e = out.featureValue(for: "embedding")?.multiArrayValue, e.count == head.dim else {
                throw WordScorer.Failure.broken
            }
            return head.scores((0..<e.count).map { Float(truncating: e[$0]) })
        }
    }

    private static let engine = Engine()

    static func scores(for image: CGImage) async throws -> [String: Float] {
        try await engine.scores(for: image)
    }

    static func install() {
        WordScorer.score = { m in
            guard let image = await ShotImage.thumbnail(m, maxPixel: 600), let cg = upright(image) else {
                throw WordScorer.Failure.unavailable
            }
            return try await scores(for: cg)
        }
        Task.detached(priority: .utility) {
            do { WordScorer.scorableIDs = try await engine.load().1.scorableIDs } catch {
                WordScorer.score = nil
                WordScorer.scorableIDs = nil
            }
        }
    }

    // 사진 앱에서 온 UIImage 는 방향을 픽셀이 아니라 imageOrientation 에 들고 올 수 있다 — .cgImage 는 그걸 버린다.
    static func upright(_ image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(at: .zero) }.cgImage
    }
}
