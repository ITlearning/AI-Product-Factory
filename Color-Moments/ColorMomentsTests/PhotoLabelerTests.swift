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

    func testWeatherFromLabels() {
        XCTAssertEqual(Weather.inferred(from: ["sky", "snow", "cloudy"]), .snow)
        XCTAssertEqual(Weather.inferred(from: ["sky", "cloudy", "blue_sky"]), .clear,
                       "파란 하늘이 보이면 흰 구름이 있어도 맑음 — 먹장구름이 붙으면 영구히 틀린다")
        XCTAssertEqual(Weather.inferred(from: ["sky", "cloudy"]), .cloudy)
        XCTAssertEqual(Weather.inferred(from: ["blue_sky"]), .clear)
        XCTAssertNil(Weather.inferred(from: ["laptop"]), "사진으로 알 수 없으면 모른다고 둔다")
    }
}
