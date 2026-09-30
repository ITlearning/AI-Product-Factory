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

    /// 기존 사용자 한 장은 알림 권한을 읽기 전엔 띄우지 않고, 이미 결정된 기기면 아예 건너뛴다.
    static func resolve(_ presentation: Presentation, noticePermission: ArrivalAsk.Permission?) -> Presentation {
        guard presentation == .arrivalAskOnly else { return presentation }
        guard let noticePermission else { return .undecided }
        return ArrivalAsk.decision(noticePermission) == .ask ? .arrivalAskOnly : .none
    }
}

/// 아침 소식을 물을지 — 시스템 알림 권한이 이미 정해졌으면 묻지 않는다.
enum ArrivalAsk {

    enum Permission: Equatable { case notDetermined, allowed, denied }

    enum Decision: Equatable {
        case ask
        /// syncs — 이미 허락했으면 묻지 않은 채 예약을 맞춘다.
        case skip(syncs: Bool)
    }

    static func decision(_ permission: Permission) -> Decision {
        switch permission {
        case .notDetermined: .ask
        case .allowed: .skip(syncs: true)
        case .denied: .skip(syncs: false)
        }
    }
}

enum OnboardingStep: Hashable {
    case intro
    case firstPebble
    /// iCloud 로 이미 기록이 들어온 사람 — 첫 조약돌 받기 대신 iCloud 상태를 먼저 보여 주고 이어서 본다.
    case continuing
    case arrival
    /// 사진이 없는 날 알림 빈도 — 알림 권한과 상관없이 늘 보인다(도착 소식 장은 권한을 이미 정했으면 빠져서 거기 넣으면 안 보였다).
    case reminder
    case cloud
    case howTo
    /// 옆면 카메라 컨트롤이 있는 기기만 — 그 버튼으로 몽돌을 여는 설정을 알린다.
    case cameraButton
    case collection
    case start
}

enum OnboardingFlow {

    static func steps(continuing: Bool, skipsFirstPebble: Bool, asksArrival: Bool,
                      hasCameraButton: Bool = false) -> [OnboardingStep] {
        var steps: [OnboardingStep] = [.intro]
        if continuing {
            steps.append(.continuing)
        } else if !skipsFirstPebble {
            steps.append(.firstPebble)
        }
        if asksArrival { steps.append(.arrival) }
        steps.append(.reminder)
        if !continuing { steps.append(.cloud) }
        steps.append(.howTo)
        if hasCameraButton { steps.append(.cameraButton) }
        steps += [.collection, .start]
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

    /// 격자는 도착한 순서대로 뒤에만 자란다 — 이미 보인 칸은 움직이지 않는다.
    /// 점수가 없는 것(실용 사진)·이미 있는 것·상한을 넘는 것은 붙이지 않는다.
    static func layout(shown: [String], arriving id: String, score: Double?, maxShown: Int) -> [String] {
        guard score != nil, shown.count < maxShown, !shown.contains(id) else { return shown }
        return shown + [id]
    }
}
