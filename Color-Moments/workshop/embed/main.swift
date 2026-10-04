import CoreML
import Foundation
import ImageIO

let lab = URL(fileURLWithPath: NSString(string: "~/mongdol-word-lab").expandingTildeInPath)
let (modelPath, name) = (CommandLine.arguments[1], CommandLine.arguments[2])
let config = MLModelConfiguration(); config.computeUnits = .cpuAndNeuralEngine
let model = try MLModel(contentsOf: MLModel.compileModel(at: URL(fileURLWithPath: modelPath)), configuration: config)
var keys: [String] = [], xs: [[Float]] = []
for dir in ["photos", "photos-train", "photos-fresh"] where FileManager.default.fileExists(atPath: lab.appendingPathComponent(dir).path) {
    let files = try FileManager.default.contentsOfDirectory(at: lab.appendingPathComponent(dir), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jpg" }.sorted { $0.path < $1.path }
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
