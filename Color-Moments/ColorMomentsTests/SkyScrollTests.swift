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
            XCTAssertGreaterThan(r.counters.draws, 0, "\(name) 하늘이 그려졌다")
        }
    }
}
