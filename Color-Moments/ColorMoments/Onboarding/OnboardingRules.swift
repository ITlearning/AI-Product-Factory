import Foundation

/// 첫 실행에 무엇을 보여 줄지 — 화면과 떼어 둔 순수 판정.
enum OnboardingGate {

    enum Presentation: Equatable {
        case undecided
        case full
        case arrivalAskOnly
        case none
    }

    static func presentation(isLoaded: Bool, didFinishOnboarding: Bool, hasRecords: Bool,
                             didAskArrivalNotice: Bool) -> Presentation {
        guard isLoaded else { return .undecided }
        if !didFinishOnboarding && !hasRecords { return .full }
        return didAskArrivalNotice ? .none : .arrivalAskOnly
    }
}

enum OnboardingStep: Hashable {
    case intro
    case firstPebble
    /// iCloud 로 이미 기록이 들어온 사람 — 첫 조약돌 받기 대신 iCloud 상태를 먼저 보여 주고 이어서 본다.
    case continuing
    case arrival
    case cloud
    case howTo
    case start
}

enum OnboardingFlow {

    static func steps(continuing: Bool, skipsFirstPebble: Bool, asksArrival: Bool) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [.intro]
        if continuing {
            steps.append(.continuing)
        } else if !skipsFirstPebble {
            steps.append(.firstPebble)
        }
        if asksArrival { steps.append(.arrival) }
        if !continuing { steps.append(.cloud) }
        steps += [.howTo, .start]
        return steps
    }

    enum PhotoAccess { case notDetermined, allowed, denied }

    /// 권한을 받지 못했거나 최근 사진이 한 장도 없으면 첫 조약돌 단계는 조용히 빠진다.
    static func skipsFirstPebble(access: PhotoAccess, recentCount: Int?) -> Bool {
        switch access {
        case .denied: return true
        case .notDetermined: return false
        case .allowed: return recentCount == 0
        }
    }

    /// 온보딩에서 담지 않았는데 들어온 하루 — iCloud 로 받은 기록.
    static func remoteDayCount(dayKeys: [String], importedDayKeys: Set<String>) -> Int {
        dayKeys.filter { !importedDayKeys.contains($0) }.count
    }

    enum ImportOutcome: Equatable {
        case gift(String)
        case todayOnly
        case added
        case nothing
    }

    static func outcome(existingRecordsWereEmpty: Bool, importedDayKeys: Set<String>, today: String) -> ImportOutcome {
        guard !importedDayKeys.isEmpty else { return .nothing }
        if let day = OnboardingGift.firstImportDay(existingRecordsWereEmpty: existingRecordsWereEmpty,
                                                   importedDayKeys: Array(importedDayKeys), today: today) {
            return .gift(day)
        }
        return importedDayKeys == [today] ? .todayOnly : .added
    }
}

/// 추천 점수 — Vision 미적 점수에 풍경 라벨을 얹는다. 실용 사진(영수증·문서 등)은 뺀다.
enum SuggestionScore {

    static let scenicLabels: Set<String> = [
        "sky", "blue_sky", "cloudy", "night_sky", "sunset_sunrise", "landscape", "outdoor",
        "mountain", "beach", "ocean", "lake", "river", "water_body", "tree", "forest",
        "flower", "blossom", "grass", "snow", "garden", "park",
    ]

    static let labelBonus = 0.25
    static let maxLabelBonus = 0.5

    /// overall 은 -1…1. 미적 점수를 못 얻었으면(시뮬레이터 등) 0 에서 시작해 라벨만 본다.
    static func combine(overall: Float?, isUtility: Bool, labels: [String]) -> Double? {
        guard !isUtility else { return nil }
        let hits = Set(labels).intersection(scenicLabels).count
        return Double(overall ?? 0) + min(Double(hits) * labelBonus, maxLabelBonus)
    }

    struct Candidate: Equatable {
        let id: String
        let score: Double
        let capturedAt: Date
    }

    /// 점수 높은 순, 같으면 최근 순, 그래도 같으면 id — 들어온 순서와 무관하게 늘 같은 줄.
    static func ranked(_ candidates: [Candidate], limit: Int) -> [Candidate] {
        Array(candidates.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.capturedAt != $1.capturedAt { return $0.capturedAt > $1.capturedAt }
            return $0.id < $1.id
        }.prefix(limit))
    }
}
