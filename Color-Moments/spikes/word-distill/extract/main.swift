// 버리는 실험 코드. 평가 사진 100장(몽돌 54 + 추가 46)마다
// 지금 규칙의 단어, judge 가 허락하는 후보, Vision 값(라벨 확신도 전부·사진 지문)을 뽑고 선생에게 줄 사진을 저장한다.
// 결과는 ~/mongdol-word-lab 에만 쓴다. 실행: ./build.sh && .build/extract
import AppKit
import Foundation
import Photos
import Vision

let lab = URL(fileURLWithPath: NSString(string: "~/mongdol-word-lab").expandingTildeInPath)
let daysURL = URL(fileURLWithPath: NSString(string: "~/Downloads/mongdol-backup-20261001/days.json").expandingTildeInPath)
let wordsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../../../Shared/Word/words.json").standardized
let photosDir = lab.appendingPathComponent("photos")
try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

let list = try JSONDecoder().decode(WordList.self, from: Data(contentsOf: wordsURL))
let words = list.words.filter { !Set(list.retired).contains($0.id) }
let vocabulary = Set(words.flatMap(\.subjects))

let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
let isoPlain = ISO8601DateFormatter()
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .custom {
    let s = try $0.singleValueContainer().decode(String.self)
    guard let d = iso.date(from: s) ?? isoPlain.date(from: s) else { throw CocoaError(.coderInvalidValue) }
    return d
}

struct Item {
    let key: String
    let set: String
    let bucket: String?
    let moment: Moment
    let phoneLabels: [String]?
    let localID: String?
}

var items: [Item] = []

let days = try decoder.decode([Moment].self, from: Data(contentsOf: daysURL))
let cloudIDs = days.compactMap { $0.cloudID.map(PHCloudIdentifier.init(stringValue:)) }
let mapping = PHPhotoLibrary.shared().localIdentifierMappings(for: cloudIDs)
for m in days {
    // cloudID 가 안 풀리는 사진(맥이 아직 못 받은 iCloud 레코드 등)은 찍은 시각 ±2초로 찾는다.
    let byTime: () -> String? = {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@",
                                  m.capturedAt.addingTimeInterval(-2) as NSDate, m.capturedAt.addingTimeInterval(2) as NSDate)
        let found = PHAsset.fetchAssets(with: .image, options: o)
        return found.count == 1 ? found.firstObject?.localIdentifier : nil
    }
    let local = m.cloudID.flatMap { id in try? mapping[PHCloudIdentifier(stringValue: id)]?.get() } ?? byTime()
    items.append(Item(key: "m-" + m.id.uuidString.prefix(8), set: "mongdol", bucket: nil, moment: m,
                      phoneLabels: m.labels, localID: local))
}

let extras = try JSONSerialization.jsonObject(with: Data(contentsOf: lab.appendingPathComponent("eval-extra.json"))) as! [[String: Any]]
let extraAssets = PHAsset.fetchAssets(withLocalIdentifiers: extras.map { $0["id"] as! String }, options: nil)
var byID: [String: PHAsset] = [:]
extraAssets.enumerateObjects { a, _, _ in byID[a.localIdentifier] = a }
for e in extras {
    let id = e["id"] as! String
    guard let a = byID[id], let date = a.creationDate else { continue }
    let place = a.location.map { Place(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                                       accuracy: $0.horizontalAccuracy) }
    let m = Moment(id: UUID(), capturedAt: date, colorHex: "", fileName: "", source: .library, assetID: id, place: place)
    items.append(Item(key: "x-" + String(WordPicker.fnv1a(id), radix: 16).prefix(8), set: "extra",
                      bucket: e["bucket"] as? String, moment: m, phoneLabels: nil, localID: id))
}

func image(_ asset: PHAsset, maxPixel: CGFloat) -> CGImage? {
    let o = PHImageRequestOptions()
    o.isSynchronous = true
    o.isNetworkAccessAllowed = true
    o.deliveryMode = .highQualityFormat
    o.resizeMode = .exact
    var out: CGImage?
    PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: maxPixel, height: maxPixel),
                                          contentMode: .aspectFit, options: o) { img, _ in
        out = img?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    return out
}

func saveJPEG(_ cg: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: cg)
    try? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])?.write(to: url)
}

var rows: [[String: Any]] = []
var features: [String: Any] = [:]
var classifyOrder: [String]?
var missing: [String] = []

for item in items {
    guard let localID = item.localID, let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil).firstObject,
          let small = image(asset, maxPixel: 600), let large = image(asset, maxPixel: 1024) else {
        missing.append(item.key); continue
    }
    saveJPEG(large, to: photosDir.appendingPathComponent(item.key + ".jpg"))

    let macLabels = PhotoLabeler.labels(for: small, vocabulary: vocabulary) ?? []
    let labels = item.phoneLabels ?? macLabels
    let ctx = PhotoContext(item.moment, labels: labels)
    let seed = item.moment.id.uuidString
    let rule = WordPicker.candidates(for: ctx, labels: labels, in: words, excluding: [], seed: seed)
    let first = rule.first
    let usedSubject = first.map { !$0.subjects.isEmpty && !Set(labels).isDisjoint(with: $0.subjects) } ?? false
    let allowed = words.filter { WordPicker.judge($0, ctx) == .yes }

    let classify = VNClassifyImageRequest()
    let printRequest = VNGenerateImageFeaturePrintRequest()
    try VNImageRequestHandler(cgImage: small, orientation: .up).perform([classify, printRequest])
    let scores = (classify.results ?? []).sorted { $0.identifier < $1.identifier }
    if classifyOrder == nil { classifyOrder = scores.map(\.identifier) }
    var vector: [Float] = []
    if let fp = printRequest.results?.first {
        vector = fp.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
    features[item.key] = ["classify": scores.map(\.confidence), "print": vector]

    let local = DateFormatter()
    local.calendar = PhotoContext.calendar(for: item.moment)
    local.timeZone = local.calendar.timeZone
    local.dateFormat = "yyyy-MM-dd HH:mm"
    rows.append([
        "key": item.key, "set": item.set, "bucket": item.bucket as Any,
        "local": local.string(from: item.moment.capturedAt),
        "partOfDay": PhotoEnrichment.partOfDay(item.moment.capturedAt, calendar: local.calendar),
        "season": ctx.season.rawValue,
        "weather": item.moment.place?.weather.map { PhotoEnrichment.label($0.condition) ?? $0.condition } as Any,
        "celsius": item.moment.place?.weather?.celsius as Any,
        "place": item.moment.place?.name as Any,
        "labels": labels, "macLabels": macLabels, "phoneLabels": item.phoneLabels as Any,
        "appWord": item.moment.word?.wordID as Any,
        "rule": first?.id as Any, "ruleBy": first == nil ? "none" : (usedSubject ? "subject" : "moment"),
        "ruleTop": rule.prefix(8).map(\.id),
        "allowed": allowed.map(\.id),
    ])
}

let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try JSONSerialization.data(withJSONObject: rows, options: opts).write(to: lab.appendingPathComponent("eval.json"))
try JSONSerialization.data(withJSONObject: ["classifyLabels": classifyOrder ?? [], "photos": features])
    .write(to: lab.appendingPathComponent("features.json"))
let words170 = list.words.map { ["id": $0.id, "word": $0.word, "meaning": $0.meaning, "moment": $0.moment, "fallback": $0.fallback] }
try JSONSerialization.data(withJSONObject: words170, options: opts).write(to: lab.appendingPathComponent("words.json"))
FileHandle.standardError.write("사진 \(rows.count)장, 못 찾음 \(missing.count): \(missing)\n".data(using: .utf8)!)
