import Foundation

public struct PebbleName: Equatable, Sendable {
    public let name: String
    public let line: String
}

public enum PebbleNaming {

    struct Word {
        let name: String
        let line: String
        /// 비면 사철. 있으면 그 달(dayKey 의 월)에만 나온다.
        var months: Set<Int> = []

        var pebbleName: PebbleName { .init(name: name, line: line) }
    }

    /// 한 색 칸의 이름들. 칸마다 사철 이름이 적어도 하나 있어야 한다 — 제철이 아닐 때 빈 칸이 된다.
    typealias Cell = [Word]

    struct HueBand {
        /// 빨강이 0 에 걸치지 않게 15° 돌린 색상에서 이 값 미만.
        let upTo: Double
        let dark: Cell
        let soft: Cell
        let bright: Cell
    }

    static let darkValue = 0.42
    static let softSaturation = 0.4
    static let achromaticSaturation = 0.12

    static let achromatic: [(upTo: Double, cell: Cell)] = [
        (0.18, [.init(name: "그믐", line: "빛이 없는 날은 쉬는 날이에요."),
                .init(name: "한밤", line: "깊은 밤도 하루의 끝자락이에요.")]),
        (0.38, [.init(name: "먹빛", line: "어두운 날도 하루로 남아요."),
                .init(name: "숯", line: "타고 남은 것도 따뜻해요.")]),
        (0.62, [.init(name: "잿빛", line: "무채색인 날도 필요해요."),
                .init(name: "자갈", line: "작은 돌끼리 모여 길이 돼요.")]),
        (0.85, [.init(name: "안개", line: "흐릿한 날은 흐릿한 대로 괜찮아요."),
                .init(name: "물안개", line: "물 위로 피어오른 숨 같아요.")]),
        (1.01, [.init(name: "해미", line: "안 보인다고 없는 건 아니에요."),
                .init(name: "뭉게구름", line: "뭉쳐 있어도 가벼워요.")]),
    ]

    private static let spring: Set<Int> = [3, 4, 5]
    private static let autumn: Set<Int> = [9, 10, 11]

    static let hues: [HueBand] = [
        // 빨강 345–15°
        .init(upTo: 30,
              dark: [.init(name: "불씨", line: "작아도 꺼지지 않았어요."),
                     .init(name: "잉걸", line: "조용히 오래 타는 빛이에요.")],
              soft: [.init(name: "저녁놀", line: "하루 끝이 이렇게 물들었네요."),
                     .init(name: "꽃노을", line: "붉은빛이 곱게 번졌어요.")],
              bright: [.init(name: "노을", line: "저무는 빛도 빛이에요."),
                       .init(name: "불꽃", line: "짧게 타도 오래 기억나요.")]),
        // 다홍 15–30°
        .init(upTo: 45,
              dark: [.init(name: "아람", line: "익는 데는 시간이 걸려요."),
                     .init(name: "흙", line: "발밑에도 색이 있어요."),
                     .init(name: "도토리", line: "작은 것에도 가을이 다 들어 있어요.", months: autumn)],
              soft: [.init(name: "살구", line: "말랑한 빛이 남은 날이에요."),
                     .init(name: "해거름", line: "기우는 해도 따뜻해요.")],
              bright: [.init(name: "해넘이", line: "넘어가는 해도 하루의 일부예요."),
                       .init(name: "모닥불", line: "둘러앉고 싶은 빛이에요.")]),
        // 주황 30–45°
        .init(upTo: 60,
              dark: [.init(name: "나뭇결", line: "켜켜이 쌓인 결이 보여요."),
                     .init(name: "솔방울", line: "떨어져서도 모양을 지켜요."),
                     .init(name: "밤톨", line: "껍질 안에서 단단히 여물었어요.", months: autumn),
                     .init(name: "가랑잎", line: "마른 잎도 소리를 내요.", months: [10, 11, 12])],
              soft: [.init(name: "햇살", line: "스며드는 건 조용해요."),
                     .init(name: "모래톱", line: "물이 닿았다 간 자리예요.")],
              bright: [.init(name: "볕뉘", line: "잠깐 든 볕도 볕이에요."),
                       .init(name: "햇발", line: "볕이 길게 뻗은 날이에요.")]),
        // 노랑 45–70°
        .init(upTo: 85,
              dark: [.init(name: "들녘", line: "넓게 펼쳐 둔 하루예요."),
                     .init(name: "볏짚", line: "마른 것도 포근할 수 있어요."),
                     .init(name: "이삭", line: "고개 숙인 건 익었다는 뜻이에요.", months: [8, 9, 10])],
              soft: [.init(name: "달무리", line: "둥글게 번진 빛이에요."),
                     .init(name: "보름달", line: "가득 찬 것도 조용해요.")],
              bright: [.init(name: "햇귀", line: "하루는 이런 데서 시작해요."),
                       .init(name: "햇볕", line: "볕은 누구에게나 들어요."),
                       .init(name: "해바라기", line: "고개를 드는 쪽이 있었네요.", months: [6, 7, 8, 9]),
                       .init(name: "개나리", line: "봄은 노랗게 먼저 와요.", months: [3, 4])]),
        // 연두 70–100°
        .init(upTo: 115,
              dark: [.init(name: "이끼", line: "느린 것도 자라는 거예요."),
                     .init(name: "솔잎", line: "뾰족해도 늘 푸르러요.")],
              soft: [.init(name: "보리밭", line: "바람이 지나간 자리가 보여요."),
                     .init(name: "쑥", line: "흔한 풀도 향이 깊어요."),
                     .init(name: "풋내", line: "덜 익은 것에도 향이 있어요.", months: [4, 5, 6, 7]),
                     .init(name: "새싹", line: "작게 시작해도 괜찮아요.", months: spring)],
              bright: [.init(name: "풀잎", line: "작은 잎에도 볕이 머물러요."),
                       .init(name: "새잎", line: "오늘 돋은 것처럼 보여요.")]),
        // 초록 100–150°
        .init(upTo: 165,
              dark: [.init(name: "숲", line: "깊이 들어가도 길은 있어요."),
                     .init(name: "그늘", line: "쉬어 가는 자리도 필요해요.")],
              soft: [.init(name: "풀숲", line: "작은 것들이 모여 사는 곳이에요."),
                     .init(name: "들풀", line: "누가 안 봐도 잘 자라요.")],
              bright: [.init(name: "풀빛", line: "초록은 오래 봐도 안 질려요."),
                       .init(name: "잎사귀", line: "볕 드는 쪽으로 펼쳐져요.")]),
        // 청록 150–185°
        .init(upTo: 200,
              dark: [.init(name: "물밑", line: "보이지 않는 데서도 흘러요."),
                     .init(name: "물이끼", line: "물가에서도 천천히 자라요.")],
              soft: [.init(name: "민물", line: "맑은 건 조용히 흘러요."),
                     .init(name: "시냇물", line: "작은 물도 멀리 가요.")],
              bright: [.init(name: "물빛", line: "흘러가는 건 나쁜 게 아니에요."),
                       .init(name: "윤슬", line: "반짝이는 건 잠깐이라 예뻐요."),
                       .init(name: "여울", line: "얕은 곳에서 물은 노래해요.")]),
        // 하늘 185–215°
        .init(upTo: 230,
              dark: [.init(name: "너울", line: "큰 물결도 결국 잔잔해져요."),
                     .init(name: "물마루", line: "멀리 보면 물도 둥글어요.")],
              soft: [.init(name: "이내", line: "멀리 있는 것도 푸르게 보여요."),
                     .init(name: "가람", line: "천천히 흘러 멀리 가요.")],
              bright: [.init(name: "하늘빛", line: "올려다본 날이었네요."),
                       .init(name: "하늘가", line: "끝은 멀어도 보이는 곳에 있어요.")]),
        // 파랑 215–245°
        .init(upTo: 260,
              dark: [.init(name: "밤바다", line: "어두워도 물결은 쉬지 않아요."),
                     .init(name: "물속", line: "깊을수록 조용해져요.")],
              soft: [.init(name: "새벽녘", line: "아직 조용할 때가 좋아요."),
                     .init(name: "먼동", line: "밝아 오는 쪽을 보고 있어요.")],
              bright: [.init(name: "쪽빛", line: "깊게 우러난 파랑이에요."),
                       .init(name: "바다", line: "끝이 안 보여도 괜찮아요.")]),
        // 남보라 245–275°
        .init(upTo: 290,
              dark: [.init(name: "미리내", line: "밤이 깊을수록 멀리 보여요."),
                     .init(name: "밤하늘", line: "별은 어두워야 보여요.")],
              soft: [.init(name: "새벽빛", line: "가장 어두운 다음에 와요."),
                     .init(name: "갓밝이", line: "이제 막 밝아지려는 참이에요.")],
              bright: [.init(name: "별빛", line: "멀리서 온 빛이에요."),
                       .init(name: "별무리", line: "모여 있으면 더 잘 보여요."),
                       .init(name: "제비꽃", line: "낮게 피어도 꽃이에요.", months: spring)]),
        // 보라 275–310°
        .init(upTo: 325,
              dark: [.init(name: "땅거미", line: "어둠은 천천히 내려와요."),
                     .init(name: "가지", line: "빛을 머금으면 윤이 나요."),
                     .init(name: "오디", line: "까맣게 익은 게 제일 달아요.", months: [5, 6])],
              soft: [.init(name: "어스름", line: "낮과 밤 사이에도 색이 있어요."),
                     .init(name: "저물녘", line: "하루가 천천히 내려앉아요.")],
              bright: [.init(name: "무지개", line: "여러 빛깔이 모여 하나가 돼요."),
                       .init(name: "나비", line: "가볍게 앉았다 가요."),
                       .init(name: "붓꽃", line: "곧게 서서 피는 꽃이에요.", months: [5, 6])]),
        // 분홍 310–345°
        .init(upTo: 360,
              dark: [.init(name: "꽃씨", line: "작은 씨에 꽃이 다 들어 있어요."),
                     .init(name: "열매", line: "익어 가는 건 천천히 붉어져요."),
                     .init(name: "머루", line: "산에서 익은 건 새콤해요.", months: [9, 10])],
              soft: [.init(name: "꽃구름", line: "구름도 가끔은 물들어요."),
                     .init(name: "꽃잎", line: "떨어진 잎도 한동안 고와요."),
                     .init(name: "복사꽃", line: "가지마다 연하게 피었어요.", months: [3, 4])],
              bright: [.init(name: "꽃물", line: "물든 자리는 쉽게 지워지지 않아요."),
                       .init(name: "꽃밭", line: "저마다 다른 빛으로 피어요."),
                       .init(name: "진달래", line: "그냥 지나치기 어려운 빛이에요.", months: spring),
                       .init(name: "꽃보라", line: "흩날리는 것도 아름다워요.", months: spring)]),
    ]

    static var allWords: [Word] {
        achromatic.flatMap(\.cell) + hues.flatMap { $0.dark + $0.soft + $0.bright }
    }

    public static var allNames: [PebbleName] { allWords.map(\.pebbleName) }

    public static func representative(of moments: [Moment]) -> ColorExtractor.RGB? {
        let colors = moments.compactMap { rgb(fromHex: $0.colorHex) }
        guard !colors.isEmpty else { return nil }
        return colors.max { a, b in saturation(a) < saturation(b) }
    }

    public static func name(for moments: [Moment]) -> PebbleName? {
        guard let c = representative(of: moments) else { return nil }
        return name(for: c, dayKey: moments.map(\.dayKey).min() ?? "")
    }

    /// dayKey 가 없으면 그 칸의 첫 사철 이름. 있으면 제철 이름까지 넣어 날마다 차례로 돈다 —
    /// 같은 칸에 이틀 잇달아 들어도 이름이 겹치지 않고, 같은 날은 어느 화면에서나 같은 이름이다.
    public static func name(for c: ColorExtractor.RGB, dayKey: String = "") -> PebbleName {
        let cell = cell(for: c)
        let month = dayKey.split(separator: "-").dropFirst().first.flatMap { Int($0) }
        let inSeason = cell.filter { $0.months.isEmpty || month.map($0.months.contains) == true }
        let pool = inSeason.isEmpty ? cell : inSeason
        guard let day = dayNumber(dayKey) else { return pool[0].pebbleName }
        return pool[rotation(count: pool.count, day: day, seed: pool[0].name)].pebbleName
    }

    static func cell(for c: ColorExtractor.RGB) -> Cell {
        let s = saturation(c), v = value(c)
        if s < achromaticSaturation {
            return (achromatic.first { v < $0.upTo } ?? achromatic[achromatic.count - 1]).cell
        }
        let shifted = (hue(c) + 15).truncatingRemainder(dividingBy: 360)
        let band = hues.first { shifted < $0.upTo } ?? hues[hues.count - 1]
        if v < darkValue { return band.dark }
        return s < softSaturation ? band.soft : band.bright
    }

    /// 순수 함수 — `count` 개를 날마다 하나씩. `count` 일 묶음마다 순서를 섞되 묶음 경계에서도 같은 게 잇달지 않는다.
    static func rotation(count n: Int, day: Int, seed: String) -> Int {
        guard n > 1 else { return 0 }
        guard n > 2 else { return ((day % 2) + 2) % 2 }
        let block = Int((Double(day) / Double(n)).rounded(.down))
        var order = shuffled(n, seed: "\(seed):\(block)")
        if order[0] == shuffled(n, seed: "\(seed):\(block - 1)")[n - 1] { order.swapAt(0, 1) }
        return order[day - block * n]
    }

    private static func shuffled(_ n: Int, seed: String) -> [Int] {
        (0..<n).sorted { fnv1a("\(seed):\($0)") < fnv1a("\(seed):\($1)") }
    }

    // Hasher 금지 — 프로세스마다 시드가 달라 같은 날의 이름이 바뀐다.
    private static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
        return h
    }

    /// "YYYY-MM-DD" → 1970-01-01 부터 센 날 수(달력 계산, 시간대와 무관).
    static func dayNumber(_ key: String) -> Int? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]), (1...31).contains(p[2]) else { return nil }
        let y = p[0] - (p[1] <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (p[1] + (p[1] > 2 ? -3 : 9)) + 2) / 5 + p[2] - 1
        return era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468
    }

    static func rgb(fromHex hex: String) -> ColorExtractor.RGB? {
        let t = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard t.count == 6, Scanner(string: t).scanHexInt64(&v) else { return nil }
        return .init(r: Double((v >> 16) & 0xFF) / 255,
                     g: Double((v >> 8) & 0xFF) / 255,
                     b: Double(v & 0xFF) / 255)
    }

    static func value(_ c: ColorExtractor.RGB) -> Double { max(c.r, c.g, c.b) }

    static func saturation(_ c: ColorExtractor.RGB) -> Double {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
        return mx <= 0 ? 0 : (mx - mn) / mx
    }

    static func hue(_ c: ColorExtractor.RGB) -> Double {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b), d = mx - mn
        guard d > 0 else { return 0 }
        var h: Double
        if mx == c.r { h = 60 * (((c.g - c.b) / d).truncatingRemainder(dividingBy: 6)) }
        else if mx == c.g { h = 60 * ((c.b - c.r) / d + 2) }
        else { h = 60 * ((c.r - c.g) / d + 4) }
        return h < 0 ? h + 360 : h
    }
}
