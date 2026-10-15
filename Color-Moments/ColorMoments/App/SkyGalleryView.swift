#if DEBUG
import SwiftUI
import UIKit

/// 디버그 전용 — 새 하늘(SkyView)을 지금 장면(SceneView)과 나란히. 실행 인자 `-skyGallery` 로 바로 열린다.
struct SkyGalleryView: View {
    static var launchRequested: Bool { ProcessInfo.processInfo.arguments.contains("-skyGallery") }
    static var dumpRequested: Bool { ProcessInfo.processInfo.arguments.contains("-skyDump") }

    @State private var scene: SkyScene = .nightCloudy
    @State private var animating = true
    @State private var showsOld = true
    @State private var fullScreen = false
    @State private var dumpStatus: String?
    @AppStorage(FrameMeterBadge.homeKey) private var meter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("장면", selection: $scene) {
                    ForEach(SkyScene.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Toggle("움직임", isOn: $animating)
                    Toggle("지금 장면도", isOn: $showsOld)
                }
                .font(Face.caption)
                Toggle("프레임 계측", isOn: $meter).font(Face.caption)
                Button("전체 화면 하늘") { fullScreen = true }
                    .font(Face.guide)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.white.opacity(0.08), in: Capsule())
                if let dumpStatus { Text(dumpStatus).font(.caption2.monospaced()).foregroundStyle(Tone.secondary) }

                label("오늘의 한 장 — 새 하늘(hero 60fps)")
                SkyCard(scene: scene, size: .hero, new: true, animating: animating)
                if showsOld {
                    label("지금 장면")
                    SkyCard(scene: scene, size: .hero, new: false, animating: animating)
                }
                label("목록 카드 — 새 하늘(card 30fps)")
                ForEach(0..<3, id: \.self) { _ in SkyCard(scene: scene, size: .row, new: true, animating: animating) }
                if showsOld {
                    label("지금 장면")
                    SkyCard(scene: scene, size: .row, new: false, animating: animating)
                }
            }
            .padding(20)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) { if meter { FrameMeterBadge().padding(.bottom, 4) } }
        .fullScreenCover(isPresented: $fullScreen) { SkyFullScreen(start: scene) }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-skyFull") { fullScreen = true }
            guard Self.dumpRequested else { return }
            dumpStatus = "그리는 중…"
            dumpStatus = await SkyDump.run()
        }
    }

    private func label(_ s: String) -> some View {
        Text(s).font(Face.caption).foregroundStyle(Tone.secondary)
    }
}

/// 「말」 칸 카드와 같은 글자 배치를 장면 위에 얹는다.
struct SkyCard: View {
    enum Size { case hero, row }
    let scene: SkyScene
    let size: Size
    let new: Bool
    var animating = false
    var image: CGImage?

    static let width: CGFloat = 354
    var cardSize: CGSize { CGSize(width: Self.width, height: size == .hero ? 232 : 96) }

    var body: some View {
        let s = cardSize
        ZStack(alignment: .topLeading) {
            backdrop
            SkyCardText(scene: scene, size: size, w: s.width, h: s.height)
        }
        .frame(width: s.width, height: s.height)
        .clipShape(RoundedRectangle(cornerRadius: size == .hero ? 26 : 22, style: .continuous))
    }

    @ViewBuilder private var backdrop: some View {
        if let image {
            Image(decorative: image, scale: 3).resizable()
        } else if new {
            SkyView(scene, quality: size == .hero ? .hero : .card, animating: animating, tilts: size == .hero)
        } else {
            SceneView(scene.legacy, style: .wash, animating: animating,
                      frameInterval: size == .hero ? SceneView.heroFrameInterval : SceneView.cardFrameInterval)
        }
    }
}

struct SkyCardText: View {
    let scene: SkyScene
    let size: SkyCard.Size
    let w: CGFloat
    let h: CGFloat

    static func sample(_ s: SkyScene) -> (word: String, meaning: String) {
        switch s {
        case .nightCloudy: ("달무리", "달 둘레에 둥그렇게 생기는 구름 같은 테")
        case .clearDay: ("햇귀", "해가 처음 솟을 때의 빛, 사방으로 퍼진 햇살")
        case .rain: ("작달비", "굵고 세차게 퍼붓는 비")
        }
    }

    var body: some View {
        let (word, meaning) = Self.sample(scene)
        if size == .hero {
            ZStack(alignment: .topLeading) {
                Text("오늘의 말").font(Face.caption).foregroundStyle(Tone.secondary)
                    .padding(.leading, 20).padding(.top, 18)
                VStack(alignment: .leading, spacing: 4) {
                    Spacer(minLength: 0)
                    Text(word).font(Face.wordHero).foregroundStyle(Tone.primary).lineLimit(1).minimumScaleFactor(0.5)
                    Text(meaning).font(Face.wordMeaning).foregroundStyle(Tone.secondary).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 0.64 * w - 20, height: 0.43 * h, alignment: .bottomLeading)
                .padding(.leading, 20)
                .offset(y: 0.5 * h)
            }
            .frame(width: w, height: h, alignment: .topLeading)
        } else {
            ZStack(alignment: .topLeading) {
                Text(word).font(Face.wordCard).foregroundStyle(Tone.primary).lineLimit(1)
                    .frame(width: 0.44 * w - 18, height: 0.6 * h - 12, alignment: .topLeading)
                    .padding(.leading, 18).padding(.top, 12)
                Text("10월 15일").font(Face.caption).foregroundStyle(Tone.secondary)
                    .frame(width: 0.36 * w - 18, height: 0.32 * h, alignment: .bottomLeading)
                    .padding(.leading, 18).offset(y: 0.6 * h)
                Text("3번").font(Face.caption).foregroundStyle(Tone.secondary)
                    .frame(width: 0.22 * w - 16, height: 0.42 * h - 12, alignment: .topTrailing)
                    .padding(.top, 12).offset(x: 0.78 * w)
                Text(scene.name).font(Face.caption).foregroundStyle(Tone.secondary)
                    .frame(width: 0.22 * w - 16, height: 0.32 * h, alignment: .bottomTrailing)
                    .offset(x: 0.78 * w, y: 0.6 * h)
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }
}

/// Apple 날씨 첫 화면처럼 — 하늘이 화면 전체, 가운데 위에 글자.
struct SkyFullScreen: View {
    let start: SkyScene
    @State private var page: SkyScene
    @Environment(\.dismiss) private var dismiss

    init(start: SkyScene) {
        self.start = start
        _page = State(initialValue: start)
    }

    var body: some View {
        GeometryReader { geo in
            TabView(selection: $page) {
                ForEach(SkyScene.allCases) { s in
                    SkyFullPage(scene: s, size: geo.size, animating: page == s).ignoresSafeArea().tag(s)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Tone.primary)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, 12)
        }
    }
}

struct SkyFullPage: View {
    let scene: SkyScene
    let size: CGSize
    var animating = true
    var image: CGImage?

    static func textRects(in size: CGSize) -> [CGRect] {
        [CGRect(x: 0.17 * size.width, y: 0.135 * size.height, width: 0.66 * size.width, height: 0.25 * size.height)]
    }

    var body: some View {
        let (word, meaning) = SkyCardText.sample(scene)
        ZStack(alignment: .top) {
            if let image {
                Image(decorative: image, scale: 3).resizable()
            } else {
                SkyView(scene, quality: .full, animating: animating, textRects: Self.textRects(in: size), tilts: true)
            }
            VStack(spacing: 6) {
                Text("오늘의 말").font(Face.caption).foregroundStyle(Tone.secondary)
                Text(word).font(.custom(Face.serifName, size: 72)).foregroundStyle(Tone.primary)
                Text(meaning).font(Face.wordMeaning).foregroundStyle(Tone.secondary)
                Text(scene.name).font(Face.caption).foregroundStyle(Tone.primary).padding(.top, 4)
            }
            .padding(.top, 0.15 * size.height)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// 실행 인자 `-skyDump` — 장면 × 크기 × 몇 프레임을 PNG 로 굽고 GPU 시간을 잰다. Documents/sky/ 에 남는다.
@MainActor
enum SkyDump {
    static func run() async -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sky")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var log: [String] = SkyGPU.shared?.noiseQuantiles().map { "noise " + $0.map { String(format: "%.2f", $0) }.joined(separator: " ") } ?? []
        let full = CGSize(width: 393, height: 852)
        let times: [Double] = [SceneArt.stillPhase, SceneArt.stillPhase + 3, SceneArt.stillPhase + 30]
        for s in SkyScene.allCases {
            for (ti, t) in times.enumerated() {
                let hero = SkyFrame(scene: s, quality: .hero, size: CGSize(width: 354, height: 232))
                let row = SkyFrame(scene: s, quality: .card, size: CGSize(width: 354, height: 96))
                let fullF = SkyFrame(scene: s, quality: .full, size: full, textRects: SkyFullPage.textRects(in: full))
                let rep = ti == 0 ? 8 : 1
                guard let h = SkySnapshot.image(hero, scale: 3, t: t, repeats: rep),
                      let r = SkySnapshot.image(row, scale: 3, t: t, repeats: rep),
                      let f = SkySnapshot.image(fullF, scale: 3, t: t, repeats: rep) else { return "그리기 실패" }
                if ti == 0 {
                    log.append(String(format: "%@ gpu ms hero %.2f card %.2f full %.2f", s.name, h.1, r.1, f.1))
                    log.append(String(format: "%@ 대비 hero %.2f card %.2f full %.2f", s.name,
                                      contrast(h.0, hero.textRects, hero.size), contrast(r.0, row.textRects, row.size),
                                      contrast(f.0, fullF.textRects, fullF.size)))
                }
                let tag = "\(s.rawValue)-t\(ti)"
                save(compare(s, hero: h.0, row: r.0), dir.appendingPathComponent("compare-\(tag).png"))
                save(render(SkyFullPage(scene: s, size: full, image: f.0)), dir.appendingPathComponent("full-\(tag).png"))
                if ti == 0, s == .nightCloudy, let refPath = UserDefaults.standard.string(forKey: "skyRef"),
                   let ref = UIImage(contentsOfFile: refPath) {
                    save(render(HStack(spacing: 12) {
                        Image(uiImage: ref).resizable().scaledToFill().frame(width: full.width, height: full.height).clipped()
                        SkyFullPage(scene: s, size: full, image: f.0)
                    }.padding(12).background(Color.black)), dir.appendingPathComponent("ref-vs-new.png"))
                }
                if ti == 0 {
                    save(render(Image(decorative: h.0, scale: 3)), dir.appendingPathComponent("raw-hero-\(s.rawValue).png"))
                    save(render(Image(decorative: f.0, scale: 3)), dir.appendingPathComponent("raw-full-\(s.rawValue).png"))
                }
            }
        }
        let text = log.joined(separator: "\n")
        try? text.write(to: dir.appendingPathComponent("log.txt"), atomically: true, encoding: .utf8)
        NSLog("SKYDUMP done %@", dir.path)
        return text
    }

    private static func compare(_ s: SkyScene, hero: CGImage, row: CGImage) -> UIImage? {
        render(HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 12) {
                Text("새 하늘 SkyView").font(.system(size: 13)).foregroundStyle(.white)
                SkyCard(scene: s, size: .hero, new: true, image: hero)
                SkyCard(scene: s, size: .row, new: true, image: row)
            }
            VStack(spacing: 12) {
                Text("지금 SceneView").font(.system(size: 13)).foregroundStyle(.white)
                SkyCard(scene: s, size: .hero, new: false)
                SkyCard(scene: s, size: .row, new: false)
            }
        }
        .padding(16)
        .background(Color.black))
    }

    private static func render(_ v: some View) -> UIImage? {
        let r = ImageRenderer(content: v.environment(\.colorScheme, .dark))
        r.scale = 3
        return r.uiImage
    }

    private static func save(_ img: UIImage?, _ url: URL) {
        if let data = img?.pngData() { try? data.write(to: url) }
    }

    /// 글자 자리 안 가장 밝은 픽셀 위에서 흰 64% 글자의 대비.
    static func contrast(_ img: CGImage, _ rects: [CGRect], _ size: CGSize) -> Double {
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let sx = Double(w) / size.width, sy = Double(h) / size.height
        var worst = Double.infinity
        for r in rects {
            let x0 = max(0, Int(r.minX * sx)), x1 = min(w, Int(r.maxX * sx))
            let y0 = max(0, Int(r.minY * sy)), y1 = min(h, Int(r.maxY * sy))
            guard x1 > x0, y1 > y0 else { continue }
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let i = (y * w + x) * 4
                    let bg = SceneRGB(Double(px[i]) / 255, Double(px[i + 1]) / 255, Double(px[i + 2]) / 255)
                    let fg = SceneRGB.white.over(bg, alpha: Tone.secondaryAlpha)
                    worst = min(worst, SceneRGB.contrast(fg, bg))
                }
            }
        }
        return worst
    }
}
#endif
