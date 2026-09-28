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
                pool[s.id] = s
                let top = SuggestionScore.ranked(pool.values.map(\.candidate), limit: PhotoSuggester.limit)
                let keep = Set(top.map(\.id))
                // 밀려난 사진의 썸네일은 버린다 — 200장을 다 들고 있으면 메모리가 커진다(골라 둔 건 남긴다).
                pool = pool.filter { keep.contains($0.key) || selected.contains($0.key) }
                let shown = SuggestionScore.ranked(pool.values.map(\.candidate), limit: pool.count)
                withAnimation(.easeOut(duration: 0.25)) {
                    suggestions = shown.compactMap { pool[$0.id] }
                }
            }
            scanning = false
        }
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    func importSelected(store: DayStore) async -> (outcome: OnboardingFlow.ImportOutcome, dayKeys: Set<String>) {
        let assets = selected.compactMap { pool[$0]?.asset }
        guard !assets.isEmpty else { return (.nothing, []) }
        scan?.cancel()
        scanning = false
        phase = .importing
        let wasEmpty = store.moments.isEmpty
        let keys = await LibraryImporter().importAssets(assets, into: store)
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
