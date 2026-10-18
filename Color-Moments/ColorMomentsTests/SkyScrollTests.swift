import Metal
import SwiftUI
import XCTest
@testable import ColorMoments

/// 9차 — 스크롤하는 곳(「말」 칸·생일 카드)은 모든 단계에서 구운 구름 판, 단계 차이는 판 품질·입자·fps·블룸.
@MainActor
final class SkyScrollTests: XCTestCase {
    private let heroSize = CGSize(width: 354, height: 232)
    private let rowSize = CGSize(width: 354, height: 96)

    func testScrollPathNeverMarchesCloudsOnAnyTier() {
        for tier in SkyTier.allCases {
            XCTAssertTrue(SkyBudget(.hero, tier: tier).bakedClouds, "\(tier.name) 히어로")
            XCTAssertTrue(SkyBudget(.card, tier: tier).bakedClouds, "\(tier.name) 카드")
            XCTAssertTrue(SkyBudget(.hero, tier: tier, thermal: .serious).bakedClouds)
            for scene in SkyScene.allCases {
                let hero = SkyFrame(scene: scene, quality: .hero, size: heroSize)
                XCTAssertEqual(SkySnapshot.cloudRenders(hero, tier: tier, seconds: 0.2).renders, 0, "\(tier.name) \(scene.name) 히어로")
            }
            let row = SkyFrame(scene: .rain, quality: .card, size: rowSize)
            XCTAssertEqual(SkySnapshot.cloudRenders(row, tier: tier, seconds: 0.2).renders, 0)
        }
        XCTAssertFalse(SkyBudget(.hero, tier: .ultra, live: true).bakedClouds, "펼친 말은 최상에서 실시간")
        XCTAssertFalse(SkyBudget(.hero, tier: .high, live: true).bakedClouds)
        XCTAssertTrue(SkyBudget(.hero, tier: .mid, live: true).bakedClouds, "중·하는 어디서나 구운 판")
    }

    /// 단계 표 — 판 촘촘함·굽기 걸음·떨림 평균·입자·fps·블룸.
    func testTierBudgetTable() throws {
        var rows: [String] = []
        for tier in SkyTier.allCases.reversed() {
            let g = SkyCloudBank.Grade(tier), hero = SkyBudget(.hero, tier: tier), card = SkyBudget(.card, tier: tier)
            let (w, h) = SkyCloudBank.Shape.band.pixels(g)
            rows.append(String(format: "%@ | 판 %.2fpx/pt(%dx%d, %.1fMB) | 굽기 %.0f걸음·떨림 %d번 | 입자 ×%.1f | 히어로 %dfps 블룸 %d | 카드 %dfps 블룸 %d",
                               tier.name, SkyCloudBank.Shape.band.pxPerPt * g.density, w, h,
                               Double(SkyCloudBank.bytes(.band, tier)) / 1_048_576, g.steps.x, g.taps, hero.particleScale,
                               hero.fps, hero.bloomLevels, card.fps, card.bloomLevels))
        }
        print("SKY9 단계 표\n" + rows.joined(separator: "\n"))
        let order = SkyTier.allCases
        for (a, b) in zip(order, order.dropFirst()) {
            XCTAssertLessThan(SkyCloudBank.Grade(a).density, SkyCloudBank.Grade(b).density)
            XCTAssertLessThan(SkyBudget(.hero, tier: a).particleScale, SkyBudget(.hero, tier: b).particleScale)
            XCTAssertLessThanOrEqual(SkyCloudBank.Grade(a).taps, SkyCloudBank.Grade(b).taps)
        }
        XCTAssertEqual(SkyCloudBank.Shape.band.pixels(SkyCloudBank.Grade(.mid)).w, 960, "중은 8차 판 그대로")
        XCTAssertEqual(SkyCloudBank.Grade(.mid).taps, 2)
        XCTAssertEqual([SkyTier.ultra, .high, .mid, .low].map { SkyBudget(.hero, tier: $0).fps }, [120, 120, 60, 60])
        XCTAssertTrue(SkyTier.allCases.allSatisfy { SkyBudget(.card, tier: $0).fps == 30 })
        XCTAssertGreaterThan(SkyBudget(.hero, tier: .ultra).bloomLevels, SkyBudget(.hero, tier: .low).bloomLevels)

        let gpu = try XCTUnwrap(SkyGPU.shared)
        let p = try XCTUnwrap(SkyCloudBank.shared.plate(.dusk, .band, tier: .ultra, device: gpu.device))
        XCTAssertEqual(p.frames[0].width, SkyCloudBank.Shape.band.pixels(SkyCloudBank.Grade(.ultra)).w)
        XCTAssertFalse(p === SkyCloudBank.shared.plate(.dusk, .band, tier: .mid, device: gpu.device), "단계마다 판이 따로")
        XCTAssertEqual(SkyCloudBank.uniforms(p.key, keyframe: 0, pixels: CGSize(width: 1, height: 1)).rays.z, 3)
    }

    /// 발열로 단계가 내려가도 판은 그대로(다시 굽지 않는다).
    func testHeatKeepsPlate() {
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra, thermal: .serious).plateTier, .ultra)
        XCTAssertEqual(SkyBudget(.hero, tier: .ultra, thermal: .serious).tier, .high)
    }

    func testScrollSpeedCapsFrames() {
        let s = SkyScroll()
        XCTAssertNil(s.cap(now: 10))
        s.report(0, now: 10)
        s.report(5, now: 10.0083)
        s.report(10, now: 10.0166)
        XCTAssertEqual(s.cap(now: 10.02), 60, "천천히 — 60fps")
        for i in 1...6 { s.report(10 + CGFloat(i) * 40, now: 10.0166 + Double(i) * 0.0083) }
        XCTAssertEqual(s.cap(now: 10.07), 0, "빠르게 — 쉰다")
        XCTAssertNil(s.cap(now: 10.4), "멈추면 원래대로")
    }

    /// 10차 — 스크롤이 시작되면 moving, 0.25초 조용하면 내려온다.
    func testScrollMovingSettles() {
        let s = SkyScroll()
        s.report(0, now: 10)
        XCTAssertFalse(s.moving, "첫 보고는 위치만")
        s.report(8, now: 10.008)
        XCTAssertTrue(s.moving)
        XCTAssertFalse(s.settle(now: 10.2), "0.25초 전엔 아직 스크롤 중")
        XCTAssertTrue(s.moving)
        XCTAssertTrue(s.settle(now: 10.3))
        XCTAssertFalse(s.moving)
        s.report(8, now: 11)
        XCTAssertFalse(s.moving, "같은 자리 보고는 스크롤이 아니다")
    }

    /// 풀은 상한까지만 쉬는 뷰를 들고, 빌리면 새로 만들지 않는다.
    func testPoolCap() {
        SkyViewPool.drain()
        let views = (0..<(SkyViewPool.cap + 4)).map { _ in SkyHost(SkyViewPool.take()) }
        views.forEach { SkyViewPool.give($0.mtk) }
        XCTAssertEqual(SkyViewPool.idleCount, SkyViewPool.cap)
        SkyStats.shared.resetCounters()
        let again = (0..<SkyViewPool.cap).map { _ in SkyViewPool.take() }
        XCTAssertEqual(SkyStats.shared.counters.made, 0, "풀 안에서는 새로 만들지 않는다")
        XCTAssertEqual(SkyStats.shared.counters.reused, SkyViewPool.cap)
        XCTAssertTrue(again.allSatisfy { $0.delegate == nil && $0.isPaused })
        SkyViewPool.drain()
    }

    /// 한 화면 8장면(10차 회귀) — 이젠 시간 유예 대신 판 참조 고정: SkyBudgetTests.testPinnedPlatesSurviveStillBakes.

    /// 결과는 Documents/sky/scroll.txt 에 덧붙는다(기기 모델·시각 포함).
    func testScrollResultFileAppends() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sky-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try XCTUnwrap(SkyScrollTest.save(["최상 · 놓침 1"], to: dir))
        SkyScrollTest.save(["상 · 놓침 2", "중 · 놓침 3"], to: dir)
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].hasSuffix("최상 · 놓침 1"))
        XCTAssertTrue(lines[2].contains(SkyScrollTest.model))
        XCTAssertEqual(url.lastPathComponent, "scroll.txt")
    }

    /// 「말」 칸 목록을 창에 띄워 실제로 스크롤한다 — 옛 구조(최상 히어로 실시간)와 새 구조를 잰다.
    /// 시뮬레이터 GPU 는 기기와 달라 놓친 프레임 수치는 참고, 레이마칭 0 은 증명.
    func testScrollProbe() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        var found: UIScrollView?
        window.rootViewController = UIHostingController(rootView: SkyScrollList { found = $0 })
        window.makeKeyAndVisible()
        defer { window.isHidden = true; SkyDebug.tier = nil }
        for _ in 0..<50 where found == nil { try await Task.sleep(for: .milliseconds(100)) }
        let scroll = try XCTUnwrap(found)
        XCTAssertGreaterThan(scroll.contentSize.height, 2000)
        var lines: [String] = []
        var results: [String: SkyScrollTest.Result] = [:]
        for (tier, legacy) in [(SkyTier.ultra, true), (.ultra, false), (.high, false), (.mid, false)] {
            let r = await SkyScrollTest.run(scroll, tier: tier, legacy: legacy, speeds: [1000, 2600])
            results[r.name] = r
            lines.append(r.line)
        }
        let report = "SKY9 스크롤 시험(시뮬레이터)\n" + lines.joined(separator: "\n")
        print(report)
        if let dir = ProcessInfo.processInfo.environment["SKY9_DIR"] {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try report.write(toFile: dir + "/scroll.txt", atomically: true, encoding: .utf8)
        }
        XCTAssertGreaterThan(results["최상 옛 구조"]?.counters.marches ?? 0, 0, "옛 구조는 스크롤 중 히어로를 실시간 레이마칭했다")
        for name in ["최상", "상", "중"] {
            let r = try XCTUnwrap(results[name])
            XCTAssertEqual(r.counters.marches, 0, "\(name) 스크롤 중 구름 레이마칭")
            XCTAssertEqual(r.counters.madeInScroll, 0, "\(name) 스크롤 중 MTKView")
            XCTAssertEqual(r.counters.made, 0, "\(name) 스크롤 중 새 MTKView")
            XCTAssertLessThanOrEqual(r.counters.updates, 12, "\(name) 하늘 갱신은 스크롤 시작 때 보이던 카드 한 번씩뿐")
            XCTAssertLessThanOrEqual(r.counters.bodies, 12, "\(name) 카드 계산도")
        }

        // 멈춘 뒤 — 보이는 카드만 움직이고, 정지 그림에서 튀지 않고 이어진다.
        let shots = try await settleShots(window)
        let hosts = skyHosts(in: window)
        XCTAssertGreaterThan(hosts.count, 0, "멈추면 움직인다")
        for h in hosts {
            XCTAssertTrue(h.convert(h.bounds, to: window).intersects(window.bounds), "화면 밖 카드는 움직이지 않는다")
        }
        XCTAssertLessThanOrEqual(SkyViewPool.idleCount, SkyViewPool.cap)
        XCTAssertTrue(hosts.allSatisfy { $0.mtk.alpha == 1 }, "첫 그림이 나가면 보인다")
        let jump = Self.meanDiff(shots.still, shots.live)
        print(String(format: "SKY10 정지→움직임 평균 차이 %.4f(0~1)", jump))
        if let dir = ProcessInfo.processInfo.environment["SKY9_DIR"] {
            try shots.still.pngData()?.write(to: URL(fileURLWithPath: dir + "/settle-still.png"))
            try shots.live.pngData()?.write(to: URL(fileURLWithPath: dir + "/settle-live.png"))
        }
        XCTAssertLessThan(jump, 0.03, "정지 그림에서 움직이는 하늘로 튀지 않는다")
    }

    /// 결과 줄 필드 이름은 고정 — 기기 결과 파일끼리 비교한다.
    func testResultLineFieldsAreFixed() {
        let fixed = ["시험", "단계", "하늘", "시간", "프레임", "놓침", "끊김", "최악", "하늘 프레임", "GPU", "동시 뷰", "풀 쉼",
                     "하늘 그리기", "쉼", "레이마칭", "하늘 갱신", "카드 계산", "MTKView 생성", "스크롤 중 생성", "풀 재사용", "최대",
                     "정지 그림", "정지 그림 조회", "구운 판", "drawable 활성", "drawable 쉼", "중간 텍스처", "하늘 GPU 합", "정지 그림 캐시", "발열",
                     "GPU 쓰임새", "GPU 패스", "스위치"]
        XCTAssertEqual(SkyScrollTest.fieldNames, fixed)
        var r = SkyScrollTest.Result(name: "최상", kind: "유휴", frozen: true)
        r.sample.thermal = [(0, .nominal), (10, .fair)]
        XCTAssertEqual(r.fields.map(\.0), fixed)
        let parts = r.line.components(separatedBy: " · ")
        XCTAssertEqual(parts.count, fixed.count)
        for (part, name) in zip(parts, fixed) { XCTAssertTrue(part.hasPrefix(name + " "), part) }
        XCTAssertTrue(r.line.hasPrefix("시험 유휴 · 단계 최상 · 하늘 정지 · "))
        XCTAssertEqual(r.thermalLine, "발열 시계열 · 시험 유휴 · 단계 최상 · 하늘 정지 · 0s nominal · 10s fair")
        XCTAssertEqual(r.lines.count, 2)
    }

    /// 계측이 실제로 쌓이고(하늘 켬), 「하늘 정지」면 MTKView 도 그린 프레임도 없다.
    func testSpendProbeAndFrozenSwitch() async throws {
        let (window, scroll) = try await openList()
        defer { window.isHidden = true; SkyDebug.tier = nil; SkyDebug.frozen = false }

        let on = await SkyScrollTest.idle(scroll, tier: .mid, frozen: false, seconds: 3.5)
        print("SKYM1 " + on.lines.joined(separator: "\nSKYM1 "))
        XCTAssertGreaterThan(on.counters.presented, 0, "그린 하늘 프레임")
        XCTAssertGreaterThan(on.counters.gpuFrames, 0, "GPU 시간 받은 프레임")
        XCTAssertGreaterThan(on.sample.viewsMax, 0, "동시 뷰")
        XCTAssertGreaterThan(on.sample.seconds, 0)
        XCTAssertGreaterThan(on.memory.drawables.active, 0, "drawable 메모리")
        XCTAssertGreaterThan(on.memory.renderer, 0, "중간 텍스처")
        XCTAssertGreaterThan(on.memory.gpu, 0)
        XCTAssertGreaterThan(on.counters.gpuUseFrames[.card] ?? 0, 0, "쓰임새별 GPU — 카드")
        XCTAssertGreaterThan(on.counters.gpuUseFrames[.hero] ?? 0, 0, "쓰임새별 GPU — 오늘의 한 장")
        XCTAssertNotNil(on.counters.passSupported, "패스 계측을 시도했다")
        XCTAssertTrue(on.line.contains("GPU 쓰임새 hero "), on.line)
        XCTAssertFalse(on.sample.thermal.isEmpty)
        XCTAssertEqual(on.sample.thermal.first?.at, 0)
        XCTAssertFalse(skyHosts(in: window).isEmpty)

        let scrolled = await SkyScrollTest.run(scroll, tier: .mid, legacy: false, speeds: [2600])
        XCTAssertGreaterThan(scrolled.counters.stillHits + scrolled.counters.stillMisses, 0, "정지 그림 조회")
        XCTAssertGreaterThan(scrolled.memory.stillBytes, 0, "정지 그림 캐시")
        XCTAssertGreaterThan(scrolled.memory.plates, 0, "구운 판")

        for r in [await SkyScrollTest.idle(scroll, tier: .mid, frozen: true, seconds: 2.5),
                  await SkyScrollTest.run(scroll, tier: .mid, legacy: false, frozen: true, speeds: [2600])] {
            print("SKYM1 " + r.lines.joined(separator: "\nSKYM1 "))
            XCTAssertTrue(r.frozen)
            XCTAssertEqual(r.counters.made, 0, "\(r.kind) 하늘 정지 — MTKView 생성")
            XCTAssertEqual(r.counters.reused, 0, "\(r.kind) 하늘 정지 — 풀에서 빌림")
            XCTAssertEqual(r.counters.presented, 0, "\(r.kind) 하늘 정지 — 그린 프레임")
            XCTAssertEqual(r.sample.viewsMax, 0)
        }
        SkyDebug.frozen = true
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(skyHosts(in: window).isEmpty, "하늘 정지 — 떠 있는 MTKView 없음")
    }

    private func openList() async throws -> (UIWindow, UIScrollView) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        var found: UIScrollView?
        window.rootViewController = UIHostingController(rootView: SkyScrollList { found = $0 })
        window.makeKeyAndVisible()
        for _ in 0..<50 where found == nil { try await Task.sleep(for: .milliseconds(100)) }
        return (window, try XCTUnwrap(found))
    }

    /// 스크롤을 조금 움직였다 멈추고 — 멈추기 직전(정지 그림)과 움직이는 하늘이 뜬 직후를 찍는다.
    private func settleShots(_ window: UIWindow) async throws -> (still: UIImage, live: UIImage) {
        let scroll = try XCTUnwrap(findScroll(window))
        scroll.setContentOffset(CGPoint(x: 0, y: 300), animated: false)
        SkyScroll.shared.report(299)
        SkyScroll.shared.report(300)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(SkyScroll.shared.moving)
        XCTAssertTrue(skyHosts(in: window).isEmpty, "스크롤 중엔 정지 그림만")
        let still = shot(window)
        let t0 = CACurrentMediaTime()
        defer { print(String(format: "SKYM2 멈춘 뒤 모두 보이기까지 %.2f초", CACurrentMediaTime() - t0)) }
        // 판 참조 고정 뒤엔 정지 그림만 쓰던 판을 바로 버린다 — 움직이기 시작한 카드는 판을 다시 구울 수 있다(그동안 정지 그림).
        for _ in 0..<200 where !(SkyScroll.shared.moving == false && !skyHosts(in: window).isEmpty
                                && skyHosts(in: window).allSatisfy { $0.mtk.alpha == 1 }) {
            try await Task.sleep(for: .milliseconds(50))
        }
        return (still, shot(window))
    }

    private func findScroll(_ v: UIView) -> UIScrollView? {
        if let s = v as? UIScrollView { return s }
        return v.subviews.lazy.compactMap(findScroll).first
    }

    private func skyHosts(in v: UIView) -> [SkyHost] {
        (v as? SkyHost).map { [$0] } ?? v.subviews.flatMap(skyHosts)
    }

    private func shot(_ window: UIWindow) -> UIImage {
        UIGraphicsImageRenderer(bounds: window.bounds).image { _ in _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
    }

    /// 두 화면의 픽셀 평균 차이(0~1).
    static func meanDiff(_ a: UIImage, _ b: UIImage) -> Double {
        guard let ca = a.cgImage, let cb = b.cgImage else { return 1 }
        let w = 98, h = 213
        func px(_ c: CGImage) -> [UInt8] {
            var buf = [UInt8](repeating: 0, count: w * h * 4)
            let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.interpolationQuality = .medium
            ctx?.draw(c, in: CGRect(x: 0, y: 0, width: w, height: h))
            return buf
        }
        let pa = px(ca), pb = px(cb)
        var sum = 0
        for i in pa.indices where i % 4 != 3 { sum += abs(Int(pa[i]) - Int(pb[i])) }
        return Double(sum) / Double(w * h * 3 * 255)
    }
}
