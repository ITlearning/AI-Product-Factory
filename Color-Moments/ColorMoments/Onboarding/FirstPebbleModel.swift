import Observation
import Photos
import SwiftUI

/// 첫 조약돌 단계의 상태 — 앞뒤로 넘겨도 이어지도록 온보딩 화면이 들고 있다.
@MainActor
@Observable
final class FirstPebbleModel {

    enum Phase: Equatable {
        case ask
        case suggesting
        case importing
        case received(OnboardingFlow.ImportOutcome)
    }

    private(set) var phase = Phase.ask
    private(set) var suggestions: [PhotoSuggester.Suggestion] = []
    private(set) var scanning = false
    var selected: Set<String> = []
    private(set) var importProgress: LibraryImporter.Progress?

    @ObservationIgnored private var pool: [String: PhotoSuggester.Suggestion] = [:]
    @ObservationIgnored private var scan: Task<Void, Never>?

    static var access: OnboardingFlow.PhotoAccess {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: .allowed
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// 권한을 받고 최근 사진을 훑기 시작한다. 건너뛰어야 하면(거부·최근 0장) false.
    func begin(askIfNeeded: Bool) async -> Bool {
        if Self.access == .notDetermined {
            guard askIfNeeded else { return true }
            _ = await LibraryImporter.requestAccess()
        }
        let access = Self.access
        guard access == .allowed else { return false }
        let assets = PhotoSuggester.recentAssets()
        guard !OnboardingFlow.skipsFirstPebble(access: access, recentCount: assets.count) else { return false }
        startScan(assets)
        return true
    }

    private func startScan(_ assets: [PHAsset]) {
        guard scan == nil else { return }
        phase = .suggesting
        scanning = true
        scan = Task { @MainActor in
            for await s in PhotoSuggester.suggestions(from: assets) {
                let ids = SuggestionScore.layout(shown: suggestions.map(\.id), arriving: s.id, score: s.score,
                                                 maxShown: PhotoSuggester.maxShown)
                guard ids.count != suggestions.count else { continue }
                pool[s.id] = s
                withAnimation(.easeOut(duration: 0.35)) { suggestions.append(s) }
                if suggestions.count >= PhotoSuggester.maxShown { break }
            }
            scanning = false
        }
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// treatsAsNew — 디버그 다시 보기에서 기록이 있어도 첫 담기로 친다(증정이 뜨게).
    func importSelected(store: DayStore, treatsAsNew: Bool = false) async -> (outcome: OnboardingFlow.ImportOutcome, dayKeys: Set<String>) {
        let assets = selected.compactMap { pool[$0]?.asset }
        guard !assets.isEmpty else { return (.nothing, []) }
        scan?.cancel()
        scanning = false
        phase = .importing
        let wasEmpty = treatsAsNew || store.moments.isEmpty
        let keys = await LibraryImporter().importAssets(assets, into: store) { self.importProgress = $0 }
        importProgress = nil
        let outcome = OnboardingFlow.outcome(existingRecordsWereEmpty: wasEmpty, importedDayKeys: keys,
                                             today: Moment.dayKey(for: Date()))
        phase = outcome == .nothing ? .suggesting : .received(outcome)
        return (outcome, keys)
    }

    func received(_ outcome: OnboardingFlow.ImportOutcome) {
        guard outcome != .nothing else { return }
        scan?.cancel()
        scanning = false
        phase = .received(outcome)
    }

    func stop() { scan?.cancel() }
}
