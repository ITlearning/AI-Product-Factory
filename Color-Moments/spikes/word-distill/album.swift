// 버리는 실험 코드. eval-extra.json 의 사진을 사진 앱 앨범 하나에 모은다(사진 자체는 건드리지 않음).
import Foundation
import Photos

let title = "몽돌 평가 46"
let path = NSString(string: "~/mongdol-word-lab/eval-extra.json").expandingTildeInPath
let picked = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [[String: Any]]
let ids = picked.map { $0["id"] as! String }
let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)

let existing = PHFetchOptions()
existing.predicate = NSPredicate(format: "title == %@", title)
// 앨범이 있으면 빠진 사진만 더한다 — Tabber 가 뺀 사진은 eval-extra.json 에 없으니 되살아나지 않는다.
let found = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: existing).firstObject
try! PHPhotoLibrary.shared().performChangesAndWait {
    if let found {
        PHAssetCollectionChangeRequest(for: found)!.addAssets(assets)
    } else {
        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title).addAssets(assets)
    }
}
print("\(title) 앨범에 \(assets.count)장")
