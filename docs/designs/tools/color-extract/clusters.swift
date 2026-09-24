import Foundation
import CoreImage
import AppKit

let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
struct RGB { var r: Double, g: Double, b: Double
    var hex: String { String(format:"#%02X%02X%02X", Int((r*255).rounded()), Int((g*255).rounded()), Int((b*255).rounded())) }
    var value: Double { max(r,g,b) }
    var sat: Double { let mx = max(r,g,b), mn = min(r,g,b); return mx <= 0 ? 0 : (mx-mn)/mx }
    /// 분홍 계열인가 (대략 320~20도 hue, 채도 0.05 이상)
    var hueDeg: Double {
        let mx = max(r,g,b), mn = min(r,g,b), d = mx-mn
        if d == 0 { return 0 }
        var h: Double
        if mx == r { h = 60 * (((g-b)/d).truncatingRemainder(dividingBy: 6)) }
        else if mx == g { h = 60 * ((b-r)/d + 2) }
        else { h = 60 * ((r-g)/d + 4) }
        return h < 0 ? h + 360 : h
    }
}
func sample(_ img: CIImage, side: Int) -> [RGB] {
    let e = img.extent, s = min(Double(side)/e.width, Double(side)/e.height)
    let sm = img.transformed(by: CGAffineTransform(scaleX: s, y: s))
    let w = Int(sm.extent.width), h = Int(sm.extent.height)
    var buf = [UInt8](repeating: 0, count: w*h*4)
    ctx.render(sm, toBitmap: &buf, rowBytes: w*4,
               bounds: CGRect(x: sm.extent.origin.x, y: sm.extent.origin.y, width: CGFloat(w), height: CGFloat(h)),
               format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    return stride(from: 0, to: buf.count, by: 4).map {
        RGB(r: Double(buf[$0])/255, g: Double(buf[$0+1])/255, b: Double(buf[$0+2])/255) }
}
func kmeans(_ px: [RGB], k: Int, iters: Int = 20) -> [(RGB, Double)] {
    guard px.count >= k else { return [] }
    var c: [RGB] = (0..<k).map { px[$0 * px.count / k] }
    var lab = [Int](repeating: 0, count: px.count)
    for _ in 0..<iters {
        for (i,p) in px.enumerated() {
            var bi = 0, bd = Double.infinity
            for (j,cc) in c.enumerated() {
                let d = (p.r-cc.r)*(p.r-cc.r)+(p.g-cc.g)*(p.g-cc.g)+(p.b-cc.b)*(p.b-cc.b)
                if d < bd { bd = d; bi = j } }
            lab[i] = bi }
        var s = [(Int,Double,Double,Double)](repeating:(0,0,0,0), count:k)
        for (i,p) in px.enumerated() { s[lab[i]].0 += 1; s[lab[i]].1 += p.r; s[lab[i]].2 += p.g; s[lab[i]].3 += p.b }
        for j in 0..<k where s[j].0 > 0 { c[j] = RGB(r: s[j].1/Double(s[j].0), g: s[j].2/Double(s[j].0), b: s[j].3/Double(s[j].0)) }
    }
    var cnt = [Int](repeating:0,count:k); for l in lab { cnt[l] += 1 }
    return (0..<k).map { (c[$0], Double(cnt[$0])/Double(px.count)) }.sorted { $0.1 > $1.1 }
}
for path in CommandLine.arguments.dropFirst() {
    guard let img = CIImage(contentsOf: URL(fileURLWithPath: path)) else { continue }
    print("=== \(URL(fileURLWithPath: path).lastPathComponent)")
    for side in [96, 300, 700] {
        let px = sample(img, side: side)
        let lit = px.sorted { $0.value < $1.value }
        let kept = Array(lit[Int(Double(lit.count)*0.30)...])
        print("  샘플 \(side)px (\(px.count) 픽셀), k=6, 어두운 30% 버린 뒤:")
        for (c, w) in kmeans(kept, k: 6) where w > 0.03 {
            let pink = (c.hueDeg >= 300 || c.hueDeg <= 30) && c.sat > 0.04
            print(String(format: "    %@  %4.1f%%  hue %3.0f  sat %.2f %@", c.hex, w*100, c.hueDeg, c.sat, pink ? " <- 분홍 계열" : ""))
        }
    }
}
