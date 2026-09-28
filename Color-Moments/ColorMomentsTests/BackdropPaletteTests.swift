import XCTest
@testable import ColorMoments

final class BackdropPaletteTests: XCTestCase {

    private let white = ColorExtractor.RGB(r: 1, g: 1, b: 1)

    func testUsesOnlyGiftedPebbleColors() {
        let hexes = BackdropPalette.sourceHexes(
            dayKeys: ["2026-09-22", "2026-09-21", "2026-09-20"],
            isGifted: { $0 <= "2026-09-21" },
            pebbleHexes: { ["2026-09-22": ["#FF0000"], "2026-09-21": ["#00FF00", "#00ff00"], "2026-09-20": ["#0000FF"]][$0] ?? [] })
        XCTAssertEqual(hexes, ["#00FF00", "#0000FF"], "받기 전 하루의 색은 쓰지 않고, 같은 색은 한 번만")
    }

    func testFallsBackToWarmPaletteWithoutPebbles() {
        XCTAssertEqual(BackdropPalette.sourceHexes(dayKeys: [], isGifted: { _ in true }, pebbleHexes: { _ in [] }),
                       Tone.backdropWarm)
        XCTAssertEqual(BackdropPalette.sourceHexes(dayKeys: ["2026-09-22"], isGifted: { _ in false },
                                                   pebbleHexes: { _ in ["#FF0000"] }),
                       Tone.backdropWarm, "받은 조약돌이 없으면 따뜻한 중간 톤")
    }

    func testCapsColorCount() {
        let hexes = BackdropPalette.sourceHexes(dayKeys: ["a", "b"], isGifted: { _ in true },
                                                pebbleHexes: { $0 == "a" ? ["#111111", "#222222", "#333333"] : ["#444444", "#555555"] })
        XCTAssertEqual(hexes.count, BackdropPalette.maxColors)
    }

    func testDarkMeshKeepsWhiteTextContrast() {
        let samples = ["#FFFFFF", "#FFD640", "#FF3B30", "#34C759", "#9DB7CF", "#E7B98A"] + Tone.backdropWarm
        for hex in samples {
            for bg in BackdropPalette.mesh(BackdropPalette.dark([hex]), bottom: 0.45) {
                let c = BackdropPalette.contrast(text: white, alpha: Tone.secondaryAlpha, over: bg)
                XCTAssertGreaterThanOrEqual(c, 4.5, "\(hex) 위 보조 글자 대비 \(c)")
            }
        }
    }

    func testDarkToneIsDesaturated() {
        let red = BackdropPalette.dark(["#FF0000"])[0]
        XCTAssertLessThanOrEqual(PebbleNaming.saturation(red), 0.42 + 1e-9)
        XCTAssertLessThanOrEqual(PebbleNaming.value(red), 0.22 + 1e-9)
    }
}
