// 화면 녹화를 릴스(1080×1920, 30fps)로 — 바탕 그림 위 가운데에 녹화 화면(둥근 모서리)을 얹고, 끝에 끝 장면을 이어 붙인다.
//   screenreel <녹화.mp4> <시작초> <끝초> <바탕.png> <끝.png> <out.mp4> <잘라낼 위아래 비율 top,bottom>
import AVFoundation
import CoreImage
import ImageIO

let a = CommandLine.arguments
let src = URL(fileURLWithPath: a[1]), start = Double(a[2])!, stop = Double(a[3])!
let crop = a[7].split(separator: ",").map { Double($0)! }
func png(_ p: String) -> CGImage { CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil)!, 0, nil)! }
let bg = png(a[4]), end = png(a[5]), out = URL(fileURLWithPath: a[6])
let W = 1080, H = 1920, fps = 30.0, endSecs = 3.0, fade = 0.4
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

try? FileManager.default.removeItem(at: out)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 14_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)

var n: Int64 = 0
func emit(_ draw: (CGContext) -> Void) {
  while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.003) }
  var pb: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
  let b = pb!; CVPixelBufferLockBaseAddress(b, [])
  let ctx = CGContext(data: CVPixelBufferGetBaseAddress(b), width: W, height: H, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(b), space: srgb, bitmapInfo: info)!
  ctx.interpolationQuality = .high
  draw(ctx); CVPixelBufferUnlockBaseAddress(b, [])
  adaptor.append(b, withPresentationTime: CMTime(value: n, timescale: Int32(fps))); n += 1
}

let ciContext = CIContext()
let sem = DispatchSemaphore(value: 0)
Task {
  let asset = AVURLAsset(url: src)
  let track = try await asset.loadTracks(withMediaType: .video).first!
  let reader = try AVAssetReader(asset: asset)
  reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: stop, preferredTimescale: 600))
  let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  reader.add(output); reader.startReading()
  var latest: CGImage? = nil, next = start
  var rect = CGRect.zero, srcRect = CGRect.zero
  func place(_ img: CGImage) {
    // 위(상태 막대·녹화 점)와 아래(사파리 도구 막대)를 잘라 내고, 높이 1380 에 맞춰 가운데.
    let sw = Double(img.width), sh = Double(img.height)
    srcRect = CGRect(x: 0, y: sh * crop[0], width: sw, height: sh * (1 - crop[0] - crop[1]))
    let dh: CGFloat = 1380, dw: CGFloat = dh * srcRect.width / srcRect.height
    rect = CGRect(x: (CGFloat(W) - dw) / 2, y: CGFloat(H) - 360 - dh, width: dw, height: dh)
  }
  func frame(_ ctx: CGContext, _ img: CGImage) {
    ctx.draw(bg, in: CGRect(x: 0, y: 0, width: W, height: H))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 60, color: CGColor(gray: 0, alpha: 0.6))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 44, cornerHeight: 44, transform: nil)); ctx.setFillColor(gray: 0, alpha: 1); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 44, cornerHeight: 44, transform: nil)); ctx.clip()
    if let c = img.cropping(to: srcRect) { ctx.draw(c, in: rect) }
    ctx.restoreGState()
  }
  while let s = output.copyNextSampleBuffer() {
    guard let buf = CMSampleBufferGetImageBuffer(s) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(s).seconds
    let ci = CIImage(cvPixelBuffer: buf)
    let img = ciContext.createCGImage(ci, from: ci.extent)!
    if latest == nil { place(img) }
    while next <= t, let l = latest { emit { frame($0, l) }; next += 1 / fps }
    latest = img
  }
  if let l = latest {
    while next < stop { emit { frame($0, l) }; next += 1 / fps }
    let fadeN = Int(fade * fps), endN = Int(endSecs * fps)
    for i in 0..<endN {
      emit { ctx in
        frame(ctx, l)
        ctx.setAlpha(min(1, Double(i + 1) / Double(fadeN)))
        ctx.draw(end, in: CGRect(x: 0, y: 0, width: W, height: H))
      }
    }
  }
  input.markAsFinished()
  writer.finishWriting { sem.signal() }
}
sem.wait()
guard writer.status == .completed else { fatalError("\(String(describing: writer.error))") }
print(n)
