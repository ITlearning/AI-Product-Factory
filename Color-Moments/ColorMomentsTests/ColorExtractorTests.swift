import CoreImage
import XCTest
@testable import ColorMoments

/// 색 추출기 회귀 테스트.
///
/// 픽스처는 Tabber가 2026-09-22에 보낸 사진 11장(320px로 줄인 것)이다.
/// 기대값은 그날 채택 결정을 내릴 때 눈으로 확인한 값이므로, 여기가 깨지면
/// **알고리즘이 그날의 판단과 달라졌다**는 뜻이다. 값을 고치기 전에 사진을 다시 볼 것.
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

    /// 2026-09-22 채택 시점의 값. 사진을 다시 보지 않고 고치지 말 것.
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

    /// 히스토그램을 쓰는 유일한 이유. 같은 사진은 샘플 해상도가 달라도 같은 색을 내야 한다.
    /// k-means 는 여기서 IMG_5471 이 38/255 벌어져 탈락했다.
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

    /// 같은 입력을 두 번 돌리면 완전히 같아야 한다.
    func testRepeatedRunsAreIdentical() throws {
        let image = try fixture("IMG_5005")
        let a = ColorExtractor.symbolicColor(for: image)
        let b = ColorExtractor.symbolicColor(for: image)
        XCTAssertEqual(a, b)
    }

    /// 탭 보정 UI가 쓸 후보 목록.
    func testCandidatesAreProvidedAndOrdered() throws {
        let cands = ColorExtractor.candidates(for: try fixture("IMG_5005"))
        XCTAssertGreaterThanOrEqual(cands.count, 3, "후보가 너무 적으면 탭 UI가 성립하지 않는다")
        XCTAssertEqual(cands.first?.color.hex, ColorExtractor.symbolicColor(for: try fixture("IMG_5005")).hex,
                       "첫 후보는 자동 선택값과 같아야 한다")
        for i in 1..<cands.count {
            XCTAssertLessThanOrEqual(cands[i].weight, cands[i - 1].weight + 1e-9, "무게 내림차순이어야 한다")
        }
    }

    /// 자동 추출의 상한. 벚꽃 사진의 정답(분홍)은 어떤 자동 방식으로도 안 나온다 —
    /// 그래서 탭 보정이 v1 필수다. 탭하면 그 지점의 색이 나와야 한다.
    func testTapCorrectionReadsTheTappedRegion() throws {
        let image = try fixture("IMG_5005")
        let auto = ColorExtractor.symbolicColor(for: image)
        // 위쪽 1/6 지점은 하늘이다. 자동값(나뭇가지 계열)과 달라야 탭이 의미가 있다.
        let sky = ColorExtractor.color(in: image, atNormalized: CGPoint(x: 0.5, y: 0.08))
        XCTAssertGreaterThan(channelDelta(auto.hex, sky.hex), 20,
                             "탭이 자동값과 같은 색만 낸다면 보정 수단이 아니다 (auto \(auto.hex), sky \(sky.hex))")
        XCTAssertGreaterThan(sky.b, sky.r, "하늘 지점은 파랑이 빨강보다 커야 한다 (\(sky.hex))")
    }

    /// 어둠컷이 실제로 어두운 쪽을 버리는가.
    func testDarkCutRemovesDarkestQuarter() {
        let px = (0..<100).map { ColorExtractor.RGB(r: Double($0) / 100, g: Double($0) / 100, b: Double($0) / 100) }
        let kept = ColorExtractor.afterDarkCut(px)
        XCTAssertEqual(kept.count, 75)
        XCTAssertGreaterThanOrEqual(kept.first!.value, 0.24)
    }
}
