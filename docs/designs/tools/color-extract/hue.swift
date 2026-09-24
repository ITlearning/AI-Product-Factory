import Foundation
import CoreImage
import AppKit

let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

struct RGB {
    var r: Double, g: Double, b: Double
    var hex: String { String(format:"#%02X%02X%02X", Int((r*255).rounded()), Int((g*255).rounded()), Int((b*255).rounded())) }
    var v: Double { max(r,g,b) }
    var s: Double { let mx = max(r,g,b), mn = min(r,g,b); return mx <= 0 ? 0 : (mx-mn)/mx }
    var h: Double {
        let mx = max(r,g,b), mn = min(r,g,b), d = mx-mn
        if d == 0 { return -1 }   // 무채색
        var x: Double
        if mx == r { x = 60 * (((g-b)/d).truncatingRemainder(dividingBy: 6)) }
        else if mx == g { x = 60 * ((b-r)/d + 2) }
        else { x = 60 * ((r-g)/d + 4) }
        return x < 0 ? x + 360 : x
    }
    /// 채도를 목표치로 끌어올린다. 사람의 기억색은 실제 픽셀보다 선명하다.
    func boosted(to target: Double) -> RGB {
        guard s > 0.005, s < target else { return self }
        let mx = max(r,g,b)
        let k = (1 - target) * mx
        let scale = (mx - k) / max(mx - mx*(1-s), 1e-6)
        func f(_ c: Double) -> Double { min(1, max(0, k + (c - mx*(1-s)) * scale)) }
        return RGB(r: f(r), g: f(g), b: f(b))
    }
}

func sample(_ img: CIImage, side: Int = 240) -> [RGB] {
    let e = img.extent, sc = min(Double(side)/e.width, Double(side)/e.height)
    let sm = img.transformed(by: CGAffineTransform(scaleX: sc, y: sc))
    let w = Int(sm.extent.width), h = Int(sm.extent.height)
    var buf = [UInt8](repeating: 0, count: w*h*4)
    ctx.render(sm, toBitmap: &buf, rowBytes: w*4,
               bounds: CGRect(x: sm.extent.origin.x, y: sm.extent.origin.y, width: CGFloat(w), height: CGFloat(h)),
               format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    return stride(from: 0, to: buf.count, by: 4).map {
        RGB(r: Double(buf[$0])/255, g: Double(buf[$0+1])/255, b: Double(buf[$0+2])/255) }
}

/// hue 30도 폭으로 묶어 가장 큰 대역을 찾고, 그 대역의 (채도 가중) 평균을 낸다.
/// 명암으로 쪼개진 같은 색을 하나로 되돌리는 것이 요점.
func hueBandColor(_ px: [RGB], darkCut: Double = 0.25, boost: Double) -> (RGB, String) {
    let lit = px.sorted { $0.v < $1.v }
    let kept = Array(lit[Int(Double(lit.count)*darkCut)...])
    let bandCount = 12                     // 30도씩
    var w = [Double](repeating: 0, count: bandCount)
    var acc = [(r: Double, g: Double, b: Double, n: Double)](repeating: (0,0,0,0), count: bandCount)
    var achromatic = 0.0
    for p in kept {
        if p.h < 0 || p.s < 0.03 { achromatic += 1; continue }
        let b = Int(p.h / 30) % bandCount
        // 채도가 높을수록 그 대역의 주장이 강하다
        let weight = 0.3 + p.s
        w[b] += weight
        acc[b].r += p.r * weight; acc[b].g += p.g * weight; acc[b].b += p.b * weight; acc[b].n += weight
    }
    guard let best = (0..<bandCount).max(by: { w[$0] < w[$1] }), acc[best].n > 0 else {
        let m = kept.reduce((0.0,0.0,0.0)) { ($0.0+$1.r, $0.1+$1.g, $0.2+$1.b) }
        let n = Double(kept.count)
        return (RGB(r: m.0/n, g: m.1/n, b: m.2/n), "무채색")
    }
    let raw = RGB(r: acc[best].r/acc[best].n, g: acc[best].g/acc[best].n, b: acc[best].b/acc[best].n)
    let share = w[best] / (w.reduce(0,+) + achromatic*0.3)
    return (raw.boosted(to: boost), String(format: "hue %d~%d도 · 점유 %.0f%% · 원색 %@",
            best*30, best*30+30, share*100, raw.hex))
}

for path in CommandLine.arguments.dropFirst() {
    guard let img = CIImage(contentsOf: URL(fileURLWithPath: path)) else { continue }
    let px = sample(img)
    let name = URL(fileURLWithPath: path).lastPathComponent
    var line = String(format: "%-16s", (name as NSString).utf8String!)
    var info = ""
    for cut in [0.25, 0.50, 0.65] {
        let (c, i) = hueBandColor(px, darkCut: cut, boost: 0.32)
        line += "  컷\(Int(cut*100))% \(c.hex)"
        if cut == 0.50 { info = i }
    }
    print(line + "   (" + info + ")")
}
