import SwiftUI

/// 디자인 토큰. **수치의 단일 출처는 `DESIGN.md` 다.**
///
/// 여기에 모아두는 이유(`DESIGN.md` §0): 「손대도 되는 것」에 있는 값은 사람이 한 곳에서
/// 조정할 수 있어야 한다. 화면에 하드코딩하지 않는다.
public enum Tone {

    // MARK: 배경 — §1.6 «다크 처리를 한 값으로»

    /// 홈 · 하루 상세 · 첫날. `#06070A`
    public static let base = Color(red: 0x06 / 255, green: 0x07 / 255, blue: 0x0A / 255)
    /// 증정 · 색 고르기 · 촬영 · 뷰어. 사진과 빛이 주인공인 화면은 완전한 검정.
    public static let pure = Color.black

    // MARK: 전경 — §2.1 «네 단계»
    //
    // **단계를 늘리지 말 것.** 흰색 불투명도가 0.22/0.32/0.35/0.40/0.45/0.55/0.62/0.85 로
    // 즉흥적으로 늘어난 게 원래 문제였다. 값은 바꿔도 되지만 단계는 넷이다.

    /// 이름, 본문. 92%
    public static let primary = Color.white.opacity(0.92)
    /// 한 줄 말, 설명. 64%
    public static let secondary = Color.white.opacity(0.64)
    /// 날짜, 안내, 캡션. 48%
    ///
    /// **40% 에서 올린 값이고 내리면 안 된다.** `base` 위에서 48% 는 4.97:1 로 WCAG AA 를
    /// 통과하고 40% 는 3.73:1 로 미달이다(실측). 11pt 캡션에 쓰이므로 대비 하한 4.5:1 을 지킨다.
    public static let tertiary = Color.white.opacity(0.48)
    /// 선·테두리 전용. 24%. **텍스트에 쓰지 말 것** — 2.03:1 이라 읽히지 않는다.
    public static let hairline = Color.white.opacity(0.24)

    // MARK: 강조

    /// 촬영 배율 활성. 앱에서 유일하게 채도 있는 색이다.
    /// **브랜드 색으로 올릴지는 미정**(`DESIGN.md` §6-2) — 올리면 아이콘·워드마크에 영향이 간다.
    public static let amber = Color(red: 1, green: 0xD6 / 255, blue: 0x40 / 255)
}

/// 폰트 파일이 어느 번들에 들어 있는지 알아내기 위한 표식. `Shared` 는 앱·확장 모두에 컴파일된다.
final class SharedBundleMarker {}

/// §2.2 타이포. **명조는 조약돌 이름과 워드마크에만.** 날짜·안내·버튼은 전부 SF.
public enum Face {
    /// 번들된 서브셋(37자). 이름이 바뀌면 글리프가 빠져 SF 로 떨어진다 — `FontSubsetTests` 가 잡는다.
    public static let serifName = "NanumMyeongjo"
    static let serifFile = "NanumMyeongjo-Subset"

    /// **Info.plist 의 `UIAppFonts` 대신 런타임에 등록한다.**
    ///
    /// 두 가지 이유다. (1) 폰트가 `Shared` 에 있어 앱·촬영 확장·컨트롤 확장 세 번들에 모두 들어가는데,
    /// plist 로 하면 타깃마다 따로 써야 한다. (2) `INFOPLIST_KEY_UIAppFonts` 는 **배열 키라
    /// 그 방식으로는 아예 안 들어간다**(실측 — 빌드는 되고 plist 에만 조용히 빠진다).
    @discardableResult
    public static func ensureRegistered() -> Bool { registered }

    private static let registered: Bool = {
        let bundle = Bundle(for: SharedBundleMarker.self)
        guard let url = bundle.url(forResource: serifFile, withExtension: "ttf") else { return false }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        // 이미 등록돼 있으면 실패로 오는데 그건 문제가 아니다.
        if !ok, let code = error?.takeRetainedValue(),
           CFErrorGetCode(code) == CTFontManagerError.alreadyRegistered.rawValue { return true }
        return ok
    }()

    private static func serif(_ size: CGFloat) -> Font {
        ensureRegistered()
        return .custom(serifName, size: size)
    }

    public static let wordmark = serif(30)        // 「몽돌」
    public static let nameCeremony = serif(32)    // 증정
    public static let nameDay = serif(27)         // 하루 상세
    public static let nameHome = serif(23)        // 홈

    public static let lineCeremony = Font.system(size: 16)   // 한 줄 말 — 증정
    public static let line = Font.system(size: 13)           // 한 줄 말 — 그 외
    public static let today = Font.system(size: 13)          // 오늘 줄
    public static let caption = Font.system(size: 11, design: .rounded)  // 날짜·시각·개수
    public static let guide = Font.system(size: 12)          // 안내
    public static let hex = Font.system(size: 16, design: .monospaced)
}

/// §2.3 형태.
public enum Shape2 {
    public static let cardFront: CGFloat = 14
    public static let cardMid: CGFloat = 13
    public static let cardBack: CGFloat = 12
    public static let photoWindow: CGFloat = 18   // 색 고르기 · 뷰어
    public static let cameraWindow: CGFloat = 22
    public static let pill: CGFloat = 100
    public static let swatchCandidate: CGFloat = 9
    public static let swatchCurrent: CGFloat = 11

    /// 조약돌 폭 : 높이. §2.3 — 0.70 으로 고정(기존 0.58~0.76 랜덤에서 바뀜).
    public static let pebbleRatio: CGFloat = 0.70

    /// 터치 하한. §4 «손대면 안 되는 것».
    public static let minTouch: CGFloat = 44
}
