import Foundation

// MARK: - Concept

struct Concept: Codable, Identifiable {
    let id: String
    let titleEn: String
    let titleKo: String
    let level: String
    let category: String
    let order: Int
    let tipKo: String
    let tipEn: String
    let teachingHintsKo: TeachingHints
    let teachingHintsEn: TeachingHints
    let analogiesKo: [String]
    let analogiesEn: [String]
    let simplerFallback: String?

    struct TeachingHints: Codable {
        let what: String
        let why: String
        let how: String
        let watchOut: String

        enum CodingKeys: String, CodingKey {
            case what, why, how, watchOut
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, level, category, order
        case titleEn = "title_en"
        case titleKo = "title_ko"
        case tipKo = "tip_ko"
        case tipEn = "tip_en"
        case teachingHintsKo = "teaching_hints_ko"
        case teachingHintsEn = "teaching_hints_en"
        case analogiesKo = "analogies_ko"
        case analogiesEn = "analogies_en"
        case simplerFallback = "simpler_fallback"
    }

    func title(for language: AppLanguage) -> String {
        language == .korean ? titleKo : titleEn
    }

    func tip(for language: AppLanguage) -> String {
        language == .korean ? tipKo : tipEn
    }

    func teachingHints(for language: AppLanguage) -> TeachingHints {
        language == .korean ? teachingHintsKo : teachingHintsEn
    }

    func analogies(for language: AppLanguage) -> [String] {
        language == .korean ? analogiesKo : analogiesEn
    }
}

// MARK: - ConceptCurriculum

struct ConceptCurriculum {
    let track: TrackType
    private let concepts: [Concept]

    /// 트랙 명시 가능. 기본은 .swift (기존 호출자 호환).
    init(track: TrackType = .swift) {
        self.track = track
        self.concepts = Self.loadConcepts(track: track)
    }

    // MARK: - Load

    /// Track + locale 조합으로 curriculum 파일 선택.
    ///
    /// 시도 순서 (fallback chain):
    /// 1. `curriculum_{track}_{locale}.json` (정확한 매치)
    /// 2. `curriculum_{track}_en.json` (track 영문 fallback)
    /// 3. `curriculum_swift_{locale}.json` (Swift 트랙 fallback — 트랙 파일 누락 대비)
    /// 4. `curriculum_swift_en.json` (최종 fallback)
    /// 5. legacy `curriculum.json` (1.1.x 이전 빌드 호환)
    static func loadConcepts(track: TrackType = .swift) -> [Concept] {
        let candidates = preferredResourceCandidates(track: track)

        var url: URL?
        for name in candidates {
            if let found = Bundle.main.url(forResource: name, withExtension: "json") {
                url = found
                break
            }
        }

        guard let url else {
            assertionFailure("curriculum json not found in bundle for track \(track.rawValue)")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Concept].self, from: data)
            return decoded.sorted { $0.order < $1.order }
        } catch {
            assertionFailure("Failed to decode \(url.lastPathComponent): \(error)")
            return []
        }
    }

    /// Locale 기반 file 후보 목록 (우선순위 순).
    private static func preferredResourceCandidates(track: TrackType) -> [String] {
        let code = Locale.current.language.languageCode?.identifier
        let langSuffix = (code == "ko") ? "ko" : "en"

        return [
            "curriculum_\(track.rawValue)_\(langSuffix)",
            "curriculum_\(track.rawValue)_en",
            "curriculum_swift_\(langSuffix)",
            "curriculum_swift_en",
            "curriculum",  // legacy
        ]
    }

    // MARK: - Query

    func allConcepts() -> [Concept] {
        concepts
    }

    func conceptByID(_ id: String) -> Concept? {
        concepts.first { $0.id == id }
    }

    /// Selects the next concept to study based on level and already mastered concepts.
    /// Returns the lowest-order concept at the given level that hasn't been mastered.
    /// Falls back to the next level up if all at the current level are mastered.
    func selectNextConcept(level: String, masteredIDs: Set<String>) -> Concept? {
        let levels = ["beginner", "basic", "intermediate", "advanced"]
        guard let startIndex = levels.firstIndex(of: level) else {
            return concepts.first { !masteredIDs.contains($0.id) }
        }

        // Try each level starting from the user's current level
        for levelIndex in startIndex..<levels.count {
            let targetLevel = levels[levelIndex]
            let candidates = concepts.filter {
                $0.level == targetLevel && !masteredIDs.contains($0.id)
            }
            if let next = candidates.first {
                return next
            }
        }

        // All concepts mastered — return nil
        return nil
    }

    /// Returns concepts filtered by category.
    func concepts(inCategory category: String) -> [Concept] {
        concepts.filter { $0.category == category }
    }

    /// Returns all unique categories in curriculum order.
    func categories() -> [String] {
        var seen = Set<String>()
        return concepts.compactMap { concept in
            if seen.contains(concept.category) { return nil }
            seen.insert(concept.category)
            return concept.category
        }
    }
}
