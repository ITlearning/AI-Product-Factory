import Foundation
import CoreImage
import AppKit
import Vision

// 사진 1장 -> 상징색 1개. 다섯 가지 방식을 같은 입력에 돌려 비교한다.
// iOS 앱에 그대로 이식되도록 Core Image 경로를 유지한다.

struct RGB {
    var r: Double, g: Double, b: Double
    var hex: String {
        String(format: "#%02X%02X%02X",
               Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
    var saturation: Double {
        let mx = max(r, g, b), mn = min(r, g, b)
        return mx <= 0 ? 0 : (mx - mn) / mx
    }
    var value: Double { max(r, g, b) }
}

let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

func average(_ image: CIImage, in rect: CGRect) -> RGB {
    let f = CIFilter(name: "CIAreaAverage")!
    f.setValue(image, forKey: kCIInputImageKey)
    f.setValue(CIVector(cgRect: rect), forKey: "inputExtent")
    guard let out = f.outputImage else { return RGB(r: 0, g: 0, b: 0) }
    var px = [UInt8](repeating: 0, count: 4)
    ctx.render(out, toBitmap: &px, rowBytes: 4,
               bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
               format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    return RGB(r: Double(px[0]) / 255, g: Double(px[1]) / 255, b: Double(px[2]) / 255)
}

/// 통계용으로 작게 줄여 픽셀을 뽑는다.
func samplePixels(_ image: CIImage, side: Int = 96) -> [RGB] {
    let e = image.extent
    let s = min(Double(side) / e.width, Double(side) / e.height)
    let small = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
    let w = Int(small.extent.width), h = Int(small.extent.height)
    guard w > 0, h > 0 else { return [] }
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    ctx.render(small, toBitmap: &buf, rowBytes: w * 4,
               bounds: CGRect(x: small.extent.origin.x, y: small.extent.origin.y,
                              width: CGFloat(w), height: CGFloat(h)),
               format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    var out: [RGB] = []
    out.reserveCapacity(w * h)
    for i in stride(from: 0, to: buf.count, by: 4) {
        out.append(RGB(r: Double(buf[i]) / 255, g: Double(buf[i+1]) / 255, b: Double(buf[i+2]) / 255))
    }
    return out
}

/// 최빈색: RGB를 16단계로 양자화해 가장 흔한 칸을 찾고 그 칸 안의 평균을 낸다.
func modeColor(_ px: [RGB]) -> RGB {
    var bins: [Int: (n: Int, r: Double, g: Double, b: Double)] = [:]
    for p in px {
        let q = (Int(p.r * 15) << 8) | (Int(p.g * 15) << 4) | Int(p.b * 15)
        var e = bins[q] ?? (0, 0, 0, 0)
        e.n += 1; e.r += p.r; e.g += p.g; e.b += p.b
        bins[q] = e
    }
    guard let best = bins.max(by: { $0.value.n < $1.value.n })?.value, best.n > 0 else {
        return RGB(r: 0, g: 0, b: 0)
    }
    return RGB(r: best.r / Double(best.n), g: best.g / Double(best.n), b: best.b / Double(best.n))
}

/// k-means. 반환: 클러스터별 (중심색, 비중)
func kmeans(_ px: [RGB], k: Int = 5, iters: Int = 12) -> [(color: RGB, weight: Double)] {
    guard px.count >= k else { return px.map { ($0, 1.0 / Double(px.count)) } }
    var centers: [RGB] = (0..<k).map { px[$0 * px.count / k] }
    var labels = [Int](repeating: 0, count: px.count)
    for _ in 0..<iters {
        for (i, p) in px.enumerated() {
            var bi = 0, bd = Double.infinity
            for (j, c) in centers.enumerated() {
                let d = (p.r-c.r)*(p.r-c.r) + (p.g-c.g)*(p.g-c.g) + (p.b-c.b)*(p.b-c.b)
                if d < bd { bd = d; bi = j }
            }
            labels[i] = bi
        }
        var sums = [(n: Int, r: Double, g: Double, b: Double)](repeating: (0,0,0,0), count: k)
        for (i, p) in px.enumerated() {
            sums[labels[i]].n += 1; sums[labels[i]].r += p.r
            sums[labels[i]].g += p.g; sums[labels[i]].b += p.b
        }
        for j in 0..<k where sums[j].n > 0 {
            centers[j] = RGB(r: sums[j].r / Double(sums[j].n),
                             g: sums[j].g / Double(sums[j].n),
                             b: sums[j].b / Double(sums[j].n))
        }
    }
    var counts = [Int](repeating: 0, count: k)
    for l in labels { counts[l] += 1 }
    let total = Double(px.count)
    return (0..<k).map { (centers[$0], Double(counts[$0]) / total) }
        .sorted { $0.weight > $1.weight }
}

/// 좌표까지 들고 오는 샘플러. 중앙 가중을 쓰려면 픽셀 위치가 필요하다.
func samplePixelsXY(_ image: CIImage, side: Int = 96) -> [(c: RGB, w: Double)] {
    let e = image.extent
    let s = min(Double(side) / e.width, Double(side) / e.height)
    let small = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
    let w = Int(small.extent.width), h = Int(small.extent.height)
    guard w > 0, h > 0 else { return [] }
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    ctx.render(small, toBitmap: &buf, rowBytes: w * 4,
               bounds: CGRect(x: small.extent.origin.x, y: small.extent.origin.y,
                              width: CGFloat(w), height: CGFloat(h)),
               format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    var out: [(RGB, Double)] = []
    for y in 0..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            // 중앙에서의 정규화 거리 -> 가우시안 가중. 중앙 피사체를 우대한다.
            let dx = (Double(x) / Double(w - 1) - 0.5) * 2
            let dy = (Double(y) / Double(h - 1) - 0.5) * 2
            let d2 = dx * dx + dy * dy
            let weight = exp(-d2 / 0.6)
            out.append((RGB(r: Double(buf[i]) / 255, g: Double(buf[i+1]) / 255, b: Double(buf[i+2]) / 255), weight))
        }
    }
    return out
}

/// 채택 후보: 어두운 하위 30%를 버리고, 중앙 가우시안 가중을 곱해 k-means 클러스터를 고른다.
func centerLitColor(_ pxw: [(c: RGB, w: Double)], cut: Double = 0.30) -> RGB {
    guard !pxw.isEmpty else { return RGB(r: 0, g: 0, b: 0) }
    let sorted = pxw.sorted { $0.c.value < $1.c.value }
    let keep = Array(sorted[Int(Double(sorted.count) * cut)...])
    guard !keep.isEmpty else { return RGB(r: 0, g: 0, b: 0) }
    let cl = kmeans(keep.map { $0.c })
    // 각 클러스터의 중앙 가중 합을 다시 계산
    var score = [Double](repeating: 0, count: cl.count)
    for item in keep {
        var bi = 0, bd = Double.infinity
        for (j, e) in cl.enumerated() {
            let c = e.color
            let d = (item.c.r-c.r)*(item.c.r-c.r) + (item.c.g-c.g)*(item.c.g-c.g) + (item.c.b-c.b)*(item.c.b-c.b)
            if d < bd { bd = d; bi = j }
        }
        score[bi] += item.w
    }
    var best = 0, bv = -1.0
    for j in 0..<cl.count {
        let v = score[j] * (0.35 + cl[j].color.saturation)
        if v > bv { bv = v; best = j }
    }
    return cl[best].color
}

/// 밝기 하위 cut 비율을 버린 뒤 k-means. 실루엣·그림자는 색 정보가 아니라 프레임이라는 가설.
func litColor(_ px: [RGB], cut: Double = 0.30) -> RGB {
    guard !px.isEmpty else { return RGB(r: 0, g: 0, b: 0) }
    let sorted = px.sorted { $0.value < $1.value }
    let keep = Array(sorted[Int(Double(sorted.count) * cut)...])
    guard !keep.isEmpty else { return RGB(r: 0, g: 0, b: 0) }
    let cl = kmeans(keep)
    return cl.max { a, b in
        (a.weight * (0.35 + a.color.saturation)) < (b.weight * (0.35 + b.color.saturation))
    }!.color
}

/// Vision 주목도 히트맵. 사람 눈이 어디를 보는지 예측한다. 온디바이스.
/// 반환: (w, h, 0~1 값 배열). 실패 시 nil.
func saliencyMap(_ image: CIImage) -> (w: Int, h: Int, v: [Float])? {
    guard let cg = ctx.createCGImage(image, from: image.extent) else { return nil }
    let req = VNGenerateAttentionBasedSaliencyImageRequest()
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    do { try handler.perform([req]) } catch { return nil }
    guard let obs = req.results?.first as? VNSaliencyImageObservation else { return nil }
    let pb = obs.pixelBuffer
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
    guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
    let stride = CVPixelBufferGetBytesPerRow(pb)
    var out = [Float](repeating: 0, count: w * h)
    for y in 0..<h {
        let row = base.advanced(by: y * stride).assumingMemoryBound(to: Float.self)
        for x in 0..<w { out[y * w + x] = row[x] }
    }
    // 0~1 정규화
    let mn = out.min() ?? 0, mx = out.max() ?? 1
    if mx > mn { for i in out.indices { out[i] = (out[i] - mn) / (mx - mn) } }
    return (w, h, out)
}

/// 채택 후보 2: 어둠 하위컷 + Vision 주목도 가중.
func salientColor(_ image: CIImage, cut: Double = 0.25) -> RGB {
    let pxw = samplePixelsXY(image)      // 좌표 가중이 들어있지만 여기선 색·좌표만 재사용
    guard !pxw.isEmpty else { return RGB(r: 0, g: 0, b: 0) }
    let side = Int(Double(pxw.count).squareRoot().rounded())
    let sal = saliencyMap(image)

    // 좌표를 다시 계산해 주목도 가중을 매긴다 (samplePixelsXY는 행 우선 96폭 기준)
    let e = image.extent
    let sc = min(96.0 / e.width, 96.0 / e.height)
    let w = Int(e.width * sc), h = Int(e.height * sc)
    var items: [(c: RGB, w: Double)] = []
    items.reserveCapacity(pxw.count)
    for i in 0..<pxw.count {
        let x = i % max(w, 1), y = i / max(w, 1)
        var weight = 1.0
        if let s = sal, w > 0, h > 0 {
            let sx = min(s.w - 1, Int(Double(x) / Double(max(w - 1, 1)) * Double(s.w - 1)))
            // Vision 히트맵은 위가 0행. CIImage 샘플은 아래가 0행이라 y를 뒤집는다.
            let fy = 1.0 - Double(y) / Double(max(h - 1, 1))
            let sy = min(s.h - 1, Int(fy * Double(s.h - 1)))
            weight = 0.15 + Double(s.v[sy * s.w + sx])   // 바닥값을 둬서 배경이 완전히 죽지 않게
        }
        items.append((pxw[i].c, weight))
    }
    _ = side
    // 어둠 하위컷
    let sorted = items.sorted { $0.c.value < $1.c.value }
    let keep = Array(sorted[Int(Double(sorted.count) * cut)...])
    guard !keep.isEmpty else { return RGB(r: 0, g: 0, b: 0) }
    let cl = kmeans(keep.map { $0.c })
    var score = [Double](repeating: 0, count: cl.count)
    for item in keep {
        var bi = 0, bd = Double.infinity
        for (j, e2) in cl.enumerated() {
            let c = e2.color
            let d = (item.c.r-c.r)*(item.c.r-c.r) + (item.c.g-c.g)*(item.c.g-c.g) + (item.c.b-c.b)*(item.c.b-c.b)
            if d < bd { bd = d; bi = j }
        }
        score[bi] += item.w
    }
    var best = 0, bv = -1.0
    for j in 0..<cl.count where score[j] > bv { bv = score[j]; best = j }
    return cl[best].color
}

// ---- 실행 ----
var rows: [String] = []
var json: [String] = []

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let img = CIImage(contentsOf: url) else {
        FileHandle.standardError.write("skip \(path)\n".data(using: .utf8)!); continue
    }
    let e = img.extent
    let px = samplePixels(img)

    let whole = average(img, in: e)
    let centerRect = CGRect(x: e.origin.x + e.width * 0.3, y: e.origin.y + e.height * 0.3,
                            width: e.width * 0.4, height: e.height * 0.4)
    let center = average(img, in: centerRect)
    let mode = modeColor(px)
    let clusters = kmeans(px)
    let dominant = clusters[0].color
    // 큰데 칙칙한 덩어리보다, 크기x채도가 가장 높은 덩어리가 사람 눈의 "이 사진의 색"에 가깝다는 가설
    let vivid = clusters.max { a, b in
        (a.weight * (0.35 + a.color.saturation)) < (b.weight * (0.35 + b.color.saturation))
    }!.color
    let lit = litColor(px)
    let centerLit = centerLitColor(samplePixelsXY(img))
    let salient = salientColor(img)

    let name = url.lastPathComponent
    // 썸네일
    let thumbScale = min(320 / e.width, 320 / e.height)
    let thumb = img.transformed(by: CGAffineTransform(scaleX: thumbScale, y: thumbScale))
    if let cg = ctx.createCGImage(thumb, from: thumb.extent) {
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? data.write(to: URL(fileURLWithPath: "thumb-\(name).jpg"))
        }
    }

    func cell(_ label: String, _ c: RGB) -> String {
        "<div class=c><div class=sw style='background:\(c.hex)'></div><b>\(label)</b><code>\(c.hex)</code></div>"
    }
    let clusterBar = clusters.map {
        "<span style='background:\($0.color.hex);flex:\(max(0.02,$0.weight))'></span>"
    }.joined()

    rows.append("""
    <div class=row>
      <img src='thumb-\(name).jpg'>
      <div class=info>
        <div class=name>\(name)</div>
        <div class=cells>
          \(cell("전체 평균", whole))\(cell("중앙 40%", center))\(cell("최빈색", mode))\(cell("k-means 최대", dominant))\(cell("선명도 가중", vivid))\(cell("어두운 30% 버림", lit))\(cell("어둠컷+중앙가중", centerLit))\(cell("어둠컷+주목도 ★", salient))
        </div>
        <div class=bar>\(clusterBar)</div>
      </div>
    </div>
    """)
    json.append("""
    {"file":"\(name)","whole":"\(whole.hex)","center":"\(center.hex)","mode":"\(mode.hex)","dominant":"\(dominant.hex)","vivid":"\(vivid.hex)","lit":"\(lit.hex)","centerLit":"\(centerLit.hex)","salient":"\(salient.hex)"}
    """)
    print("\(name)  전체 \(whole.hex) | 중앙 \(center.hex) | 최빈 \(mode.hex) | k최대 \(dominant.hex) | 선명 \(vivid.hex) | 밝은쪽 \(lit.hex) | 중앙+밝은쪽 \(centerLit.hex) | 주목도 \(salient.hex)")
}

let html = """
<!doctype html><meta charset=utf-8><title>색 추출 비교</title>
<style>
body{background:#111;color:#eee;font:14px -apple-system,sans-serif;margin:0;padding:24px}
h1{font-size:18px;font-weight:600;margin:0 0 4px}
p.sub{color:#888;margin:0 0 24px;font-size:12px}
.row{display:flex;gap:16px;align-items:flex-start;padding:16px 0;border-top:1px solid #262626}
.row img{width:150px;border-radius:8px;display:block}
.info{flex:1;min-width:0}
.name{color:#777;font-size:11px;font-family:ui-monospace,monospace;margin-bottom:10px}
.cells{display:flex;gap:10px;flex-wrap:wrap}
.c{text-align:center}
.sw{width:76px;height:76px;border-radius:8px;border:1px solid #333}
.c b{display:block;font-size:11px;font-weight:500;margin-top:6px;color:#bbb}
.c code{display:block;font-size:10px;color:#666}
.bar{display:flex;height:14px;margin-top:12px;border-radius:4px;overflow:hidden}
.bar span{display:block}
</style>
<h1>사진 1장 → 상징색 1개 · 다섯 가지 방식 비교</h1>
<p class=sub>맨 아래 띠는 k-means 5개 클러스터를 비중 폭으로 늘어놓은 것. ★는 어두운 하위 25%를 버리고 Vision 주목도 히트맵으로 가중한 것.</p>
\(rows.joined(separator: "\n"))
"""
try? html.write(toFile: "compare.html", atomically: true, encoding: .utf8)
try? ("[\n" + json.joined(separator: ",\n") + "\n]").write(toFile: "colors.json", atomically: true, encoding: .utf8)
FileHandle.standardError.write("\nwrote compare.html\n".data(using: .utf8)!)
