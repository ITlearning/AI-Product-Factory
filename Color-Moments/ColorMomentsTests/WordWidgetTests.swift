import SwiftUI
import XCTest
@testable import ColorMoments

final class WordWidgetTests: XCTestCase {

    private let words = BundledWordSource.cached
    private let text = WordWidgetText.cached

    private func date(_ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        PhotoContext.korea.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
    }

    private func slots(_ now: Date) -> [AmbientNow.Slot] { AmbientNow.slots(from: now, forecast: nil, place: nil, in: words) }

    // MARK: 문구는 데이터로

    func testTextLoadsWithEverySceneAndLook() throws {
        let t = try XCTUnwrap(text, "번들에 widget-words.json 이 없다")
        for kind in SceneKind.allCases {
            let scene = try XCTUnwrap(t.scenes[kind.rawValue], kind.rawValue)
            XCTAssertFalse(scene.lines.isEmpty, kind.rawValue)
            XCTAssertTrue(scene.short.contains(WordWidgetText.wordMark), kind.rawValue)
            for line in scene.lines { XCTAssertTrue(line.contains(WordWidgetText.wordMark), line) }
        }
        for style in SceneStyle.allCases { XCTAssertNotNil(t.looks[style.rawValue], style.rawValue) }
        XCTAssertFalse(t.pick.isEmpty)
        XCTAssertFalse(t.picked.isEmpty)
    }

    /// 위젯 화면 소스엔 한글이 없다 — 있으면 확장 글꼴 서브셋 검사 대상에서 빠진 글자가 생긴다.
    func testWidgetViewSourcesHaveNoHangul() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for path in ["Shared/Widget/WordWidgetViews.swift", "Shared/Widget/WordWidgetTimeline.swift"] {
            let src = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            let code = src.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined()
            XCTAssertFalse(code.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }, "\(path) 코드에 한글 문구")
        }
    }

    // MARK: 조사

    func testParticlesFollowFinalConsonant() {
        // 해거름(ㅁ 받침) · 는개(받침 없음) · 하늘(ㄹ 받침)
        let cases: [(String, String, String)] = [
            ("{이/가}", "해거름", "이"), ("{이/가}", "는개", "가"), ("{이/가}", "하늘", "이"),
            ("{은/는}", "해거름", "은"), ("{은/는}", "는개", "는"),
            ("{을/를}", "해거름", "을"), ("{을/를}", "는개", "를"),
            ("{과/와}", "해거름", "과"), ("{과/와}", "는개", "와"),
            ("{으로/로}", "해거름", "으로"), ("{으로/로}", "는개", "로"), ("{으로/로}", "하늘", "로"),
        ]
        for (pair, word, expected) in cases {
            XCTAssertEqual(WordWidgetText.particles(pair, after: word), expected, "\(word)\(pair)")
        }
    }

    func testEveryTemplateFillsWithEveryKindOfWord() throws {
        let t = try XCTUnwrap(text)
        for (kind, scene) in t.scenes {
            for line in scene.lines + [scene.short] {
                for word in ["해거름", "는개", "하늘"] {
                    let s = try XCTUnwrap(WordWidgetText.fill(line, word: word), line)
                    XCTAssertEqual(s.word, word)
                    XCTAssertFalse(s.plain.contains("{") || s.plain.contains("}"), "\(kind): \(s.plain)")
                    XCTAssertTrue(s.plain.contains("'\(word)'"), s.plain)
                }
            }
        }
        let rain = try XCTUnwrap(WordWidgetText.fill("밖에 '{w}'{이/가} 내려요", word: "는개"))
        XCTAssertEqual(rain.plain, "밖에 '는개'가 내려요")
        XCTAssertEqual(rain.before, "밖에 '")
        XCTAssertEqual(rain.after, "'가 내려요")
    }

    // MARK: 타임라인

    func testTwentyFourHourlyEntriesStartingNow() {
        let now = date(10, 15, 18, 20)
        let models = WordWidgetTimeline.models(slots: slots(now), picks: [], justPicked: nil, now: now, text: text)
        XCTAssertEqual(models.count, 24)
        XCTAssertEqual(models[0].date, now)
        XCTAssertEqual(models[1].date, date(10, 15, 19))
        XCTAssertTrue(models.allSatisfy { $0.pick == .open })
        XCTAssertNotNil(models[0].sentence)
        XCTAssertEqual(models[0].sentence?.word, models[0].word)
        XCTAssertEqual(WordWidgetTimeline.reloadAfter, 3 * 3600)
    }

    func testPickedWordShowsPebbleForThatDayOnly() throws {
        let now = date(10, 15, 18, 20)
        let s = slots(now)
        let word = try XCTUnwrap(s[0].word)
        let pick = PickLine(kind: .pick, word: word.word, wordID: word.id, source: .widget, at: date(10, 15, 9))
        let models = WordWidgetTimeline.models(slots: s, picks: [pick], justPicked: nil, now: now, text: text)
        XCTAssertEqual(models[0].pick, .picked, "같은 말은 하루 한 번 — 버튼 대신 작은 조약돌")
        for m in models where m.word == word.word && Moment.dayKey(for: m.date) != Moment.dayKey(for: now) {
            XCTAssertEqual(m.pick, .open, "새벽 4시가 지나면 다시 주울 수 있다")
        }
    }

    func testJustPickedHoldsThenSettles() throws {
        let now = date(10, 15, 18, 20)
        let s = slots(now)
        let word = try XCTUnwrap(s[0].word)
        let pick = PickLine(kind: .pick, word: word.word, wordID: word.id, source: .widget, at: now.addingTimeInterval(-0.5))
        let just = JustPicked(word: word.word, at: now.addingTimeInterval(-0.5))
        let models = WordWidgetTimeline.models(slots: s, picks: [pick], justPicked: just, now: now, text: text)
        XCTAssertEqual(models[0].pick, .justPicked)
        XCTAssertEqual(models[1].pick, .picked)
        XCTAssertEqual(models[1].date.timeIntervalSince(now), WordWidgetTimeline.pickedHold, accuracy: 0.001)
        XCTAssertEqual(models.count, 25)

        let stale = WordWidgetTimeline.models(slots: s, picks: [pick], justPicked: JustPicked(word: word.word, at: now.addingTimeInterval(-60)),
                                              now: now, text: text)
        XCTAssertEqual(stale[0].pick, .picked, "늦게 불린 타임라인은 「주웠어요」 없이 바로 조약돌")

        let unwritten = WordWidgetTimeline.models(slots: s, picks: [], justPicked: just, now: now, text: text)
        XCTAssertEqual(unwritten[0].pick, .open, "기록이 디스크에 없으면 「주웠어요」를 보이지 않는다")
    }

    func testBrokenWordListGivesBlankSceneWithBrandOnly() {
        let now = date(10, 15, 18)
        let models = WordWidgetTimeline.models(now: now, forecast: nil, place: nil, picks: [], justPicked: nil, words: [])
        XCTAssertEqual(models, [.blank(now)])
        XCTAssertNil(models[0].word)
        XCTAssertNil(models[0].scene)
        XCTAssertEqual(models[0].accessibilityText(text), text?.brand)
    }

    func testReadsAsOneSentence() throws {
        let now = date(10, 15, 18, 20)
        let m = try XCTUnwrap(WordWidgetTimeline.models(slots: slots(now), picks: [], justPicked: nil, now: now, text: text).first)
        let label = try XCTUnwrap(m.accessibilityText(text))
        XCTAssertTrue(label.hasPrefix(try XCTUnwrap(m.word)))
        XCTAssertTrue(label.contains(try XCTUnwrap(m.meaning)))
        XCTAssertTrue(label.contains(try XCTUnwrap(m.sentence?.plain)))
    }

    // MARK: 줍기

    func testPickWritesOnceADayToWidgetFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("widget-pick-\(UUID())")
        let widget = PickedWords(writer: .widget, directory: dir)
        XCTAssertFalse(widget.pickedToday("는개"))
        _ = try widget.pick("는개", wordID: "neungae", source: .widget)
        XCTAssertTrue(widget.pickedToday("는개"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("picks-widget.jsonl").path))
        XCTAssertTrue(PickedWords(writer: .app, directory: dir).pickedToday("는개"), "앱도 같은 판정")
    }

    // MARK: 눈으로 보기 — TEST_RUNNER_WIDGET_SHOTS=폴더

    @MainActor
    func testDumpWidgets() throws {
        guard let dir = ProcessInfo.processInfo.environment["WIDGET_SHOTS"] else { throw XCTSkip("덤프 폴더 없음") }
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func model(_ id: String, _ pick: WordWidgetModel.Pick = .open, moonAge: Double = 14.8) throws -> WordWidgetModel {
            let w = try XCTUnwrap(byID[id], id)
            let scene = SceneKind.of(w)
            return WordWidgetModel(date: Date(), word: w.word, wordID: w.id, meaning: w.meaning, scene: scene, moonAge: moonAge,
                                   pick: pick, sentence: text?.sentence(w.word, id: w.id, scene: scene),
                                   short: text?.short(w.word, scene: scene))
        }
        func small(_ m: WordWidgetModel, _ style: SceneStyle) -> AnyView {
            AnyView(WordWidgetSmall(model: m, style: style, drawsBackground: true) { [text] _ in WordPickLabel(text?.pick ?? "") }
                .frame(width: 170, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
        }
        func lock(_ v: some View, _ w: CGFloat, _ h: CGFloat) -> AnyView {
            AnyView(v.foregroundStyle(.white).frame(width: w, height: h)
                .padding(10).background(Color(red: 0.16, green: 0.2, blue: 0.3)))
        }
        var shots: [(String, AnyView)] = []
        for id in ["neungae", "jakdalbi", "haegeoreum", "ondal", "gaeulbyeot", "saebyeoknyeok", "nunbora"] {
            shots.append(("small-wash-\(id)", small(try model(id), .wash)))
            shots.append(("small-print-\(id)", small(try model(id), .print)))
        }
        shots.append(("small-wash-picked", small(try model("neungae", .picked), .wash)))
        shots.append(("small-wash-justpicked", small(try model("neungae", .justPicked), .wash)))
        shots.append(("small-blank", small(.blank(Date()), .wash)))
        for id in ["neungae", "haegeoreum", "ondal", "gaeulbyeot", "nunbora", "saebyeoknyeok", "kkotsaemchuwi"] {
            let m = try model(id, moonAge: 6)
            shots.append(("lock-inline-\(id)", lock(WordLockInline(model: m).font(.system(size: 15)), 220, 22)))
            shots.append(("lock-circular-\(id)", lock(WordLockCircular(model: m), 72, 72)))
            shots.append(("lock-rect-\(id)", lock(WordLockRectangular(model: m), 160, 72)))
        }
        for age in [3.0, 7.4, 11.0, 14.8, 22.1, 26.0] {
            shots.append(("lock-moon-\(age)", lock(LockSceneGlyph(scene: .moon, moonAge: age), 60, 60)))
        }
        for kind in SceneKind.allCases {
            shots.append(("glyph-\(kind.rawValue)", lock(LockSceneGlyph(scene: kind, moonAge: 9), 60, 60)))
        }
        for (name, view) in shots {
            let r = ImageRenderer(content: view.environment(\.colorScheme, .dark))
            r.scale = 3
            let data = try XCTUnwrap(r.uiImage?.pngData(), name)
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
