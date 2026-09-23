import Foundation
import LockedCameraCapture
import Observation
import CoreImage
import UIKit

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

    static var shotsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func start() {
        guard task == nil else { return }
        note("수신 시작. 기존 sessionContentURLs \(LockedCameraCaptureManager.shared.sessionContentURLs.count)개")
        task = Task { [weak self] in
            for await update in LockedCameraCaptureManager.shared.sessionContentUpdates {
                guard let self else { return }
                switch update {
                case .initial(let urls):
                    self.note("initial \(urls.count)개")
                    for url in urls { await self.ingest(url) }
                case .added(let url):
                    self.note("added \(url.lastPathComponent)")
                    await self.ingest(url)
                case .removed(let url):
                    self.note("removed \(url.lastPathComponent)")
                @unknown default:
                    self.note("알 수 없는 업데이트")
                }
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    func reset() {
        imported = []
        log = []
        note("전부 지움")
    }

    private func ingest(_ url: URL) async {
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
        for f in files {
            let dest = CaptureInbox.shotsDirectory.appendingPathComponent(f.lastPathComponent)
            do {
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: f, to: dest)
                let size = (try? fm.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
                imported.append(Imported(url: dest, importedAt: Date(), byteCount: size ?? 0))
                note("들여옴 \(f.lastPathComponent) \(((size ?? 0) / 1024))KB")
                await record(dest)
            } catch {
                note("복사 실패 \(f.lastPathComponent): \(error.localizedDescription)")
            }
        }
        do {
            try await LockedCameraCaptureManager.shared.invalidateSessionContent(at: url)
            note("원본 무효화 완료")
        } catch {
            note("무효화 실패: \(error.localizedDescription)")
        }
    }

    private func record(_ url: URL) async {
        guard let store = dayStore else { return }
        guard let image = CIImage(contentsOf: url) else { note("색 추출 실패 \(url.lastPathComponent)"); return }
        let hex = ColorExtractor.symbolicColor(for: image).hex

        let name = url.lastPathComponent
        let stamp = name.split(separator: "-").last.flatMap { Double($0.replacingOccurrences(of: ".jpg", with: "")) }
        let capturedAt = stamp.map { Date(timeIntervalSince1970: $0) } ?? Date()
        let moment = Moment(capturedAt: capturedAt, colorHex: hex, fileName: name, source: .locked)
        store.add(moment)
        note("기록 \(hex) · \(Moment.dayKey(for: capturedAt))")
        await AssetAdopter.adopt(moment, store: store)
    }

    private func note(_ s: String) {
        let t = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.insert("[\(t)] \(s)", at: 0)
    }

    func loadExisting() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: CaptureInbox.shotsDirectory,
                                                 includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        imported = files.compactMap { url in
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            return Imported(url: url, importedAt: date, byteCount: size ?? 0)
        }.sorted { $0.importedAt > $1.importedAt }
    }
}
