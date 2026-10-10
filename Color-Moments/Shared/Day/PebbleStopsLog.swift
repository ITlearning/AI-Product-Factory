import Foundation
import Observation

@Observable
public final class PebbleStopsLog {
    public static let shared = PebbleStopsLog()
    public private(set) var all: [String: [DayGradient.Stop]]
    @ObservationIgnored public var onLocalChange: ((String) -> Void)? {
        didSet { guard let onLocalChange else { return }; unsent.forEach(onLocalChange); unsent = [] }
    }
    @ObservationIgnored private var unsent: [String] = []
    private let defaults: UserDefaults
    private static let storageKey = "pebbleStops"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: Self.storageKey) as? [String: [String]] ?? [:]
        all = raw.compactMapValues { Self.decode($0) }
    }

    public var dayKeys: [String] { Array(all.keys) }
    public func stops(on dayKey: String) -> [DayGradient.Stop]? { all[dayKey] }

    public func stamp(_ dayKey: String, _ stops: [DayGradient.Stop]) {
        guard all[dayKey] == nil, !stops.isEmpty else { return }
        all[dayKey] = Self.normalized(stops); save()
        guard let onLocalChange else { unsent.append(dayKey); return }
        onLocalChange(dayKey)
    }

    /// 두 기기가 다르게 찍었으면 인코딩 문자열이 앞선 쪽으로 모인다. 바뀌었으면 true.
    @discardableResult
    public func applyRemote(dayKey: String, stops: [DayGradient.Stop]) -> Bool {
        guard !stops.isEmpty else { return false }
        let stops = Self.normalized(stops)
        if let mine = all[dayKey], mine == stops || Self.encode(mine).joined() <= Self.encode(stops).joined() { return false }
        all[dayKey] = stops; save(); return true
    }

    /// 디스크에 저장되는 모양(소수 3자리)으로 맞춰 메모리와 재실행 뒤 값이 같게 한다.
    private static func normalized(_ stops: [DayGradient.Stop]) -> [DayGradient.Stop] {
        decode(encode(stops)) ?? stops
    }

    public static func encode(_ stops: [DayGradient.Stop]) -> [String] {
        stops.map { String(format: "%.3f:%@", $0.location, $0.hex) }
    }

    public static func decode(_ raw: [String]) -> [DayGradient.Stop]? {
        let stops = raw.compactMap { s -> DayGradient.Stop? in
            let p = s.split(separator: ":")
            guard p.count == 2, let loc = Double(p[0]), p[1].count == 7 else { return nil }
            return DayGradient.Stop(location: loc, hex: String(p[1]))
        }
        return stops.count == raw.count && !stops.isEmpty ? stops : nil
    }

    private func save() { defaults.set(all.mapValues(Self.encode), forKey: Self.storageKey) }
}
