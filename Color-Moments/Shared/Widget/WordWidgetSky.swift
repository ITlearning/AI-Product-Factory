import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// 홈 위젯 물빛 배경의 하늘 정지 그림 — 위젯 확장은 Metal 을 돌리지 않는다. 앱이 App Group 에 구워 두고 위젯은 읽기만.
/// 하늘 장면마다 크기별 한 장(JPEG). 파일 이름에 장면·크기·하늘 판 번호.
public enum WordWidgetSky {
    public enum Size: String, CaseIterable, Sendable {
        /// 홈 작은 위젯 — 가장 큰 기기(170pt)에 맞춰 굽고 작은 기기는 줄여 깐다.
        case small

        public var points: CGSize {
            switch self {
            case .small: CGSize(width: 170, height: 170)
            }
        }
    }

    static let folder = "WidgetSky"
    static let quality = 0.85

    public static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appendingPathComponent(folder, isDirectory: true)
    }

    public static func fileName(_ scene: SkyScene, size: Size = .small, edition: Int = SkyScene.edition) -> String {
        "sky-\(scene.key)-\(size.rawValue)-e\(edition).jpg"
    }

    /// 하늘이 있는 장면 전부(겹치는 건 한 번).
    public static var scenes: [SkyScene] {
        var out: [SkyScene] = []
        for k in SceneKind.allCases { if let s = SkyScene.of(k), !out.contains(s) { out.append(s) } }
        return out
    }

    /// 없거나, 달이 뜨는 밤 하늘인데 오늘 구운 게 아니면 다시 굽는다.
    public static func needsBake(_ scene: SkyScene, modified: Date?, now: Date) -> Bool {
        guard let modified else { return true }
        return scene.showsMoon && Moment.dayKey(for: modified) != Moment.dayKey(for: now)
    }

    /// 이번 판이 아닌 파일 — 지워서 App Group 을 작게.
    public static func stale(_ names: [String], edition: Int = SkyScene.edition) -> [String] {
        let keep = Set(scenes.flatMap { s in Size.allCases.map { fileName(s, size: $0, edition: edition) } })
        return names.filter { $0.hasPrefix("sky-") && !keep.contains($0) }
    }

    /// 위젯 — 구운 그림이 있으면 그것, 없으면 nil(부르는 쪽이 SceneView 로).
    public static func image(for kind: SceneKind, size: Size = .small, in dir: URL? = container) -> UIImage? {
        guard let scene = SkyScene.of(kind), let dir else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(fileName(scene, size: size)).path)
    }

    /// 앱 — 필요한 것만 굽는다. 하나라도 새로 구웠으면 true(위젯 다시 그리기).
    @discardableResult
    public static func bakeIfNeeded(in dir: URL? = container, now: Date = Date(), scale: CGFloat = 3,
                                    render: (SkyFrame, CGFloat) -> CGImage? = Self.snapshot) -> Bool {
        guard let dir else { return false }
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in stale((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []) {
            try? fm.removeItem(at: dir.appendingPathComponent(name))
        }
        var baked = false
        for scene in scenes {
            for size in Size.allCases {
                let url = dir.appendingPathComponent(fileName(scene, size: size))
                let modified = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
                guard needsBake(scene, modified: modified, now: now) else { continue }
                let frame = SkyFrame(scene: scene, quality: .hero, size: size.points,
                                     texts: SkyTexts.card(size.points), moonAge: Celestial.moonAge(at: now))
                guard let image = render(frame, scale), let data = jpeg(image) else { continue }
                if (try? data.write(to: url, options: .atomic)) != nil { baked = true }
            }
        }
        return baked
    }

    public static func snapshot(_ frame: SkyFrame, scale: CGFloat) -> CGImage? {
        SkySnapshot.image(frame, scale: scale, t: SceneArt.stillPhase)?.image
    }

    static func jpeg(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
