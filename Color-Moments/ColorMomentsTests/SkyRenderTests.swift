import SwiftUI
import XCTest
@testable import ColorMoments

/// 스파이크 하늘 — 셰이더가 실제로 그려지고, 글자 자리에서 흰 64% 글자가 4.5:1 을 지키는지.
@MainActor
final class SkyRenderTests: XCTestCase {
    private let full = CGSize(width: 393, height: 852)

    func testEverySkyKeepsTextContrast() throws {
        let sizes: [(SkyQuality, CGSize)] = [(.hero, CGSize(width: 354, height: 232)), (.card, CGSize(width: 354, height: 96))]
        for scene in SkyScene.allCases {
            for (q, size) in sizes {
                for age in [3.0, 14.8] {
                    let frame = SkyFrame(scene: scene, quality: q, size: size, moonAge: age)
                    let out = try XCTUnwrap(SkySnapshot.image(frame, scale: 2, t: SceneArt.stillPhase), "\(scene) \(q)")
                    let c = SkyDump.contrast(out.image, frame.textRects, size)
                    XCTAssertGreaterThanOrEqual(c, 4.5, "\(scene.name) \(q.rawValue) 달 \(age)")
                }
            }
        }
    }

    func testMeteorIsDeterministicAndPaced() throws {
        let size = CGSize(width: 354, height: 232)
        var starts: [Double] = []
        var t = 0.0, wasOn = false
        while t < 1200 {
            let m = SkyMeteor.at(t: t, size: size)
            XCTAssertEqual(m, SkyMeteor.at(t: t, size: size))
            if m != nil, !wasOn { starts.append(t) }
            wasOn = m != nil
            t += 1.0 / 60
        }
        XCTAssertGreaterThan(starts.count, 30)
        for (a, b) in zip(starts, starts.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b - a, 10, "간격")
            XCTAssertLessThanOrEqual(b - a, 40, "간격")
        }
        let s = try XCTUnwrap(starts.first)
        let mid = try XCTUnwrap(SkyMeteor.at(t: s + 0.18, size: size))
        XCTAssertLessThan(mid.direction.dx, 0, "왼쪽으로")
        XCTAssertGreaterThan(mid.direction.dy, 0, "아래로")

        let frame = SkyFrame(scene: .clearNight, quality: .full, size: full, textRects: SkyFullPage.textRects(in: full))
        let at = s + 0.18
        let a = try XCTUnwrap(SkySnapshot.image(frame, scale: 1, t: at, meteors: true)).image
        let b = try XCTUnwrap(SkySnapshot.image(frame, scale: 1, t: at, meteors: true)).image
        let none = try XCTUnwrap(SkySnapshot.image(frame, scale: 1, t: at, meteors: false)).image
        XCTAssertEqual(pixels(a), pixels(b), "같은 t → 같은 그림")
        XCTAssertNotEqual(pixels(a), pixels(none), "별똥별이 보인다")
        XCTAssertGreaterThanOrEqual(SkyDump.contrast(a, frame.textRects, full), 4.5, "별똥별이 지나가도 글자 대비")
    }

    func testMoonPhaseFollowsAge() throws {
        func lit(_ age: Double) throws -> (area: Int, meanX: Double) {
            let size = CGSize(width: 354, height: 232)
            let frame = SkyFrame(scene: .clearNight, quality: .hero, size: size, textRects: [], moonAge: age, moonScale: 2)
            let img = try XCTUnwrap(SkySnapshot.image(frame, scale: 2, t: SceneArt.stillPhase)).image
            let l = frame.light
            let px = pixels(img), w = img.width
            var area = 0, sx = 0.0
            let r = Int(l.radius * 2 * 1.05), cx = Int(l.center.x * 2), cy = Int(l.center.y * 2)
            for y in max(cy - r, 0)..<min(cy + r, img.height) {
                for x in max(cx - r, 0)..<min(cx + r, w) {
                    let i = (y * w + x) * 4
                    if Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) > 3 * 150 { area += 1; sx += Double(x - cx) }
                }
            }
            return (area, area > 0 ? sx / Double(area) : 0)
        }
        let crescent = try lit(3), quarter = try lit(7.4), fullMoon = try lit(14.8), waning = try lit(22.1)
        XCTAssertGreaterThan(fullMoon.area, quarter.area)
        XCTAssertGreaterThan(quarter.area, crescent.area)
        XCTAssertGreaterThan(crescent.area, 0)
        XCTAssertGreaterThan(quarter.meanX, 0, "상현은 오른쪽이 밝다")
        XCTAssertLessThan(waning.meanX, 0, "하현은 왼쪽이 밝다")
        print("SKY2 달 밝은 면적 초승 \(crescent.area) 상현 \(quarter.area) 보름 \(fullMoon.area)")
    }

    func testCloudsAreNotMarchedEveryFrame() {
        let frame = SkyFrame(scene: .nightCloudy, quality: .hero, size: CGSize(width: 354, height: 232))
        let ultra = SkySnapshot.cloudRenders(frame, tier: .ultra, seconds: 1)
        let high = SkySnapshot.cloudRenders(frame, tier: .high, seconds: 1)
        let mid = SkySnapshot.cloudRenders(frame, tier: .mid, seconds: 1)
        let low = SkySnapshot.cloudRenders(frame, tier: .low, seconds: 1)
        XCTAssertEqual(ultra.frames, 120)
        XCTAssertEqual(mid.frames, 60)
        XCTAssertLessThanOrEqual(ultra.renders, 120 / 4 + 2)
        XCTAssertLessThanOrEqual(high.renders, 120 / 6 + 2)
        XCTAssertLessThanOrEqual(mid.renders, 60 / 4 + 2)
        XCTAssertLessThanOrEqual(low.renders, 60 / 8 + 2)
        print("SKY2 구름/초 ultra \(ultra.renders)/\(ultra.frames) high \(high.renders)/\(high.frames) mid \(mid.renders)/\(mid.frames) low \(low.renders)/\(low.frames)")
    }

    func testTierBudgets() {
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra).fps, 120)
        XCTAssertEqual(SkyBudget(.hero, tier: .high).fps, 120)
        XCTAssertEqual(SkyBudget(.hero, tier: .mid).fps, 60)
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra, lowPower: true).fps, 60)
        let hot = SkyBudget(.hero, tier: .ultra, thermal: .serious)
        XCTAssertEqual(hot.fps, 30)
        XCTAssertEqual(hot.tier, .high)
        XCTAssertEqual(SkyBudget(.hero, tier: .low).farSteps, 0)
        XCTAssertEqual(SkyBudget(.hero, tier: .low).raySamples, 0)
    }

    // MARK: - 눈으로 보는 PNG (TEST_RUNNER_SKY2_DIR 가 있을 때만)

    func testDumpSky2() throws {
        guard let dir = ProcessInfo.processInfo.environment["SKY2_DIR"] else { throw XCTSkip("SKY2_DIR 없음") }
        let url = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let rects = SkyFullPage.textRects(in: full)
        let phases: [(String, Double)] = [("1-crescent", 3.2), ("2-first-quarter", 7.4), ("3-full", 14.8),
                                          ("4-last-quarter", 22.1), ("5-waning-crescent", 26.3)]
        for (name, age) in phases {
            let f = SkyFrame(scene: .clearNight, quality: .full, size: full, textRects: rects, moonAge: age)
            let img = try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: SceneArt.stillPhase)).image
            save(render(SkyFullPage(scene: .clearNight, size: full, image: img)), url.appendingPathComponent("moon-\(name).png"))
            let big = SkyFrame(scene: .clearNight, quality: .full, size: full, textRects: rects, moonAge: age, moonScale: 4)
            let bimg = try XCTUnwrap(SkySnapshot.image(big, scale: 3, t: SceneArt.stillPhase)).image
            let l = big.light
            let r = l.radius * 1.35 * 3
            if let crop = bimg.cropping(to: CGRect(x: l.center.x * 3 - r, y: l.center.y * 3 - r, width: 2 * r, height: 2 * r)) {
                save(UIImage(cgImage: crop), url.appendingPathComponent("moon-close-\(name).png"))
            }
        }
        let cloudy = SkyFrame(scene: .nightCloudy, quality: .full, size: full, textRects: rects, moonAge: 14.8)
        let ci = try XCTUnwrap(SkySnapshot.image(cloudy, scale: 3, t: SceneArt.stillPhase)).image
        save(render(SkyFullPage(scene: .nightCloudy, size: full, image: ci)), url.appendingPathComponent("cloudy-full-moon.png"))
        for i in 0..<2 {
            var t = 0.0, n = 0, start = 0.0
            while t < 2000 {
                if SkyMeteor.at(t: t, size: full) != nil {
                    n += 1
                    if n == 1 + 3 * i { start = t; break }
                    t += 2
                } else { t += 1.0 / 60 }
            }
            let f = SkyFrame(scene: .clearNight, quality: .full, size: full, textRects: rects, moonAge: 10)
            for (j, dt) in [0.1, 0.2, 0.3].enumerated() {
                let img = try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: start + dt, meteors: true)).image
                save(render(SkyFullPage(scene: .clearNight, size: full, image: img)), url.appendingPathComponent("meteor-\(i)-\(j).png"))
            }
        }
        let hero = SkyFrame(scene: .clearNight, quality: .hero, size: CGSize(width: 354, height: 232), moonAge: 5)
        let h = try XCTUnwrap(SkySnapshot.image(hero, scale: 3, t: SceneArt.stillPhase)).image
        save(render(SkyCard(scene: .clearNight, size: .hero, new: true, image: h)), url.appendingPathComponent("hero-clear-night.png"))
        for tier in SkyTier.allCases {
            let f = SkyFrame(scene: .nightCloudy, quality: .hero, size: CGSize(width: 354, height: 232), moonAge: 12)
            let img = try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: SceneArt.stillPhase, tier: tier)).image
            save(render(SkyCard(scene: .nightCloudy, size: .hero, new: true, image: img)),
                 url.appendingPathComponent("tier-\(tier.rawValue)-\(tier.name).png"))
        }
    }

    private func render(_ v: some View) -> UIImage? {
        let r = ImageRenderer(content: v.environment(\.colorScheme, .dark))
        r.scale = 3
        return r.uiImage
    }

    private func save(_ img: UIImage?, _ url: URL) {
        if let data = img?.pngData() { try? data.write(to: url) }
    }

    private func pixels(_ img: CGImage) -> [UInt8] {
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return px
    }
}
