import Foundation
import Observation

/// 「이 단어는 아니에요」 기록 — 이 기기 안에만 쌓인다(iCloud·서버로 보내지 않는다).
/// 사진마다 한 번. 두 번 넘게 버린 단어는 다음부터 되도록 피한다(개인화 첫걸음).
/// 모아서 규칙·단어를 고칠 때 읽는 형식이라 그때의 라벨·후보·때·날씨를 같이 남긴다.
@Observable
public final class WordRejections {
    public struct Entry: Codable, Equatable, Sendable {
        public let momentID: UUID
        public let wordID: String
        public let replacedBy: String
        public let labels: [String]
        public let candidates: [String]
        public let partOfDay: String
        public let weather: String?
        public let appVersion: String
        public let at: Date

        public init(momentID: UUID, wordID: String, replacedBy: String, labels: [String], candidates: [String],
                    partOfDay: String, weather: String?, appVersion: String, at: Date) {
            self.momentID = momentID; self.wordID = wordID; self.replacedBy = replacedBy; self.labels = labels
            self.candidates = candidates; self.partOfDay = partOfDay; self.weather = weather
            self.appVersion = appVersion; self.at = at
        }
    }

    public static let shared = WordRejections()
    /// 이만큼 버린 단어는 되도록 피한다 — 한 번은 사진 탓일 수 있다.
    public static let avoidAfter = 2

    private let fileURL: URL
    public private(set) var entries: [Entry]

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("word-rejections.json")
        entries = (try? Data(contentsOf: self.fileURL)).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    public func hasRejected(_ momentID: UUID) -> Bool { entries.contains { $0.momentID == momentID } }

    public func rejected(_ momentID: UUID) -> Set<String> { Set(entries.filter { $0.momentID == momentID }.map(\.wordID)) }

    public var avoided: Set<String> {
        Set(Dictionary(grouping: entries, by: \.wordID).filter { $0.value.count >= Self.avoidAfter }.keys)
    }

    public func record(_ entry: Entry) {
        guard !hasRejected(entry.momentID) else { return }
        entries.append(entry)
        if let data = try? JSONEncoder().encode(entries) { try? data.write(to: fileURL, options: .atomic) }
    }
}
