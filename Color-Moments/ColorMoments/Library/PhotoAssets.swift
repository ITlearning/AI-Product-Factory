import CoreLocation
import Photos
import UIKit

/// Shared 의 `AssetImageSource` 를 사진 앱으로 채우는 실제 구현. 앱 타깃에서만 Photos 를 안다.
final class PhotoAssetSource: AssetImageSource, @unchecked Sendable {

    func image(assetID: String, maxPixel: CGFloat) async -> UIImage? {
        guard !Task.isCancelled,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let targetSize: CGSize
        let contentMode: PHImageContentMode
        if maxPixel == .greatestFiniteMagnitude {
            // 원본 그대로(PHImageManagerMaximumSize)는 파노라마 등에서 메모리를 과하게 쓴다 — 긴 변 4096 로 제한.
            targetSize = CGSize(width: 4096, height: 4096)
            contentMode = .aspectFit
        } else {
            targetSize = CGSize(width: maxPixel, height: maxPixel)
            contentMode = .aspectFill
        }

        let manager = PHImageManager.default()
        return await ImageRequestBridge.run(
            start: { deliver in
                manager.requestImage(for: asset, targetSize: targetSize, contentMode: contentMode,
                                     options: options) { result, info in
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                    let failed = info?[PHImageErrorKey] != nil
                    // .highQualityFormat 도 드물게 저화질을 먼저 준다 — 저화질이면 기다리고, 취소·실패면 바로 끝낸다.
                    if degraded && !cancelled && !failed && result != nil { return }
                    deliver(cancelled ? nil : result)
                }
            },
            cancel: { manager.cancelImageRequest($0) }
        )
    }
}

/// 콜백 한 번짜리 요청을 async 로 — 콜백이 두 번 와도, 취소가 먼저 와도 continuation 은 한 번만 푼다.
/// 취소되면 요청을 거두고 바로 nil 로 돌아간다(뒤늦은 콜백은 버린다).
enum ImageRequestBridge {

    static func run<ID: Sendable>(
        start: (@escaping @Sendable (UIImage?) -> Void) -> ID,
        cancel: @escaping @Sendable (ID) -> Void
    ) async -> UIImage? {
        let box = Box<ID>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (c: CheckedContinuation<UIImage?, Never>) in
                guard box.install(c) else { return }
                let id = start { box.finish($0) }
                if box.setRequest(id) { cancel(id) }
            }
        } onCancel: {
            if let id = box.markCancelled() { cancel(id) }
            box.finish(nil)
        }
    }

    private final class Box<ID>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<UIImage?, Never>?
        private var request: ID?
        private var cancelled = false
        private var finished = false

        /// 이미 취소됐으면 바로 nil 로 풀고 false — 요청을 시작하지 않는다.
        func install(_ c: CheckedContinuation<UIImage?, Never>) -> Bool {
            lock.lock()
            if cancelled || finished {
                finished = true
                lock.unlock()
                c.resume(returning: nil)
                return false
            }
            continuation = c
            lock.unlock()
            return true
        }

        /// 요청 번호를 남긴다. 그사이 취소가 왔으면 true — 호출부가 거둔다.
        func setRequest(_ id: ID) -> Bool {
            lock.lock(); defer { lock.unlock() }
            request = id
            return cancelled
        }

        func markCancelled() -> ID? {
            lock.lock(); defer { lock.unlock() }
            cancelled = true
            return request
        }

        func finish(_ image: UIImage?) {
            lock.lock()
            guard !finished else { lock.unlock(); return }
            finished = true
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume(returning: image)
        }
    }
}

/// 파일 → 사진 앱 저장. placeholder 의 localIdentifier 는 performChanges 블록 밖에서는 못 읽으므로 안에서 꺼내둔다.
/// 파일 경로로 실패하면 데이터로, 그래도 실패하면 다시 인코딩한 JPEG 로 한 번씩 더 — 시도마다 결과를 남긴다.
enum AssetSaver {

    enum Method: String, Sendable {
        case file = "파일 경로"
        case data = "파일 데이터"
        case reencoded = "JPEG 재인코딩"
    }

    struct Attempt: Equatable, Sendable {
        let method: Method
        /// nil 이면 성공.
        let error: String?
    }

    struct Report: Equatable, Sendable {
        let fileName: String
        var assetID: String?
        var attempts: [Attempt] = []
        /// 파일이 없어 시도조차 못 했다.
        var fileMissing = false

        var failed: Bool { assetID == nil }
        var summary: String {
            if fileMissing { return "\(fileName): 파일 없음" }
            let steps = attempts.map { "\($0.method.rawValue) \($0.error ?? "성공")" }.joined(separator: " → ")
            return "\(fileName): \(steps)"
        }
    }

    struct NoPlaceholder: LocalizedError {
        var errorDescription: String? { "placeholder 없음" }
    }

    struct Undecodable: LocalizedError {
        var errorDescription: String? { "이미지로 읽을 수 없음" }
    }

    static func describe(_ error: Error) -> String {
        let e = error as NSError
        var text = "\(e.domain) \(e.code): \(e.localizedDescription)"
        if let under = e.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += " (\(under.domain) \(under.code))"
        }
        return text
    }

    /// 순수 흐름 — 시도를 차례로 돌리고 처음 성공에서 멈춘다.
    static func run(fileName: String, attempts: [(Method, () async throws -> String)]) async -> Report {
        var report = Report(fileName: fileName)
        for (method, attempt) in attempts {
            do {
                let id = try await attempt()
                report.attempts.append(Attempt(method: method, error: nil))
                report.assetID = id
                return report
            } catch {
                report.attempts.append(Attempt(method: method, error: describe(error)))
            }
        }
        return report
    }

    static func save(fileURL: URL, creationDate: Date, location: CLLocation?) async -> Report {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Report(fileName: fileURL.lastPathComponent, fileMissing: true)
        }
        return await run(fileName: fileURL.lastPathComponent, attempts: [
            (.file, { try await create(creationDate: creationDate, location: location) {
                $0.addResource(with: .photo, fileURL: fileURL, options: nil)
            } }),
            (.data, {
                let data = try Data(contentsOf: fileURL)
                return try await create(creationDate: creationDate, location: location) {
                    $0.addResource(with: .photo, data: data, options: nil)
                }
            }),
            (.reencoded, {
                let data = try Data(contentsOf: fileURL)
                guard let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.92) else { throw Undecodable() }
                return try await create(creationDate: creationDate, location: location) {
                    $0.addResource(with: .photo, data: jpeg, options: nil)
                }
            }),
        ])
    }

    // 재인코딩본엔 원본 EXIF 가 없다 — 찍은 시각·장소는 늘 요청에 직접 적는다.
    private static func create(creationDate: Date, location: CLLocation?,
                               add: @escaping (PHAssetCreationRequest) -> Void) async throws -> String {
        var placeholderID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            add(request)
            request.creationDate = creationDate
            request.location = location
            placeholderID = request.placeholderForCreatedAsset?.localIdentifier
        }
        guard let placeholderID else { throw NoPlaceholder() }
        return placeholderID
    }
}

/// 파일로 남은 Moment 를 사진 앱으로 옮기는 흐름 — 찍은 직후·잠금화면 가져온 직후·앱 시작(옛 사진)에서 같은 함수를 쓴다.
enum AssetAdopter {

    /// 사진 앱·디스크에 닿는 부분 — 테스트는 가짜로 바꾼다.
    struct Env {
        var access: () -> PHAuthorizationStatus
        var save: (URL, Date, CLLocation?) async -> AssetSaver.Report
        var existing: ([String]) async -> Set<String>
        var localIDs: ([String]) async -> [String: String]
        var localFiles: ([String]) async -> Set<String>
        var removeFile: (URL) -> Void
        var assignMissing: @MainActor (DayStore) async -> Void

        static let live = Env(
            access: { PHPhotoLibrary.authorizationStatus(for: .readWrite) },
            save: { await AssetSaver.save(fileURL: $0, creationDate: $1, location: $2) },
            existing: { await AssetReconciler.existing($0) },
            localIDs: { await CloudIDMapper.localIDs(forCloudIDs: $0) },
            localFiles: { await AssetReconciler.localFileNames($0) },
            removeFile: { try? FileManager.default.removeItem(at: $0) },
            assignMissing: { await CloudIDMapper.assignMissing(store: $0) }
        )
    }

    /// 이번 실행의 입양 기록 — 진단 화면이 읽는다.
    struct Stats: Equatable {
        var adoptTried = 0
        var adoptSucceeded = 0
        var readoptTried = 0
        var readoptSucceeded = 0
        var lastFailure: AssetSaver.Report?
        /// 첫 방법이 실패하고 대안으로 성공한 마지막 저장.
        var lastFallback: AssetSaver.Report?
    }
    @MainActor private(set) static var stats = Stats()

    @MainActor
    private static func record(_ report: AssetSaver.Report, readopt: Bool) {
        if readopt { stats.readoptTried += 1 } else { stats.adoptTried += 1 }
        if report.failed {
            stats.lastFailure = report
            print("AssetSaver: 저장 실패 \(report.summary)")
        } else if report.attempts.count > 1 {
            stats.lastFallback = report
        }
    }

    // 같은 Moment 를 캡처 직후 흐름과 adoptAll 이 동시에 부를 수 있어, 저장이 두 번 나가지 않게 막는다.
    @MainActor private static var adopting: Set<Moment.ID> = []
    @MainActor private static var isAdoptingAll = false

    @MainActor
    static func adopt(_ m: Moment, store: DayStore, env: Env = .live) async {
        guard await adoptWithoutMapping(m, store: store, env: env) else { return }
        await env.assignMissing(store)
    }

    /// adopt 의 본체 — cloudID 매핑은 호출부가 결정한다(adoptAll 은 루프 끝에 한 번만 하고 싶어서).
    @MainActor
    private static func adoptWithoutMapping(_ m: Moment, store: DayStore, env: Env) async -> Bool {
        guard !adopting.contains(m.id) else { return false }
        // 전달받은 스냅샷은 낡았을 수 있다(다른 경로가 먼저 입양했거나 그사이 지워졌을 수 있음) —
        // 지금 저장소에서 다시 읽어 확인한다.
        guard let current = store.moments.first(where: { $0.id == m.id }), current.assetID == nil else { return false }
        let status = env.access()
        guard status == .authorized || status == .limited else { return false }

        adopting.insert(m.id)
        defer { adopting.remove(m.id) }

        let fileURL = ShotImage.url(current.fileName)
        let location = current.place.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let report = await env.save(fileURL, current.capturedAt, location)
        record(report, readopt: false)
        guard let assetID = report.assetID else { return false }

        // 저장은 성공했어도 그사이 다른 경로가 먼저 입양했을 수 있다 — store.adopt 가 true 일 때만 지운다.
        // false 면 파일은 그대로 두고 로그만 남긴다(고아 에셋이 사진 앱에 남지만, 로컬 파일이
        // 유일한 사본이 아니게 된 것뿐이라 다음 정리에서 자연히 지워진다).
        guard store.adopt(current.id, assetID: assetID) else {
            print("AssetAdopter: \(current.id) 는 저장 중 이미 입양돼 파일을 지우지 않음")
            return false
        }
        stats.adoptSucceeded += 1
        // 파일이 유일한 사본이던 기록 — 입양이 디스크에 닿기 전에 지우면 kill 뒤 기록이 빈 파일을 가리킨다.
        // 쓰기 실패·저장 막힘이면 파일을 남겨야 다음 실행에 다시 입양된다.
        guard await store.flushAfterLoad() else { return true }
        env.removeFile(fileURL)
        return true
    }

    @MainActor
    static func adoptAll(store: DayStore, env: Env = .live) async {
        guard !isAdoptingAll else { return }
        let status = env.access()
        guard status == .authorized || status == .limited else { return }

        isAdoptingAll = true
        defer { isAdoptingAll = false }

        let snapshot = store.moments
        let ids = Array(Set(snapshot.compactMap(\.assetID)))
        let found = await env.existing(ids)

        // 사진첩에서 담은 옛 사본은 이미 assetID 가 있어 에셋으로 그려진다 — 남은 파일만 고아라 지운다.
        // 단, 그 assetID 가 실제로 사진 앱에서 찾아질 때만 지운다. 못 찾으면(기기 복원 등으로 assetID 가
        // 어긋난 경우) 파일을 남긴다 — ShotImage 가 에셋을 못 찾으면 파일로 폴백해 계속 그려진다.
        // 사본이 아예 없는 fileBacked 파일(assetID == nil)은 여기서 지우지 않는다 — 반드시 adopt 를 거쳐 저장한 뒤에만 지운다.
        for m in snapshot where m.fileName.hasPrefix("library-") && m.assetID.map(found.contains) == true {
            env.removeFile(ShotImage.url(m.fileName))
        }

        // 에셋이 사라진 기록(사본 파일이 남았어도)은 사진 앱에서 지운 것 — 여기서 되살리지 않고 정리에 맡긴다.
        for m in store.fileBacked {
            _ = await adoptWithoutMapping(m, store: store, env: env)
        }
        await env.assignMissing(store)
    }
}

#if DEBUG
/// 디버그 진단 화면의 수동 「복구」 — 에셋이 사라진 기록의 사본을 사진 앱에 다시 저장한다. 자동으로는 돌지 않는다.
extension AssetAdopter {

    static let restoreLimit = 20

    /// 순수 함수 — 에셋이 사라졌는데 이 기기에 파일이 남은 기록(파일로 다시 입양할 대상).
    /// 전체 접근일 때만(제한 접근에서 못 찾은 건 고르지 않은 것뿐이라 다시 저장하면 중복된다),
    /// 조회가 통째로 비면 아무것도 안 고른다. cloudID 로 다시 찾아지는 기록은 정리가 바꿔 끼우므로 뺀다.
    static func readoptCandidates(snapshot: [Moment], found: Set<String>, relocatable: Set<String>,
                                  onDisk: Set<String>, fullAccess: Bool) -> [Moment] {
        guard fullAccess else { return [] }
        let ids = Set(snapshot.compactMap(\.assetID))
        guard !(found.isEmpty && !ids.isEmpty) else { return [] }
        return snapshot.filter { m in
            guard let id = m.assetID, !found.contains(id), !relocatable.contains(id) else { return false }
            return AssetReconciler.holdsLocalFile(fileName: m.fileName, exists: onDisk.contains)
        }
    }

    @MainActor
    private static func readoptWithoutMapping(_ m: Moment, store: DayStore, env: Env) async -> Bool {
        guard !adopting.contains(m.id), let old = m.assetID else { return false }
        guard let current = store.moments.first(where: { $0.id == m.id }), current.assetID == old,
              current.fileName == m.fileName else { return false }
        guard env.access() == .authorized else { return false }

        adopting.insert(m.id)
        defer { adopting.remove(m.id) }

        let fileURL = ShotImage.url(current.fileName)
        let location = current.place.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let report = await env.save(fileURL, current.capturedAt, location)
        record(report, readopt: true)
        guard let newID = report.assetID else { return false }

        guard store.readopt(current.id, from: old, to: newID) else {
            // 방금 만든 에셋을 지우지 않는다 — 삭제 요청이 사용자 사진을 잘못 겨누면 되돌릴 수 없다(고아가 낫다).
            print("AssetAdopter: \(current.id) 는 다시 저장하는 사이 바뀌어 파일을 지우지 않음(새 에셋 \(newID) 는 사진 앱에 남음)")
            return false
        }
        stats.readoptSucceeded += 1
        guard await store.flushAfterLoad() else { return true }
        env.removeFile(fileURL)
        return true
    }

    /// 한 번에 `limit` 개까지. 다시 저장한 수를 돌려준다.
    @MainActor
    @discardableResult
    static func restoreLost(store: DayStore, limit: Int = restoreLimit, env: Env = .live) async -> Int {
        let fullAccess = env.access() == .authorized
        guard fullAccess else { return 0 }
        let snapshot = store.moments
        let found = await env.existing(Array(Set(snapshot.compactMap(\.assetID))))
        let lost = snapshot.filter { m in m.assetID.map { !found.contains($0) } ?? false }
        guard !lost.isEmpty else { return 0 }
        let onDisk = await env.localFiles(lost.map(\.fileName))
        let lostWithFile = lost.filter { AssetReconciler.holdsLocalFile(fileName: $0.fileName, exists: onDisk.contains) }
        let clouds = lostWithFile.compactMap(\.cloudID)
        let locals = clouds.isEmpty ? [:] : await env.localIDs(clouds)
        let relocatable = Set(lostWithFile.filter { $0.cloudID.flatMap { locals[$0] } != nil }.compactMap(\.assetID))
        var restored = 0
        for m in readoptCandidates(snapshot: snapshot, found: found, relocatable: relocatable,
                                   onDisk: onDisk, fullAccess: fullAccess).prefix(limit) {
            if await readoptWithoutMapping(m, store: store, env: env) { restored += 1 }
        }
        if restored > 0 { await env.assignMissing(store) }
        return restored
    }
}
#endif
