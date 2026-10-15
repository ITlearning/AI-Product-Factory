import SwiftUI
import XCTest
@testable import ColorMoments

/// 셰이더 하늘을 「말」 칸·생일 카드·위젯에 잇는 자리.
final class SkyWireTests: XCTestCase {

    private let words = BundledWordSource.cached
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 21))!

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sky-wire-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    // MARK: 대응

    func testMappingCoversTheFourSkiesAndLeavesTheRestToSceneView() {
        XCTAssertEqual(SkyScene.of(.sun), .clearDay)
        XCTAssertEqual(SkyScene.of(.stars), .clearNight)
        XCTAssertEqual(SkyScene.of(.moon), .nightCloudy)
        XCTAssertEqual(SkyScene.of(.rain), .rain)
        XCTAssertEqual(SkyScene.of(.drizzle), .rain)
        for k in [SceneKind.dawn, .dusk, .snow, .fog, .wind, .petals, .leaves, .frost] {
            XCTAssertNil(SkyScene.of(k), k.rawValue)
        }
        XCTAssertEqual(Set(WordWidgetSky.scenes), Set(SkyScene.allCases), "모든 하늘이 어떤 장면에서든 쓰인다")
    }

    func testSmallTextIsPrimaryOnlyOnClearDay() {
        XCTAssertEqual(SceneKind.sun.smallTextTone, Tone.primary)
        for k in SceneKind.allCases where k != .sun { XCTAssertEqual(k.smallTextTone, Tone.secondary, k.rawValue) }
    }

    func testBirthdaySeasonsGoThroughTheSameMapping() {
        XCTAssertEqual(SkyScene.of(BirthdayCardSky.kind(month: 7)), .clearDay)
        XCTAssertNil(SkyScene.of(BirthdayCardSky.kind(month: 10)), "가을 낙엽은 아직 SceneView")
    }

    // MARK: 위젯 정지 그림

    func testFileNameCarriesSceneSizeAndEdition() {
        XCTAssertEqual(WordWidgetSky.fileName(.clearDay, size: .small, edition: 4), "sky-clearDay-small-e4.jpg")
        XCTAssertNotEqual(WordWidgetSky.fileName(.rain, edition: 4), WordWidgetSky.fileName(.rain, edition: 5))
        XCTAssertEqual(Set(SkyScene.allCases.map { WordWidgetSky.fileName($0) }).count, SkyScene.allCases.count)
    }

    func testBakeOnlyWhenMissingOrNightMoonIsFromAnotherDay() {
        let morning = Calendar.current.date(byAdding: .hour, value: -12, to: now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertTrue(WordWidgetSky.needsBake(.clearDay, modified: nil, now: now))
        XCTAssertFalse(WordWidgetSky.needsBake(.clearDay, modified: yesterday, now: now), "낮 하늘은 판이 같으면 그대로")
        XCTAssertFalse(WordWidgetSky.needsBake(.rain, modified: yesterday, now: now))
        XCTAssertTrue(WordWidgetSky.needsBake(.clearNight, modified: yesterday, now: now), "달은 날마다")
        XCTAssertTrue(WordWidgetSky.needsBake(.nightCloudy, modified: yesterday, now: now))
        XCTAssertFalse(WordWidgetSky.needsBake(.nightCloudy, modified: morning, now: now))
    }

    func testOldEditionsAreSwept() {
        let names = ["sky-clearDay-small-e3.jpg", WordWidgetSky.fileName(.clearDay), "sky-rain-medium-e4.jpg", "other.json"]
        XCTAssertEqual(WordWidgetSky.stale(names), ["sky-clearDay-small-e3.jpg", "sky-rain-medium-e4.jpg"])
    }

    func testBakeWritesOncePerSceneAndRebakesOnNewDayOrEdition() throws {
        // 파일 수정 시각은 진짜 지금 — 시계도 진짜로.
        let now = Date()
        let dir = try tempDir()
        var rendered: [SkyScene] = []
        let fake: (SkyFrame, CGFloat) -> CGImage? = { f, _ in
            rendered.append(f.scene)
            XCTAssertEqual(f.size, WordWidgetSky.Size.small.points)
            XCTAssertEqual(f.texts, SkyTexts.card(f.size), "위젯 글자 자리 = 네모 카드 자리")
            return Self.pixel()
        }
        XCTAssertTrue(WordWidgetSky.bakeIfNeeded(in: dir, now: now, render: fake))
        XCTAssertEqual(Set(rendered), Set(SkyScene.allCases))
        rendered = []
        XCTAssertFalse(WordWidgetSky.bakeIfNeeded(in: dir, now: now, render: fake), "다 있으면 굽지 않는다")
        XCTAssertTrue(rendered.isEmpty)

        let old = dir.appendingPathComponent("sky-rain-small-e1.jpg")
        try Data([1]).write(to: old)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        XCTAssertTrue(WordWidgetSky.bakeIfNeeded(in: dir, now: tomorrow, render: fake))
        XCTAssertEqual(Set(rendered), [.clearNight, .nightCloudy], "다음 날엔 달 뜨는 밤만")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path), "옛 판은 지운다")

        let image = try XCTUnwrap(WordWidgetSky.image(for: .drizzle, in: dir))
        XCTAssertEqual(image.size.width, 1)
        XCTAssertNil(WordWidgetSky.image(for: .frost, in: dir), "하늘 없는 장면은 SceneView")
    }

    func testRealBakeIsSmall() throws {
        let dir = try tempDir()
        XCTAssertTrue(WordWidgetSky.bakeIfNeeded(in: dir, now: now))
        var total = 0
        for s in SkyScene.allCases {
            let url = dir.appendingPathComponent(WordWidgetSky.fileName(s))
            let size = try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, s.key)
            XCTAssertLessThan(size, 150_000, s.key)
            total += size
        }
        XCTAssertLessThan(total, 400_000)
    }

    private static func pixel() -> CGImage? {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1))
        ctx?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return ctx?.makeImage()
    }

    // MARK: 멈춘 카드 그림

    func testStillsAreCachedPerSceneSizeAndMoonDay() throws {
        let stills = SkyStills()
        let size = CGSize(width: 354, height: 96)
        let a = try XCTUnwrap(stills.image(.rain, quality: .card, size: size, scale: 2, now: now))
        let b = try XCTUnwrap(stills.image(.rain, quality: .card, size: size, scale: 2, now: now))
        XCTAssertTrue(a === b, "같은 열쇠는 다시 굽지 않는다")
        XCTAssertEqual(a.width, 708)
        XCTAssertEqual(SkyStills.key(.rain, quality: .card, size: size, scale: 2, moonDay: 3),
                       SkyStills.key(.rain, quality: .card, size: size, scale: 2, moonDay: 9), "비엔 달이 없다")
        XCTAssertNotEqual(SkyStills.key(.clearNight, quality: .card, size: size, scale: 2, moonDay: 3),
                          SkyStills.key(.clearNight, quality: .card, size: size, scale: 2, moonDay: 9))
    }

    // MARK: 눈으로 보기 — TEST_RUNNER_WIRE_SHOTS=<폴더>

    @MainActor
    func testDumpWire() throws {
        guard let dir = ProcessInfo.processInfo.environment["WIRE_SHOTS"] else { throw XCTSkip("덤프 폴더 없음") }
        let out = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        func pick(_ word: String, _ at: Date, _ source: PickLine.Source = .widget) -> PickLine {
            PickLine(kind: .pick, word: word, wordID: words.first { $0.word == word }?.id, source: source, at: at)
        }
        func at(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
            Calendar.current.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
        }
        let picks = [pick("작달비", at(10, 15, 18)), pick("는개", at(10, 14, 9)), pick("가을볕", at(10, 13)),
                     pick("온달", at(10, 12, 22)), pick("해거름", at(10, 10, 18)), pick("새벽녘", at(10, 9, 5)),
                     pick("미리내", at(10, 8, 23)), pick("가을볕", at(10, 2), .birthday)]
        let shelf = WordShelf.make(PickedWords.merge(PickedWords.live(picks), words: words), entries: words, now: now)
        func page(_ s: WordShelf, now card: WordCardModel? = nil) -> some View {
            VStack(spacing: 0) {
                WordsHeader(count: s.count)
                WordsPage(phase: .ready, shelf: s, now: card, nowLooked: true, picked: false, attribution: nil,
                          active: false, visible: [], lazy: false)
            }
            .frame(width: 390)
            .background(Tone.base)
        }
        var shots: [(String, AnyView, CGFloat)] = [
            ("words-list", AnyView(page(shelf)), 2),
        ]
        for id in ["jakdalbi", "gaeulbyeot", "ondal"] {
            if let e = words.first(where: { $0.id == id }) {
                shots.append(("words-empty-\(id)", AnyView(page(.empty, now: WordShelf.now(e))), 2))
            }
        }
        if let c = shelf.hero {
            shots.append(("words-opened", AnyView(OpenedWordSheet(model: c, remove: {}).content
                .environment(\._accessibilityReduceMotion, true).frame(width: 390).background(Tone.base)), 2))
        }
        let bd = BirthdayPick(word: "윤슬", meaning: "햇빛이나 달빛에 비쳐 반짝이는 잔물결", extras: [], pool: 1)
        for month in [7, 10] {
            var frames: [(String, Double, Double?, Bool)] = [("land", 2.4, nil, false), ("settled", 6.0, nil, false)]
            for f in [0.15, 0.3, 0.45, 0.6, 0.8, 0.9, 1.0, 1.3] { frames.append(("fold-\(f)", 6.0, f, false)) }
            for f in [0.2, 0.35, 0.5, 0.8] { frames.append(("still-fold-\(f)", 6.0, f, true)) }
            for (name, t, fold, still) in frames {
                let scene = BirthdayRevealScene(pick: bd, month: month, day: 3, passing: ["물비늘", "윤슬"],
                                                t: t, land: BirthdayReveal.land, fold: fold, still: still)
                    .environment(\._accessibilityReduceMotion, true)
                    .frame(width: 350, height: 520)
                    .padding(20)
                    .background(Tone.base)
                shots.append(("birthday-\(month)-\(name)", AnyView(scene), 2))
            }
        }
        let skyDir = out.appendingPathComponent("widget-sky")
        try? FileManager.default.removeItem(at: skyDir)
        WordWidgetSky.bakeIfNeeded(in: skyDir, now: now)
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for id in ["jakdalbi", "neungae", "gaeulbyeot", "ondal", "mirinae", "haegeoreum"] {
            guard let w = byID[id] else { continue }
            let scene = SceneKind.of(w)
            let m = WordWidgetModel(date: now, word: w.word, wordID: w.id, meaning: w.meaning, scene: scene, moonAge: 14.8,
                                    pick: .open, sentence: nil, short: nil)
            let v = ZStack {
                WordWidgetBackground(model: m, style: .wash, skyDirectory: skyDir)
                WordWidgetSmall(model: m, style: .wash, drawsBackground: false) { _ in WordPickLabel("줍기") }
            }
            .frame(width: 170, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            shots.append(("widget-\(id)-\(scene.rawValue)", AnyView(v), 3))
        }
        for (name, view, scale) in shots {
            let r = ImageRenderer(content: view.environment(\.colorScheme, .dark))
            r.scale = scale
            let data = try XCTUnwrap(r.uiImage?.pngData(), name)
            try data.write(to: out.appendingPathComponent("\(name).png"))
        }
    }
}
