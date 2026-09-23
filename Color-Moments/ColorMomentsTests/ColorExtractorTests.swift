import CoreImage
import XCTest
@testable import ColorMoments

final class ColorExtractorTests: XCTestCase {

    private func fixture(_ name: String) throws -> CIImage {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures"),
            "픽스처 Fixtures/\(name).jpg 없음")
        return try XCTUnwrap(CIImage(contentsOf: url), "\(name) 디코드 실패")
    }

    private func channelDelta(_ a: String, _ b: String) -> Int {
        func v(_ s: String, _ i: Int) -> Int {
            Int(s[s.index(s.startIndex, offsetBy: i)...s.index(s.startIndex, offsetBy: i + 1)], radix: 16) ?? 0
        }
        return max(abs(v(a, 1) - v(b, 1)), abs(v(a, 3) - v(b, 3)), abs(v(a, 5) - v(b, 5)))
    }

    private let expected: [(String, String)] = [
        ("IMG_2493", "#9D917C"),
        ("IMG_2788", "#3873B5"),
        ("IMG_4794", "#496A92"),
        ("IMG_5005", "#6C6362"),
        ("IMG_5098", "#8C9788"),
        ("IMG_5278", "#2A2812"),
        ("IMG_5354", "#B4B1A7"),
        ("IMG_5471", "#85847B"),
        ("IMG_5874", "#B0B7BA"),
        ("IMG_6233", "#24365F"),
        ("IMG_6245", "#5E82D6"),
    ]

    func testSymbolicColorMatchesRecordedValues() throws {
        for (name, hex) in expected {
            let got = ColorExtractor.symbolicColor(for: try fixture(name)).hex
            XCTAssertLessThanOrEqual(channelDelta(got, hex), 3,
                                     "\(name): 기대 \(hex), 실제 \(got)")
        }
    }

    func testDeterministicAcrossSampleResolutions() throws {
        for (name, _) in expected {
            let image = try fixture(name)
            let base = ColorExtractor.histogramColors(
                ColorExtractor.afterDarkCut(ColorExtractor.sample(image, side: 96)), count: 1).first!.hex
            for side in [64, 140, 240] {
                let other = ColorExtractor.histogramColors(
                    ColorExtractor.afterDarkCut(ColorExtractor.sample(image, side: side)), count: 1).first!.hex
                XCTAssertLessThanOrEqual(channelDelta(base, other), 6,
                                         "\(name) @\(side)px: \(base) vs \(other)")
            }
        }
    }

    func testRepeatedRunsAreIdentical() throws {
        let image = try fixture("IMG_5005")
        let a = ColorExtractor.symbolicColor(for: image)
        let b = ColorExtractor.symbolicColor(for: image)
        XCTAssertEqual(a, b)
    }

    func testDarkCutRemovesDarkestQuarter() {
        let px = (0..<100).map { ColorExtractor.RGB(r: Double($0) / 100, g: Double($0) / 100, b: Double($0) / 100) }
        let kept = ColorExtractor.afterDarkCut(px)
        XCTAssertEqual(kept.count, 75)
        XCTAssertGreaterThanOrEqual(kept.first!.value, 0.24)
    }
}
