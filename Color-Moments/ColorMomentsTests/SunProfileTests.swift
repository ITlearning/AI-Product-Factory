import CoreImage
import Metal
import SwiftUI
import XCTest
@testable import ColorMoments

/// 9차 — 해 단면. 실제 렌더 픽셀을 해 중심에서 바깥으로 링마다 재서, 한 덩어리로 매끄럽게 줄어드는지 본다.
/// 겹친 원(심지 두 겹의 어깨·EDR 어깨의 평평한 꼭대기)은 단면의 2차 미분 부호가 여러 번 바뀌거나 평평한 구간으로 드러난다.
@MainActor
final class SunProfileTests: XCTestCase {
    static let scenes: [SkyScene] = [.clearDay, .petals, .leaves, .frost, .wind, .dawn, .dusk]
    static let sizes: [(String, SkyQuality, CGSize)] = [("위젯", .hero, CGSize(width: 170, height: 170)),
                                                         ("히어로", .hero, CGSize(width: 354, height: 232)),
                                                         ("전체", .full, CGSize(width: 393, height: 852))]
    static let scale: CGFloat = 3

    struct Profile {
        var radius: CGFloat
        var values: [Double]
        var step: Double
        var start: Double
    }

    /// 링(0.5pt)마다 지각 밝기(sRGB 감마 휘도, 0~head^(1/2.2)) 중앙값. 해 원판 반지름의 8배까지.
    func profile(_ frame: SkyFrame, headroom: Float, clouds: Bool) throws -> Profile {
        let gpu = try XCTUnwrap(SkyGPU.shared)
        var b = SkyBudget(frame.quality, tier: .ultra, still: true)
        b.particleScale = 0
        if !clouds { b.cloudSteps = 0; b.farSteps = 0; b.bakedClouds = false }
        let (w, h, px) = try hdr(gpu, frame, headroom: headroom, budget: b)
        let l = frame.light
        let step = 0.5, reach = Double(l.radius) * 8
        let n = Int(reach / step)
        var rings = [[Double]](repeating: [], count: n)
        let s = Double(Self.scale)
        let cx = Double(l.center.x) * s, cy = Double(l.center.y) * s
        let rpx = reach * s
        for y in max(0, Int(cy - rpx))..<min(h, Int(cy + rpx) + 1) {
            for x in max(0, Int(cx - rpx))..<min(w, Int(cx + rpx) + 1) {
                let d = hypot(Double(x) + 0.5 - cx, Double(y) + 0.5 - cy) / s
                let k = Int(d / step)
                guard k < n else { continue }
                let i = (y * w + x) * 4
                let L = 0.2126 * Double(px[i]) + 0.7152 * Double(px[i + 1]) + 0.0722 * Double(px[i + 2])
                rings[k].append(pow(max(L, 0), 1 / 2.2))
            }
        }
        var vals: [Double] = [], start = 0
        for (k, r) in rings.enumerated() {
            guard !r.isEmpty else { if vals.isEmpty { start = k + 1; continue } else { break } }
            let sorted = r.sorted()
            vals.append(sorted[sorted.count / 2])
        }
        return Profile(radius: l.radius, values: vals, step: step, start: Double(start) * step)
    }

    struct Shape {
        var rises: Double   // 바깥으로 가며 다시 밝아진 가장 큰 폭(지각 밝기)
        var rim: Double     // 반지름 1/4 안에서 기울기가 얼마나 갑자기 붙는가(최대 기울기 대비) — 평평한 원판의 테두리
        var flips: Int      // 기울기 봉우리 수 - 1 — 원판 위에 원판이면 봉우리가 둘
        var plateau: Double // 꼭대기가 평평한 길이(pt)
    }

    func shape(_ p: Profile) -> Shape {
        let v = smooth(p.values, 1)
        guard v.count > 8, p.start == 0 else { return Shape(rises: 0, rim: 0, flips: 0, plateau: 0) }
        var rises = 0.0
        var lo = v[0]
        for x in v { rises = max(rises, x - lo); lo = min(lo, x) }
        let s = smooth(zip(v.dropFirst(), v).map { -($0 - $1) / p.step }, 1)
        let r = Double(p.radius)
        let lim = min(Int(5 * r / p.step), s.count), half = max(Int((0.25 * r / p.step).rounded()), 1)
        let peak = s[..<lim].max() ?? 0
        guard peak > 0 else { return Shape(rises: rises, rim: 0, flips: 0, plateau: 0) }
        var rim = 0.0
        for i in 0..<max(lim - half, 0) { rim = max(rim, (s[i + half] - s[i]) / peak) }
        var flips = 0, up = true, extreme = s[0]
        for x in s[..<lim] {
            if up, x < extreme - 0.15 * peak { up = false; extreme = x; continue }
            if !up, x > extreme + 0.15 * peak { up = true; flips += 1; extreme = x; continue }
            extreme = up ? max(extreme, x) : min(extreme, x)
        }
        let top = v[0]
        var plateau = 0.0
        for (i, x) in s.enumerated() where v[i] > 0.97 * top && x < 0.002 { plateau += p.step }
        return Shape(rises: rises, rim: rim, flips: flips, plateau: plateau)
    }

    private func smooth(_ v: [Double], _ r: Int) -> [Double] {
        v.indices.map { i in
            let lo = max(0, i - r), hi = min(v.count - 1, i + r)
            return v[lo...hi].reduce(0, +) / Double(hi - lo + 1)
        }
    }

    /// 구름 없이 잰 해 단면이 한 덩어리 — 다시 밝아지지 않고, 기울기 봉우리가 하나, 평평한 원판의 테두리(갑자기 붙는 기울기)가 없다.
    /// 구름 있는 단면은 표에만(구름 가장자리가 섞인다).
    func testSunFallsOffAsOneSmoothShape() throws {
        var rows: [String] = [], fails: [String] = []
        let env = ProcessInfo.processInfo.environment
        let tag = env["SKY9B_TAG"] ?? "now"
        for scene in Self.scenes {
            for (size, q, dim) in Self.sizes {
                for head: Float in [1, 2, 4] {
                    for clouds in [false, true] {
                        let f = SkyFrame(scene: scene, quality: q, size: dim, texts: SkyTexts.none)
                        guard f.light.drawn else { continue }
                        let p = try profile(f, headroom: head, clouds: clouds)
                        let s = shape(p)
                        let row = String(format: "%@ %@ 여유%.0f %@ | r %.1fpt | 다시 밝아짐 %.4f | 테두리 %.2f | 봉우리 %d | 평평 %.2fpt",
                                         scene.name, size, head, clouds ? "구름" : "맑게", p.radius, s.rises, s.rim, s.flips + 1, s.plateau)
                        rows.append(row)
                        if !clouds, s.rises > 0.004 || s.rim > Self.rimLimit || s.flips > 0 { fails.append(row) }
                        if let dir = env["SKY9B_DIR"] {
                            let name = "profile-\(tag)-\(scene)-\(size)-h\(Int(head))\(clouds ? "-c" : "").txt"
                            let text = p.values.enumerated().map { String(format: "%.2f\t%.4f", p.start + Double($0.offset) * p.step, $0.element) }
                            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                            try text.joined(separator: "\n").write(toFile: dir + "/" + name, atomically: true, encoding: .utf8)
                        }
                    }
                }
            }
        }
        let report = "SKY9B 해 단면\n" + rows.joined(separator: "\n") + "\n실패:\n" + fails.joined(separator: "\n")
        print(report)
        if let dir = env["SKY9B_DIR"] {
            try report.write(toFile: dir + "/sun-\(tag).txt", atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(fails.isEmpty, "해 단면이 한 덩어리가 아니다:\n" + fails.joined(separator: "\n"))
    }

    static let rimLimit = 0.65

    /// 해 확대 PNG — 히어로 카드의 해 둘레(가로 12r), 장면마다 [구름 없이 여유1 · 여유2 · 구름 있게 여유1 · 여유2]. 여유2는 1/2 로 눌러 모양만. SKY9B_DIR.
    func testDumpSunCrops() throws {
        guard let dir = ProcessInfo.processInfo.environment["SKY9B_DIR"] else { throw XCTSkip("SKY9B_DIR 없음") }
        let tag = ProcessInfo.processInfo.environment["SKY9B_TAG"] ?? "now"
        let gpu = try XCTUnwrap(SkyGPU.shared)
        var rows: [(String, [CGImage])] = []
        for scene in Self.scenes where scene != .dawn {
            var tiles: [CGImage] = []
            for clouds in [false, true] {
                for head: Float in [1, 2] {
                    let f = SkyFrame(scene: scene, quality: .hero, size: CGSize(width: 354, height: 232), texts: SkyTexts.none)
                    var b = SkyBudget(.hero, tier: .ultra, still: true)
                    b.particleScale = 0
                    if !clouds { b.cloudSteps = 0; b.farSteps = 0; b.bakedClouds = false }
                    let (w, h, px) = try hdr(gpu, f, headroom: head, budget: b)
                    let l = f.light, s = Self.scale
                    let x0 = max(0, Int((l.center.x - 6 * l.radius) * s)), x1 = min(w, Int((l.center.x + 6 * l.radius) * s))
                    let y0 = max(0, Int((l.center.y - 4 * l.radius) * s)), y1 = min(h, Int((l.center.y + 4 * l.radius) * s))
                    let cw = x1 - x0, ch = y1 - y0
                    var out = [UInt8](repeating: 255, count: cw * ch * 4)
                    for y in 0..<ch {
                        for x in 0..<cw {
                            let i = ((y + y0) * w + x + x0) * 4, o = (y * cw + x) * 4
                            for c in 0..<3 {
                                let v = Double(px[i + c]) / Double(head)
                                out[o + c] = UInt8(min(max(pow(max(v, 0), 1 / 2.2), 0), 1) * 255)
                            }
                        }
                    }
                    let ctx = try XCTUnwrap(CGContext(data: &out, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: cw * 4,
                                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    tiles.append(try XCTUnwrap(ctx.makeImage()))
                }
            }
            rows.append((scene.name, tiles))
        }
        let r = ImageRenderer(content: VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "\(tag) — 구름 없이 여유1 · 여유2(÷2) · 구름 있게 여유1 · 여유2(÷2)").font(.system(size: 12)).foregroundStyle(.white)
            ForEach(rows.indices, id: \.self) { k in
                HStack(spacing: 6) {
                    Text(rows[k].0).font(.system(size: 12)).foregroundStyle(.white).frame(width: 40)
                    ForEach(rows[k].1.indices, id: \.self) { i in
                        let img = rows[k].1[i]
                        Image(decorative: img, scale: 1).resizable().frame(width: 260, height: 260 * CGFloat(img.height) / CGFloat(img.width))
                    }
                }
            }
        }.padding(6).background(Color.black))
        r.scale = 1
        try XCTUnwrap(r.uiImage?.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent("sun-crops-\(tag).png"))
    }

    /// 단면 그래프 — SKY9B_DIR 의 profile-<전>-…·profile-<후>-… 를 나란히(지각 밝기와 그 기울기). SKY9B_GRAPH="전,후".
    func testDumpProfileGraphs() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["SKY9B_DIR"], let pair = env["SKY9B_GRAPH"]?.split(separator: ",").map(String.init), pair.count == 2
        else { throw XCTSkip("SKY9B_GRAPH 없음") }
        func load(_ tag: String, _ scene: SkyScene, _ size: String, _ head: Int) -> [Double] {
            let path = "\(dir)/profile-\(tag)-\(scene)-\(size)-h\(head).txt"
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
            return text.split(separator: "\n").compactMap { $0.split(separator: "\t").last.flatMap { Double($0) } }
        }
        let size = "히어로"
        let colors: [Color] = [.gray, .orange]
        let grid = VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "해 단면 — \(size), 회색 \(pair[0]) · 주황 \(pair[1]). 위: 지각 밝기(0~1), 아래: 기울기(바깥으로 갈수록). 가로 0~8r")
                .font(.system(size: 11)).foregroundStyle(.white)
            ForEach(Self.scenes.filter { $0 != .dawn }, id: \.self) { scene in
                HStack(spacing: 10) {
                    Text(scene.name).font(.system(size: 11)).foregroundStyle(.white).frame(width: 40)
                    ForEach([1, 2, 4], id: \.self) { head in
                        let curves = pair.map { load($0, scene, size, head) }
                        ZStack(alignment: .topLeading) {
                            Canvas { ctx, sz in
                                let top = curves.flatMap { $0 }.max() ?? 1
                                for (k, v) in curves.enumerated() where v.count > 3 {
                                    var p = Path(), q = Path()
                                    let slope = (1..<v.count).map { max(v[$0 - 1] - v[$0], 0) }
                                    let sm = slope.max() ?? 1
                                    for i in v.indices {
                                        let x = sz.width * Double(i) / Double(v.count - 1)
                                        let y = sz.height * 0.5 * (1 - v[i] / top)
                                        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                                        if i > 0 {
                                            let yy = sz.height * (1 - 0.45 * slope[i - 1] / max(sm, 1e-6))
                                            i == 1 ? q.move(to: CGPoint(x: x, y: yy)) : q.addLine(to: CGPoint(x: x, y: yy))
                                        }
                                    }
                                    ctx.stroke(p, with: .color(colors[k]), lineWidth: 1.5)
                                    ctx.stroke(q, with: .color(colors[k].opacity(0.8)), lineWidth: 1)
                                }
                            }
                            Text("여유 \(head)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.7)).padding(3)
                        }
                        .frame(width: 220, height: 130).background(Color(white: 0.12))
                    }
                }
            }
        }.padding(10).background(Color.black)
        let r = ImageRenderer(content: grid)
        r.scale = 2
        try XCTUnwrap(r.uiImage?.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent("sun-graph-\(pair[0])-\(pair[1]).png"))
    }

    private func hdr(_ gpu: SkyGPU, _ frame: SkyFrame, headroom: Float, budget: SkyBudget) throws -> (Int, Int, [Float]) {
        let w = Int(frame.size.width * Self.scale), h = Int(frame.size.height * Self.scale)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        let target = try XCTUnwrap(gpu.device.makeTexture(descriptor: d))
        let cb = try XCTUnwrap(gpu.queue.makeCommandBuffer())
        SkyRenderer(gpu: gpu).encode(cb, into: target, frame: frame, t: SceneArt.stillPhase, headroom: headroom, budget: budget)
        cb.commit(); cb.waitUntilCompleted()
        let lin = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let ci = try XCTUnwrap(CIImage(mtlTexture: target, options: [.colorSpace: lin])).oriented(.downMirrored)
        var px = [Float](repeating: 0, count: w * h * 4)
        CIContext(mtlDevice: gpu.device, options: [.workingColorSpace: lin])
            .render(ci, toBitmap: &px, rowBytes: w * 16, bounds: ci.extent, format: .RGBAf, colorSpace: lin)
        return (w, h, px)
    }
}
