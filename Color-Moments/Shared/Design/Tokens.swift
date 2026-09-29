import SwiftUI

public enum Tone {

    public static let base = Color(red: 0x06 / 255, green: 0x07 / 255, blue: 0x0A / 255)

    public static let pure = Color.black

    public static let primaryAlpha = 0.92
    public static let primary = Color.white.opacity(primaryAlpha)

    public static let secondaryAlpha = 0.64
    public static let secondary = Color.white.opacity(secondaryAlpha)

    public static let tertiary = Color.white.opacity(0.48)

    public static let hairline = Color.white.opacity(0.24)

    /// 색을 아직 보여 주면 안 되는 자리(닫히기 전 하루의 사진 로딩 자리·점).
    public static let veil = Color(white: 0.16)

    public static let amber = Color(red: 1, green: 0xD6 / 255, blue: 0x40 / 255)

    /// 온보딩 배경 — 받은 조약돌이 없을 때의 따뜻한 중간 톤(어둡게 눌러 쓴다).
    public static let backdropWarm = ["#B98A6A", "#8E6E86", "#C9A27A", "#6F7F8E"]

    /// 아침 소식 장면의 하늘 — 새벽(위·아래)에서 아침(위·아래)으로 천천히.
    public static let skyDawn = ["#1E1A33", "#4A3446"]
    public static let skyMorning = ["#233A52", "#5C6B78"]

    // 밝은 화면(온보딩 「준비됐어요」) 위 글자·버튼 — 파스텔 배경 대비 4.5:1 이상.
    public static let inkPrimaryHex = "#1E1B18"
    public static let inkPrimary = Color(hex: inkPrimaryHex)
    public static let inkSecondaryHex = "#3E3832"
    public static let inkSecondary = Color(hex: inkSecondaryHex)
    public static let inkHairline = Color(hex: inkPrimaryHex).opacity(0.24)
    public static let paperHex = "#F7F2EA"
    public static let paper = Color(hex: paperHex)
}

final class SharedBundleMarker {}

public enum Face {

    public static let serifName = "NanumMyeongjo"
    static let serifFile = "NanumMyeongjo-Subset"

    /// 본문 고운돋움 — 앱엔 한글 11,172자 전체, 확장엔 쓰는 글자만 구운 작은 판(이름은 같다).
    public static let sansName = "GowunDodum-Regular"
    static let sansFiles = ["GowunDodum-Hangul", "GowunDodum-Mini"]

    /// 버튼 전용 세미볼드 — 고운돋움은 Regular 하나뿐이라 버튼 문구만 담은 서브셋을 따로 쓴다.
    public static let actionBoldName = "IBMPlexSansKR-SemiBold"
    static let actionBoldFile = "IBMPlexSansKR-SemiBold-Subset"

    @discardableResult
    public static func ensureRegistered() -> Bool { serifRegistered && sansRegistered && actionBoldRegistered }

    private static let serifRegistered = register([serifFile])
    private static let sansRegistered = register(sansFiles)
    private static let actionBoldRegistered = register([actionBoldFile])

    private static func register(_ files: [String]) -> Bool {
        let bundle = Bundle(for: SharedBundleMarker.self)
        guard let url = files.lazy.compactMap({ bundle.url(forResource: $0, withExtension: "ttf") }).first
        else { return false }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

        if !ok, let code = error?.takeRetainedValue(),
           CFErrorGetCode(code) == CTFontManagerError.alreadyRegistered.rawValue { return true }
        return ok
    }

    private static func serif(_ size: CGFloat) -> Font {
        ensureRegistered()
        return .custom(serifName, size: size)
    }

    // 굵기가 하나뿐이다 — .bold() 를 걸면 가짜 굵기가 된다. 강조는 크기로.
    // 고운돋움은 같은 pt 에서 SF 보다 작아 보인다 — 크기는 SF 시절보다 약 2pt 크게 잡았다(2026-09-28 Tabber).
    private static func sans(_ size: CGFloat) -> Font {
        ensureRegistered()
        return .custom(sansName, size: size)
    }

    private static func actionBold(_ size: CGFloat) -> Font {
        ensureRegistered()
        return .custom(actionBoldName, size: size)
    }

    public static let wordmark = serif(30)
    public static let nameCeremony = serif(32)
    public static let nameDay = serif(27)
    public static let nameHome = serif(23)
    public static let nameCompact = serif(17)
    public static let word = serif(30)

    public static let wordMeaning = sans(13)
    public static let wordMeta = sans(12)

    public static let lineCeremony = sans(17.5)
    public static let line = sans(15)
    public static let today = sans(15)
    public static let caption = sans(13)
    public static let time = sans(12)
    public static let action = actionBold(17)
    /// 온보딩 주 버튼 — 헤더와 같이 쓰던 lineCeremony(17.5) 대신, 버튼만 굵게.
    public static let actionCeremony = actionBold(17)
    /// 온보딩 보조 버튼 — line(15) 자리를 대신한다.
    public static let actionSecondary = actionBold(15)
    public static let noticeApp = sans(15)
    public static let guide = sans(14)
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
    /// 셰이더 조약돌 지름 = PebbleView 높이 × 이 값 — 예전 둥근 사각형과 눈에 보이는 덩어리가 비슷하게.
    public static let softDiameter: CGFloat = 0.70

    public static let minTouch: CGFloat = 44
}
