// 릴스 앞부분에 초록 배경 밈을 얹는다 — 초록을 빼고 사진 자리 위에 세운다. 프레임 JPEG 를 덮어쓴다.
//   meme <프레임 폴더> <초록 배경 영상> <앞부분 초> <fps> <사진 자리 x,y,w,h>
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1]), clip = URL(fileURLWithPath: args[2])
let intro = Double(args[3])!, fps = Double(args[4])!
let box = args[5].split(separator: ",").map { CGFloat(Double($0)!) }
let count = Int((intro * fps).rounded())
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

// 초록 빼기 — 초록이 빨강·파랑보다 얼마나 앞서는지로 투명도를 정하고, 털 가장자리에 남은 초록은 눌러 둔다.
func key(_ buffer: CVPixelBuffer) -> (CGImage, CGRect) {
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
  let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer), row = CVPixelBufferGetBytesPerRow(buffer)
  let src = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
  var out = [UInt8](repeating: 0, count: w * h * 4)
  var minX = w, minY = h, maxX = 0, maxY = 0
  for y in 0..<h {
    for x in 0..<w {
      let p = src + y * row + x * 4, b = Double(p[0]), g = Double(p[1]), r = Double(p[2])
      let spill = g - max(r, b), a = min(1, max(0, 1 - (spill - 30) / 50))
      guard a > 0 else { continue }
      // 초록을 누르면 보랏빛이 돌아서 회색 쪽으로 60% 당긴다 — 영상 속 털 색에 가깝다.
      let gg = min(g, max(r, b)), l = 0.3 * r + 0.59 * gg + 0.11 * b, o = (y * w + x) * 4
      let mix = { (c: Double) in UInt8((c * 0.4 + l * 0.6) * a) }
      out[o] = mix(b); out[o + 1] = mix(gg); out[o + 2] = mix(r); out[o + 3] = UInt8(a * 255)
      if a > 0.5 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
    }
  }
  let ctx = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: srgb, bitmapInfo: info)!
  return (ctx.makeImage()!, CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY)))
}

var cats: [CGImage] = [], bounds = CGRect.null
let sem = DispatchSemaphore(value: 0)
Task {
  let asset = AVURLAsset(url: clip)
  let track = try await asset.loadTracks(withMediaType: .video).first!
  let reader = try AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  reader.add(output)
  reader.startReading()
  while cats.count < count, let sample = output.copyNextSampleBuffer(), let buffer = CMSampleBufferGetImageBuffer(sample) {
    let (img, rect) = key(buffer)
    cats.append(img); bounds = bounds.union(rect)
  }
  sem.signal()
}
sem.wait()
guard !cats.isEmpty, !bounds.isNull else { fatalError("밈 영상에서 그림을 못 읽었어요: \(clip.path)") }

// 사진 자리 높이의 90% 로 세우고, 발이 사진 아래 끝에 닿게 한다.
let scale = box[3] * 0.9 / bounds.height
let drawW = CGFloat(cats[0].width) * scale, drawH = CGFloat(cats[0].height) * scale
let left = box[0] + box[2] / 2 - (bounds.midX * scale), top = box[1] + box[3] + 20 - bounds.maxY * scale

for i in 0..<count {
  let url = dir.appendingPathComponent(String(format: "f%05d.jpg", i))
  guard let s = CGImageSourceCreateWithURL(url as CFURL, nil), let frame = CGImageSourceCreateImageAtIndex(s, 0, nil) else { continue }
  let W = frame.width, H = frame.height
  let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: srgb, bitmapInfo: info)!
  ctx.draw(frame, in: CGRect(x: 0, y: 0, width: W, height: H))
  ctx.interpolationQuality = .high
  ctx.setShadow(offset: .zero, blur: 46, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.55)) // 까만 고양이가 어두운 사진에 묻히지 않게
  ctx.draw(cats[i % cats.count], in: CGRect(x: left, y: CGFloat(H) - top - drawH, width: drawW, height: drawH))
  let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dst, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
  CGImageDestinationFinalize(dst)
}
