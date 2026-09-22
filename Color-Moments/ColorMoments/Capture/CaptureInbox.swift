import Foundation
import LockedCameraCapture
import Observation
import CoreImage
import UIKit

/// 잠금화면 확장이 찍어둔 것을 본 앱으로 들여오는 수신함.
///
/// 잠긴 상태에서 찍힌 사진은 확장의 sessionContentURL 에만 쌓인다.
/// 앱이 열리면 여기서 가져와 앱 저장소로 옮기고, 원본은 무효화한다.
@Observable
final class CaptureInbox {

    struct Imported: Identifiable {
        let id = UUID()
        let url: URL
        let importedAt: Date
        let byteCount: Int
    }

    private(set) var imported: [Imported] = []
    /// 들여온 것을 기록할 저장소. 확장이 넘긴 사진은 여기서 처음 기록된다.
    var dayStore: DayStore?
    private(set) var log: [String] = []
    private var task: Task<Void, Never>?

    /// 앱 저장소. 스파이크 단계에서는 Documents/Shots 로 충분하다.
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

    /// 목록과 로그를 비운다. 파일 삭제는 DayStore.removeAll() 이 한다.
    func reset() {
        imported = []
        log = []
        note("전부 지움")
    }

    /// 확장이 남긴 것을 앱 저장소로 옮기고 원본을 무효화한다.
    /// 무효화하지 않으면 다음 실행에서 같은 것을 또 받는다.
    private func ingest(_ url: URL) async {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            note("없는 경로 \(url.lastPathComponent)"); return
        }
        // sessionContentURL 은 디렉토리로 올 수 있다. 안의 파일을 전부 가져온다.
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
                record(dest)
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

    /// 잠긴 확장은 색을 앱 저장소에 못 남긴다. 추출기가 결정론적이므로
    /// 여기서 다시 뽑아도 확장이 계산했던 값과 같다 — 사이드카 파일이 필요 없다.
    private func record(_ url: URL) {
        guard let store = dayStore else { return }
        guard let image = CIImage(contentsOf: url) else { note("색 추출 실패 \(url.lastPathComponent)"); return }
        let hex = ColorExtractor.symbolicColor(for: image).hex
        // 파일명에 박힌 epoch 가 촬영 시각이다 (확장이 그렇게 짓는다).
        let name = url.lastPathComponent
        let stamp = name.split(separator: "-").last.flatMap { Double($0.replacingOccurrences(of: ".jpg", with: "")) }
        let capturedAt = stamp.map { Date(timeIntervalSince1970: $0) } ?? Date()
        store.add(Moment(capturedAt: capturedAt, colorHex: hex, fileName: name, source: .locked))
        note("기록 \(hex) · \(Moment.dayKey(for: capturedAt))")
    }

    private func note(_ s: String) {
        let t = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.insert("[\(t)] \(s)", at: 0)
    }

    /// 앱이 이미 들여온 것들 (재실행 시 목록 복원)
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
