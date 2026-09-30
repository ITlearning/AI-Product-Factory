import XCTest
import UIKit
@testable import ColorMoments

final class PhotoLabelerTests: XCTestCase {

    private func fixture(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures"))
        return try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
    }

    func testBlossomPhotoIsRecognised() throws {
        guard let labels = PhotoLabeler.labels(for: try fixture("IMG_5005")) else {
            throw XCTSkip("이 환경에서 Vision 분류가 돌지 않는다")
        }
        XCTAssertTrue(Set(labels).isSuperset(of: ["flower"]) || labels.contains("blossom"),
                      "벚꽃 사진(IMG_5005)인데 꽃이 안 잡혔다: \(labels)")
    }

    private var vocabulary: Set<String> {
        get async { Set(await BundledWordSource().words().flatMap(\.subjects)) }
    }

    func testWordLabelsLoosenButStrayFoodStaysOut() async throws {
        let sea = try fixture("IMG_2788"), leaves = try fixture("IMG_6245")
        guard let strict = PhotoLabeler.labels(for: sea) else { throw XCTSkip("이 환경에서 Vision 분류가 돌지 않는다") }
        let vocab = await vocabulary
        let loose = try XCTUnwrap(PhotoLabeler.labels(for: sea, vocabulary: vocab))
        XCTAssertFalse(strict.contains("beach"))
        XCTAssertTrue(loose.contains("beach"), "바다 사진(IMG_2788)의 해변은 단어 라벨이라 한 단계 느슨하게 받는다: \(loose)")
        XCTAssertTrue(Set(strict).isSubset(of: loose), "확실한 라벨은 그대로 남는다")
        let leafLabels = try XCTUnwrap(PhotoLabeler.labels(for: leaves, vocabulary: vocab))
        XCTAssertFalse(leafLabels.contains("food"), "70%로 다 풀면 food 가 거의 모든 사진에 붙는다 — 확신도 하한이 거른다")
    }

    func testSameSceneIsNearAndOtherPhotosAreFar() throws {
        let sea = try fixture("IMG_2788"), blossom = try fixture("IMG_5005")
        let nudged = try XCTUnwrap(sea.cropping(to: CGRect(x: sea.width / 20, y: sea.height / 20,
                                                            width: sea.width * 9 / 10, height: sea.height * 9 / 10)))
        guard let same = PhotoLabeler.distance(sea, nudged), let other = PhotoLabeler.distance(sea, blossom) else {
            throw XCTSkip("이 환경에서 특징값을 못 뽑는다")
        }
        XCTAssertLessThan(same, PhotoLabeler.sameSceneDistance, "조금 어긋나게 다시 찍은 같은 장면")
        XCTAssertGreaterThan(other, PhotoLabeler.sameSceneDistance, "바다와 벚꽃")
    }

    func testWeatherFromLabels() {
        XCTAssertEqual(Weather.inferred(from: ["sky", "snow", "cloudy"]), .snow)
        XCTAssertEqual(Weather.inferred(from: ["sky", "cloudy", "blue_sky"]), .clear,
                       "파란 하늘이 보이면 흰 구름이 있어도 맑음 — 먹장구름이 붙으면 영구히 틀린다")
        XCTAssertEqual(Weather.inferred(from: ["sky", "cloudy"]), .cloudy)
        XCTAssertEqual(Weather.inferred(from: ["blue_sky"]), .clear)
        XCTAssertNil(Weather.inferred(from: ["laptop"]), "사진으로 알 수 없으면 모른다고 둔다")
    }
}
