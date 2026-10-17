import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// 위젯 「주웠어요」 옆 조약돌 — 위젯 확장은 셰이더 조약돌을 믿고 돌릴 수 없어, 앱이 진짜 조약돌(SoftPebbleView)을 작은 PNG 로
/// 구워 App Group 에 둔다. 장면마다 한 장(그 장면 색), 오늘 찍은 색이 있으면 오늘 한 장(그날 조약돌 색·모양). 위젯은 오늘 것을 먼저.
public enum WordWidgetPebble {
    /// 조약돌 그림이 바뀌면 올린다.
    public static let edition = 1
    static let folder = "WidgetPebble"
    /// 돌 지름(pt) — 위젯은 이보다 작게 줄여 쓴다.
    public static let stoneHeight: CGFloat = 20
    /// 접지 그림자만 — 후광은 투명 위에 더하는 빛이라 PNG 알파에 남지 않는다.
    static let glow: SoftPebbleView.Glow = .bare
    /// 그림 한 변(pt) — 돌 둘레로 그림자 자리가 있다.
    public static var canvas: CGFloat { stoneHeight * glow.canvas }

    public static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appendingPathComponent(folder, isDirectory: true)
    }

    static func sceneFile(_ kind: SceneKind, edition: Int = edition) -> String { "pebble-scene-\(kind.rawValue)-e\(edition).png" }

    static func dayPrefix(_ dayKey: String) -> String { "pebble-day-\(dayKey)-" }

    static func dayFile(_ dayKey: String, stops: [Float], edition: Int = edition) -> String {
        dayPrefix(dayKey) + digest(stops) + "-e\(edition).png"
    }

    /// 정지점이 바뀌면(그날 사진을 더 찍으면) 이름이 바뀐다.
    static func digest(_ stops: [Float]) -> String {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for v in stops {
            h ^= UInt64(bitPattern: Int64((v * 1000).rounded()))
            h = h &* 0x0000_0100_0000_01B3
        }
        return String(h & 0xFFFF_FFFF, radix: 16)
    }

    /// 장면 색 — 인쇄 모양의 강조색이 있으면 그것, 없으면 장면 하늘의 밝은 쪽 색. 위가 밝고 아래가 짙게 세 칸.
    public static func sceneStops(_ kind: SceneKind) -> [Float] {
        let base = SceneRGB(hex: SceneArt.accentHex(kind) ?? quietHex(kind))
        func mix(_ c: SceneRGB, _ to: SceneRGB, _ k: Double) -> SceneRGB {
            SceneRGB(c.r + (to.r - c.r) * k, c.g + (to.g - c.g) * k, c.b + (to.b - c.b) * k)
        }
        let light = mix(base, .white, 0.28), dark = mix(base, SceneRGB(0, 0, 0), 0.22)
        return [(0.0, light), (0.5, base), (1.0, dark)].flatMap { [Float($0.0), Float($0.1.r), Float($0.1.g), Float($0.1.b)] }
    }

    static func quietHex(_ kind: SceneKind) -> String {
        switch kind {
        case .moon: "#C3C8D8"
        case .rain: "#8DA2B0"
        case .drizzle: "#9AA9B2"
        case .snow: "#D3DAE4"
        case .fog: "#B6BEC4"
        case .wind: "#9CB4A6"
        case .frost: "#BAD0E0"
        default: "#B8B2A8"
        }
    }

    /// 장면 조약돌의 모양 — 장면마다 다르고 언제나 같다.
    static func sceneShape(_ kind: SceneKind) -> SoftPebbleShape { SoftPebbleShape(dayKey: "scene-\(kind.rawValue)") }

    /// 위젯 — 그날 조약돌이 있으면 그것, 없으면 주운 말 장면의 조약돌. 둘 다 없으면 nil(아무것도 안 그린다).
    public static func image(for model: WordWidgetModel, in dir: URL? = container) -> UIImage? {
        guard let dir else { return nil }
        let prefix = dayPrefix(Moment.dayKey(for: model.date)), suffix = "-e\(edition).png"
        if let name = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            .first(where: { $0.hasPrefix(prefix) && $0.hasSuffix(suffix) }),
           let img = UIImage(contentsOfFile: dir.appendingPathComponent(name).path) {
            return img
        }
        guard let kind = model.scene else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(sceneFile(kind)).path)
    }

    public struct Today: Equatable, Sendable {
        public let dayKey: String
        public let stops: [Float]

        public init(dayKey: String, stops: [Float]) {
            self.dayKey = dayKey
            self.stops = stops
        }
    }

    /// 남길 파일 밖은 지운다 — 다른 판, 지난날, 오늘의 옛 정지점. today 가 nil 이면 날 조약돌은 건드리지 않는다.
    static func stale(_ names: [String], today: Today?, edition: Int = edition) -> [String] {
        let scenes = Set(SceneKind.allCases.map { sceneFile($0, edition: edition) })
        return names.filter { name in
            guard name.hasPrefix("pebble-") else { return false }
            if name.hasPrefix("pebble-scene-") { return !scenes.contains(name) }
            guard let today else { return !name.hasSuffix("-e\(edition).png") }
            return today.stops.isEmpty || name != dayFile(today.dayKey, stops: today.stops, edition: edition)
        }
    }

    /// 앱 — 없는 것만 굽는다. 하나라도 새로 굽거나 지웠으면 true(위젯 다시 그리기).
    @MainActor @discardableResult
    static func bakeIfNeeded(today: Today?, in dir: URL? = container, scale: CGFloat = 3,
                                    render: (_ stops: [Float], _ shape: SoftPebbleShape, _ scale: CGFloat) -> CGImage? = Self.render) -> Bool {
        guard let dir else { return false }
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var changed = false
        for name in stale((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [], today: today) {
            if (try? fm.removeItem(at: dir.appendingPathComponent(name))) != nil { changed = true }
        }
        var jobs: [(String, [Float], SoftPebbleShape)] = SceneKind.allCases.map { (sceneFile($0), sceneStops($0), sceneShape($0)) }
        if let today, !today.stops.isEmpty {
            jobs.append((dayFile(today.dayKey, stops: today.stops), today.stops, SoftPebbleShape(dayKey: today.dayKey)))
        }
        for (name, stops, shape) in jobs {
            let url = dir.appendingPathComponent(name)
            guard !fm.fileExists(atPath: url.path) else { continue }
            guard let image = render(stops, shape, scale), let data = png(image) else { continue }
            if (try? data.write(to: url, options: .atomic)) != nil { changed = true }
        }
        return changed
    }

    @MainActor
    static func render(_ stops: [Float], _ shape: SoftPebbleShape, _ scale: CGFloat) -> CGImage? {
        let r = ImageRenderer(content: SoftPebbleView(stops: stops, height: stoneHeight, glow: glow, shape: shape)
            .frame(width: canvas, height: canvas)
            .environment(\.displayScale, scale))
        r.scale = scale
        r.isOpaque = false
        return r.cgImage
    }

    static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
