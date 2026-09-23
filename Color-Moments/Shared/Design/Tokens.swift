import SwiftUI

public enum Tone {

    public static let base = Color(red: 0x06 / 255, green: 0x07 / 255, blue: 0x0A / 255)

    public static let pure = Color.black

    public static let primary = Color.white.opacity(0.92)

    public static let secondary = Color.white.opacity(0.64)

    public static let tertiary = Color.white.opacity(0.48)

    public static let hairline = Color.white.opacity(0.24)

    public static let amber = Color(red: 1, green: 0xD6 / 255, blue: 0x40 / 255)
}

final class SharedBundleMarker {}

public enum Face {

    public static let serifName = "NanumMyeongjo"
    static let serifFile = "NanumMyeongjo-Subset"

    @discardableResult
    public static func ensureRegistered() -> Bool { registered }

    private static let registered: Bool = {
        let bundle = Bundle(for: SharedBundleMarker.self)
        guard let url = bundle.url(forResource: serifFile, withExtension: "ttf") else { return false }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

        if !ok, let code = error?.takeRetainedValue(),
           CFErrorGetCode(code) == CTFontManagerError.alreadyRegistered.rawValue { return true }
        return ok
    }()

    private static func serif(_ size: CGFloat) -> Font {
        ensureRegistered()
        return .custom(serifName, size: size)
    }

    public static let wordmark = serif(30)
    public static let nameCeremony = serif(32)
    public static let nameDay = serif(27)
    public static let nameHome = serif(23)
    public static let word = serif(30)

    public static let lineCeremony = Font.system(size: 16)
    public static let line = Font.system(size: 13)
    public static let today = Font.system(size: 13)
    public static let caption = Font.system(size: 11, design: .rounded)
    public static let guide = Font.system(size: 12)
    public static let hex = Font.system(size: 16, design: .monospaced)
}

public enum Shape2 {
    public static let cardFront: CGFloat = 14
    public static let cardMid: CGFloat = 13
    public static let cardBack: CGFloat = 12
    public static let photoWindow: CGFloat = 18
    public static let cameraWindow: CGFloat = 22
    public static let pill: CGFloat = 100

    public static let pebbleRatio: CGFloat = 0.70

    public static let minTouch: CGFloat = 44
}
