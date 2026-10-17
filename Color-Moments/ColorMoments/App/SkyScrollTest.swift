#if DEBUG
import SwiftUI
import UIKit

/// 디버그 — 「말」 칸과 같은 목록(WordsPage)을 자동으로 위아래로 스크롤하며(또는 손 안 대고 두며) 놓친 프레임·최악 간격·하늘 계측을 잰다.
/// 「하늘 정지」(SkyDebug.frozen)로 같은 시험을 한 번 더 돌려 하늘 몫을 가른다.
@MainActor
enum SkyScrollTest {
    /// 결과 줄 필드 — 이름은 바꾸지 않는다(기기 결과 파일끼리 비교).
    static let fieldNames = ["시험", "단계", "하늘", "시간", "프레임", "놓침", "끊김", "최악", "하늘 프레임", "GPU", "동시 뷰", "풀 쉼",
                             "하늘 그리기", "쉼", "레이마칭", "하늘 갱신", "카드 계산", "MTKView 생성", "스크롤 중 생성", "풀 재사용", "최대",
                             "정지 그림", "정지 그림 조회", "구운 판", "drawable 활성", "drawable 쉼", "중간 텍스처", "하늘 GPU 합", "정지 그림 캐시", "발열",
                             "GPU 쓰임새", "GPU 패스", "스위치"]

    struct Result {
        var name: String
        var kind = "스크롤"
        var frozen = false
        var seconds = 0.0
        var frames = 0
        var missed = 0
        var hitches = 0
        var worstMs = 0.0
        var counters = SkyStats.Counters()
        var sample = SkySampler.Run()
        var memory = SkyMemory()
        var idleEnd = 0
        var switches = SkyDebug.switches

        var fields: [(String, String)] {
            let c = counters, m = memory, d = m.drawables, s = max(seconds, 0.001)
            let lookups = c.stillHits + c.stillMisses
            let drawAvg: Double = c.draws > 0 ? c.drawMs / Double(c.draws) : 0
            let hitRate: Double = lookups > 0 ? Double(c.stillHits) * 100 / Double(lookups) : 0
            return [
                ("시험", kind), ("단계", name), ("하늘", frozen ? "정지" : "켬"),
                ("시간", String(format: "%.1fs", seconds)),
                ("프레임", "\(frames)"), ("놓침", "\(missed)"), ("끊김", "\(hitches)"), ("최악", String(format: "%.1fms", worstMs)),
                ("하늘 프레임", String(format: "%d(%.1f/초)", c.presented, Double(c.presented) / s)),
                ("GPU", String(format: "%.0fms(%.1fms/초, %d장)", c.gpuMs, c.gpuMs / s, c.gpuFrames)),
                ("동시 뷰", String(format: "최대 %d 평균 %.1f", sample.viewsMax, sample.viewsAvg)),
                ("풀 쉼", String(format: "최대 %d 끝 %d", sample.idleMax, idleEnd)),
                ("하늘 그리기", String(format: "평균 %.2f 최악 %.1fms(%d번)", drawAvg, c.worstDrawMs, c.draws)),
                ("쉼", "\(c.rests)"), ("레이마칭", "\(c.marches)"), ("하늘 갱신", "\(c.updates)"), ("카드 계산", "\(c.bodies)"),
                ("MTKView 생성", "\(c.made)"), ("스크롤 중 생성", "\(c.madeInScroll)"), ("풀 재사용", "\(c.reused)"), ("최대", "\(c.maxAlive)"),
                ("정지 그림", String(format: "%d장 %.0fms(최악 %.1f)", c.stills, c.stillMs, c.worstStillMs)),
                ("정지 그림 조회", String(format: "적중 %d 실패 %d(%.0f%%)", c.stillHits, c.stillMisses, hitRate)),
                ("구운 판", String(format: "%d장 %.1fMB 새로 %d", m.plates, mb(m.plateBytes), c.platesMade)),
                ("drawable 활성", String(format: "%.1fMB(%d뷰)", mb(d.active), d.activeViews)),
                ("drawable 쉼", String(format: "%.1fMB(%d뷰)", mb(d.idle), d.idleViews)),
                ("중간 텍스처", String(format: "%.1fMB", mb(m.renderer))),
                ("하늘 GPU 합", String(format: "%.1fMB", mb(m.gpu))),
                ("정지 그림 캐시", String(format: "%.1fMB(%d장, CPU)", mb(m.stillBytes), m.stills)),
                ("발열", sample.thermal.last.map { $0.state.name } ?? "-"),
                ("GPU 쓰임새", Self.uses(c, seconds: s)),
                ("GPU 패스", Self.passes(c)),
                ("스위치", switches),
            ]
        }

        /// 쓰임새별 — 「hero 120.0ms/초(장당 1.10ms, 1090장), card …」.
        static func uses(_ c: SkyStats.Counters, seconds s: Double) -> String {
            let parts = SkyQuality.allCases.compactMap { q -> String? in
                guard let n = c.gpuUseFrames[q], n > 0, let ms = c.gpuUse[q] else { return nil }
                return String(format: "%@ %.1fms/초(장당 %.2fms, %d장)", q.rawValue, ms / s, ms / Double(n), n)
            }
            return parts.isEmpty ? "-" : parts.joined(separator: ", ")
        }

        /// 패스별 장당 GPU ms(표본 프레임 평균) — 「card(표본 40) 합성 0.80 블룸 0.20 …」. 계측을 못 하는 기기는 「지원 안 함」.
        static func passes(_ c: SkyStats.Counters) -> String {
            if c.passSupported == false { return "지원 안 함" }
            let parts = SkyQuality.allCases.compactMap { q -> String? in
                guard let n = c.passFrames[q], n > 0, let ms = c.passMs[q] else { return nil }
                let each = SkyPass.allCases.compactMap { p in ms[p].map { String(format: "%@ %.2f", p.rawValue, $0 / Double(n)) } }
                return "\(q.rawValue)(표본 \(n)) " + each.joined(separator: " ")
            }
            return parts.isEmpty ? "-" : parts.joined(separator: ", ")
        }

        var line: String { fields.map { "\($0.0) \($0.1)" }.joined(separator: " · ") }

        /// 시험 시작부터 10초마다 발열 상태 — 한 줄.
        var thermalLine: String {
            "발열 시계열 · 시험 \(kind) · 단계 \(name) · 하늘 \(frozen ? "정지" : "켬") · "
                + sample.thermal.map { "\($0.at)s \($0.state.name)" }.joined(separator: " · ")
        }

        var lines: [String] { [line, thermalLine] }
    }

    nonisolated static func mb(_ b: Int) -> Double { Double(b) / 1_048_576 }

    /// 결과를 Documents/sky/scroll.txt 에 덧붙인다 — 기기에서 devicectl 로 꺼내 본다.
    @discardableResult
    static func save(_ lines: [String], to dir: URL? = nil, now: Date = Date()) -> URL? {
        guard let dir = dir ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("sky")
        else { return nil }
        let url = dir.appendingPathComponent("scroll.txt")
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let stamp = f.string(from: now)
        let text = lines.map { "\(stamp) · \(model) · \(os) · \($0)\n" }.joined()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let h = try? FileHandle(forWritingTo: url) {
                defer { try? h.close() }
                try h.seekToEnd()
                try h.write(contentsOf: Data(text.utf8))
            } else {
                try Data(text.utf8).write(to: url)
            }
            return url
        } catch {
            NSLog("SKYSCROLL 저장 실패 %@", error.localizedDescription)
            return nil
        }
    }

    /// 기기 모델(iPhone17,1 등) — 시뮬레이터는 흉내 낸 기기.
    static var model: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return "\(sim)(시뮬레이터)" }
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: &u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    static var os: String { "iOS \(UIDevice.current.systemVersion)" }

    /// 열세 장면을 돌아가며 — 오늘의 한 장 + 철 묶음 여섯에 여섯 장씩.
    static func shelf() -> WordShelf {
        let kinds = SceneKind.allCases
        func card(_ i: Int) -> WordCardModel {
            WordCardModel(word: "시험\(i)", meaning: "스크롤 시험용 카드 — 장면을 돌아가며", scene: kinds[i % kinds.count], tintHex: nil,
                          when: "10월 \(1 + i % 28)일 저녁", mark: i % 3 == 0 ? "두 번" : nil, picked: nil)
        }
        let seasons = (0..<6).map { s in
            WordShelf.Shelf(id: "s\(s)", title: "가을 · \(10 - s)월", cards: (0..<6).map { card(1 + s * 6 + $0) })
        }
        return WordShelf(hero: card(0), seasons: seasons, count: 37)
    }

    private static func name(_ tier: SkyTier?, legacy: Bool) -> String { "\(tier?.name ?? "자동")\(legacy ? " 옛 구조" : "")" }

    /// 계측을 비우고 1초 표본·발열 시계열을 시작한다.
    private static func begin() -> Double {
        SkyDebug.passTiming = true
        SkyStats.shared.reset()
        SkyStats.shared.resetCounters()
        SkySampler.shared.begin()
        return CACurrentMediaTime()
    }

    private static func finish(_ r: inout Result, start: Double) {
        r.seconds = CACurrentMediaTime() - start
        r.counters = SkyStats.shared.counters
        r.sample = SkySampler.shared.end()
        r.memory = SkyMemory.now
        r.idleEnd = SkyViewPool.idleCount
        r.switches = SkyDebug.switches
    }

    /// 한 구성(단계·옛 구조·하늘 정지)을 잰다 — 먼저 한 번 훑어 판·정지 그림을 굽고, 계측을 비운 뒤 느리게·빠르게 위아래로.
    static func run(_ scroll: UIScrollView, tier: SkyTier?, legacy: Bool, frozen: Bool = false,
                    speeds: [Double] = [900, 2600]) async -> Result {
        SkyDebug.tier = tier
        SkyDebug.liveInScroll = legacy
        SkyDebug.frozen = frozen
        defer { SkyDebug.liveInScroll = false; SkyDebug.frozen = false }
        scroll.setContentOffset(.zero, animated: false)
        try? await Task.sleep(for: .seconds(1))
        _ = await ScrollDriver(scroll, speeds: [2000]).run()
        try? await Task.sleep(for: .seconds(0.8))
        let start = begin()
        var r = await ScrollDriver(scroll, speeds: speeds).run()
        r.name = name(tier, legacy: legacy)
        r.frozen = frozen
        finish(&r, start: start)
        return r
    }

    /// 유휴 시험 — 목록 맨 위를 띄운 채 손 안 대고 seconds 초. 프레임 간격은 재지 않는다(재는 디스플레이 링크가 화면을 깨운다).
    static func idle(_ scroll: UIScrollView, tier: SkyTier?, frozen: Bool, seconds: Double = 120) async -> Result {
        SkyDebug.tier = tier
        SkyDebug.frozen = frozen
        defer { SkyDebug.frozen = false }
        scroll.setContentOffset(.zero, animated: false)
        try? await Task.sleep(for: .seconds(2))
        let start = begin()
        try? await Task.sleep(for: .seconds(seconds))
        var r = Result(name: name(tier, legacy: false), kind: "유휴", frozen: frozen)
        finish(&r, start: start)
        return r
    }

    private static func record(_ r: Result, into lines: inout [String]) {
        lines += r.lines
        NSLog("SKYSCROLL %@", r.line)
        NSLog("SKYSCROLL %@", r.thermalLine)
    }

    /// 한 단계를 하늘 켬·정지로 — 결과 넷 줄(켬·발열·정지·발열).
    static func pair(_ scroll: UIScrollView, tier: SkyTier?, idleSeconds: Double? = nil,
                     progress: (String) -> Void = { _ in }) async -> String {
        let saved = SkyDebug.tier
        defer { SkyDebug.tier = saved }
        var lines: [String] = []
        for frozen in [false, true] {
            let what = "\(name(tier, legacy: false)) 하늘 \(frozen ? "정지" : "켬")"
            if let idleSeconds {
                progress("유휴 \(what) \(Int(idleSeconds))초…")
                record(await idle(scroll, tier: tier, frozen: frozen, seconds: idleSeconds), into: &lines)
            } else {
                progress("스크롤 \(what) 재는 중…")
                record(await run(scroll, tier: tier, legacy: false, frozen: frozen), into: &lines)
            }
        }
        save(lines)
        return lines.joined(separator: "\n")
    }

    static func runAll(_ scroll: UIScrollView, progress: (String) -> Void = { _ in }) async -> String {
        let saved = SkyDebug.tier
        defer { SkyDebug.tier = saved }
        var lines: [String] = []
        let plan: [(SkyTier?, Bool, Bool)] = [(.ultra, true, false), (.high, true, false), (.ultra, false, false), (.high, false, false),
                                              (.mid, false, false), (.low, false, false), (nil, false, true)]
        for (tier, legacy, frozen) in plan {
            progress("\(name(tier, legacy: legacy))\(frozen ? " 하늘 정지" : "") 재는 중…")
            record(await run(scroll, tier: tier, legacy: legacy, frozen: frozen), into: &lines)
        }
        save(lines)
        return lines.joined(separator: "\n")
    }
}

/// 1초마다 — 그린 하늘 프레임·GPU·동시에 그린 뷰·풀의 쉬는 뷰. 시험 중엔 10초마다 발열도.
@MainActor
final class SkySampler {
    static let shared = SkySampler()

    struct Run {
        var seconds = 0
        var viewsMax = 0
        var viewsSum = 0
        var idleMax = 0
        var thermal: [(at: Int, state: ProcessInfo.ThermalState)] = []
        var viewsAvg: Double { seconds > 0 ? Double(viewsSum) / Double(seconds) : 0 }
    }

    private(set) var last = SkyStats.Second()
    private var timer: Timer?
    private var users = 0
    private var run: Run?
    private var runStart = 0.0

    func start() {
        users += 1
        guard timer == nil else { return }
        restart()
    }

    func stop() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func begin() {
        users += 1
        restart()
        runStart = CACurrentMediaTime()
        run = Run(thermal: [(0, ProcessInfo.processInfo.thermalState)])
    }

    func end() -> Run {
        var r = run ?? Run()
        let at = Int((CACurrentMediaTime() - runStart).rounded())
        if r.thermal.last?.at != at { r.thermal.append((at, ProcessInfo.processInfo.thermalState)) }
        run = nil
        stop()
        return r
    }

    private func restart() {
        timer?.invalidate()
        _ = SkyStats.shared.roll()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        last = SkyStats.shared.roll()
        guard var r = run else { return }
        r.seconds += 1
        r.viewsMax = max(r.viewsMax, last.views)
        r.viewsSum += last.views
        r.idleMax = max(r.idleMax, SkyViewPool.idleCount)
        if r.seconds % 10 == 0 { r.thermal.append((r.seconds, ProcessInfo.processInfo.thermalState)) }
        run = r
    }
}

/// 하늘 메모리 추정 — GPU(drawable·렌더러 중간 텍스처·구운 판)와 CPU(정지 그림 캐시).
struct SkyMemory {
    var drawables = SkyViewPool.Drawables()
    var renderer = 0
    var plates = 0
    var plateBytes = 0
    var stills = 0
    var stillBytes = 0
    var gpu: Int { drawables.active + drawables.idle + renderer + plateBytes }

    @MainActor static var now: SkyMemory {
        let bank = SkyCloudBank.shared, held = SkyStills.shared.memory
        return SkyMemory(drawables: SkyViewPool.drawables, renderer: SkyStats.shared.rendererMemory, plates: bank.count,
                         plateBytes: bank.bytes, stills: held.count, stillBytes: held.bytes)
    }
}

extension ProcessInfo.ThermalState {
    var name: String {
        switch self {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}

/// 갤러리 계측 한 줄 — 초당 하늘 프레임·GPU ms·동시 뷰·풀 쉼·발열·메모리.
struct SkySpendBadge: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let s = SkySampler.shared.last, m = SkyMemory.now
            Text(String(format: "하늘 %d장/초 · GPU %.1fms/초 · 동시 %d · 쉼 %d · 열 %@ · GPU %.0fMB(+정지 %.0fMB)",
                        s.frames, s.gpuMs, s.views, SkyViewPool.idleCount, ProcessInfo.processInfo.thermalState.name,
                        SkyScrollTest.mb(m.gpu), SkyScrollTest.mb(m.stillBytes)))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
                .padding(.vertical, 3).frame(maxWidth: .infinity)
                .background(.black.opacity(0.6))
        }
        .onAppear { SkySampler.shared.start() }
        .onDisappear { SkySampler.shared.stop() }
    }
}

/// 스크롤 뷰를 직접 움직인다 — 손가락 스크롤처럼 UIScrollView 의 contentOffset 을 프레임마다.
@MainActor
final class ScrollDriver: NSObject {
    private let scroll: UIScrollView
    private var legs: [(to: CGFloat, speed: Double)] = []
    private var link: CADisplayLink?
    private var last = 0.0
    private var y: CGFloat = 0
    private var result = SkyScrollTest.Result(name: "")
    private var done: CheckedContinuation<SkyScrollTest.Result, Never>?

    init(_ scroll: UIScrollView, speeds: [Double]) {
        self.scroll = scroll
        super.init()
        let bottom = max(scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height, 0)
        for s in speeds { legs += [(bottom, s), (0, s)] }
    }

    func run() async -> SkyScrollTest.Result {
        y = scroll.contentOffset.y
        return await withCheckedContinuation { c in
            done = c
            let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            l.add(to: .main, forMode: .common)
            link = l
        }
    }

    @objc private func tick(_ l: CADisplayLink) {
        defer { last = l.timestamp }
        guard last > 0 else { return }
        let gap = l.timestamp - last
        let expected = max(l.targetTimestamp - l.timestamp, 1.0 / 120)
        result.frames += 1
        result.missed += max(Int((gap / expected).rounded()) - 1, 0)
        if gap > expected * 1.5 { result.hitches += 1 }
        result.worstMs = max(result.worstMs, gap * 1000)
        guard let leg = legs.first else {
            l.invalidate()
            link = nil
            done?.resume(returning: result)
            done = nil
            return
        }
        let step = CGFloat(leg.speed * gap)
        y = leg.to > y ? min(y + step, leg.to) : max(y - step, leg.to)
        if y == leg.to { legs.removeFirst() }
        scroll.contentOffset = CGPoint(x: 0, y: y)
    }
}

/// 「말」 칸과 같은 목록 — 스크롤 위치를 SkyScroll 에 알린다.
struct SkyScrollList: View {
    var found: (UIScrollView) -> Void

    private let shelf = SkyScrollTest.shelf()

    var body: some View {
        ScrollView {
            WordsPage(phase: .ready, shelf: shelf, now: nil, nowLooked: true, picked: false, attribution: nil, active: true)
                .background(ScrollViewFinder(found: found))
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, new in SkyScroll.shared.report(new) }
        .background(Tone.base.ignoresSafeArea())
    }
}

/// 둘레의 UIScrollView 를 찾아 넘긴다.
struct ScrollViewFinder: UIViewRepresentable {
    var found: (UIScrollView) -> Void

    final class Probe: UIView {
        var found: ((UIScrollView) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                var v = self?.superview
                while let s = v, !(s is UIScrollView) { v = s.superview }
                if let s = v as? UIScrollView { self?.found?(s) }
            }
        }
    }

    func makeUIView(context: Context) -> Probe {
        let p = Probe()
        p.isUserInteractionEnabled = false
        p.found = found
        return p
    }

    func updateUIView(_ v: Probe, context: Context) { v.found = found }
}

/// 갤러리에서 여는 화면 — 단계별(옛 구조 포함)로 차례로 재고 표를 보인다. 한 단계를 고르면 하늘 켬·정지 둘.
/// 실행 인자: `-skyScroll`(스크롤 시험 자동) `-skyIdle`(유휴 시험 자동, 스크롤 뒤) `-skyTier 0~3`(단계) `-skyIdleSeconds 120`.
struct SkyScrollTestScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scroll: UIScrollView?
    @State private var status = "준비 중…"
    @State private var running = false
    @State private var tier = Self.argTier ?? -1

    private static var argTier: Int? {
        UserDefaults.standard.object(forKey: "skyTier") == nil ? nil : UserDefaults.standard.integer(forKey: "skyTier")
    }

    private static var idleSeconds: Double {
        let s = UserDefaults.standard.double(forKey: "skyIdleSeconds")
        return s > 0 ? s : 120
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SkyScrollList { s in if scroll !== s { scroll = s } }
            VStack(alignment: .leading, spacing: 8) {
                ScrollView { Text(status).font(.caption2.monospaced()).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 180)
                Picker("단계", selection: $tier) {
                    Text("전부").tag(-1)
                    ForEach(SkyTier.allCases.reversed()) { Text($0.name).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Button("닫기") { dismiss() }
                    Spacer()
                    Button(running ? "재는 중" : "스크롤 시험") { Task { await scrollTest() } }.disabled(running || scroll == nil)
                    Button("유휴 \(Int(Self.idleSeconds))초") { Task { await idleTest() } }.disabled(running || scroll == nil)
                }
                .font(Face.caption)
            }
            .padding(12)
            .background(.black.opacity(0.75))
        }
        .preferredColorScheme(.dark)
        .onAppear { SkyView.prewarm() }
        .task(id: scroll == nil) {
            let args = ProcessInfo.processInfo.arguments
            guard scroll != nil, args.contains("-skyScroll") || args.contains("-skyIdle"), !running else { return }
            try? await Task.sleep(for: .seconds(1.5))
            if args.contains("-skyScroll") { await scrollTest() }
            if args.contains("-skyIdle") { await idleTest() }
            NSLog("SKYSCROLL 끝")
        }
    }

    private func scrollTest() async {
        guard let scroll, !running else { return }
        running = true
        defer { running = false }
        if let t = SkyTier(rawValue: tier) {
            status = await SkyScrollTest.pair(scroll, tier: t) { status = $0 }
        } else {
            status = await SkyScrollTest.runAll(scroll) { status = $0 }
        }
    }

    /// 단계 「전부」면 기기 자동 단계로.
    private func idleTest() async {
        guard let scroll, !running else { return }
        running = true
        defer { running = false }
        status = await SkyScrollTest.pair(scroll, tier: SkyTier(rawValue: tier), idleSeconds: Self.idleSeconds) { status = $0 }
    }
}
#endif
