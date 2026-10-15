import CoreImage
import Metal
import SwiftUI
import XCTest
@testable import ColorMoments

/// 스파이크 하늘 — 셰이더가 실제로 그려지고, 글자 자리 대비를 지키는지.
/// 밤·흐린 밤·비는 하늘만으로 작은 글자(흰 64%) 4.5:1. 밝은 하늘은 실제 글자 + 그림자(.skyText)를 얹은 그림에서
/// 작은 글자(흰 92%)·큰 말(명조 48 이상, 흰 92%) 3:1 — DESIGN.md §2.1.1.
@MainActor
final class SkyRenderTests: XCTestCase {
    private let full = CGSize(width: 393, height: 852)

    func testEverySkyKeepsTextContrast() throws {
        let sizes: [(SkyQuality, CGSize, SkyTexts?)] = [(.hero, CGSize(width: 354, height: 232), nil),
                                                         (.card, CGSize(width: 354, height: 96), nil),
                                                         (.full, full, SkyFullPage.texts(in: full))]
        var log: [String] = []
        for scene in SkyScene.allCases {
            for (q, size, texts) in sizes {
                for age in scene.isNight ? [3.0, 14.8] : [14.8] {
                    for t in [SceneArt.stillPhase, SceneArt.stillPhase + 40] {
                        let frame = SkyFrame(scene: scene, quality: q, size: size, texts: texts, moonAge: age)
                        let tag = "\(scene.name) \(q.rawValue) 달 \(age) t \(t)"
                        if scene.brightSky {
                            let out = try XCTUnwrap(SkySnapshot.image(frame, scale: 3, t: t), tag)
                            let c = try shadedContrast(out.image, frame)
                            XCTAssertGreaterThanOrEqual(c.small, 3, "작은 글자(그림자 포함) \(tag)")
                            XCTAssertGreaterThanOrEqual(c.big, 3, "큰 말(그림자 포함) \(tag)")
                            log.append(String(format: "%@ %@ 그림자 포함 작은 %.2f 큰 %.2f", scene.name, q.rawValue, c.small, c.big))
                        } else {
                            let out = try XCTUnwrap(SkySnapshot.image(frame, scale: 2, t: t), tag)
                            let small = SkyDump.contrast(out.image, frame.texts.small, size, alpha: frame.smallTextAlpha)
                            let big = SkyDump.contrast(out.image, frame.texts.big, size, alpha: Tone.primaryAlpha)
                            XCTAssertGreaterThanOrEqual(small, frame.smallTextContrast, "작은 글자 \(tag)")
                            XCTAssertGreaterThanOrEqual(big, 3, "큰 말 \(tag)")
                            log.append(String(format: "%@ %@ 달%.0f 작은 %.2f 큰 %.2f", scene.name, q.rawValue, age, small, big))
                        }
                    }
                }
            }
        }
        print("SKY7 대비\n" + log.joined(separator: "\n"))
    }

    /// 실제 글자(+ .skyText 그림자)를 얹어 그린 뒤, 글자 획 바로 옆(2pt 안, 획 밖) 배경 위에서 그 글자 색의 대비 최저값.
    /// 큰 말 자리 안이면 큰 말(primary), 밖이면 작은 글자(smallTextAlpha).
    private func shadedContrast(_ sky: CGImage, _ frame: SkyFrame) throws -> (small: Double, big: Double) {
        let size = frame.size
        let clear = try XCTUnwrap(CGContext(data: nil, width: sky.width, height: sky.height, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage())
        func view(_ img: CGImage) -> AnyView {
            frame.quality == .full ? AnyView(SkyFullPage(scene: frame.scene, size: size, image: img))
                : AnyView(SkyCard(scene: frame.scene, size: size.height > 150 ? .hero : .row, new: true, image: img))
        }
        func draw(_ v: AnyView) throws -> (Int, Int, [UInt8]) {
            let r = ImageRenderer(content: v.environment(\.colorScheme, .dark))
            r.scale = 3
            let cg = try XCTUnwrap(r.cgImage)
            return (cg.width, cg.height, pixels(cg))
        }
        let (w, h, all) = try draw(view(sky))
        let (w2, h2, layer) = try draw(view(clear))
        XCTAssertEqual(w, w2); XCTAssertEqual(h, h2)
        var core = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) { core[i] = layer[i * 4] > 128 }
        let rad = 6
        var rowNear = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            var last = -1_000
            for x in 0..<w { if core[y * w + x] { last = x }; if x - last <= rad { rowNear[y * w + x] = true } }
            last = 1_000_000
            for x in stride(from: w - 1, through: 0, by: -1) { if core[y * w + x] { last = x }; if last - x <= rad { rowNear[y * w + x] = true } }
        }
        var near = [Bool](repeating: false, count: w * h)
        for x in 0..<w {
            var last = -1_000
            for y in 0..<h { if rowNear[y * w + x] { last = y }; if y - last <= rad { near[y * w + x] = true } }
            last = 1_000_000
            for y in stride(from: h - 1, through: 0, by: -1) { if rowNear[y * w + x] { last = y }; if last - y <= rad { near[y * w + x] = true } }
        }
        let sx = Double(w) / size.width, sy = Double(h) / size.height
        let bigRects = frame.texts.big.map { $0.insetBy(dx: -3, dy: -3) }
        var small = Double.infinity, big = Double.infinity
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                guard near[i], layer[i * 4] < 8 else { continue }
                let bg = SceneRGB(Double(all[i * 4]) / 255, Double(all[i * 4 + 1]) / 255, Double(all[i * 4 + 2]) / 255)
                let p = CGPoint(x: Double(x) / sx, y: Double(y) / sy)
                let isBig = bigRects.contains { $0.contains(p) }
                let fg = SceneRGB.white.over(bg, alpha: isBig ? Tone.primaryAlpha : frame.smallTextAlpha)
                let c = SceneRGB.contrast(fg, bg)
                if isBig { big = min(big, c) } else { small = min(small, c) }
            }
        }
        return (small, big)
    }

    func testEverySceneKindHasASky() throws {
        XCTAssertEqual(Set(SceneKind.allCases.map { SkyScene($0) }).count, SceneKind.allCases.count)
        XCTAssertEqual(SkyScene(.sun), .clearDay)
        XCTAssertEqual(SkyScene(.stars), .clearNight)
        XCTAssertEqual(SkyScene(.moon), .nightCloudy)
        XCTAssertEqual(SkyScene(.rain), .rain)
        for kind in SceneKind.allCases { XCTAssertEqual(SkyScene(kind).legacy, kind) }
    }

    /// 위젯 — 13 장면 모두 정지 그림(입자는 멈춘 한 장, EDR 없음)이 같은 t 에 같은 그림.
    func testEverySceneBakesAStillPicture() throws {
        let size = CGSize(width: 170, height: 170)
        for scene in SkyScene.allCases {
            let f = SkyFrame(scene: scene, quality: .card, size: size)
            let a = try XCTUnwrap(SkySnapshot.image(f, scale: 2, t: SceneArt.stillPhase), scene.name).image
            let b = try XCTUnwrap(SkySnapshot.image(f, scale: 2, t: SceneArt.stillPhase), scene.name).image
            let pa = pixels(a), pb = pixels(b)
            var n = 0, md = 0, x0 = Int.max, y0 = Int.max, x1 = 0, y1 = 0
            for i in stride(from: 0, to: pa.count, by: 4) {
                let d = (0..<3).map { abs(Int(pa[i + $0]) - Int(pb[i + $0])) }.max()!
                guard d > 0 else { continue }
                n += 1; md = max(md, d)
                let x = (i / 4) % a.width, y = (i / 4) / a.width
                x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y)
            }
            // GPU 부동소수 순서로 픽셀 한두 개가 1/255 흔들릴 때가 있다 — 그림이 달라진 건 아니다.
            XCTAssertLessThanOrEqual(md, 2, "\(scene.name) 같은 t → 같은 그림 — 다른 픽셀 \(n) 최대 \(md) 자리 \(x0),\(y0)~\(x1),\(y1)")
            XCTAssertLessThanOrEqual(n, 16, "\(scene.name) 같은 t → 같은 그림 — 다른 픽셀 \(n)")
        }
    }

    func testParticlesShrinkWithTier() {
        let size = CGSize(width: 354, height: 232)
        for scene in [SkyScene.rain, .drizzle, .snow, .petals, .leaves] {
            let f = SkyFrame(scene: scene, quality: .hero, size: size)
            let n = SkyTier.allCases.map { tier -> Int in let p = f.particles(SkyBudget(.hero, tier: tier)); return p.rain + p.flakes }
            XCTAssertGreaterThan(n[0], 0, scene.name)
            XCTAssertEqual(n, n.sorted(), "\(scene.name) 하 ≤ 중 ≤ 상 ≤ 최상")
            XCTAssertLessThan(n[0], n[3], scene.name)
        }
        XCTAssertEqual(SkyFrame(scene: .fog, quality: .hero, size: size).particles(SkyBudget(.hero, tier: .ultra)).flakes, 0)
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

        let frame = SkyFrame(scene: .clearNight, quality: .full, size: full, texts: SkyFullPage.texts(in: full))
        let at = s + 0.18
        let a = try XCTUnwrap(SkySnapshot.image(frame, scale: 1, t: at, meteors: true)).image
        let b = try XCTUnwrap(SkySnapshot.image(frame, scale: 1, t: at, meteors: true)).image
        let none = try XCTUnwrap(SkySnapshot.image(frame, scale: 1, t: at, meteors: false)).image
        XCTAssertEqual(pixels(a), pixels(b), "같은 t → 같은 그림")
        XCTAssertNotEqual(pixels(a), pixels(none), "별똥별이 보인다")
        XCTAssertGreaterThanOrEqual(SkyDump.contrast(a, frame.texts.small, full), 4.5, "별똥별이 지나가도 글자 대비")
    }

    func testMoonPhaseFollowsAge() throws {
        func lit(_ age: Double) throws -> (area: Int, meanX: Double) {
            let size = CGSize(width: 354, height: 232)
            let frame = SkyFrame(scene: .clearNight, quality: .hero, size: size, texts: SkyTexts.none, moonAge: age, moonScale: 2)
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

    // MARK: - 6차 — 구름 창·구운 판

    /// 구름은 pt 세계 좌표 — 크기가 달라도 같은 창이면 같은 pt 자리는 같은 구름 자리를 본다.
    func testCardWindowIsWorldSpace() {
        let origin = CGPoint(x: 1234, y: 150)
        for flow in [0.0, -7.5] {
            for t in [0.0, 37.5, 1000] {
                let a = SkyCloudBank.window(origin, size: CGSize(width: 354, height: 96), shape: .band, flow: flow, t: t)
                let b = SkyCloudBank.window(origin, size: CGSize(width: 170, height: 170), shape: .band, flow: flow, t: t)
                let c = SkyCloudBank.window(origin, size: CGSize(width: 354, height: 232), shape: .band, flow: flow, t: t)
                XCTAssertEqual(a, b)
                XCTAssertEqual(a, c)
                XCTAssertGreaterThanOrEqual(a.x, 0)
                XCTAssertLessThan(a.x, 768)
            }
        }
        let t0 = SkyCloudBank.window(origin, size: CGSize(width: 354, height: 96), shape: .band, flow: -7.5, t: 0)
        let t1 = SkyCloudBank.window(origin, size: CGSize(width: 354, height: 96), shape: .band, flow: -7.5, t: 2)
        XCTAssertEqual(t1.x - t0.x, 15, accuracy: 1e-6, "왼쪽으로 7.5pt/초 흐른다 — 판 안 자리는 오른쪽으로")
        for size in [CGSize(width: 354, height: 96), CGSize(width: 393, height: 300)] {
            let f = SkyFrame(scene: .rain, quality: .card, size: size, window: origin)
            let u = f.uniforms(pixels: size, t: 0, headroom: 1, tilt: .zero, frameIndex: 0, rainCount: 0,
                               budget: SkyBudget(.hero, tier: .ultra, still: true), meteor: nil)
            XCTAssertEqual(u.win.x, 1234)
            XCTAssertEqual(u.win.y, 150)
        }
        XCTAssertEqual(SkyCloudBank.Shape.fitting(CGSize(width: 354, height: 96)), .band)
        XCTAssertEqual(SkyCloudBank.Shape.fitting(CGSize(width: 354, height: 232)), .band)
        XCTAssertEqual(SkyCloudBank.Shape.fitting(CGSize(width: 393, height: 852)), .tall)
    }

    func testCardWindowSeedsAreDeterministicAndDistinct() throws {
        XCTAssertEqual(SkyFrame.window(seed: 7), SkyFrame.window(seed: 7))
        let w = (0..<20).map { SkyFrame.window(seed: $0) }
        XCTAssertEqual(Set(w.map { "\($0.x),\($0.y)" }).count, 20)
        let size = CGSize(width: 354, height: 96)
        func img(_ seed: Int) throws -> [UInt8] {
            let f = SkyFrame(scene: .petals, quality: .card, size: size, window: SkyFrame.window(seed: seed))
            return pixels(try XCTUnwrap(SkySnapshot.image(f, scale: 2, t: SceneArt.stillPhase)).image)
        }
        let a = try img(1)
        XCTAssertEqual(a, try img(1), "같은 씨앗 → 같은 카드")
        XCTAssertNotEqual(a, try img(2), "다른 씨앗 → 다른 구름")
    }

    func testBakedCloudPlatesFollowVersion() throws {
        let gpu = try XCTUnwrap(SkyGPU.shared)
        let bank = SkyCloudBank.shared
        let saved = SkyCloudBank.version
        defer { SkyCloudBank.version = saved }
        let p1 = try XCTUnwrap(bank.plate(.dusk, .band, device: gpu.device))
        XCTAssertTrue(p1 === bank.plate(.dusk, .band, device: gpu.device), "같은 판 번호면 다시 굽지 않는다")
        XCTAssertEqual(p1.key.version, SkyCloudBank.version)
        let before = bank.stripsBaked
        let cb = try XCTUnwrap(gpu.queue.makeCommandBuffer())
        bank.advance(p1, cb: cb, gpu: gpu, all: false, now: 1_000_000)
        bank.advance(p1, cb: cb, gpu: gpu, all: false, now: 1_000_000)
        XCTAssertEqual(bank.stripsBaked - before, p1.complete ? 0 : 1, "움직이는 화면은 한 프레임에 한 줄")
        bank.advance(p1, cb: cb, gpu: gpu, all: true)
        cb.commit(); cb.waitUntilCompleted()
        XCTAssertTrue(p1.complete)
        SkyCloudBank.version += 1
        let p2 = try XCTUnwrap(bank.plate(.dusk, .band, device: gpu.device))
        XCTAssertFalse(p1 === p2, "판 번호가 바뀌면 새로 굽는다")
        XCTAssertFalse(p2.complete)
        XCTAssertEqual(p2.key.version, saved + 1)
        XCTAssertLessThanOrEqual(bank.bytes, bank.capBytes + p2.bytes)
    }

    func testCardsNeverMarchClouds() {
        XCTAssertTrue(SkyTier.allCases.allSatisfy { SkyBudget(.card, tier: $0).bakedClouds })
        XCTAssertTrue(SkyBudget(.hero, tier: .mid).bakedClouds)
        XCTAssertTrue(SkyBudget(.full, tier: .low).bakedClouds)
        XCTAssertFalse(SkyBudget(.hero, tier: .ultra).bakedClouds)
        XCTAssertNil(SkyBudget(.card, tier: .mid).upscaleTo, "구운 카드엔 MetalFX 를 쓰지 않는다")
        let frame = SkyFrame(scene: .rain, quality: .card, size: CGSize(width: 354, height: 96))
        XCTAssertEqual(SkySnapshot.cloudRenders(frame, tier: .ultra, seconds: 1).renders, 0)
    }

    /// 6차 — 장면별 히어로(최상 실시간 · 중·하 구운 판) + 목록 카드 세 장(창 다름, 최상·중). SKY6C_DIR.
    func testDumpSky6c() throws {
        guard let dir = ProcessInfo.processInfo.environment["SKY6C_DIR"] else { throw XCTSkip("SKY6C_DIR 없음") }
        let url = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let heroSize = CGSize(width: 354, height: 232), rowSize = CGSize(width: 354, height: 96)
        let t0 = SceneArt.stillPhase + (ProcessInfo.processInfo.environment["SKY6C_T"].flatMap(Double.init) ?? 0)
        let scenes: [SkyScene] = ProcessInfo.processInfo.environment["SKY6C_ONLY"].map { only in
            SkyScene.allCases.filter { only.split(separator: ",").contains(Substring("\($0)")) }
        } ?? [.clearDay, .petals, .leaves, .dawn, .dusk, .rain, .nightCloudy]
        for scene in scenes {
            let tag = String(format: "%02d-%@", scene.rawValue, "\(scene)")
            var heroes: [(String, CGImage)] = []
            let heroWindow = ProcessInfo.processInfo.environment["SKY6C_WIN"].map { v -> CGPoint in
                let n = v.split(separator: ",").compactMap { Double($0) }
                return CGPoint(x: n[0], y: n[1])
            } ?? .zero
            for tier in [SkyTier.ultra, .mid, .low] {
                let f = SkyFrame(scene: scene, quality: .hero, size: heroSize, moonAge: 10, window: heroWindow)
                heroes.append((tier.name, try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: t0, tier: tier)).image))
            }
            var cards: [(String, CGImage)] = []
            for tier in [SkyTier.ultra, .mid] {
                for seed in 0..<3 {
                    let f = SkyFrame(scene: scene, quality: .card, size: rowSize, moonAge: 10, window: SkyFrame.window(seed: seed))
                    cards.append(("\(tier.name) 창\(seed)", try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: t0, tier: tier)).image))
                }
            }
            save(render(HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(heroes.indices, id: \.self) { i in
                        Text("히어로 \(heroes[i].0)").font(.system(size: 11)).foregroundStyle(.white)
                        SkyCard(scene: scene, size: .hero, new: true, image: heroes[i].1)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cards.indices, id: \.self) { i in
                        Text("카드 \(cards[i].0)").font(.system(size: 11)).foregroundStyle(.white)
                        SkyCard(scene: scene, size: .row, new: true, image: cards[i].1)
                    }
                }
            }.padding(12).background(Color.black)), url.appendingPathComponent("\(tag).png"))
            if ProcessInfo.processInfo.environment["SKY6C_FULL"] != nil {
                let texts = SkyFullPage.texts(in: full)
                var pages: [CGImage] = []
                for tier in [SkyTier.ultra, .mid, .low] {
                    let f = SkyFrame(scene: scene, quality: .full, size: full, texts: texts, moonAge: 10)
                    pages.append(try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: t0, tier: tier)).image)
                }
                save(render(HStack(spacing: 10) { ForEach(pages.indices, id: \.self) { i in
                    SkyFullPage(scene: scene, size: self.full, image: pages[i])
                } }.padding(10).background(Color.black)), url.appendingPathComponent("full-\(tag).png"))
            }
        }
        var gpu: [String] = []
        for scene in scenes {
            let g = try XCTUnwrap(SkyGPU.shared)
            let bank = SkyCloudBank.shared
            bank.removeAll()
            let p = try XCTUnwrap(bank.plate(scene, .band, device: g.device))
            let cb = try XCTUnwrap(g.queue.makeCommandBuffer())
            bank.advance(p, cb: cb, gpu: g, all: true)
            let bakeStart = CACurrentMediaTime()
            cb.commit(); cb.waitUntilCompleted()
            let bakeMs = (CACurrentMediaTime() - bakeStart) * 1000
            if let lin = CGColorSpace(name: CGColorSpace.extendedLinearSRGB), let srgb = CGColorSpace(name: CGColorSpace.sRGB),
               let ci = CIImage(mtlTexture: p.frames[0], options: [.colorSpace: lin]) {
                let ctx = CIContext(mtlDevice: g.device)
                let img = ci.settingAlphaOne(in: ci.extent).oriented(.downMirrored)
                if let cg = ctx.createCGImage(img, from: img.extent, format: .RGBA8, colorSpace: srgb) {
                    save(UIImage(cgImage: cg), url.appendingPathComponent(String(format: "plate-%02d.png", scene.rawValue)))
                }
                let alpha = ci.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)]).oriented(.downMirrored)
                if let cg = ctx.createCGImage(alpha, from: img.extent, format: .RGBA8, colorSpace: srgb) {
                    save(UIImage(cgImage: cg), url.appendingPathComponent(String(format: "plate-T-%02d.png", scene.rawValue)))
                }
            }
            let card = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: scene, quality: .card, size: rowSize), scale: 3, t: t0, repeats: 4, tier: .mid))
            let heroU = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: scene, quality: .hero, size: heroSize), scale: 3, t: t0, repeats: 4, tier: .ultra))
            let heroM = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: scene, quality: .hero, size: heroSize), scale: 3, t: t0, repeats: 4, tier: .mid))
            gpu.append(String(format: "%@ 굽기 %.1fms(판 %.1fMB) · 카드 %.2fms · 히어로 최상 %.2fms · 히어로 중 %.2fms", scene.name,
                              bakeMs, Double(p.bytes) / 1_048_576, card.gpuMilliseconds,
                              heroU.gpuMilliseconds, heroM.gpuMilliseconds))
        }
        try gpu.joined(separator: "\n").write(to: url.appendingPathComponent("gpu.txt"), atomically: true, encoding: .utf8)
        print("SKY6C\n" + gpu.joined(separator: "\n"))
    }

    // MARK: - 눈으로 보는 PNG (TEST_RUNNER_SKY2_DIR 가 있을 때만)

    func testDumpSky2() throws {
        guard let dir = ProcessInfo.processInfo.environment["SKY2_DIR"] else { throw XCTSkip("SKY2_DIR 없음") }
        let url = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let rects = SkyFullPage.texts(in: full)
        let phases: [(String, Double)] = [("1-crescent", 3.2), ("2-first-quarter", 7.4), ("3-full", 14.8),
                                          ("4-last-quarter", 22.1), ("5-waning-crescent", 26.3)]
        for (name, age) in phases {
            let f = SkyFrame(scene: .clearNight, quality: .full, size: full, texts: rects, moonAge: age)
            let img = try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: SceneArt.stillPhase)).image
            save(render(SkyFullPage(scene: .clearNight, size: full, image: img)), url.appendingPathComponent("moon-\(name).png"))
            let big = SkyFrame(scene: .clearNight, quality: .full, size: full, texts: rects, moonAge: age, moonScale: 4)
            let bimg = try XCTUnwrap(SkySnapshot.image(big, scale: 3, t: SceneArt.stillPhase)).image
            let l = big.light
            let r = l.radius * 1.35 * 3
            if let crop = bimg.cropping(to: CGRect(x: l.center.x * 3 - r, y: l.center.y * 3 - r, width: 2 * r, height: 2 * r)) {
                save(UIImage(cgImage: crop), url.appendingPathComponent("moon-close-\(name).png"))
            }
        }
        let cloudy = SkyFrame(scene: .nightCloudy, quality: .full, size: full, texts: rects, moonAge: 14.8)
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
            let f = SkyFrame(scene: .clearNight, quality: .full, size: full, texts: rects, moonAge: 10)
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

    /// 3차 — 맑은 낮(전체·히어로·카드)과 맑은 밤 별을 Apple 화면과 나란히. SKY3_DIR(출력)·SKY3_REF(참고 폴더).
    func testDumpSky3() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["SKY3_DIR"], let refDir = env["SKY3_REF"] else { throw XCTSkip("SKY3_DIR 없음") }
        let url = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let ref = { (name: String) in UIImage(contentsOfFile: refDir + "/" + name) }
        let texts = SkyFullPage.texts(in: full)
        let t0 = SceneArt.stillPhase
        let day = SkyFrame(scene: .clearDay, quality: .full, size: full, texts: texts)
        let dayImg = try XCTUnwrap(SkySnapshot.image(day, scale: 3, t: t0)).image
        let dayPage = SkyFullPage(scene: .clearDay, size: full, image: dayImg)
        save(render(dayPage), url.appendingPathComponent("day-full.png"))
        save(render(Image(decorative: dayImg, scale: 3)), url.appendingPathComponent("day-full-raw.png"))
        if let a = ref("ref/day-antarctica.png") {
            save(render(HStack(spacing: 12) {
                Image(uiImage: a).resizable().scaledToFill().frame(width: full.width, height: full.height).clipped()
                dayPage
            }.padding(12).background(Color.black)), url.appendingPathComponent("compare-day.png"))
        }
        let heroSize = CGSize(width: 354, height: 232), rowSize = CGSize(width: 354, height: 96)
        let h = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: .clearDay, quality: .hero, size: heroSize), scale: 3, t: t0)).image
        let r = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: .clearDay, quality: .card, size: rowSize), scale: 3, t: t0)).image
        let cards = VStack(spacing: 12) {
            SkyCard(scene: .clearDay, size: .hero, new: true, image: h)
            SkyCard(scene: .clearDay, size: .row, new: true, image: r)
        }
        save(render(cards.padding(12).background(Color.black)), url.appendingPathComponent("day-cards.png"))
        if let c = ref("ref/cards-day.png") {
            save(render(HStack(alignment: .top, spacing: 12) {
                Image(uiImage: c).resizable().scaledToFit().frame(height: 760)
                cards
            }.padding(12).background(Color.black)), url.appendingPathComponent("compare-cards.png"))
        }
        for tier in SkyTier.allCases {
            let img = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: .clearDay, quality: .hero, size: heroSize), scale: 3, t: t0, tier: tier)).image
            save(render(SkyCard(scene: .clearDay, size: .hero, new: true, image: img)), url.appendingPathComponent("day-tier-\(tier.rawValue)-\(tier.name).png"))
        }
        let night = SkyFrame(scene: .clearNight, quality: .hero, size: heroSize, moonAge: 5)
        let n = try XCTUnwrap(SkySnapshot.image(night, scale: 3, t: t0)).image
        save(render(SkyCard(scene: .clearNight, size: .hero, new: true, image: n)), url.appendingPathComponent("night-hero.png"))
        let nf = SkyFrame(scene: .clearNight, quality: .full, size: full, texts: texts, moonAge: 5)
        let nfi = try XCTUnwrap(SkySnapshot.image(nf, scale: 3, t: t0)).image
        let nightPage = SkyFullPage(scene: .clearNight, size: full, image: nfi)
        if let a = ref("ref/night-stars.png") {
            save(render(HStack(spacing: 12) {
                Image(uiImage: a).resizable().scaledToFill().frame(width: full.width, height: full.height).clipped()
                nightPage
            }.padding(12).background(Color.black)), url.appendingPathComponent("compare-night.png"))
        }
        // 별 확대 — Apple 확대(영상 ≈1.06px/pt, 280×200px ≈ 264×189pt)와 같은 넓이를 전체 화면 밤에서.
        if let crop = nfi.cropping(to: CGRect(x: 40 * 3, y: 420 * 3, width: 264 * 3, height: 189 * 3)), let a = ref("vid1/c/crop_1.000.png") {
            save(render(HStack(spacing: 12) {
                Image(uiImage: a).resizable().interpolation(.high).frame(width: 280 * 2, height: 200 * 2)
                Image(decorative: crop, scale: 1).resizable().interpolation(.high).frame(width: 280 * 2, height: 200 * 2)
            }.padding(12).background(Color.black)), url.appendingPathComponent("compare-stars.png"))
        }
        var frames: [CGImage] = []
        for dt in [0.0, 1.5, 3.0] {
            let img = try XCTUnwrap(SkySnapshot.image(night, scale: 3, t: t0 + dt)).image
            if let c = img.cropping(to: CGRect(x: 30 * 3, y: 70 * 3, width: 280, height: 200)) { frames.append(c) }
        }
        save(render(HStack(spacing: 8) { ForEach(frames.indices, id: \.self) { i in
            Image(decorative: frames[i], scale: 1).resizable().interpolation(.high).frame(width: 420, height: 300)
        } }.padding(8).background(Color.black)), url.appendingPathComponent("stars-flow.png"))
        // 글자 자리 확인 — 실제 글자 위에 작은(초록)·큰(주황) 자리를 겹쳐 그린다.
        let boxes = ZStack(alignment: .topLeading) {
            dayPage
            ForEach(Array(texts.small.enumerated()), id: \.offset) { _, r in
                Rectangle().stroke(.green, lineWidth: 1).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
            }
            ForEach(Array(texts.big.enumerated()), id: \.offset) { _, r in
                Rectangle().stroke(.orange, lineWidth: 1).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
            }
        }.frame(width: full.width, height: full.height, alignment: .topLeading)
        save(render(boxes), url.appendingPathComponent("text-rects-full.png"))
        let hb = SkyTexts.card(heroSize)
        save(render(ZStack(alignment: .topLeading) {
            SkyCard(scene: .clearDay, size: .hero, new: true, image: h)
            ForEach(Array(hb.small.enumerated()), id: \.offset) { _, r in
                Rectangle().stroke(.green, lineWidth: 1).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
            }
            ForEach(Array(hb.big.enumerated()), id: \.offset) { _, r in
                Rectangle().stroke(.orange, lineWidth: 1).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
            }
        }.frame(width: heroSize.width, height: heroSize.height, alignment: .topLeading)), url.appendingPathComponent("text-rects-hero.png"))
        var worst: [String] = []
        for (name, f, img) in [("full", day, dayImg), ("hero", SkyFrame(scene: .clearDay, quality: .hero, size: heroSize), h),
                               ("card", SkyFrame(scene: .clearDay, quality: .card, size: rowSize), r)] {
            let px = pixels(img), w = img.width
            for rect in f.texts.all {
                var best = (0.0, 0, 0)
                for y in Int(rect.minY * 3)..<min(Int(rect.maxY * 3), img.height) {
                    for x in Int(rect.minX * 3)..<min(Int(rect.maxX * 3), w) {
                        let i = (y * w + x) * 4
                        let l = SceneRGB(Double(px[i]) / 255, Double(px[i + 1]) / 255, Double(px[i + 2]) / 255).luminance
                        if l > best.0 { best = (l, x / 3, y / 3) }
                    }
                }
                worst.append(String(format: "%@ rect %.0f,%.0f %.0fx%.0f max L %.3f at %d,%d", name, rect.minX, rect.minY, rect.width, rect.height, best.0, best.1, best.2))
            }
        }
        try worst.joined(separator: "\n").write(to: url.appendingPathComponent("worst.txt"), atomically: true, encoding: .utf8)
        var gpu: [String] = []
        for tier in SkyTier.allCases.reversed() {
            for (name, f) in [("full", day), ("hero", SkyFrame(scene: .clearDay, quality: .hero, size: heroSize)),
                              ("night-full", nf)] {
                let ms = try XCTUnwrap(SkySnapshot.image(f, scale: 3, t: t0, repeats: 6, tier: tier)).gpuMilliseconds
                gpu.append(String(format: "%@ %@ %.2fms", tier.name, name, ms))
            }
        }
        try gpu.joined(separator: "\n").write(to: url.appendingPathComponent("gpu.txt"), atomically: true, encoding: .utf8)
    }

    /// 5차 — 13 장면 히어로(글자 얹은 것)·전체 화면·목록 카드 모음. SKY5_DIR.
    func testDumpSky5() throws {
        guard let dir = ProcessInfo.processInfo.environment["SKY5_DIR"] else { throw XCTSkip("SKY5_DIR 없음") }
        let url = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let heroSize = CGSize(width: 354, height: 232), rowSize = CGSize(width: 354, height: 96)
        let t0 = SceneArt.stillPhase
        let only = ProcessInfo.processInfo.environment["SKY5_ONLY"].map { Set($0.split(separator: ",").map(String.init)) }
        var rows: [(SkyScene, CGImage)] = []
        var log: [String] = []
        for scene in SkyScene.allCases {
            let r = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: scene, quality: .card, size: rowSize, moonAge: 10), scale: 3, t: t0)).image
            rows.append((scene, r))
            if let only, !only.contains("\(scene)") { continue }
            let tag = String(format: "%02d-%@", scene.rawValue, "\(scene)")
            let h = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: scene, quality: .hero, size: heroSize, moonAge: 10), scale: 3, t: t0)).image
            save(render(SkyCard(scene: scene, size: .hero, new: true, image: h)), url.appendingPathComponent("hero-\(tag).png"))
            let texts = SkyFullPage.texts(in: full)
            let ff = SkyFrame(scene: scene, quality: .full, size: full, texts: texts, moonAge: 10)
            let f = try XCTUnwrap(SkySnapshot.image(ff, scale: 3, t: t0)).image
            save(render(SkyFullPage(scene: scene, size: full, image: f)), url.appendingPathComponent("full-\(tag).png"))
            if scene.hasFlakes || scene == .wind || scene == .frost {
                var frames: [CGImage] = []
                for dt in [0.0, 0.5, 1.0] {
                    let img = try XCTUnwrap(SkySnapshot.image(ff, scale: 3, t: t0 + dt)).image
                    if let c = img.cropping(to: CGRect(x: 0, y: 330 * 3, width: 393 * 3, height: 380 * 3)) { frames.append(c) }
                }
                save(render(HStack(spacing: 6) { ForEach(frames.indices, id: \.self) { i in
                    Image(decorative: frames[i], scale: 3).resizable().frame(width: 393, height: 380)
                } }.background(Color.black)), url.appendingPathComponent("flow-\(tag).png"))
            }
            var gpu: [String] = []
            for tier in SkyTier.allCases.reversed() {
                let ms = try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: scene, quality: .hero, size: heroSize), scale: 3, t: t0, repeats: 4, tier: tier)).gpuMilliseconds
                gpu.append(String(format: "%@ %.2f", tier.name, ms))
            }
            log.append("\(scene.name) hero ms " + gpu.joined(separator: " · "))
        }
        var worst: [String] = []
        for scene in SkyScene.allCases where scene.brightSky {
            for (q, size, texts) in [(SkyQuality.hero, heroSize, SkyTexts?.none), (.card, rowSize, nil), (.full, full, SkyFullPage.texts(in: full))] {
                for t in [t0, t0 + 40] {
                    let f = SkyFrame(scene: scene, quality: q, size: size, texts: texts)
                    let img = try XCTUnwrap(SkySnapshot.image(f, scale: 2, t: t)).image
                    let px = pixels(img), w = img.width
                    for rect in f.texts.all {
                        var best = (0.0, 0, 0)
                        for y in Int(rect.minY * 2)..<min(Int(rect.maxY * 2), img.height) {
                            for x in Int(rect.minX * 2)..<min(Int(rect.maxX * 2), w) {
                                let i = (y * w + x) * 4
                                let l = SceneRGB(Double(px[i]) / 255, Double(px[i + 1]) / 255, Double(px[i + 2]) / 255).luminance
                                if l > best.0 { best = (l, x / 2, y / 2) }
                            }
                        }
                        if best.0 > 0.2 {
                            worst.append(String(format: "%@ %@ t%.0f rect %.0f,%.0f %.0fx%.0f max L %.3f at %d,%d rgb %d %d %d", scene.name, q.rawValue, t, rect.minX, rect.minY, rect.width, rect.height, best.0, best.1, best.2,
                                                px[(best.2 * 2 * w + best.1 * 2) * 4], px[(best.2 * 2 * w + best.1 * 2) * 4 + 1], px[(best.2 * 2 * w + best.1 * 2) * 4 + 2]))
                        }
                    }
                }
            }
        }
        try worst.joined(separator: "\n").write(to: url.appendingPathComponent("worst.txt"), atomically: true, encoding: .utf8)
        var heroes: [(SkyScene, CGImage)] = []
        for scene in SkyScene.allCases {
            heroes.append((scene, try XCTUnwrap(SkySnapshot.image(SkyFrame(scene: scene, quality: .hero, size: heroSize, moonAge: 10), scale: 3, t: t0)).image))
        }
        save(render(VStack(alignment: .leading, spacing: 8) { ForEach(0..<5, id: \.self) { r in HStack(spacing: 8) {
            ForEach(heroes.indices.filter { $0 / 3 == r }, id: \.self) { i in SkyCard(scene: heroes[i].0, size: .hero, new: true, image: heroes[i].1) }
        } } }.padding(10).background(Color.black)), url.appendingPathComponent("heroes-all.png"))
        save(render(VStack(spacing: 8) { ForEach(rows.indices, id: \.self) { i in
            SkyCard(scene: rows[i].0, size: .row, new: true, image: rows[i].1)
        } }.padding(10).background(Color.black)), url.appendingPathComponent("cards-all.png"))
        try log.joined(separator: "\n").write(to: url.appendingPathComponent("gpu.txt"), atomically: true, encoding: .utf8)
    }

    /// 꽃잎·잎은 반짝이지 않는다 — EDR 여유를 크게 줘도 잎 때문에 흰색(1)을 넘는 픽셀(잎 없이 그린 것보다 밝아진 곳)이 없다.
    func testPetalsAndLeavesNeverSparkle() throws {
        let gpu = try XCTUnwrap(SkyGPU.shared)
        var log: [String] = []
        for scene in [SkyScene.petals, .leaves] {
            for (q, size) in [(SkyQuality.hero, CGSize(width: 354, height: 232)), (.full, full)] {
                let frame = SkyFrame(scene: scene, quality: q, size: size, texts: q == .full ? SkyFullPage.texts(in: full) : nil)
                let with = SkyBudget(q, tier: .ultra, still: true)
                var without = with
                without.particleScale = 1e-9
                var over = 0, drawn = 0, peak: Float = 0, box = CGRect.null
                for k in 0..<12 {
                    let t = SceneArt.stillPhase + Double(k) * 0.37
                    let (w, h, px) = try hdr(gpu, frame, t: t, headroom: 4, budget: with)
                    let (_, _, bare) = try hdr(gpu, frame, t: t, headroom: 4, budget: without)
                    let s = Double(w) / size.width
                    for i in 0..<(w * h) {
                        let o = i * 4
                        let d = max(abs(px[o] - bare[o]), abs(px[o + 1] - bare[o + 1]), abs(px[o + 2] - bare[o + 2]))
                        guard d > 0.01 else { continue }
                        drawn += 1
                        let m = max(px[o], px[o + 1], px[o + 2]), mb = max(bare[o], bare[o + 1], bare[o + 2])
                        guard (m > 1 && m > mb + 0.01) || !m.isFinite else { continue }
                        over += 1
                        peak = max(peak, m)
                        box = box.union(CGRect(x: Double(i % w) / s, y: Double(i / w) / s, width: 1, height: 1))
                    }
                }
                XCTAssertGreaterThan(drawn, 1000, "\(scene.name) \(q.rawValue) 잎이 그려졌다")
                log.append(String(format: "%@ %@ 잎 픽셀 %d 중 흰색 넘는 픽셀 %d 최고 %.2f", scene.name, q.rawValue, drawn, over, peak))
                XCTAssertEqual(over, 0, "\(scene.name) \(q.rawValue) 반짝임 \(over)픽셀 최고 \(peak) 자리 \(box)")
            }
        }
        print("SKY7 반짝임\n" + log.joined(separator: "\n"))
    }

    private func hdr(_ gpu: SkyGPU, _ frame: SkyFrame, t: Double, headroom: Float, budget: SkyBudget) throws -> (Int, Int, [Float]) {
        let w = Int(frame.size.width * 2), h = Int(frame.size.height * 2)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        let target = try XCTUnwrap(gpu.device.makeTexture(descriptor: d))
        let cb = try XCTUnwrap(gpu.queue.makeCommandBuffer())
        SkyRenderer(gpu: gpu).encode(cb, into: target, frame: frame, t: t, headroom: headroom, budget: budget)
        cb.commit(); cb.waitUntilCompleted()
        let lin = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let ci = try XCTUnwrap(CIImage(mtlTexture: target, options: [.colorSpace: lin])).oriented(.downMirrored)
        var px = [Float](repeating: 0, count: w * h * 4)
        CIContext(mtlDevice: gpu.device, options: [.workingColorSpace: lin])
            .render(ci, toBitmap: &px, rowBytes: w * 16, bounds: ci.extent, format: .RGBAf, colorSpace: lin)
        return (w, h, px)
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
