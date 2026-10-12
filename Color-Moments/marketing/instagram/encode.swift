// JPEG 프레임 폴더를 H.264 mp4 로 묶는다 — ffmpeg 없이 AVFoundation 으로.
//   encode <프레임 폴더> <out.mp4> [fps]
import AVFoundation
import ImageIO

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let fps = Int32(args.count > 3 ? args[3] : "30") ?? 30
let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
  .filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

func load(_ url: URL) -> CGImage {
  guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    fatalError("프레임을 못 읽었어요: \(url.path)")
  }
  return img
}
guard let first = files.first else { fatalError("프레임이 없어요: \(dir.path)") }
let (w, h) = { let i = load(first); return (i.width, i.height) }()

try? FileManager.default.removeItem(at: out)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
  AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                              AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                              AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000,
                                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
for (i, file) in files.enumerated() {
  while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
  var buffer: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
  guard let buffer else { fatalError("픽셀 버퍼를 못 만들었어요") }
  CVPixelBufferLockBaseAddress(buffer, [])
  let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: w, height: h, bitsPerComponent: 8,
                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: srgb,
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
  ctx.draw(load(file), in: CGRect(x: 0, y: 0, width: w, height: h))
  CVPixelBufferUnlockBaseAddress(buffer, [])
  adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(i), timescale: fps))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { fatalError("mp4 를 못 만들었어요: \(String(describing: writer.error))") }
