// 버리는 실험 코드 (spike/mongdol-word-distill). 앱 타깃에 넣지 않는다.
// 사진 보관함에서 평가 후보를 무작위로 뽑아 Vision 라벨·얼굴·글자 양을 잰다. 사진은 ~/mongdol-word-lab 밖으로 나가지 않는다.
// 실행: swift survey.swift <표본 수> <제외할 days.json>
import AppKit
import CoreLocation
import Foundation
import Photos
import Vision

let args = CommandLine.arguments
let sampleSize = args.count > 1 ? Int(args[1])! : 600
let daysPath = args.count > 2 ? args[2] : NSString(string: "~/Downloads/mongdol-backup-20261001/days.json").expandingTildeInPath
let outPath = NSString(string: "~/mongdol-word-lab/survey.jsonl").expandingTildeInPath

let sem = DispatchSemaphore(value: 0)
var status = PHAuthorizationStatus.notDetermined
PHPhotoLibrary.requestAuthorization(for: .readWrite) { status = $0; sem.signal() }
sem.wait()
guard status == .authorized || status == .limited else {
    FileHandle.standardError.write("사진 접근 거부: \(status.rawValue)\n".data(using: .utf8)!)
    exit(1)
}

let days = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: daysPath)))) as? [[String: Any]] ?? []
let dayFormatter = DateFormatter()
dayFormatter.dateFormat = "yyyy-MM-dd"
let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
var excludedDays = Set<String>()
var excludedIDs = Set<String>()
for d in days {
    if let id = d["assetID"] as? String { excludedIDs.insert(id) }
    if let s = d["capturedAt"] as? String, let date = iso.date(from: s) { excludedDays.insert(dayFormatter.string(from: date)) }
}

let since = Calendar.current.date(byAdding: .year, value: -3, to: Date())!
let options = PHFetchOptions()
options.predicate = NSPredicate(format: "mediaType == %d AND creationDate >= %@", PHAssetMediaType.image.rawValue, since as NSDate)
let fetched = PHAsset.fetchAssets(with: options)

var pool: [PHAsset] = []
fetched.enumerateObjects { a, _, _ in
    guard !a.mediaSubtypes.contains(.photoScreenshot),
          a.location != nil, let date = a.creationDate,
          !excludedIDs.contains(a.localIdentifier),
          !excludedDays.contains(dayFormatter.string(from: date)) else { return }
    pool.append(a)
}
FileHandle.standardError.write("보관함 \(fetched.count)장 중 조건 통과 \(pool.count)장\n".data(using: .utf8)!)
pool.shuffle()

let imageOptions = PHImageRequestOptions()
imageOptions.isSynchronous = true
imageOptions.isNetworkAccessAllowed = false
imageOptions.deliveryMode = .highQualityFormat
imageOptions.resizeMode = .fast

FileManager.default.createFile(atPath: outPath, contents: nil)
let out = FileHandle(forWritingAtPath: outPath)!
let hourFormatter = DateFormatter()
hourFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

var done = 0
for a in pool {
    if done >= sampleSize { break }
    var cg: CGImage?
    PHImageManager.default().requestImage(for: a, targetSize: CGSize(width: 512, height: 512), contentMode: .aspectFit, options: imageOptions) { img, _ in
        cg = img?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    guard let cg else { continue }
    let classify = VNClassifyImageRequest()
    let faces = VNDetectFaceRectanglesRequest()
    let text = VNRecognizeTextRequest()
    text.recognitionLevel = .fast
    try? VNImageRequestHandler(cgImage: cg).perform([classify, faces, text])
    let labels = (classify.results ?? []).filter { $0.confidence > 0.3 }.prefix(12).map { [$0.identifier, String(format: "%.2f", $0.confidence)] }
    let faceAreas = (faces.results ?? []).map { Double($0.boundingBox.width * $0.boundingBox.height) }
    let chars = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string.count }.reduce(0, +)
    let row: [String: Any] = [
        "id": a.localIdentifier,
        "local": hourFormatter.string(from: a.creationDate!),
        "lat": a.location!.coordinate.latitude, "lon": a.location!.coordinate.longitude,
        "labels": labels,
        "faces": faceAreas.count, "maxFace": faceAreas.max() ?? 0,
        "textChars": chars,
        "favorite": a.isFavorite,
    ]
    out.write(try! JSONSerialization.data(withJSONObject: row))
    out.write("\n".data(using: .utf8)!)
    done += 1
    if done % 50 == 0 { FileHandle.standardError.write("\(done)/\(sampleSize)\n".data(using: .utf8)!) }
}
FileHandle.standardError.write("완료 \(done)장 → \(outPath)\n".data(using: .utf8)!)
