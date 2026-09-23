import CoreText
import UIKit
import XCTest
@testable import ColorMoments

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

    func testEverySerifGlyphIsPresent() throws {
        Face.ensureRegistered()
        let uiFont = try XCTUnwrap(UIFont(name: Face.serifName, size: 20))
        let font = uiFont as CTFont

        var needed = Set<Unicode.Scalar>("몽돌".unicodeScalars)

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

        for w in BundledWordSource.load()?.words ?? [] { needed.formUnion(w.word.unicodeScalars) }

        let missing = needed.filter { !glyphExists($0, in: font) }.map(String.init).sorted()
        XCTAssertTrue(missing.isEmpty,
            "서브셋에 없는 글자 \(missing.count)개: \(missing.joined()) — Shared/Design/Fonts/README.md 대로 다시 구울 것")
        XCTAssertGreaterThan(needed.count, 20, "색 구간을 훑었는데 이름이 거의 안 나왔다 — 이 테스트가 헛돌고 있다")
    }

    func testWordListIsReallyCovered() throws {
        let words = try XCTUnwrap(BundledWordSource.load()?.words)
        XCTAssertGreaterThan(words.count, 0, "단어 목록이 비어 이 검사가 헛돈다")
    }

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
