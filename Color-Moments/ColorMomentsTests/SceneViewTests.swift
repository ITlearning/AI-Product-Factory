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

    /// 5A — 해·달·노을·빛은 글자 없는 오른쪽에만.
    func testBrightMarksStayOutOfTextZone() {
        for size in sizes {
            let zone = SceneArt.textZone(in: size)
            for kind in SceneKind.allCases {
                for style in SceneStyle.allCases {
                    for box in SceneArt.brightBounds(kind, style, in: size) {
                        XCTAssertGreaterThanOrEqual(box.minX, zone.maxX - 0.01, "\(kind)/\(style) \(size) \(box)")
                    }
                }
            }
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
        let words: [SceneKind: String] = [.sun: "아침나절", .dawn: "첫새벽", .dusk: "해거름", .stars: "별밤", .moon: "보름달",
                                          .rain: "는개", .drizzle: "이슬비", .snow: "함박눈", .fog: "안개", .wind: "건들바람",
                                          .petals: "꽃비", .leaves: "가랑잎", .frost: "무서리"]
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
            ForEach([SceneKind.rain, .moon, .dusk, .sun], id: \.self) { kind in
                ZStack(alignment: .topLeading) {
                    SceneView(kind, phase: SceneArt.stillPhase)
                    VStack(alignment: .leading) {
                        Text("오늘 오후 2:10 · 비").font(Face.caption).foregroundStyle(Tone.secondary)
                        Spacer()
                        Text(words[kind] ?? "").font(.custom(Face.serifName, size: 48)).foregroundStyle(Tone.primary)
                        Text("안개보다 굵고 이슬비보다 가는 비").font(Face.caption).foregroundStyle(Tone.secondary)
                    }
                    .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
                }
                .frame(width: 354, height: 232)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
        .padding(20).background(Tone.base)
        let r = ImageRenderer(content: hero)
        r.scale = 2
        try XCTUnwrap(r.uiImage?.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent("scene-hero.png"))
    }

    private func widget(_ kind: SceneKind, _ style: SceneStyle, _ word: String, _ phase: Double) -> some View {
        ZStack(alignment: .bottomLeading) {
            SceneView(kind, style: style, phase: phase)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.rawValue).font(Face.time).foregroundStyle(Tone.secondary)
                Spacer()
                Text(word).font(.custom(Face.serifName, size: 28)).foregroundStyle(Tone.primary)
                Text("밖에 '\(word)'").font(Face.time).foregroundStyle(Tone.secondary)
            }
            .padding(14)
        }
        .frame(width: 158, height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func card(_ kind: SceneKind, _ style: SceneStyle, _ word: String, _ phase: Double) -> some View {
        ZStack {
            SceneView(kind, style: style, phase: phase)
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
}
