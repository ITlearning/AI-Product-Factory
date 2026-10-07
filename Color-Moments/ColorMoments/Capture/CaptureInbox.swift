import Foundation
import LockedCameraCapture
import Observation
import CoreImage
import UIKit

@MainActor
@Observable
final class CaptureInbox {

    struct Imported: Identifiable {
        let id = UUID()
        let url: URL
        let importedAt: Date
        let byteCount: Int
    }

    private(set) var imported: [Imported] = []

    var dayStore: DayStore?
    private(set) var log: [String] = []
    private var task: Task<Void, Never>?
    private var inFlight: Set<URL> = []

    private let sessionURLs: () -> [URL]
    private let invalidate: (URL) async throws -> Void
    private let adopt: (Moment, DayStore) async -> Void
    private let shotsDirectory: URL
    private let removedNames: () -> Set<String>

    init(sessionURLs: @escaping () -> [URL] = { LockedCameraCaptureManager.shared.sessionContentURLs },
         invalidate: @escaping (URL) async throws -> Void = {
             try await LockedCameraCaptureManager.shared.invalidateSessionContent(at: $0)
         },
         adopt: @escaping (Moment, DayStore) async -> Void = { await AssetAdopter.adopt($0, store: $1) },
         shotsDirectory: URL = CaptureInbox.shotsDirectory,
         removedNames: @escaping () -> Set<String> = { RemovedPhotos.originalNames() }) {
        self.sessionURLs = sessionURLs
        self.invalidate = invalidate
        self.adopt = adopt
        self.shotsDirectory = shotsDirectory
        self.removedNames = removedNames
    }

    nonisolated static var shotsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func start() {
        guard task == nil else { return }
        note("수신 시작. 기존 sessionContentURLs \(sessionURLs().count)개")
        task = Task { @MainActor [weak self] in
            await self?.sweep()
            for await update in LockedCameraCaptureManager.shared.sessionContentUpdates {
                guard let self else { return }
                switch update {
                case .initial(let urls):
                    self.note("initial \(urls.count)개")
                    for url in urls { await self.ingestOnce(url) }
                case .added(let url):
                    self.note("added \(url.lastPathComponent)")
                    await self.ingestOnce(url)
                case .removed(let url):
                    self.note("removed \(url.lastPathComponent)")
                @unknown default:
                    self.note("알 수 없는 업데이트")
                }
            }
        }
    }

    /// 스트림이 .initial·.added 를 끝내 안 보낼 때가 있다(iOS 26.1 실측, 애플 포럼 769209) — 목록을 직접 읽는다.
    func sweep() async {
        for url in sessionURLs() { await ingestOnce(url) }
    }

    private func ingestOnce(_ url: URL) async {
        let key = url.standardizedFileURL
        guard inFlight.insert(key).inserted else { return }
        defer { inFlight.remove(key) }
        await ingest(url)
    }

    func stop() { task?.cancel(); task = nil }

    func reset() {
        imported = []
        log = []
        note("전부 지움")
    }

    private func ingest(_ url: URL) async {
        // 저장소 없이 돌면 기록 없이 원본만 무효화된다 — sweep 은 앱이 dayStore 를 꽂기 전에도 불린다.
        guard dayStore != nil else { note("저장소 연결 전 — 건너뜀 \(url.lastPathComponent)"); return }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            note("없는 경로 \(url.lastPathComponent)"); return
        }

        let files: [URL]
        if isDir.boolValue {
            files = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        } else {
            files = [url]
        }

        var toAdopt: [Moment] = []
        let removed = removedNames()
        // 위치 쪽지(LockedPlaceNote)는 사진이 아니다 — 사진을 들여올 때 옆에서 읽기만 한다.
        for f in files where f.pathExtension.lowercased() != "json" {
            // 무효화에 실패해 다시 온 세션 — 그사이 몽돌에서 뺀 사진은 add 의 중복 판정에 안 걸린다.
            guard !removed.contains(f.lastPathComponent) else { note("뺀 사진이라 건너뜀 \(f.lastPathComponent)"); continue }
            let dest = shotsDirectory.appendingPathComponent(f.lastPathComponent)
            do {
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: f, to: dest)
                let size = (try? fm.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
                imported.append(Imported(url: dest, importedAt: Date(), byteCount: size ?? 0))
                note("들여옴 \(f.lastPathComponent) \(((size ?? 0) / 1024))KB")
                let placeNote = (try? Data(contentsOf: LockedPlaceNote.url(for: f)))
                    .flatMap { try? JSONDecoder().decode(LockedPlaceNote.self, from: $0) }
                if let moment = await record(dest, placeNote: placeNote) {
                    toAdopt.append(moment)
                }
            } catch {
                note("복사 실패 \(f.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // 복사 + 기록(add)까지 마친 뒤에만 세션 원본을 무효화한다 — 반드시 입양(adopt) 전에 끊는다.
        // 그래야 다음 앱 실행에서 같은 세션이 재전달돼도(무효화가 실패했거나 타이밍이 겹친 경우)
        // add 의 fileName/originalName 중복 판정이 입양 시도보다 먼저 걸린다.
        // 무효화는 되돌릴 수 없다 — 방금 넣은 기록이 디스크에 닿은 뒤에 끊는다.
        if let dayStore, !(await dayStore.flushAfterLoad()) {
            note("기록 쓰기 실패 — 원본을 무효화하지 않음(다음 실행에 다시 들여옴)")
            return
        }
        do {
            try await invalidate(url)
            note("원본 무효화 완료")
        } catch {
            note("무효화 실패: \(error.localizedDescription)")
        }

        guard let store = dayStore else { return }
        for moment in toAdopt {
            await adopt(moment, store)
        }
    }

    /// 색 추출 결과로 store.add 를 부른다. 실제로 넣었을 때만(중복이 아닐 때만) Moment 를 돌려준다 —
    /// 호출부는 이 값이 있을 때만 입양(adopt)을 시도해야 재전달로 인한 이중 저장을 막는다.
    private func record(_ url: URL, placeNote: LockedPlaceNote?) async -> Moment? {
        guard let store = dayStore else { return nil }
        let name = url.lastPathComponent

        // 색 추출은 CPU 무거운 일이라 메인 액터 밖(백그라운드)에서 돌린다.
        guard let hex = await Task.detached(priority: .userInitiated) { () -> String? in
            autoreleasepool {
                guard let image = CIImage(contentsOf: url) else { return nil }
                return ColorExtractor.symbolicColor(for: image).hex
            }
        }.value else {
            note("색 추출 실패 \(name)")
            return nil
        }

        let stamp = name.split(separator: "-").last.flatMap { Double($0.replacingOccurrences(of: ".jpg", with: "")) }
        let capturedAt = stamp.map { Date(timeIntervalSince1970: $0) } ?? Date()
        let recordsPlace = UserDefaults.standard.object(forKey: PlaceFinder.enabledKey) as? Bool ?? true
        let place = recordsPlace ? placeNote?.place : nil
        UserDefaults.standard.set(placeNote?.summary ?? "쪽지 없음(위치 시험 전 확장)", forKey: Self.lockedPlaceProbeKey)
        let moment = Moment(capturedAt: capturedAt, colorHex: hex, fileName: name, source: .locked,
                            place: place, originalName: name)
        let added = store.add(moment)
        if added { Telemetry.photosAdded(.locked, count: 1, total: store.moments.count) }
        note("기록 \(hex) · \(Moment.dayKey(for: capturedAt))")
        return added ? moment : nil
    }

    /// 디버그 화면용 — 마지막으로 들여온 잠금화면 사진의 위치 판정.
    static let lockedPlaceProbeKey = "lockedPlaceProbe"

    private func note(_ s: String) {
        let t = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.insert("[\(t)] \(s)", at: 0)
    }

    func loadExisting() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: shotsDirectory,
                                                 includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        imported = files.compactMap { url in
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            return Imported(url: url, importedAt: date, byteCount: size ?? 0)
        }.sorted { $0.importedAt > $1.importedAt }
    }
}
