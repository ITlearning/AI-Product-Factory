import CoreText
import UIKit
import XCTest
@testable import ColorMoments

/// 번들된 명조 서브셋이 **실제로 필요한 글자를 다 갖고 있는가.**
///
/// 서브셋은 37자뿐이다(2,987KB → 13.2KB). 조약돌 이름이 하나라도 바뀌면 그 글자의 글리프가 없어
/// **그 이름만 조용히 SF 로 떨어진다.** 앱은 안 죽고 로그도 안 남는다 — 화면을 직접 봐야만 안다.
/// 이름은 색에서 결정되므로 특정 색 구간을 만들기 전엔 눈에 띄지도 않는다.
final class FontSubsetTests: XCTestCase {

    private func glyphExists(_ scalar: Unicode.Scalar, in font: CTFont) -> Bool {
        var chars = Array(String(scalar).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        let ok = CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
        return ok && glyphs.allSatisfy { $0 != 0 }
    }

    func testBundledSerifIsRegistered() {
        XCTAssertTrue(Face.ensureRegistered(), "번들에서 폰트 파일을 찾지 못했거나 등록에 실패했다")
        XCTAssertNotNil(UIFont(name: Face.serifName, size: 20),
                        "\(Face.serifName) 가 등록되지 않았다 — project.yml 의 UIAppFonts 또는 번들 리소스 확인")
    }

    /// 조약돌 이름 19개 + 워드마크의 모든 글자가 들어 있어야 한다.
    func testEverySerifGlyphIsPresent() throws {
        Face.ensureRegistered()
        let uiFont = try XCTUnwrap(UIFont(name: Face.serifName, size: 20))
        let font = uiFont as CTFont

        var needed = Set<Unicode.Scalar>("몽돌".unicodeScalars)
        // 이름 목록을 하드코딩하지 않는다 — 색 전 구간을 훑어 실제로 나올 수 있는 이름을 다 모은다.
        for r in stride(from: 0, through: 255, by: 17) {
            for g in stride(from: 0, through: 255, by: 17) {
                for b in stride(from: 0, through: 255, by: 17) {
                    let hex = String(format: "#%02X%02X%02X", r, g, b)
                    let m = Moment(capturedAt: Date(), colorHex: hex, fileName: "x.jpg", source: .app)
                    if let named = PebbleNaming.name(for: [m]) {
                        needed.formUnion(named.name.unicodeScalars)
                    }
                }
            }
        }

        let missing = needed.filter { !glyphExists($0, in: font) }.map(String.init).sorted()
        XCTAssertTrue(missing.isEmpty,
            "서브셋에 없는 글자 \(missing.count)개: \(missing.joined()) — Shared/Design/Fonts/README.md 대로 다시 구울 것")
        XCTAssertGreaterThan(needed.count, 20, "색 구간을 훑었는데 이름이 거의 안 나왔다 — 이 테스트가 헛돌고 있다")
    }

    /// 서브셋이 슬쩍 전체 폰트로 되돌아가지 않았는지. 2MB 짜리가 들어가면 바로 잡는다.
    func testSubsetStaysSmall() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "NanumMyeongjo-Subset", withExtension: "ttf")
            ?? Bundle.main.url(forResource: "NanumMyeongjo-Subset", withExtension: "ttf"),
            "번들에서 서브셋 파일을 못 찾았다")
        let bytes = try Data(contentsOf: url).count
        XCTAssertLessThan(bytes, 60_000,
            "폰트가 \(bytes / 1024)KB — 전체 한글이 들어간 것 같다. 서브셋으로 되돌릴 것")
    }
}
