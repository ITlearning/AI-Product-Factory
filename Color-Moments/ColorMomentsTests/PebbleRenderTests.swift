import SwiftUI
import XCTest
@testable import ColorMoments

@MainActor
final class PebbleRenderTests: XCTestCase {

    private func day(_ hexes: [String], daysAgo: Int) -> [Moment] {
        let base = Date().addingTimeInterval(Double(-86_400 * daysAgo))
        return hexes.enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 1800),
                   colorHex: $0.element, fileName: "p\(daysAgo)-\($0.offset).jpg", source: .app)
        }
    }

    func testSoftPebbleShaderCompiles() async throws {
        try await SoftPebbleView.compileShader()
    }

    func testGrainIsBakedOnceAndTiny() throws {
        let a = try XCTUnwrap(Grain.image, "그레인 텍스처 생성 실패 — 4번 겹이 통째로 빠진다")
        let b = try XCTUnwrap(Grain.image)
        XCTAssertTrue(a === b, "그레인이 매번 새로 만들어진다 — static let 캐시가 깨졌다")
        XCTAssertEqual(a.size, CGSize(width: Grain.tileSide, height: Grain.tileSide))
    }

    /// 점선 조약돌은 단위 윤곽을 한 번 구워 키운다 — rect 마다 윤곽을 다시 구하던 때와 같은 점이어야 한다.
    func testSoftPebbleOutlineMatchesPerRectOutline() {
        func points(_ p: Path) -> [CGPoint] {
            var out: [CGPoint] = []
            p.forEach { e in
                switch e {
                case .move(let to), .line(let to): out.append(to)
                default: break
                }
            }
            return out
        }
        let other = SoftPebbleShape(tilt: -0.3, egg: 0.15, wa: 0.1, wb: 0.8, wc: 0.2)
        let cases: [(SoftPebbleShape, CGRect)] = [
            (.placeholder, CGRect(x: 0, y: 0, width: 60, height: 70)),
            (.placeholder, CGRect(x: 12, y: -4, width: 97.5, height: 113)),
            (.placeholder, .zero),
            (other, CGRect(x: 5, y: 5, width: 40, height: 50)),
        ]
        for (shape, rect) in cases {
            let r = rect.height / 2
            let expected = shape.outline().map { CGPoint(x: rect.midX + $0.x * r, y: rect.midY + $0.y * r) }
            let got = points(SoftPebbleOutline(shape: shape).path(in: rect))
            XCTAssertEqual(got.count, expected.count)
            // Path 는 점을 Float 로 담는다 — 단위 윤곽을 키우면 1e-6pt 쯤 어긋난다(그림엔 안 보인다).
            let worst = zip(got, expected).map { max(abs($0.x - $1.x), abs($0.y - $1.y)) }.max() ?? 0
            XCTAssertLessThan(worst, 1e-4, "\(rect)")
        }
    }

    func testDumpPebblesWhenAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["PEBBLE_DUMP"] else {
            throw XCTSkip("PEBBLE_DUMP 미지정")
        }
        let cases: [(String, [Moment])] = [
            ("노을",   day(["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"], daysAgo: 1)),
            ("하늘빛", day(["#7FB0DC", "#8CB8DE", "#6795BC", "#3C6A9B"], daysAgo: 2)),
            ("풀빛",   day(["#5B7F5B", "#8FA36B", "#A79C87"], daysAgo: 3)),
            ("잿빛",   day(["#6B6261", "#887F7E", "#9D917C"], daysAgo: 4)),
            ("단색",   day(["#B12E12"], daysAgo: 5)),
        ]
        for (name, moments) in cases {
            for h in [84.0, 130.0, 180.0] as [CGFloat] {
                let r = ImageRenderer(content:
                    PebbleView(moments: moments, height: h)
                        .padding(26)
                        .background(Tone.base))
                r.scale = 3
                let png = try XCTUnwrap(r.uiImage?.pngData())
                try png.write(to: URL(fileURLWithPath: dir)
                    .appendingPathComponent("pebble-\(name)-\(Int(h)).png"))
            }
        }

        let r = ImageRenderer(content:
            PebbleView(moments: cases[0].1, height: 180, sheen: 0.5)
                .padding(26).background(Tone.base))
        r.scale = 3
        try XCTUnwrap(r.uiImage?.pngData())
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("pebble-sheen.png"))
    }
}

// MARK: - 셰이더 조약돌(SoftPebbleView) 렌더 덤프 — 레퍼런스(docs/designs/tools/soft-pebble-reference.py)와 대조용

extension PebbleRenderTests {
    func testDumpSoftPebblesWhenAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["PEBBLE_DUMP"] else {
            throw XCTSkip("PEBBLE_DUMP 미지정")
        }
        func even(_ hexes: [String]) -> [Float] {
            SoftPebbleView.floats(hexes.enumerated().map {
                DayGradient.Stop(location: Double($0.offset) / Double(hexes.count - 1), hex: $0.element)
            })
        }
        func shape(_ deg: Double, _ egg: Double, _ w: (Double, Double, Double)) -> SoftPebbleShape {
            SoftPebbleShape(tilt: deg * .pi / 180, egg: egg, wa: w.0, wb: w.1, wc: w.2)
        }
        func render<V: View>(_ v: V, _ name: String) throws {
            let r = ImageRenderer(content: v.environment(\.displayScale, 3))
            r.scale = 3
            try XCTUnwrap(r.uiImage?.pngData())
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
        }

        let icon = shape(32, 0.22, (0.3, 0.6, 0.4))
        try render(SoftPebbleView(stops: PebbleLabView.iconStops, height: 180, glow: .hero, shape: icon)
            .frame(width: 333, height: 333).background(Tone.base), "metal-icon.png")

        let days = [
            (even(["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"]), shape(-20, 0.15, (0.1, 0.8, 0.2))),
            (even(["#7FB0DC", "#8CB8DE", "#6795BC", "#3C6A9B"]), shape(10, 0.26, (0.7, 0.3, 0.9))),
            (even(["#5B7F5B", "#8FA36B", "#A79C87"]), shape(48, 0.20, (0.5, 0.6, 0.4))),
        ]
        try render(HStack(spacing: 0) {
            ForEach(0..<days.count, id: \.self) {
                SoftPebbleView(stops: days[$0].0, height: 180, glow: .hero, shape: days[$0].1)
                    .frame(width: 333, height: 333)
            }
        }.background(Tone.base), "metal-days.png")

        try render(VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<PebbleLabView.samples.count, id: \.self) {
                    LegacyPebbleView(moments: PebbleLabView.samples[$0], height: 70).frame(width: 84, height: 96)
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<PebbleLabView.samples.count, id: \.self) {
                    SoftPebbleView(moments: PebbleLabView.samples[$0], height: 62).frame(width: 84, height: 96)
                }
            }
        }.padding(20).background(Tone.base), "metal-grid.png")
    }
}

// MARK: - 조약돌이 들어가는 화면 부품 덤프 — 교체 전후 비교용

extension PebbleRenderTests {
    func testDumpPebbleSurfacesWhenAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["PEBBLE_DUMP"],
              let tag = ProcessInfo.processInfo.environment["PEBBLE_TAG"] else {
            throw XCTSkip("PEBBLE_DUMP/PEBBLE_TAG 미지정")
        }
        let days = PebbleLabView.samples
        func render<V: View>(_ v: V, _ name: String) throws {
            let r = ImageRenderer(content: v.environment(\.displayScale, 3))
            r.scale = 3
            try XCTUnwrap(r.uiImage?.pngData())
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(tag)-\(name).png"))
        }
        try render(VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<days.count, id: \.self) {
                CompactDayRow(pebbleMoments: days[$0], moments: days[$0])
            }
        }.padding(20).frame(width: 360).background(Tone.base), "compact")
        try render(PebbleCard(dayKey: days[0][0].dayKey, pebbleMoments: days[0])
            .frame(width: 360, height: 640), "card")
        try render(HandfulCard(month: "2026-09", pebbleGroups: days).frame(width: 360, height: 640), "handful")
        try render(HStack(spacing: 24) {
            DayBadgeView(moments: days[1], size: 150, showsCaption: false)
            DayBadgeView(moments: days[1], size: 150, showsCaption: false, sheen: 0.45)
        }.padding(30).background(Tone.base), "badge")
        try render(HStack(spacing: 20) {
            DashedPebble(height: 84)
            PebbleView(moments: days[2], height: 84)
        }.padding(30).background(Tone.base), "dashed")

        // 하루 상세 머리(DayMomentsView.header 와 같은 배치) — 두 모양 모두
        let sky = [
            Moment(capturedAt: Date(timeIntervalSince1970: 1_757_050_000), colorHex: "#2F3A22",
                   fileName: "h0.jpg", source: .app),
            Moment(capturedAt: Date(timeIntervalSince1970: 1_757_050_240), colorHex: "#5B7FD6",
                   fileName: "h1.jpg", source: .app),
        ]
        func header() -> some View {
            HStack(alignment: .center, spacing: 20) {
                PebbleView(moments: sky, height: 130)
                VStack(alignment: .leading, spacing: 8) {
                    Text("하늘빛").font(Face.nameDay).foregroundStyle(Tone.primary)
                    Text("올려다본 날이었네요.").font(Face.line).foregroundStyle(Tone.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.vertical, 40).frame(width: 402).background(Tone.base)
        }
        try render(SettingsSheet(preview: days[0]).frame(width: 402, height: 340), "settings")
        try render(ZStack {
            Tone.base
            ImportProgressNote(progress: .init(done: 3, total: 12))
        }.frame(width: 402, height: 300), "import-progress")
        try render(CloudScene(linked: true, receiving: false, remoteDays: 0)
            .frame(width: 402, height: 420).background(Tone.base), "cloud")
        try render(HStack(spacing: 40) {
            PebbleView(moments: days[0], height: 150)
            PebbleView(moments: days[0], height: 150, glow: .bare)
        }.padding(50).background(Tone.base), "intro-glow")
        try render(VStack(alignment: .leading, spacing: 20) {
            OnboardingText(title: "찍을 때는 색을 숨겨 두고, 하루가 닫히면 그날의 색으로 빚은 조약돌이 도착해요.")
            PebbleStyleChoice()
        }.padding(28).frame(width: 402).background(Tone.base), "onboarding")

        let saved = PebbleStyle.store.string(forKey: PebbleStyle.key)
        defer { PebbleStyle.store.set(saved, forKey: PebbleStyle.key) }
        for style in PebbleStyle.allCases {
            PebbleStyle.store.set(style.rawValue, forKey: PebbleStyle.key)
            try render(header(), "header-\(style.rawValue)")
        }
    }
}

// MARK: - 조약돌 모아 보기 시안 덤프

extension PebbleRenderTests {
    func testDumpPebbleCollectionWhenAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["PEBBLE_DUMP"] else {
            throw XCTSkip("PEBBLE_DUMP 미지정")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("collection-\(UUID()).json")
        let closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = DayStore(fileURL: url, closures: closures)
        let gifts = GiftLog(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let palettes = [
            ["#6A7EA0", "#9FBDDB", "#F4E6CF", "#F6C7A2", "#EC9383", "#B86676"],
            ["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"],
            ["#7FB0DC", "#8CB8DE", "#6795BC", "#3C6A9B"],
            ["#5B7F5B", "#8FA36B", "#A79C87"],
            ["#6B6261", "#887F7E", "#9D917C"],
            ["#E7B98A", "#9DB7CF", "#D98F7A"],
            ["#3A4A6B", "#58708F", "#C8B79A"],
            ["#B85C4A", "#D98F6A", "#F0C98A"],
        ]
        for d in 1...11 {
            let base = Date().addingTimeInterval(Double(-86_400 * (d * 3)))
            let hexes = palettes[d % palettes.count]
            let moments = hexes.enumerated().map {
                Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 1800),
                       colorHex: $0.element, fileName: "col\(d)-\($0.offset).jpg", source: .app)
            }
            _ = store.add(contentsOf: moments)
            gifts.markGifted(moments[0].dayKey)
        }
        let view = PebbleCollectionView(store: store, gifts: gifts, closures: closures)
        let r = ImageRenderer(content: view.grid(view.monthsForPreview, lazy: false)
            .frame(width: 402, alignment: .topLeading)
            .background(Tone.base)
            .environment(\.displayScale, 3))
        r.scale = 3
        try XCTUnwrap(r.uiImage?.pngData())
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("collection.png"))
    }
}
