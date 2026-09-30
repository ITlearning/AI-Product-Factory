import Foundation
import Observation

/// 받은 조약돌의 이름 도장. 이름은 색·날짜·이름 목록으로 계산돼서, 목록이나 색 구간을 고치거나 그날 사진이
/// 하나 빠지기만 해도 지난 조약돌 이름이 바뀐다 — 받은 날 한 번 찍어 두면 그 뒤로는 도장이 이긴다(PebbleNaming.name).
@Observable
public final class PebbleNameLog {
    public static let shared = PebbleNameLog()

    public private(set) var names: [String: PebbleName]

    /// 이 기기에서 찍은 것만 — applyRemote 는 부르지 않는다(되돌아 올라가면 끝없이 돈다).
    /// 구독 전에 생긴 변경은 모아 두었다가 설정되는 순간 넘긴다.
    @ObservationIgnored
    public var onLocalChange: ((String) -> Void)? {
        didSet {
            guard let onLocalChange else { return }
            let keys = unsent
            unsent = []
            keys.forEach(onLocalChange)
        }
    }
    @ObservationIgnored private var unsent: [String] = []

    private let defaults: UserDefaults
    private static let storageKey = "pebbleNames"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: Self.storageKey) as? [String: [String]] ?? [:]
        names = raw.compactMapValues { $0.count == 2 ? PebbleName(name: $0[0], line: $0[1]) : nil }
    }

    public func name(on dayKey: String) -> PebbleName? { names[dayKey] }

    /// 처음 한 번만 — 이미 찍혀 있으면 그대로 둔다.
    public func stamp(_ dayKey: String, _ name: PebbleName) {
        guard names[dayKey] == nil else { return }
        names[dayKey] = name
        save()
        guard let onLocalChange else { unsent.append(dayKey); return }
        onLocalChange(dayKey)
    }

    /// 두 기기가 다르게 찍었으면 둘 다 가나다순으로 앞선 이름으로 모인다. 바뀌었으면 true.
    @discardableResult
    public func applyRemote(dayKey: String, name: PebbleName) -> Bool {
        if let mine = names[dayKey], mine == name || mine.name <= name.name { return false }
        names[dayKey] = name
        save()
        return true
    }

    private func save() {
        defaults.set(names.mapValues { [$0.name, $0.line] }, forKey: Self.storageKey)
    }
}
