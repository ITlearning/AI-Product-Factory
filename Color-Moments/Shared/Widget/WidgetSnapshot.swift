import Foundation

public struct WidgetSnapshot: Codable, Equatable, Sendable {

    // location — DayGradient 상대 위치(0...1). 찍은 시각은 App Group 에 남기지 않는다.
    public struct ColorPoint: Codable, Equatable, Sendable {
        public let hex: String
        public let location: Double
    }

    public struct Latest: Codable, Equatable, Sendable {
        public let dayKey: String
        public let name: String?
        public let colors: [ColorPoint]

        // PebbleView 는 시각에서 그라데이션 위치(비율)와 실루엣의 dayKey 만 본다 — 그 날 08시부터 12시간 안에 비율대로 되살린다.
        public var moments: [Moment] {
            let base = Moment.sealDate(for: dayKey)?.addingTimeInterval(-20 * 3600) ?? Date()
            return colors.map {
                Moment(capturedAt: base.addingTimeInterval($0.location * 12 * 3600),
                       colorHex: $0.hex, fileName: "", source: .app)
            }
        }

        public var dateText: String {
            let parts = dayKey.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return "" }
            return "\(parts[1])월 \(parts[2])일"
        }
    }

    public struct Arrival: Codable, Equatable, Sendable {
        public let dayKey: String
        public let arrivesAt: Date
    }

    public enum State: Equatable, Sendable {
        case pebble(Latest)
        case arriving(dayKey: String)
        case empty
    }

    public struct Entry: Equatable, Sendable {
        public let date: Date
        public let state: State
    }

    public let latest: Latest?
    public let arrivals: [Arrival]

    public init(latest: Latest?, arrivals: [Arrival]) {
        self.latest = latest
        self.arrivals = arrivals
    }

    public static let empty = WidgetSnapshot(latest: nil, arrivals: [])

    // 증정 판정(GiftSchedule)과 같은 기준(isGifted · hasSealedMoments)이어야 위젯의 「도착」과 실제 증정이 어긋나지 않는다.
    public static func make(store: DayStore, gifts: GiftLog) -> WidgetSnapshot {
        let candidates = store.dayKeys.filter(store.hasSealedMoments)
        let latest = candidates.first(where: gifts.isGifted).map { key -> Latest in
            let pebble = store.pebbleMoments(on: key)
            return Latest(dayKey: key,
                          name: PebbleNaming.name(for: pebble)?.name,
                          colors: DayGradient.positions(for: pebble).map {
                              ColorPoint(hex: $0.moment.colorHex, location: ($0.location * 1000).rounded() / 1000)
                          })
        }
        let arrivals = candidates.filter { !gifts.isGifted($0) }.compactMap { key in
            store.sealDate(on: key).map { Arrival(dayKey: key, arrivesAt: $0) }
        }
        return WidgetSnapshot(latest: latest, arrivals: arrivals.sorted { $0.arrivesAt < $1.arrivesAt })
    }

    public func state(at date: Date) -> State {
        if let arrived = arrivals.last(where: { $0.arrivesAt <= date }) { return .arriving(dayKey: arrived.dayKey) }
        return latest.map(State.pebble) ?? .empty
    }

    public func entries(now: Date) -> [Entry] {
        let later = Set(arrivals.map(\.arrivesAt).filter { $0 > now }).sorted()
        return ([now] + later).map { Entry(date: $0, state: state(at: $0)) }
    }

    public static let appGroup = "group.com.itlearning.colormoments"
    static let fileName = "widget-snapshot.json"

    public static var containerFile: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    public static func decoded(from data: Data) throws -> WidgetSnapshot {
        try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    // 실패는 조용히 버린다 — 위젯 때문에 앱 동작이 흔들리면 안 된다.
    public func write(to url: URL? = WidgetSnapshot.containerFile) {
        guard let url, let data = try? encoded() else { return }
        try? data.write(to: url, options: .atomic)
    }

    public static func read(from url: URL? = WidgetSnapshot.containerFile) -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url), let s = try? decoded(from: data) else { return .empty }
        return s
    }
}
