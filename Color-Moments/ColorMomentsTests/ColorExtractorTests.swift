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

    func testPaletteStartsWithSymbolicColor() throws {
        for (name, _) in expected {
            let image = try fixture(name)
            let palette = ColorExtractor.palette(for: image)
            XCTAssertEqual(palette.first?.hex, ColorExtractor.symbolicColor(for: image).hex, "\(name): 첫 색이 대표 색이어야 홈·타임라인과 어긋나지 않는다")
            XCTAssertEqual(palette.map(\.share).reduce(0, +), 100, "\(name): 비중 합 100")
            XCTAssertLessThanOrEqual(palette.count, 4)
            let rest = palette.dropFirst().map(\.share)
            XCTAssertEqual(rest, rest.sorted(by: >), "\(name): 대표 색 뒤로는 비중 순")
        }
    }

    func testPaletteColorsAreDistinct() throws {
        for (name, _) in expected {
            let p = ColorExtractor.palette(for: try fixture(name))
            for i in p.indices { for j in p.indices where j > i {
                XCTAssertGreaterThan(channelDelta(p[i].hex, p[j].hex), 25, "\(name): \(p[i].hex)·\(p[j].hex) — 거의 같은 색을 두 번 고르면 조약돌이 단색이 된다")
            }}
        }
    }

    func testFlatImageGivesSingleColor() {
        let flat = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.52)).cropped(to: CGRect(x: 0, y: 0, width: 200, height: 200))
        let p = ColorExtractor.palette(for: flat)
        XCTAssertEqual(p.count, 1, "한 색뿐인 사진 — 빈 팔레트도, 가짜 곁들임도 없이 한 색")
        XCTAssertEqual(p.first?.share, 100)
    }

    func testPaletteColorEncodingRoundTrips() {
        let c = PaletteColor(hex: "#E9B07D", share: 76)
        XCTAssertEqual(c.encoded, "#E9B07D:76")
        XCTAssertEqual(PaletteColor(encoded: c.encoded), c)
        XCTAssertNil(PaletteColor(encoded: "E9B07D"), "모양이 어긋난 값은 버린다")
        XCTAssertNil(PaletteColor(encoded: "#E9B07D:x"))
    }
}
