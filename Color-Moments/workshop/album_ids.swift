import Foundation
import Photos

let o = PHFetchOptions()
o.predicate = NSPredicate(format: "title == %@", CommandLine.arguments[1])
let album = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: o).firstObject!
PHAsset.fetchAssets(in: album, options: nil).enumerateObjects { a, _, _ in print(a.localIdentifier) }
