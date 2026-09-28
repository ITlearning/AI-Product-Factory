#if DEBUG
import XCTest
@testable import ColorMoments

final class AssetDiagnosticsTests: XCTestCase {

    private func m(_ name: String, asset: String? = nil, cloud: String? = nil) -> Moment {
        Moment(capturedAt: Date(), colorHex: "#101010", fileName: name, source: .app, assetID: asset, cloudID: cloud)
    }

    func testClassifiesEveryBranch() {
        let moments = [
            m("shot-1.jpg"),                                   // ①
            m("shot-2.jpg"),                                   // ②
            m("library-3.jpg", asset: "L3"),                   // ③ library
            m("shot-4.jpg", asset: "A4"),                      // ③ 그 밖
            m("asset-5", asset: "A5"),                         // ④
            m("asset-6", asset: "A6"),                         // ⑤
            m("asset-7", asset: "A7", cloud: "C7"),            // 정상
            m("remote-8", cloud: "C8"),                        // 받은 기록
        ]
        let c = AssetDiagnostics.classify(moments, found: ["A6", "A7"],
                                          onDisk: ["shot-1.jpg", "library-3.jpg", "shot-4.jpg"])
        XCTAssertEqual(c.fileOnly, 1)
        XCTAssertEqual(c.fileOnlyMissing, 1)
        XCTAssertEqual(c.lostWithLibraryFile, 1)
        XCTAssertEqual(c.lostWithOtherFile, 1)
        XCTAssertEqual(c.lostNoFile, 1)
        XCTAssertEqual(c.foundNoCloud, 1)
        XCTAssertEqual(c.noCloud, 6)
        XCTAssertEqual(c.examples.count, 5, "예시는 상한까지만")
        XCTAssertEqual(c.examples.first, "① shot-1.jpg · app")
    }
}
#endif
