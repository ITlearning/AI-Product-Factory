#if DEBUG
import SwiftUI
import UIKit

/// 디버그 — 「말」 칸과 같은 목록(WordsPage)을 자동으로 위아래로 스크롤하며 놓친 프레임·최악 간격·하늘 계측을 잰다.
@MainActor
enum SkyScrollTest {
    struct Result {
        var name: String
        var frames = 0
        var missed = 0
        var hitches = 0
        var worstMs = 0.0
        var counters = SkyStats.Counters()

        var line: String {
            let c = counters
            return String(format: "%@ · 프레임 %d · 놓침 %d · 끊김 %d · 최악 %.1fms · 하늘 그리기 평균 %.2f 최악 %.1fms(%d번) · 쉼 %d · 레이마칭 %d · 하늘 갱신 %d · 카드 계산 %d · MTKView 생성 %d · 스크롤 중 생성 %d · 풀 재사용 %d · 최대 %d · 정지 그림 %d장 %.0fms(최악 %.1f)",
                          name, frames, missed, hitches, worstMs, c.draws > 0 ? c.drawMs / Double(c.draws) : 0, c.worstDrawMs, c.draws,
                          c.rests, c.marches, c.updates, c.bodies, c.made, c.madeInScroll, c.reused, c.maxAlive, c.stills, c.stillMs, c.worstStillMs)
        }
    }

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
        let text = lines.map { "\(stamp) · \(model) · \($0)\n" }.joined()
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

    /// 한 구성(단계·옛 구조)을 잰다 — 먼저 한 번 훑어 판을 굽고, 계측을 비운 뒤 느리게·빠르게 위아래로.
    static func run(_ scroll: UIScrollView, tier: SkyTier?, legacy: Bool, speeds: [Double] = [900, 2600]) async -> Result {
        SkyDebug.tier = tier
        SkyDebug.liveInScroll = legacy
        defer { SkyDebug.liveInScroll = false }
        scroll.setContentOffset(.zero, animated: false)
        try? await Task.sleep(for: .seconds(1))
        _ = await ScrollDriver(scroll, speeds: [2000]).run()
        try? await Task.sleep(for: .seconds(0.8))
        SkyStats.shared.reset()
        SkyStats.shared.resetCounters()
        var r = await ScrollDriver(scroll, speeds: speeds).run()
        r.counters = SkyStats.shared.counters
        r.name = "\(tier?.name ?? "자동")\(legacy ? " 옛 구조" : "")"
        return r
    }

    static func runAll(_ scroll: UIScrollView, progress: (String) -> Void = { _ in }) async -> String {
        let saved = SkyDebug.tier
        defer { SkyDebug.tier = saved }
        var lines: [String] = []
        let plan: [(SkyTier, Bool)] = [(.ultra, true), (.high, true), (.ultra, false), (.high, false), (.mid, false), (.low, false)]
        for (tier, legacy) in plan {
            progress("\(tier.name)\(legacy ? " 옛 구조" : "") 재는 중…")
            let r = await run(scroll, tier: tier, legacy: legacy)
            lines.append(r.line)
            NSLog("SKYSCROLL %@", r.line)
        }
        save(lines)
        return lines.joined(separator: "\n")
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

/// 갤러리에서 여는 화면 — 단계별(옛 구조 포함)로 차례로 재고 표를 보인다.
struct SkyScrollTestScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scroll: UIScrollView?
    @State private var status = "준비 중…"
    @State private var running = false
    @State private var tier = -1

    var body: some View {
        ZStack(alignment: .bottom) {
            SkyScrollList { s in if scroll !== s { scroll = s } }
            VStack(alignment: .leading, spacing: 8) {
                ScrollView { Text(status).font(.caption2.monospaced()).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 180)
                HStack {
                    Button("닫기") { dismiss() }
                    Spacer()
                    Picker("단계", selection: $tier) {
                        Text("전부").tag(-1)
                        ForEach(SkyTier.allCases.reversed()) { Text($0.name).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    Button(running ? "재는 중" : "시작") { start() }.disabled(running || scroll == nil)
                }
                .font(Face.caption)
            }
            .padding(12)
            .background(.black.opacity(0.75))
        }
        .preferredColorScheme(.dark)
        .onAppear { SkyView.prewarm() }
        .task(id: scroll == nil) {
            guard scroll != nil, ProcessInfo.processInfo.arguments.contains("-skyScroll"), !running else { return }
            try? await Task.sleep(for: .seconds(1.5))
            start()
        }
    }

    private func start() {
        guard let scroll else { return }
        running = true
        Task {
            if let t = SkyTier(rawValue: tier) {
                status = "\(t.name) 재는 중…"
                let saved = SkyDebug.tier
                let r = await SkyScrollTest.run(scroll, tier: t, legacy: false)
                SkyDebug.tier = saved
                NSLog("SKYSCROLL %@", r.line)
                SkyScrollTest.save([r.line])
                status = r.line
            } else {
                status = await SkyScrollTest.runAll(scroll) { status = $0 }
            }
            running = false
        }
    }
}
#endif
