import XCTest
@testable import ColorMoments

final class WordModelTests: XCTestCase {
    private func head(ids: [String], bias: [Float]? = nil) -> (Data, Data) {
        let json = try! JSONSerialization.data(withJSONObject: ["format": 1, "wordsVersion": 6, "dim": 2, "ids": ids,
                                                                "mean": [0, 0], "std": [1, 1], "bias": bias ?? ids.map { _ in 0 }])
        var w: [Float16] = []
        for i in ids.indices { w += [Float16(i == 0 ? 1 : 0), Float16(i == 0 ? 0 : 1)] }
        return (json, w.withUnsafeBufferPointer { Data(buffer: $0) })
    }

    func testScoresAreAMatrixProduct() throws {
        let (j, b) = head(ids: ["a", "b"])
        let h = try WordModel.Head.load(json: j, bin: b, expected: ["a", "b"])
        let s = h.scores([0.2, 0.9])
        XCTAssertEqual(s["a"]!, 0.2, accuracy: 0.01); XCTAssertEqual(s["b"]!, 0.9, accuracy: 0.01)
    }

    func testScoresUseRowMajorIdsByDim() throws {
        let json = try JSONSerialization.data(withJSONObject: ["format": 1, "wordsVersion": 6, "dim": 2, "ids": ["a", "b", "c"],
                                                               "mean": [0, 0], "std": [1, 1], "bias": [0, 0, 0]])
        let w: [Float16] = [1, 2, 3, 4, 5, 6]
        let h = try WordModel.Head.load(json: json, bin: w.withUnsafeBufferPointer { Data(buffer: $0) }, expected: ["a", "b", "c"])
        let s = h.scores([0.5, 0.25])
        XCTAssertEqual(s["a"]!, 1.0, accuracy: 1e-4); XCTAssertEqual(s["b"]!, 2.5, accuracy: 1e-4); XCTAssertEqual(s["c"]!, 4.0, accuracy: 1e-4)
    }

    func testWrongLengthEmbeddingGivesNoScores() throws {
        let (j, b) = head(ids: ["a", "b"])
        let h = try WordModel.Head.load(json: j, bin: b, expected: ["a", "b"])
        XCTAssertTrue(h.scores([0.2]).isEmpty)
        XCTAssertTrue(h.scores([0.2, 0.9, 0.1]).isEmpty)
    }

    func testPermanentLoadFailureIsNotRetried() async {
        let calls = Counter()
        let engine = WordModel.Engine { calls.tick(); throw WordModel.LoadError.idMismatch }
        for _ in 0..<2 {
            do { _ = try await engine.load(); XCTFail("깨진 모델은 실패해야 한다") }
            catch { XCTAssertEqual(error as? WordScorer.Failure, .broken) }
        }
        XCTAssertEqual(calls.value, 1, "한 번 못 읽으면 다시 읽지 않는다")
    }

    func testBiasIsAddedOnce() throws {
        let (j, b) = head(ids: ["a", "b"], bias: [0.5, -0.25])
        let h = try WordModel.Head.load(json: j, bin: b, expected: ["a", "b"])
        let s = h.scores([0.2, 0.9])
        XCTAssertEqual(s["a"]!, 0.7, accuracy: 0.01); XCTAssertEqual(s["b"]!, 0.65, accuracy: 0.01)
    }

    func testNormalizesWithMeanAndStd() throws {
        let json = try JSONSerialization.data(withJSONObject: ["format": 1, "wordsVersion": 6, "dim": 2, "ids": ["a", "b"],
                                                               "mean": [0.1, 0.5], "std": [0.5, 2], "bias": [0, 0]])
        let w: [Float16] = [1, 0, 0, 1]
        let h = try WordModel.Head.load(json: json, bin: w.withUnsafeBufferPointer { Data(buffer: $0) }, expected: ["a", "b"])
        let s = h.scores([0.2, 0.9])
        XCTAssertEqual(s["a"]!, 0.2, accuracy: 0.01); XCTAssertEqual(s["b"]!, 0.2, accuracy: 0.01)
    }

    func testUnseenWordsAreLeftOut() throws {
        let (j, b) = head(ids: ["a", "b", "c"], bias: [0, -10_000, -1e3])
        let h = try WordModel.Head.load(json: j, bin: b, expected: ["a", "b", "c"])
        XCTAssertEqual(Set(h.scores([0.2, 0.9]).keys), ["a"])
    }

    func testHeadWithDifferentIDsIsRejected() {
        let (j, b) = head(ids: ["a", "b"])
        XCTAssertThrowsError(try WordModel.Head.load(json: j, bin: b, expected: ["a", "c"]))
    }

    func testHeadWithShortWeightsIsRejected() {
        let (j, b) = head(ids: ["a", "b"])
        XCTAssertThrowsError(try WordModel.Head.load(json: j, bin: b.prefix(b.count - 2), expected: ["a", "b"]))
    }

    func testBundledHeadMatchesTheWordList() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "WordHead", withExtension: "json"))
        let bin = try XCTUnwrap(Bundle.main.url(forResource: "WordHead", withExtension: "bin"))
        XCTAssertNoThrow(try WordModel.Head.load(json: Data(contentsOf: url), bin: Data(contentsOf: bin),
                                                expected: BundledWordSource.cached.map(\.id)))
    }

    func testBundledEncoderIsCompiled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "WordEncoder", withExtension: "mlmodelc"))
    }

    func testEncoderScoresARealPhotoWithSeenWordsOnly() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "IMG_2493", withExtension: "jpg", subdirectory: "Fixtures"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        let s = try await WordModel.scores(for: image)
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.values.allSatisfy(\.isFinite))
        XCTAssertTrue(Set(s.keys).isSubset(of: Set(BundledWordSource.cached.map(\.id))))
        XCTAssertLessThan(s.count, BundledWordSource.cached.count, "한 번도 정답이 아니었던 단어는 빠져야 한다")
    }

    func testExtensionsCarryNoModelOrWordList() throws {
        let plugins = [Bundle.main.builtInPlugInsURL, Bundle.main.bundleURL.appendingPathComponent("Extensions")].compactMap { $0 }
        for dir in plugins {
            for appex in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                for name in ["WordEncoder.mlmodelc", "WordHead.json", "WordHead.bin", "words.json", "lunar-days.json"] {
                    XCTAssertFalse(FileManager.default.fileExists(atPath: appex.appendingPathComponent(name).path),
                                   "\(appex.lastPathComponent) 에 \(name) — 확장 크기·메모리")
                }
            }
        }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    func tick() { lock.lock(); n += 1; lock.unlock() }
}
