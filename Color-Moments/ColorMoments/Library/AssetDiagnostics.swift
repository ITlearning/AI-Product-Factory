#if DEBUG
import Photos

/// 사진 앱으로 못 옮긴 기록을 갈래별로 센다 — 홈 렌치 화면 전용.
enum AssetDiagnostics {

    struct Counts: Equatable {
        /// ① assetID 없음·실제 파일 이름·파일 있음 — 입양 대기
        var fileOnly = 0
        /// ② ①인데 파일 없음 — 되살릴 원본이 없다
        var fileOnlyMissing = 0
        /// ③ assetID 있음·에셋 없음·파일 있음 — 다시 입양 대상
        var lostWithLibraryFile = 0
        var lostWithOtherFile = 0
        /// ④ assetID 있음·에셋 없음·파일 없음
        var lostNoFile = 0
        /// ⑤ 에셋은 있는데 cloudID 없음
        var foundNoCloud = 0
        /// ⑥ cloudID 없는 기록 전체
        var noCloud = 0
        var examples: [String] = []
    }

    /// 순수 함수 — `onDisk` 는 실제 파일이 있는 fileName.
    static func classify(_ moments: [Moment], found: Set<String>, onDisk: Set<String>, exampleLimit: Int = 5) -> Counts {
        var c = Counts()
        let real: (String) -> Bool = { AssetReconciler.holdsLocalFile(fileName: $0, exists: { _ in true }) }
        for m in moments {
            if m.cloudID == nil { c.noCloud += 1 }
            let hasFile = onDisk.contains(m.fileName) && real(m.fileName)
            var problem: String?
            if let id = m.assetID {
                if found.contains(id) {
                    if m.cloudID == nil { c.foundNoCloud += 1; problem = "⑤" }
                } else if hasFile {
                    if m.fileName.hasPrefix("library-") { c.lostWithLibraryFile += 1 } else { c.lostWithOtherFile += 1 }
                    problem = "③"
                } else {
                    c.lostNoFile += 1
                    problem = "④"
                }
            } else if real(m.fileName) {
                if hasFile { c.fileOnly += 1; problem = "①" } else { c.fileOnlyMissing += 1; problem = "②" }
            }
            if let problem, c.examples.count < exampleLimit {
                c.examples.append("\(problem) \(m.fileName) · \(m.source.rawValue)")
            }
        }
        return c
    }

    struct Snapshot {
        var status: PHAuthorizationStatus
        var loadIssue: DayStore.LoadIssue?
        var isSaveBlocked: Bool
        var total: Int
        var counts: Counts
        var stats: AssetAdopter.Stats
    }

    @MainActor
    static func snapshot(store: DayStore) async -> Snapshot {
        let moments = store.moments
        let found = await AssetReconciler.existing(Array(Set(moments.compactMap(\.assetID))))
        let onDisk = await AssetReconciler.localFileNames(moments.map(\.fileName))
        return Snapshot(status: PHPhotoLibrary.authorizationStatus(for: .readWrite), loadIssue: store.loadIssue,
                        isSaveBlocked: store.isSaveBlocked, total: moments.count,
                        counts: classify(moments, found: found, onDisk: onDisk), stats: AssetAdopter.stats)
    }

    static func statusText(_ s: PHAuthorizationStatus) -> String {
        switch s {
        case .authorized: return "전체 접근"
        case .limited: return "선택한 사진만"
        case .denied: return "거부"
        case .restricted: return "제한됨"
        case .notDetermined: return "묻기 전"
        @unknown default: return "알 수 없음(\(s.rawValue))"
        }
    }
}
#endif
