import Foundation

/// 지난 조약돌을 다시 꺼내 보는 쪽 — 작년 이맘때·한 달 한 줌의 날짜·배치 계산만 순수 함수로 둔다.
public enum Memories {

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private static func components(_ dayKey: String) -> (y: Int, m: Int, d: Int)? {
        let p = dayKey.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return (p[0], p[1], p[2])
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date? {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return calendar.date(from: c)
    }

    private static func date(from dayKey: String) -> Date? {
        guard let c = components(dayKey) else { return nil }
        return date(c.y, c.m, c.d)
    }

    /// 오늘의 1년 전 ±3일 안에서 받은 하루 중 가장 가까운 것(같으면 이른 날). 2/29 는 2/28 기준(전년엔 그 날짜가 없다).
    public static func lastYear(today: String, giftedDays: [String]) -> String? {
        guard let t = components(today) else { return nil }
        let anchorDay = (t.m == 2 && t.d == 29) ? 28 : t.d
        guard let anchor = date(t.y - 1, t.m, anchorDay) else { return nil }

        let candidates: [(key: String, diff: Int)] = giftedDays.compactMap { key in
            guard let d = date(from: key) else { return nil }
            let diff = abs(calendar.dateComponents([.day], from: anchor, to: d).day ?? Int.max)
            guard diff <= 3 else { return nil }
            return (key, diff)
        }
        return candidates.min { a, b in a.diff != b.diff ? a.diff < b.diff : a.key < b.key }?.key
    }

    /// 이번 달 제외, 받은 하루가 있는 달("yyyy-MM") 최신순 — giftedDays 는 이미 받은 날짜만 넘어온다고 가정한다.
    public static func months(giftedDays: [String], today: String) -> [String] {
        let currentMonth = String(today.prefix(7))
        var seen = Set<String>()
        var result: [String] = []
        for key in giftedDays.sorted(by: >) where key.count >= 7 {
            let month = String(key.prefix(7))
            guard month != currentMonth, seen.insert(month).inserted else { continue }
            result.append(month)
        }
        return result
    }

    /// 한 손(반지름 1의 원) 안에 겹쳐 쌓는 배치 — 같은 (count, seed) 는 항상 같은 결과를 낸다.
    public static func handfulLayout(count: Int, seed: UInt64) -> [(x: Double, y: Double, rotation: Double, scale: Double)] {
        guard count > 0 else { return [] }
        let goldenAngle = 2.399963229728653
        let baseScale = count <= 6 ? 1.0 : max(0.45, 1.0 - Double(count - 6) * 0.02)

        return (0..<count).map { i in
            let h = mix(seed: seed, index: UInt64(i))
            let t = Double(i) + 0.5
            let radius = sqrt(t / Double(count))
            let angle = t * goldenAngle
            let jitterMag = 0.08 * (1 - radius)
            let jx = (Double(h & 0xFFFF) / Double(0xFFFF) - 0.5) * 2 * jitterMag
            let jy = (Double((h >> 16) & 0xFFFF) / Double(0xFFFF) - 0.5) * 2 * jitterMag

            var x = radius * cos(angle) + jx
            var y = radius * sin(angle) + jy
            // 가장자리 지터가 원 밖으로 나가면 되돌린다 — "31개도 한 손 안에" 규칙.
            let r = (x * x + y * y).squareRoot()
            if r > 1 { x /= r; y /= r }

            let rotation = (Double((h >> 32) & 0xFFFF) / Double(0xFFFF) - 0.5) * 60
            let scaleJitter = 0.85 + Double((h >> 48) & 0xFFFF) / Double(0xFFFF) * 0.3
            return (x: x, y: y, rotation: rotation, scale: baseScale * scaleJitter)
        }
    }

    // splitmix64 마무리 단계 — Hasher 는 프로세스마다 시드가 달라 여기 쓰면 안 된다(WordPicker.fnv1a 와 같은 이유).
    private static func mix(seed: UInt64, index: UInt64) -> UInt64 {
        var h = seed &+ (index &* 0x9E37_79B9_7F4A_7C15)
        h ^= h >> 30; h = h &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 27; h = h &* 0x94D0_49BB_1331_11EB
        h ^= h >> 31
        return h
    }
}
