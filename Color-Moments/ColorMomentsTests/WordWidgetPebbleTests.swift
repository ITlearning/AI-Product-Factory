import SwiftUI
import XCTest
@testable import ColorMoments

/// 9차 — 위젯 「주웠어요」 조약돌은 앱이 구운 진짜 조약돌. 판·정지점이 바뀔 때만 다시 굽고, 없으면 아무것도 안 그린다.
@MainActor
final class WordWidgetPebbleTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pebble-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func model(_ scene: SceneKind?, _ pick: WordWidgetModel.Pick, date: Date = Date()) -> WordWidgetModel {
        WordWidgetModel(date: date, word: scene == nil ? nil : "는개", wordID: "x", meaning: nil, scene: scene, moonAge: 9,
                        pick: pick, sentence: nil, short: nil)
    }

    private func files() -> Set<String> { Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []) }

    func testBakesRealPebbleWithShadowAndTransparentCorners() throws {
        XCTAssertTrue(WordWidgetPebble.bakeIfNeeded(today: nil, in: dir))
        XCTAssertEqual(files().count, SceneKind.allCases.count)
        let img = try XCTUnwrap(WordWidgetPebble.image(for: model(.leaves, .picked), in: dir)?.cgImage)
        XCTAssertEqual(img.width, Int(WordWidgetPebble.canvas * 3), accuracy: 2)
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try XCTUnwrap(CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        func at(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
            let i = (y * w + x) * 4
            return (Int(px[i]), Int(px[i + 1]), Int(px[i + 2]), Int(px[i + 3]))
        }
        XCTAssertEqual(at(0, 0).a, 0, "모서리는 비어 있어야 하늘이 비친다")
        let c = at(w / 2, h / 2)
        XCTAssertEqual(c.a, 255, "가운데는 돌")
        var lum: [Int] = []
        for y in stride(from: h / 4, to: 3 * h / 4, by: 2) where at(w / 2, y).a == 255 {
            let p = at(w / 2, y)
            lum.append(p.r + p.g + p.b)
        }
        XCTAssertGreaterThan((lum.max() ?? 0) - (lum.min() ?? 0), 40, "돌에 빛·그늘 결이 있어야 한다(납작한 타원이 아니라)")
    }

    func testBakesOneWhitePebblePerSceneOnlyOnce() throws {
        var renders = 0
        func count(_ s: [Float], _ shape: SoftPebbleShape, _ scale: CGFloat) -> CGImage? {
            renders += 1
            XCTAssertEqual(s, WordWidgetPebble.whiteStops, "조약돌은 흰빛 한 가지")
            return WordWidgetPebble.render(s, shape, 1)
        }
        XCTAssertTrue(WordWidgetPebble.bakeIfNeeded(today: nil, in: dir, render: count))
        XCTAssertEqual(renders, SceneKind.allCases.count)
        XCTAssertFalse(WordWidgetPebble.bakeIfNeeded(today: nil, in: dir, render: count))
        XCTAssertEqual(renders, SceneKind.allCases.count, "있는 건 다시 굽지 않는다")
        XCTAssertTrue(files().filter { $0.hasPrefix("pebble-day-") }.isEmpty, "그날 색 조약돌은 굽지 않는다")
        XCTAssertNotNil(WordWidgetPebble.image(for: model(.rain, .picked, date: Date().addingTimeInterval(-86_400 * 2)), in: dir))
    }

    func testStaleEditionsAreRemoved() {
        let old = ["pebble-scene-rain-e0.png", "pebble-day-2026-10-01-ab-e0.png", "sky-rain-small-e5.jpg"]
        let cur = WordWidgetPebble.sceneFile(.rain)
        XCTAssertEqual(Set(WordWidgetPebble.stale(old + [cur], today: nil)), Set(old.prefix(2)))
        XCTAssertNotEqual(WordWidgetPebble.sceneFile(.rain, edition: 1), WordWidgetPebble.sceneFile(.rain, edition: 2))
    }

    func testNoImageDrawsNothing() {
        XCTAssertNil(WordWidgetPebble.image(for: model(.rain, .picked), in: dir))
        XCTAssertNil(WordWidgetPebble.image(for: model(.rain, .picked), in: nil))
    }

    func testEverySceneUsesTheSameWhite() {
        for k in SceneKind.allCases { XCTAssertEqual(WordWidgetPebble.sceneStops(k), WordWidgetPebble.whiteStops, k.rawValue) }
        XCTAssertEqual(WordWidgetPebble.whiteStops.count, 12)
    }

    // MARK: 눈으로 보기 — SKY9B_DIR(+SKY9B_TAG)

    /// 하늘 위 위젯 — 맑은 낮·낙엽·밤·비, 주운 직후·1.5초 뒤. 알약 바탕과 글자의 대비(그림자 빼고)를 표로.
    func testDumpPickedWidgets() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["SKY9B_DIR"] else { throw XCTSkip("SKY9B_DIR 없음") }
        let tag = env["SKY9B_TAG"] ?? "now"
        let skyDir = dir.appendingPathComponent("sky")
        WordWidgetSky.bakeIfNeeded(in: skyDir)
        WordWidgetPebble.bakeIfNeeded(today: nil, in: dir)
        WordWidgetPebble.bakeIfNeeded(today: nil)
        let text = WordWidgetText.cached
        var picks: [(SceneKind, WordEntry)] = []
        for kind in [SceneKind.sun, .leaves, .stars, .rain] {
            if let w = BundledWordSource.cached.first(where: { SceneKind.of($0) == kind }) { picks.append((kind, w)) }
        }
        var rows: [AnyView] = []
        var report: [String] = []
        for (kind, w) in picks {
            let sky = try XCTUnwrap(WordWidgetSky.image(for: kind, in: skyDir))
            var cells: [AnyView] = []
            for pick in [WordWidgetModel.Pick.open, .justPicked, .picked] {
                let m = WordWidgetModel(date: Date(), word: w.word, wordID: w.id, meaning: w.meaning, scene: kind, moonAge: 9, pick: pick,
                                        sentence: text?.sentence(w.word, id: w.id, scene: kind), short: nil)
                cells.append(AnyView(ZStack {
                    Image(uiImage: sky).resizable().scaledToFill()
                    WordWidgetSmall(model: m, style: .wash, text: text, drawsBackground: false) { _ in WordPickLabel(text?.pick ?? "") }
                }
                .frame(width: 170, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))))
            }
            rows.append(AnyView(HStack(spacing: 10) { ForEach(cells.indices, id: \.self) { cells[$0] } }))
            report.append(String(format: "%@ 알약 글자 대비 %.2f:1 (그림자 빼고)", kind.rawValue, pillContrast(sky)))
        }
        let sheet = VStack(spacing: 10) { ForEach(rows.indices, id: \.self) { rows[$0] } }.padding(10).background(Color.black)
        let r = ImageRenderer(content: sheet.environment(\.colorScheme, .dark))
        r.scale = 2
        try XCTUnwrap(r.uiImage?.pngData()).write(to: URL(fileURLWithPath: out).appendingPathComponent("widget-picked-\(tag).png"))
        let zoom = ImageRenderer(content: VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { rows[$0].frame(width: 530, height: 170).clipped() }
        }.frame(width: 530).background(Color.black).environment(\.colorScheme, .dark))
        zoom.scale = 3
        if let img = zoom.uiImage?.cgImage, let crop = img.cropping(to: CGRect(x: 0, y: 0, width: img.width, height: img.height)) {
            try XCTUnwrap(UIImage(cgImage: crop).pngData()).write(to: URL(fileURLWithPath: out).appendingPathComponent("widget-picked-\(tag)-3x.png"))
        }
        print("SKY9B 알약\n" + report.joined(separator: "\n"))
        try report.joined(separator: "\n").write(toFile: out + "/pill-contrast-\(tag).txt", atomically: true, encoding: .utf8)
    }

    /// 알약 자리(왼쪽 위 12~92pt × 17~47pt) 하늘 평균 위에 흰 14% 바탕, 흰 92% 글자.
    private func pillContrast(_ sky: UIImage) -> Double {
        guard let cg = sky.cgImage else { return 0 }
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return 0 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let s = Double(w) / 170
        func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        var worst = Double.infinity
        for y in stride(from: Int(17 * s), to: Int(47 * s), by: 2) {
            for x in stride(from: Int(12 * s), to: Int(92 * s), by: 2) {
                let i = (y * w + x) * 4
                var bg = 0.0, fg = 0.0
                for (k, wt) in [(0, 0.2126), (1, 0.7152), (2, 0.0722)] {
                    let b = Double(px[i + k]) / 255 * 0.86 + 0.14
                    bg += wt * lin(b)
                    fg += wt * lin(b * 0.08 + 0.92)
                }
                worst = min(worst, (fg + 0.05) / (bg + 0.05))
            }
        }
        return worst
    }
}
