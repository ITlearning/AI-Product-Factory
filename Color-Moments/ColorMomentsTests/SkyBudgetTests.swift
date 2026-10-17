import ImageIO
import MetalKit
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import ColorMoments

/// 하늘 예산 2단계 — 카드 SDR·2/3 배율, drawable 2·풀 5·release, 블룸 줄이기, 판 참조 고정, 쓰임새·패스별 GPU 계측.
@MainActor
final class SkyBudgetTests: XCTestCase {
    private let heroSize = CGSize(width: 354, height: 232)
    private let cardSize = CGSize(width: 361, height: 96)

    override func tearDown() {
        SkyDebug.off = []
        SkyDebug.heroScaleDown = false
        SkyDebug.heroBloomLite = false
        super.tearDown()
    }

    func testCardIsSDRAtTwoThirdsAndHeroKeepsEDR() {
        XCTAssertEqual(SkyQuality.card.renderScale(3), 2)
        XCTAssertEqual(SkyQuality.hero.renderScale(3), 3, "D1 — hero 는 그대로")
        XCTAssertEqual(SkyQuality.full.renderScale(3), 3)
        SkyDebug.heroScaleDown = true
        XCTAssertEqual(SkyQuality.hero.renderScale(3), 2)
        SkyDebug.heroScaleDown = false

        SkyViewPool.drain()
        let card = SkyViewPool.take(.card, screen: 3)
        XCTAssertEqual(card.colorPixelFormat, .bgra8Unorm_srgb)
        XCTAssertEqual(card.contentScaleFactor, 2)
        let cl = card.layer as! CAMetalLayer
        XCTAssertFalse(cl.wantsExtendedDynamicRangeContent, "카드는 EDR 끔")
        XCTAssertEqual(cl.maximumDrawableCount, 2)

        let hero = SkyViewPool.take(.hero, screen: 3)
        XCTAssertEqual(hero.colorPixelFormat, .rgba16Float)
        XCTAssertEqual(hero.contentScaleFactor, 3)
        let hl = hero.layer as! CAMetalLayer
        XCTAssertTrue(hl.wantsExtendedDynamicRangeContent)
        XCTAssertEqual(hl.maximumDrawableCount, 2)

        // 풀에서 쓰임새를 바꿔 빌려도 포맷·EDR·배율이 따라온다.
        SkyViewPool.give(card)
        let again = SkyViewPool.take(.hero, screen: 3)
        XCTAssertTrue(again === card)
        XCTAssertEqual(again.colorPixelFormat, .rgba16Float)
        XCTAssertTrue((again.layer as! CAMetalLayer).wantsExtendedDynamicRangeContent)
        XCTAssertEqual(again.contentScaleFactor, 3)
        SkyViewPool.drain()
    }

    func testCardDrawableSizeInWindow() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true; SkyViewPool.drain() }
        let v = SkyViewPool.take(.card, screen: 3)
        v.frame = CGRect(x: 0, y: 0, width: 361, height: 96)
        root.view.addSubview(v)
        root.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(v.contentScaleFactor, 2, "창에 들어가도 2/3 배율 유지")
        XCTAssertEqual(v.drawableSize, CGSize(width: 722, height: 192))
    }

    private final class ProbeView: MTKView {
        var released = 0
        override func releaseDrawables() { released += 1; super.releaseDrawables() }
    }

    func testPoolCapFiveAndGiveReleasesDrawables() {
        XCTAssertEqual(SkyViewPool.cap, 5, "D2 — 동시 5와 같다")
        SkyViewPool.drain()
        let probe = ProbeView(frame: .zero, device: SkyGPU.systemDevice)
        SkyViewPool.give(probe)
        XCTAssertEqual(probe.released, 1, "풀에 돌려줄 때 drawable 을 놓는다")
        XCTAssertTrue(probe.isPaused)
        SkyViewPool.drain()
    }

    /// 카드 — 움직이는 길(SDR bgra8 sRGB, 2배)과 정지 그림(같은 배율, CIContext)의 색이 같다.
    func testCardSDRMatchesStill() throws {
        var worst = 0.0
        var log: [String] = []
        for s in SkyScene.allCases {
            let f = SkyFrame(scene: s, quality: .card, size: cardSize, moonAge: 10, window: SkyFrame.window(seed: 7))
            let still = try XCTUnwrap(SkySnapshot.image(f, scale: 2, t: SceneArt.stillPhase)?.image)
            let live = try XCTUnwrap(SkySnapshot.sdrImage(f, scale: 2, t: SceneArt.stillPhase))
            let d = Self.diff(still, live)
            worst = max(worst, d.mean)
            log.append(String(format: "%@ 평균 %.4f 최대 %.3f", s.name, d.mean, d.max))
            XCTAssertLessThan(d.mean, 0.01, "\(s.name) 정지 그림과 움직이는 카드의 색")
        }
        print("SKYM2 카드 정지↔SDR\n" + log.joined(separator: "\n"))
        XCTAssertLessThan(worst, 0.03, "기존 허용치(SkyScrollTests 정지→움직임)")
    }

    /// 블룸을 건너뛰는 장면은 블룸이 그림에 거의 안 보인다(hero EDR·카드 SDR 모두).
    func testBloomSkipIsInvisible() throws {
        var log: [String] = []
        SkyRenderer.noBloom = []
        defer { SkyRenderer.noBloom = SkyRenderer.skipsBloom }
        for s in SkyScene.allCases {
            for (q, size, scale, head, age) in [(SkyQuality.hero, heroSize, CGFloat(3), Float(4), 10.0), (.hero, heroSize, 3, 4, 14.8),
                                                (.card, cardSize, 2, 1, 14.8)] where age == 10 || s.isNight || q == .card {
                let f = SkyFrame(scene: s, quality: q, size: size, moonAge: age, window: SkyFrame.window(seed: 7))
                let on = try XCTUnwrap(Self.linear(f, scale: scale, headroom: head, offBloom: false))
                let off = try XCTUnwrap(Self.linear(f, scale: scale, headroom: head, offBloom: true))
                var sum = 0.0, mx = 0.0
                for i in on.indices where i % 4 != 3 {
                    let d = Double(abs(Self.encode(on[i]) - Self.encode(off[i])))
                    sum += d; mx = max(mx, d)
                }
                let mean = sum / Double(on.count / 4 * 3)
                log.append(String(format: "%@ %@ 달%.0f 블룸 몫 평균 %.4f 최대 %.4f%@", s.name, q.rawValue, age, mean, mx,
                                  SkyRenderer.skipsBloom.contains(s) ? " (건너뜀)" : ""))
                if SkyRenderer.skipsBloom.contains(s) {
                    XCTAssertLessThan(mean, 0.5 / 255, "\(s.name) \(q.rawValue)")
                    XCTAssertLessThan(mx, 4 / 255, "\(s.name) \(q.rawValue)")
                }
            }
        }
        print("SKYM2 블룸 몫(sRGB 0~1)\n" + log.joined(separator: "\n"))
    }

    /// 카드 블룸은 1/4 해상도부터, 단계 하나 덜 — 같은 2배 카드에서 옛 블룸(1/2 부터)과 차이가 작다.
    func testCardBloomFromQuarter() throws {
        XCTAssertEqual(SkyBudget(.card, tier: .ultra).bloomStart, 4)
        XCTAssertEqual(SkyBudget(.card, tier: .ultra).bloomLevels, 3)
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra).bloomStart, 2, "hero 는 그대로(D1)")
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra).bloomLevels, 5)
        SkyDebug.heroBloomLite = true
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra).bloomStart, 4)
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra).bloomLevels, 4)
    }

    /// 한 화면 8장면(10차 회귀) — 움직이는 카드가 쥔 판은 정지 그림 굽기가 상한을 넘겨도 버려지지 않고, 구름이 다 나타난다.
    func testPinnedPlatesSurviveStillBakes() async throws {
        let gpu = try XCTUnwrap(SkyGPU.shared)
        let bank = SkyCloudBank.shared
        bank.removeAll()
        defer { bank.removeAll() }
        let scenes = Array(SkyScene.allCases.prefix(10))
        let others = Array(SkyScene.allCases.dropFirst(10))
        let tier = SkyTier.ultra
        let b = SkyBudget(.card, tier: tier)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.sdrFormat, width: 722, height: 192, mipmapped: false)
        d.usage = [.renderTarget]
        d.storageMode = .private
        let target = try XCTUnwrap(gpu.device.makeTexture(descriptor: d))
        var renderers: [SkyRenderer]? = scenes.map { _ in SkyRenderer(gpu: gpu) }
        func frameAll(_ t: Double) {
            guard let cb = gpu.queue.makeCommandBuffer() else { return }
            for (s, r) in zip(scenes, renderers ?? []) {
                r.encode(cb, into: target, frame: SkyFrame(scene: s, quality: .card, size: cardSize), t: t, headroom: 1,
                         budget: b, progressive: true)
            }
            cb.commit(); cb.waitUntilCompleted()
        }
        frameAll(0)
        let held = scenes.map { bank.plate($0, .band, tier: tier, device: gpu.device) }
        XCTAssertTrue(held.allSatisfy { $0 != nil })
        let pinnedBytes = held.compactMap { $0 }.reduce(0) { $0 + $1.bytes }
        XCTAssertGreaterThan(pinnedBytes, bank.cap(tier), "쥔 판이 상한보다 크다 — 그래도 버리면 안 된다")
        let start = CACurrentMediaTime()
        var i = 0
        while CACurrentMediaTime() - start < 6, !held.allSatisfy({ $0?.complete == true }) {
            frameAll(Double(i) / 30)
            if i % 10 == 0 {
                // 다른 장면 정지 그림 굽기 — 판을 새로 만들고 상한을 넘긴다.
                _ = SkySnapshot.image(SkyFrame(scene: others[(i / 10) % others.count], quality: .card, size: cardSize), scale: 1, t: 0, tier: tier)
                XCTAssertLessThanOrEqual(bank.bytes, max(bank.cap(tier), pinnedBytes) + SkyCloudBank.bytes(.band, tier),
                                         "쥐지 않은 판은 상한까지 버린다")
            }
            try await Task.sleep(for: .milliseconds(17))
            i += 1
        }
        for (s, p) in zip(scenes, held) {
            XCTAssertTrue(p === bank.plate(s, .band, tier: tier, device: gpu.device), "\(s.name) 판을 다시 만들지 않는다")
            XCTAssertTrue(p?.complete == true, "\(s.name) 구름이 다 구워져 나타난다")
        }
        renderers = nil
        XCTAssertLessThanOrEqual(bank.bytes, bank.cap(tier), "아무도 안 쥐면 상한 안")
    }

    func testPinnedPlateIsNeverEvicted() throws {
        let gpu = try XCTUnwrap(SkyGPU.shared)
        let bank = SkyCloudBank.shared
        bank.removeAll()
        defer { bank.removeAll() }
        let first = try XCTUnwrap(bank.plate(.rain, .band, tier: .mid, device: gpu.device, now: 1))
        bank.pin(first)
        for (i, s) in SkyScene.allCases.dropFirst().enumerated() {
            _ = bank.plate(s, .band, tier: .mid, device: gpu.device, now: 2 + Double(i))
            XCTAssertLessThanOrEqual(bank.bytes, bank.cap(.mid) + first.bytes, "상한 초과 없음(쥔 판 몫만)")
        }
        XCTAssertTrue(first === bank.plate(.rain, .band, tier: .mid, device: gpu.device, now: 100), "제일 오래된 판이라도 쥐고 있으면 둔다")
        bank.unpin(first)
        for (i, s) in SkyScene.allCases.dropFirst().prefix(10).enumerated() { _ = bank.plate(s, .band, tier: .mid, device: gpu.device, now: 200 + Double(i)) }
        XCTAssertLessThanOrEqual(bank.bytes, bank.cap(.mid))
    }

    /// 판 상한은 판 단계 기준 — 발열로 단계가 내려가도 그대로.
    func testPlateCapFollowsPlateTier() {
        let hot = SkyBudget(.card, tier: .ultra, thermal: .serious)
        XCTAssertEqual(hot.plateTier, .ultra)
        XCTAssertEqual(SkyCloudBank.shared.cap(hot.plateTier), SkyCloudBank.shared.cap(.ultra))
    }

    func testStillCacheCapAndLRU() throws {
        XCTAssertEqual(SkyStills.cap(width: 361, screen: 3), 48 * 722 * 192 * 4 + 4 * 1083 * 696 * 4)
        let probe = try XCTUnwrap(SkyStills(capBytes: 1 << 30).image(.clearDay, quality: .card, size: cardSize, scale: 2))
        let one = probe.bytesPerRow * probe.height
        let stills = SkyStills(capBytes: one * 3)
        let scenes: [SkyScene] = [.rain, .snow, .fog, .wind]
        for s in scenes.prefix(3) { XCTAssertNotNil(stills.image(s, quality: .card, size: cardSize, scale: 2)) }
        XCTAssertNotNil(stills.cached(.rain, quality: .card, size: cardSize, scale: 2), "본 지 오래된 비를 다시 본다")
        XCTAssertNotNil(stills.image(.wind, quality: .card, size: cardSize, scale: 2))
        XCTAssertEqual(stills.memory.count, 3)
        XCTAssertLessThanOrEqual(stills.memory.bytes, one * 3)
        XCTAssertNotNil(stills.cached(.rain, quality: .card, size: cardSize, scale: 2), "최근에 본 건 남는다")
        XCTAssertNil(stills.cached(.snow, quality: .card, size: cardSize, scale: 2), "가장 오래 안 본(화면에서 먼) 것부터 버린다")
    }

    func testPerUseGPUAndPassFields() {
        var c = SkyStats.Counters()
        c.gpuUse = [.hero: 120, .card: 60]
        c.gpuUseFrames = [.hero: 100, .card: 30]
        c.passMs = [.card: [.compose: 3, .bloom: 1]]
        c.passFrames = [.card: 2]
        let uses = SkyScrollTest.Result.uses(c, seconds: 10)
        XCTAssertEqual(uses, "hero 12.0ms/초(장당 1.20ms, 100장), card 6.0ms/초(장당 2.00ms, 30장)")
        XCTAssertEqual(SkyScrollTest.Result.passes(c), "card(표본 2) 합성 1.50 블룸 0.50")
        c.passSupported = false
        XCTAssertEqual(SkyScrollTest.Result.passes(c), "지원 안 함")
        XCTAssertFalse(uses.contains(" · "), "결과 줄 구분자와 겹치지 않는다")
        XCTAssertFalse(SkyDebug.switches.contains(" · "))
        XCTAssertEqual(SkyDebug.switches, "hero2/3 끔, hero블룸줄임 끔, 패스끔 없음")
    }

    /// 패스별 GPU — 기기는 MTLCounterSampleBuffer, 시뮬레이터(맥 GPU)는 패스를 꺼서 뺀 값(참고).
    func testPassBreakdownProbe() throws {
        let gpu = try XCTUnwrap(SkyGPU.shared)
        print("SKYM2 패스 계측 지원 \(gpu.timestamps != nil)")
        var log: [String] = []
        for (q, size, scale) in [(SkyQuality.hero, heroSize, CGFloat(3)), (.card, cardSize, 2)] {
            var rows: [SkyPass: Double] = [:]
            var total = 0.0
            for s in SkyScene.allCases {
                let f = SkyFrame(scene: s, quality: q, size: size, moonAge: 10)
                func ms(_ off: Set<SkyPass>) -> Double {
                    SkyDebug.off = off
                    defer { SkyDebug.off = [] }
                    return SkySnapshot.image(f, scale: scale, t: SceneArt.stillPhase, repeats: 9)?.gpuMilliseconds ?? 0
                }
                let all = ms([])
                total += all
                for p in SkyPass.switchable { rows[p, default: 0] += max(all - ms([p]), 0) }
            }
            let n = Double(SkyScene.allCases.count)
            let parts = SkyPass.switchable.map { String(format: "%@ %.3f", $0.rawValue, rows[$0]! / n) }
            log.append(String(format: "%@ 장당 %.3fms(장면 평균) · ", q.rawValue, total / n) + parts.joined(separator: " · ")
                       + String(format: " · 나머지(합성·판 샘플·마무리) %.3f", (total - rows.values.reduce(0, +)) / n))
        }
        print("SKYM2 패스 차감(시뮬레이터 참고)\n" + log.joined(separator: "\n"))
    }

    // MARK: 눈 비교 PNG — SKYM2_DIR

    func testDumpAfter() throws {
        guard let dir = ProcessInfo.processInfo.environment["SKYM2_DIR"] else { throw XCTSkip("SKYM2_DIR 없음") }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for s in SkyScene.allCases {
            let hero = SkyFrame(scene: s, quality: .hero, size: heroSize, moonAge: 10)
            let card = SkyFrame(scene: s, quality: .card, size: cardSize, moonAge: 10, window: SkyFrame.window(seed: 7))
            if let i = SkySnapshot.image(hero, scale: 3, t: SceneArt.stillPhase)?.image { try write(i, "\(dir)/\(s.key)-hero.png") }
            if let i = SkySnapshot.image(card, scale: 2, t: SceneArt.stillPhase)?.image { try write(i, "\(dir)/\(s.key)-card.png") }
            if let i = SkySnapshot.sdrImage(card, scale: 2, t: SceneArt.stillPhase) { try write(i, "\(dir)/\(s.key)-card-sdr.png") }
            SkyDebug.heroScaleDown = true; SkyDebug.heroBloomLite = true
            let lite = SkyFrame(scene: s, quality: .hero, size: heroSize, moonAge: 10)
            if let i = SkySnapshot.image(lite, scale: 2, t: SceneArt.stillPhase)?.image { try write(i, "\(dir)/\(s.key)-hero-lite.png") }
            SkyDebug.heroScaleDown = false; SkyDebug.heroBloomLite = false
        }
    }

    private func write(_ img: CGImage, _ path: String) throws {
        let d = try XCTUnwrap(CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(d, img, nil)
        XCTAssertTrue(CGImageDestinationFinalize(d))
    }

    // MARK: 도우미

    /// 마무리까지 그린 선형 값(rgba16F).
    static func linear(_ f: SkyFrame, scale: CGFloat, headroom: Float, offBloom: Bool) -> [Float]? {
        guard let gpu = SkyGPU.shared else { return nil }
        SkyDebug.off = offBloom ? [.bloom] : []
        defer { SkyDebug.off = [] }
        let w = Int(f.size.width * scale), h = Int(f.size.height * scale)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .shared
        guard let target = gpu.device.makeTexture(descriptor: d), let cb = gpu.queue.makeCommandBuffer() else { return nil }
        SkyRenderer(gpu: gpu).encode(cb, into: target, frame: f, t: SceneArt.stillPhase, headroom: headroom,
                                     budget: SkyBudget(f.quality, tier: .ultra, still: true))
        cb.commit(); cb.waitUntilCompleted()
        var half = [Float16](repeating: 0, count: w * h * 4)
        target.getBytes(&half, bytesPerRow: w * 8, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return half.map { Float($0) }
    }

    /// 선형 → sRGB(0~1, 1 넘는 EDR 은 그대로 늘림).
    static func encode(_ x: Float) -> Float { x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055 }

    static func diff(_ a: CGImage, _ b: CGImage) -> (mean: Double, max: Double) {
        let w = a.width, h = a.height
        func px(_ c: CGImage) -> [UInt8] {
            var buf = [UInt8](repeating: 0, count: w * h * 4)
            let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(c, in: CGRect(x: 0, y: 0, width: w, height: h))
            return buf
        }
        let pa = px(a), pb = px(b)
        var sum = 0, mx = 0
        for i in pa.indices where i % 4 != 3 {
            let d = abs(Int(pa[i]) - Int(pb[i]))
            sum += d; mx = max(mx, d)
        }
        return (Double(sum) / Double(w * h * 3 * 255), Double(mx) / 255)
    }
}
