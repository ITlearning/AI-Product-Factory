import CoreML
import Foundation
import ImageIO

let lab = URL(fileURLWithPath: NSString(string: "~/mongdol-word-lab").expandingTildeInPath)
let (modelPath, name) = (CommandLine.arguments[1], CommandLine.arguments[2])
let config = MLModelConfiguration(); config.computeUnits = .cpuAndNeuralEngine
let model = try MLModel(contentsOf: MLModel.compileModel(at: URL(fileURLWithPath: modelPath)), configuration: config)
var keys: [String] = [], xs: [[Float]] = []
// 세 번째 인자: 그 폴더만(기기가 보낸 224px 그림 — parity.py). 없으면 lab 의 사진 폴더 셋.
let dirs = CommandLine.arguments.count > 3 ? [URL(fileURLWithPath: CommandLine.arguments[3])]
    : ["photos", "photos-train", "photos-fresh"].map { lab.appendingPathComponent($0) }
for dir in dirs where FileManager.default.fileExists(atPath: dir.path) {
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        .filter { ["jpg", "png"].contains($0.pathExtension) }.sorted { $0.path < $1.path }
    for f in files {
        guard let src = CGImageSourceCreateWithURL(f as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil), let input = WordImage.input(from: cg) else { continue }
        let out = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": try MLFeatureValue(cgImage: input, pixelsWide: 224, pixelsHigh: 224, pixelFormatType: kCVPixelFormatType_32BGRA, options: nil)]))
        let e = out.featureValue(for: "embedding")!.multiArrayValue!
        keys.append(f.deletingPathExtension().lastPathComponent)
        xs.append((0..<e.count).map { Float(truncating: e[$0]) })
    }
}
try JSONSerialization.data(withJSONObject: ["keys": keys, "x": xs]).write(to: lab.appendingPathComponent("emb-coreml-\(name).json"))
print(keys.count, "장")
