import SwiftUI
import XCTest
@testable import ColorMoments

@MainActor
final class SceneViewTests: XCTestCase {

    /// 위젯 작은 칸, 「말」 칸 카드, 오늘의 한 장.
    private let sizes = [CGSize(width: 158, height: 158), CGSize(width: 170, height: 170),
                         CGSize(width: 354, height: 96), CGSize(width: 354, height: 232)]

    private let captionInk = SceneRGB.white

    private func worstContrast(_ kind: SceneKind, _ style: SceneStyle, tintHex: String? = nil) -> Double {
        let ys = (0...400).map { Double($0) / 400 } + SceneArt.palette(kind, style).sky.map(\.at)
        return ys.map { y in
            let bg = SceneArt.backdrop(kind, style, y: y, tintHex: tintHex)
            return SceneRGB.contrast(captionInk.over(bg, alpha: Tone.secondaryAlpha), bg)
        }.min() ?? 0
    }

    func testSceneKindCountStaysInPlannedRange() {
        XCTAssertTrue((10...15).contains(SceneKind.allCases.count), "장면 갈래 \(SceneKind.allCases.count)개")
    }

    /// 5A — 장면 위 가장 옅은 글자(secondary 64%)도 글자 자리 어디서나 4.5:1.
    func testTextZoneContrastHoldsForEveryScene() {
        var report: [String] = []
        for kind in SceneKind.allCases {
            for style in SceneStyle.allCases {
                let worst = worstContrast(kind, style)
                report.append("\(kind.rawValue)/\(style.rawValue) \(String(format: "%.2f", worst))")
                XCTAssertGreaterThanOrEqual(worst, 4.5, "\(kind)/\(style) 글자 자리 대비 \(worst)")
            }
        }
        print("SCENE-CONTRAST " + report.joined(separator: ", "))
    }

    /// 사진 색을 섞어도 하늘이 밝아지지 않는다 — 대비는 그대로 4.5:1 이상.
    func testPhotoTintNeverBreaksContrast() {
        let tints = ["#FFFFFF", "#FFD640", "#B12E12", "#7FB0DC", "#8FA36B", "#000000", "#F7F2EA"]
        for kind in SceneKind.allCases {
            let plain = SceneArt.sky(kind, .wash)
            for tint in tints {
                XCTAssertGreaterThanOrEqual(worstContrast(kind, .wash, tintHex: tint), 4.5, "\(kind) + \(tint)")
                for (p, t) in zip(plain, SceneArt.sky(kind, .wash, tintHex: tint)) {
                    XCTAssertLessThanOrEqual(t.color.luminance, p.color.luminance + 1e-9, "\(kind) + \(tint) 가 하늘을 밝혔다")
                }
            }
        }
        XCTAssertNotEqual(SceneArt.sky(.rain, .wash, tintHex: "#B12E12"), SceneArt.sky(.rain, .wash), "색이 하나도 안 섞였다")
        XCTAssertEqual(SceneArt.sky(.rain, .print, tintHex: "#B12E12"), SceneArt.sky(.rain, .print), "판화엔 사진 색을 섞지 않는다")
    }

    /// 5A — 해·달·노을·지평선·빛·바람 줄은 글자 자리(카드 모양별 실제 글자 자리 전체) 밖에만.
    func testBrightMarksStayOutOfTextZone() {
        for size in sizes {
            let rects = SceneArt.textRects(in: size)
            for kind in SceneKind.allCases {
                for style in SceneStyle.allCases {
                    for box in SceneArt.brightBounds(kind, style, in: size) {
                        for text in rects {
                            let hit = box.intersection(text)
                            XCTAssertTrue(hit.isNull || hit.width < 0.01 || hit.height < 0.01,
                                          "\(kind)/\(style) \(size) \(box) 가 글자 자리 \(text) 와 겹친다")
                        }
                    }
                }
            }
        }
    }

    /// 글자 자리 정의가 실제 글자를 다 덮는다 — 눈으로 보기 시트의 세 배치(위젯·목록 카드·오늘의 한 장)를 장면 없이 그려 본다.
    func testTextRectsCoverRenderedText() throws {
        Face.ensureRegistered()
        let layouts: [(String, CGSize, (String, SceneKind) -> AnyView)] = [
            ("widget158", CGSize(width: 158, height: 158), { w, k in AnyView(self.widget(k, .wash, w, 0, scene: false)) }),
            ("widget170", CGSize(width: 170, height: 170), { w, k in AnyView(self.widget(k, .wash, w, 0, scene: false, side: 170)) }),
            ("card", CGSize(width: 354, height: 96), { w, k in AnyView(self.card(k, .wash, w, 0, scene: false)) }),
            ("hero", CGSize(width: 354, height: 232), { w, k in AnyView(self.hero(k, w, scene: false)) })]
        for (name, size, make) in layouts {
            let rects = SceneArt.textRects(in: size)
            for kind in SceneKind.allCases {
                let px = try pixels(make(Self.words[kind] ?? "", kind), size)
                var outside = 0
                for y in 0..<px.h {
                    for x in 0..<px.w where px.max(x, y) > 10 {
                        let p = CGPoint(x: (Double(x) + 0.5) / px.scale, y: (Double(y) + 0.5) / px.scale)
                        if !rects.contains(where: { $0.contains(p) }) { outside += 1 }
                    }
                }
                XCTAssertEqual(outside, 0, "\(name) \(kind) 글자 픽셀 \(outside)개가 글자 자리 밖")
            }
        }
    }

    /// 5A — 글자 자리 안엔 하늘·띠만: 장면을 다 그린 것과 하늘만 그린 것이 같고, 입자까지 넣어도 secondary 4.5:1.
    func testNothingDrawnInsideTextRects() throws {
        var worst = Double.infinity
        var report: [String] = []
        for size in sizes {
            let rects = SceneArt.textRects(in: size)
            for kind in SceneKind.allCases {
                for style in SceneStyle.allCases {
                    let sky = try pixels(canvas(kind, style, SceneArt.stillPhase, marks: false), size)
                    for t in [SceneArt.stillPhase, SceneArt.stillPhase + 0.6, SceneArt.stillPhase + 2.3] {
                        let full = try pixels(canvas(kind, style, t, marks: true), size)
                        var diff = 0, low = Double.infinity
                        for y in 0..<full.h {
                            for x in 0..<full.w {
                                let p = CGPoint(x: (Double(x) + 0.5) / full.scale, y: (Double(y) + 0.5) / full.scale)
                                guard rects.contains(where: { $0.contains(p) }) else { continue }
                                diff = max(diff, full.diff(sky, x, y))
                                let bg = full.rgb(x, y)
                                low = min(low, SceneRGB.contrast(captionInk.over(bg, alpha: Tone.secondaryAlpha), bg))
                            }
                        }
                        worst = min(worst, low)
                        if diff > 3 { report.append("\(kind)/\(style) \(Int(size.width))x\(Int(size.height)) t\(t) +\(diff)") }
                        XCTAssertGreaterThanOrEqual(low, 4.5, "\(kind)/\(style) \(size) t\(t) 글자 자리 대비 \(low)")
                    }
                }
            }
        }
        print("SCENE-TEXT-RECT worst contrast \(String(format: "%.2f", worst)); drawn over text: \(report.joined(separator: ", "))")
        XCTAssertTrue(report.isEmpty, "글자 자리에 그림이 그려졌다: \(report.joined(separator: ", "))")
    }

    /// 판화 가는 비도 눈에 보인다 — 또렷이 밝은 픽셀이 판화 비의 80% 이상.
    func testPrintDrizzleIsVisible() throws {
        for size in sizes {
            func lit(_ kind: SceneKind) throws -> Int {
                let full = try pixels(canvas(kind, .print, SceneArt.stillPhase, marks: true), size)
                let sky = try pixels(canvas(kind, .print, SceneArt.stillPhase, marks: false), size)
                var n = 0
                for y in 0..<full.h { for x in 0..<full.w where full.diff(sky, x, y) >= 90 { n += 1 } }
                return n
            }
            let (drizzle, rain) = (try lit(.drizzle), try lit(.rain))
            print("SCENE-DRIZZLE \(size) drizzle \(drizzle) rain \(rain)")
            XCTAssertGreaterThanOrEqual(Double(drizzle), 0.8 * Double(rain), "\(size) 판화 가는 비가 안 보인다")
        }
    }

    /// R6 — 카드당 빗줄기 30·별 20.
    func testParticleCaps() {
        for kind in SceneKind.allCases {
            let p = SceneArt.particles(kind)
            XCTAssertLessThanOrEqual(p.rain, SceneArt.rainCap, "\(kind)")
            XCTAssertLessThanOrEqual(p.stars, SceneArt.starCap, "\(kind)")
            XCTAssertLessThanOrEqual(p.flakes, 30, "\(kind)")
        }
        XCTAssertEqual(SceneArt.rainCap, 30)
        XCTAssertEqual(SceneArt.starCap, 20)
        XCTAssertEqual(SceneView.heroFrameInterval, 1.0 / 60)
        XCTAssertEqual(SceneView.cardFrameInterval, 1.0 / 30)
    }

    /// R6 — 멈추면 그 순간을 붙잡고, 다시 움직이면 거기서 이어 간다(되감기·건너뛰기 없음).
    func testClockHoldsWhenStoppedAndResumesFromThere() {
        let t0 = Date(timeIntervalSinceReferenceDate: 1000)
        var clock = SceneTime(phase: 7)
        XCTAssertEqual(clock.time(at: t0.addingTimeInterval(50)), 7, "멈춘 그림은 시간이 흐르지 않는다")

        clock.set(running: true, at: t0)
        XCTAssertEqual(clock.time(at: t0.addingTimeInterval(2)), 9, accuracy: 1e-9)

        clock.set(running: false, at: t0.addingTimeInterval(3))
        XCTAssertEqual(clock.held, 10, accuracy: 1e-9)
        XCTAssertEqual(clock.time(at: t0.addingTimeInterval(100)), 10, accuracy: 1e-9, "화면 밖에선 그대로")

        clock.set(running: true, at: t0.addingTimeInterval(100))
        XCTAssertEqual(clock.time(at: t0.addingTimeInterval(100)), 10, accuracy: 1e-9, "들어올 때 튀지 않는다")
        XCTAssertEqual(clock.time(at: t0.addingTimeInterval(101.5)), 11.5, accuracy: 1e-9)

        clock.set(running: true, at: t0.addingTimeInterval(200))
        XCTAssertEqual(clock.time(at: t0.addingTimeInterval(201.5)), 11.5 + 100, accuracy: 1e-9, "두 번 켜도 시작점이 안 바뀐다")
    }

    func testEverySceneRendersInBothStyles() throws {
        for kind in SceneKind.allCases {
            for style in SceneStyle.allCases {
                let r = ImageRenderer(content: SceneView(kind, style: style).frame(width: 60, height: 40))
                XCTAssertNotNil(r.uiImage, "\(kind)/\(style)")
            }
        }
    }

    /// 위젯 확장에도 들어가는 소스 — 한글이 있으면 확장용 글꼴 서브셋 검사가 깨진다.
    func testSourceHasNoHangul() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent("Shared/Design/SceneView.swift"), encoding: .utf8)
        let hangul = text.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
        XCTAssertTrue(hangul.isEmpty, "SceneView.swift 에 한글 \(hangul.count)자")
    }

    // MARK: 눈으로 보기 — TEST_RUNNER_SCENE_DUMP=<폴더> 로 돌리면 장면별 PNG 를 뜬다

    func testDumpScenesWhenAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCENE_DUMP"] else { throw XCTSkip("SCENE_DUMP 미지정") }
        Face.ensureRegistered()
        let words = Self.words
        for style in SceneStyle.allCases {
            for (index, phase) in [SceneArt.stillPhase, SceneArt.stillPhase + 0.6].enumerated() {
                let sheet = VStack(alignment: .leading, spacing: 14) {
                    ForEach(SceneKind.allCases, id: \.self) { kind in
                        HStack(alignment: .top, spacing: 14) {
                            self.widget(kind, style, words[kind] ?? "", phase)
                            self.card(kind, style, words[kind] ?? "", phase)
                        }
                    }
                }
                .padding(20)
                .background(Tone.base)
                let r = ImageRenderer(content: sheet)
                r.scale = 2
                try XCTUnwrap(r.uiImage?.pngData())
                    .write(to: URL(fileURLWithPath: dir).appendingPathComponent("scene-\(style.rawValue)-\(index).png"))
            }
        }
        let hero = VStack(spacing: 14) {
            ForEach([SceneKind.rain, .moon, .dusk, .sun, .dawn, .stars], id: \.self) { kind in
                self.hero(kind, words[kind] ?? "", scene: true)
            }
        }
        .padding(20).background(Tone.base)
        let r = ImageRenderer(content: hero)
        r.scale = 2
        try XCTUnwrap(r.uiImage?.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent("scene-hero.png"))
    }

    private static let words: [SceneKind: String] = [
        .sun: "아침나절", .dawn: "첫새벽", .dusk: "해거름", .stars: "별밤", .moon: "보름달", .rain: "는개", .drizzle: "이슬비",
        .snow: "함박눈", .fog: "안개", .wind: "건들바람", .petals: "꽃비", .leaves: "가랑잎", .frost: "무서리"]

    @ViewBuilder private func backdrop(_ kind: SceneKind, _ style: SceneStyle, _ phase: Double, _ scene: Bool) -> some View {
        if scene { SceneView(kind, style: style, phase: phase) } else { Color.black }
    }

    private func hero(_ kind: SceneKind, _ word: String, scene: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            backdrop(kind, .wash, SceneArt.stillPhase, scene)
            VStack(alignment: .leading) {
                Text("오늘 오후 2:10 · 비").font(Face.caption).foregroundStyle(Tone.secondary)
                Spacer()
                Text(word).font(.custom(Face.serifName, size: 48)).foregroundStyle(Tone.primary)
                Text("안개보다 굵고 이슬비보다 가는 비").font(Face.caption).foregroundStyle(Tone.secondary)
            }
            .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
        }
        .frame(width: 354, height: 232)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func widget(_ kind: SceneKind, _ style: SceneStyle, _ word: String, _ phase: Double,
                        scene: Bool = true, side: CGFloat = 158) -> some View {
        ZStack(alignment: .bottomLeading) {
            backdrop(kind, style, phase, scene)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.rawValue).font(Face.time).foregroundStyle(Tone.secondary)
                Spacer()
                Text(word).font(.custom(Face.serifName, size: 28)).foregroundStyle(Tone.primary)
                Text("밖에 '\(word)'").font(Face.time).foregroundStyle(Tone.secondary)
            }
            .padding(14)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func card(_ kind: SceneKind, _ style: SceneStyle, _ word: String, _ phase: Double, scene: Bool = true) -> some View {
        ZStack {
            backdrop(kind, style, phase, scene)
            VStack {
                HStack(alignment: .top) {
                    Text(word).font(.custom(Face.serifName, size: 28)).foregroundStyle(Tone.primary)
                    Spacer()
                    Text("두 번").font(Face.time).foregroundStyle(Tone.secondary)
                }
                Spacer()
                HStack {
                    Text("10월 7일 밤").font(Face.time).foregroundStyle(Tone.secondary)
                    Spacer()
                    Text(kind.rawValue).font(Face.time).foregroundStyle(Tone.secondary)
                }
            }
            .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
        }
        .frame(width: 354, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: pixels

    private struct Pixels {
        let w: Int, h: Int, scale: Double
        let bytes: [UInt8]
        func at(_ x: Int, _ y: Int, _ c: Int) -> Int { Int(bytes[(y * w + x) * 4 + c]) }
        func max(_ x: Int, _ y: Int) -> Int { Swift.max(at(x, y, 0), at(x, y, 1), at(x, y, 2)) }
        func diff(_ o: Pixels, _ x: Int, _ y: Int) -> Int { (0..<3).map { abs(at(x, y, $0) - o.at(x, y, $0)) }.max() ?? 0 }
        func rgb(_ x: Int, _ y: Int) -> SceneRGB { SceneRGB(Double(at(x, y, 0)) / 255, Double(at(x, y, 1)) / 255, Double(at(x, y, 2)) / 255) }
    }

    private func canvas(_ kind: SceneKind, _ style: SceneStyle, _ t: Double, marks: Bool) -> some View {
        Canvas(opaque: true) { ctx, size in SceneArt.draw(kind, style, t: t, marks: marks, in: &ctx, size: size) }
    }

    private func pixels(_ view: some View, _ size: CGSize, scale: Double = 2) throws -> Pixels {
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        r.scale = scale
        let cg = try XCTUnwrap(r.cgImage)
        let (w, h) = (cg.width, cg.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try XCTUnwrap(CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Pixels(w: w, h: h, scale: scale, bytes: bytes)
    }
}
