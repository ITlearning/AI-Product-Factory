import Foundation

/// 주운 말 기록 한 줄. 위젯과 앱이 각자 자기 파일에 덧붙이기만 한다 — 한 파일을 두 프로세스가 고치면 나중 쓴 쪽이 앞 줍기를 지운다.
public struct PickLine: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case pick, unpick }
    public enum Source: String, Codable, Sendable { case widget, photo, birthday }

    public let id: UUID
    public let kind: Kind
    public let word: String
    public var wordID: String?
    /// 생일 말만 싣는다 — 생일 목록엔 words.json 에 없는 말도 있다.
    public var meaning: String?
    public var source: Source?
    public let at: Date
    public var photoID: String?
    /// unpick 이 지우는 pick 의 id — 시각이 아니라 id 로 지워서 두 파일의 줄 순서와 상관없다.
    public var targets: [UUID]?

    public init(id: UUID = UUID(), kind: Kind, word: String, wordID: String? = nil, meaning: String? = nil,
                source: Source? = nil, at: Date, photoID: String? = nil, targets: [UUID]? = nil) {
        self.id = id
        self.kind = kind
        self.word = word
        self.wordID = wordID
        self.meaning = meaning
        self.source = source
        self.at = at
        self.photoID = photoID
        self.targets = targets
    }

    /// 같은 말의 기준 — 앞뒤 공백을 뺀 글자.
    public var key: String { word.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// 「주운 말」 한 줄 — 같은 글자의 기록을 묶은 것.
public struct PickedWord: Equatable, Sendable {
    public let word: String
    /// words.json 뜻풀이가 먼저, 생일 목록에만 있는 말은 생일 뜻풀이.
    public let meaning: String?
    public let wordID: String?
    /// 오래된 것부터.
    public let picks: [PickLine]

    public var count: Int { picks.count }
    public var lastPickedAt: Date { picks.last?.at ?? .distantPast }
    /// 생일로 주운 적이 있으면 words.json 말과 합쳐진 줄에도 남는다.
    public var isBirthday: Bool { picks.contains { $0.source == .birthday } }
    public var photoIDs: [String] { picks.compactMap(\.photoID) }
}

public struct PickedWords: Sendable {

    public enum Writer: String, Sendable {
        case app, widget
        var fileName: String { "picks-\(rawValue).jsonl" }
    }

    public enum WriteError: Error { case noContainer, cannotCreate }

    public let directory: URL
    public let writer: Writer

    public init(writer: Writer, directory: URL) {
        self.writer = writer
        self.directory = directory
    }

    /// App Group 컨테이너 — 못 찾으면 nil(쓸 수 없으니 「주웠어요」도 보이면 안 된다).
    public init?(writer: Writer) {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)
        else { return nil }
        self.init(writer: writer, directory: dir)
    }

    func fileURL(_ w: Writer) -> URL { directory.appendingPathComponent(w.fileName) }

    // MARK: 읽기

    /// 두 파일을 합친 줄 — 같은 id 는 한 번, 깨진 줄은 건너뛴다.
    public func lines() -> [PickLine] {
        let decoder = JSONDecoder()
        var seen = Set<UUID>()
        var out: [PickLine] = []
        for w in [Writer.widget, .app] {
            guard let data = try? Data(contentsOf: fileURL(w)) else { continue }
            for raw in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
                guard let line = try? decoder.decode(PickLine.self, from: Data(raw)),
                      seen.insert(line.id).inserted else { continue }
                out.append(line)
            }
        }
        return out
    }

    /// 빼지 않은 pick 들, 시각 순.
    public func livePicks() -> [PickLine] {
        Self.live(lines())
    }

    static func live(_ lines: [PickLine]) -> [PickLine] {
        let removed = Set(lines.lazy.filter { $0.kind == .unpick }.flatMap { $0.targets ?? [] })
        return lines.filter { $0.kind == .pick && !removed.contains($0.id) && !$0.key.isEmpty }
            .sorted { $0.at != $1.at ? $0.at < $1.at : $0.id.uuidString < $1.id.uuidString }
    }

    /// 말 하나에 한 줄, 가장 최근에 주운 것부터. words 를 안 주면 번들 words.json.
    public func merged(words: [WordEntry]? = nil) -> [PickedWord] {
        Self.merge(livePicks(), words: words ?? BundledWordSource.cached)
    }

    static func merge(_ picks: [PickLine], words: [WordEntry]) -> [PickedWord] {
        var entries: [String: WordEntry] = [:]
        for w in words {
            let k = w.word.trimmingCharacters(in: .whitespacesAndNewlines)
            if entries[k] == nil { entries[k] = w }
        }
        var groups: [String: [PickLine]] = [:]
        for p in picks { groups[p.key, default: []].append(p) }
        return groups.map { key, list in
            let entry = entries[key]
            let birthdayMeaning = list.last { $0.source == .birthday && $0.meaning != nil }?.meaning
            return PickedWord(word: key,
                              meaning: entry?.meaning ?? birthdayMeaning ?? list.last { $0.meaning != nil }?.meaning,
                              wordID: entry?.id ?? list.last { $0.wordID != nil }?.wordID,
                              picks: list)
        }
        .sorted { $0.lastPickedAt != $1.lastPickedAt ? $0.lastPickedAt > $1.lastPickedAt : $0.word < $1.word }
    }

    /// 같은 말은 하루(새벽 4시 경계)에 한 번 — 합친 결과로 판정한다.
    public func pickedToday(_ word: String, now: Date = Date()) -> Bool {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let today = Moment.dayKey(for: now)
        return livePicks().contains { $0.key == key && Moment.dayKey(for: $0.at) == today }
    }

    // MARK: 쓰기 — 디스크에 닿아야 돌아온다. 던지면 「주웠어요」를 보이지 말 것.

    public func pick(_ word: String, wordID: String? = nil, meaning: String? = nil, source: PickLine.Source,
                     photoID: String? = nil, at: Date = Date()) throws -> PickLine {
        let line = PickLine(kind: .pick, word: word, wordID: wordID, meaning: meaning, source: source, at: at, photoID: photoID)
        try append(line)
        return line
    }

    /// 「주운 말에서 빼기」 — 그 말의 기록 전부. 뺄 게 없으면 아무것도 쓰지 않고 nil.
    public func unpick(word: String, at: Date = Date()) throws -> PickLine? {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines)
        return try unpick(key, matching: { $0.key == key }, photoID: nil, at: at)
    }

    /// 「이 단어는 아니에요」 — 그 사진으로 주운 기록만. 위젯·생일 기록은 남는다.
    public func unpick(photoID: String, at: Date = Date()) throws -> PickLine? {
        try unpick(nil, matching: { $0.photoID == photoID }, photoID: photoID, at: at)
    }

    private func unpick(_ word: String?, matching: (PickLine) -> Bool, photoID: String?, at: Date) throws -> PickLine? {
        let targets = livePicks().filter(matching)
        guard let first = targets.first else { return nil }
        let line = PickLine(kind: .unpick, word: word ?? first.key, at: at, photoID: photoID, targets: targets.map(\.id))
        try append(line)
        return line
    }

    private static let appendLock = NSLock()

    func append(_ line: PickLine) throws {
        var data = try JSONEncoder().encode(line)
        data.append(0x0A)
        Self.appendLock.lock()
        defer { Self.appendLock.unlock() }
        let fm = FileManager.default
        let url = fileURL(writer)
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            guard fm.createFile(atPath: url.path, contents: nil) else { throw WriteError.cannotCreate }
        }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        // 앞 쓰기가 줄 중간에서 끊겼으면 새 줄에서 시작한다 — 안 그러면 이 줄까지 깨진 줄이 된다.
        if end > 0 {
            try handle.seek(toOffset: end - 1)
            if try handle.read(upToCount: 1) != Data([0x0A]) { data.insert(0x0A, at: 0) }
            try handle.seekToEnd()
        }
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
}

// MARK: - 생일 말

public struct BirthdayWord: Codable, Equatable, Sendable {
    public let w: String
    public let m: String
    public let months: [Int]
}

public struct BirthdayPick: Equatable, Sendable {
    public struct Said: Equatable, Sendable {
        public let word: String
        public let meaning: String
    }
    public let word: String
    public let meaning: String
    /// 곁말 둘 — 그 달 뒤쪽 하나, 아무 때나 좋은 말 하나.
    public let extras: [Said]
    public let pool: Int
}

/// Mongdol-Desk/js/birthday-pick.js 를 그대로 옮긴 것 — 같은 규칙·같은 목록. 고정 열쇠로 JS 결과와 맞추는 테스트가 지킨다.
/// 목록(birthday-words.json) 순서가 바뀌면 모두의 말이 바뀐다 — 웹과 같이, 끝에 붙이거나 그 자리에서만 고칠 것.
public enum BirthdayWords {

    static let day: [String: String] = ["0101": "해맞이", "0505": "어린이날", "0508": "어버이날", "1231": "해넘이"]
    static let seedKey = "birthdaySeed"

    public static func load() -> [BirthdayWord]? {
        guard let url = Bundle(for: SharedBundleMarker.self).url(forResource: "birthday-words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([BirthdayWord].self, from: data)
    }

    /// 설치마다 한 번 만드는 열쇠 — App Group 에만 둔다. 저장소를 못 쓰면 이번만 쓰는 열쇠.
    public static func installSeed(defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> String {
        if let s = defaults?.string(forKey: seedKey), !s.isEmpty { return s }
        let fresh = UUID().uuidString.lowercased()
        defaults?.set(fresh, forKey: seedKey)
        return fresh
    }

    // JS 는 UTF-16 단위로 돌고 Math.imul·>>> 0 은 32비트로 감싼다 — &* 와 UInt32 로 같은 비트를 낸다.
    static func hash(_ s: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for u in s.utf16 {
            h ^= UInt32(u)
            h = h &* 16777619
        }
        return h
    }

    // mulberry32 — JS 의 `| 0` 은 Int32 로 감싸기, `>>>` 는 UInt32 로 본 논리 시프트.
    static func rng(_ seed: UInt32) -> () -> Double {
        var a = Int32(bitPattern: seed)
        return {
            a = a &+ 0x6D2B79F5
            var t = (a ^ Int32(bitPattern: UInt32(bitPattern: a) >> 15)) &* (1 | a)
            t = (t &+ ((t ^ Int32(bitPattern: UInt32(bitPattern: t) >> 7)) &* (61 | t))) ^ t
            let u = UInt32(bitPattern: t)
            return Double(u ^ (u >> 14)) / 4294967296
        }
    }

    static func perm<T>(_ list: [T], key: String) -> [T] {
        let r = rng(hash(key))
        var a = list
        var i = a.count - 1
        while i > 0 {
            let j = Int((r() * Double(i + 1)).rounded(.down))
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }

    public static func pick(_ words: [BirthdayWord], seed: String, month m: Int, day d: Int) -> BirthdayPick? {
        let dayWords = Set(day.values)
        let month = words.filter { $0.months.contains(m) && !dayWords.contains($0.w) }
        let any = words.filter { $0.months.isEmpty }
        let pm = perm(month, key: "\(seed):\(m)"), pa = perm(any, key: "\(seed):any"), L = pm.count
        guard L > 0, !pa.isEmpty else { return nil }
        let key = String(format: "%02d%02d", m, d)
        let special = day[key].flatMap { name in
            hash("\(seed):\(key)") % 4 == 0 ? words.first { $0.w == name } : nil
        }
        let main = special ?? pm[(d - 1) % L]
        let x1 = L > 31 ? pm[31 + (d - 1) % (L - 31)] : pm[(d + 14) % L]
        let x2 = pa[((m - 1) * 31 + d - 1) % pa.count]
        return BirthdayPick(word: main.w, meaning: main.m,
                            extras: [x1, x2].map { BirthdayPick.Said(word: $0.w, meaning: $0.m) },
                            pool: L + (day[key] != nil ? 1 : 0))
    }
}
