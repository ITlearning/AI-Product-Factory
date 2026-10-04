import Foundation

/// 공방이 korean_lunar_calendar 로 만든 표 — iOS 의 .chinese 는 중국 기준이라 하루 어긋나는 날이 있다.
public enum LunarDays {
    public nonisolated(unsafe) static var table: [String: [String]] = load()

    public static func load() -> [String: [String]] {
        let bundle = Bundle(for: SharedBundleMarker.self)
        guard let url = bundle.url(forResource: "lunar-days", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return file.days
    }

    public static func keys(on dateKey: String) -> Set<String> { Set(table[dateKey] ?? []) }

    struct File: Decodable { let version: Int; let days: [String: [String]] }
}
