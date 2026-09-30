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

        // 이름은 날짜·제철에 따라 돌아서 색만 훑으면 일부만 나온다 — 목록 전체도 본다.
        for named in PebbleNaming.allNames { needed.formUnion(named.name.unicodeScalars) }

        for w in BundledWordSource.load()?.words ?? [] { needed.formUnion(w.word.unicodeScalars) }

        let missing = needed.filter { !glyphExists($0, in: font) }.map(String.init).sorted()
        XCTAssertTrue(missing.isEmpty,
            "서브셋에 없는 글자 \(missing.count)개: \(missing.joined()) — Shared/Design/Fonts/README.md 대로 다시 구울 것")
        XCTAssertGreaterThan(needed.count, 20, "색 구간을 훑었는데 이름이 거의 안 나왔다 — 이 테스트가 헛돌고 있다")
    }

    func testWordListLoads() throws {
        let words = try XCTUnwrap(BundledWordSource.load()?.words)
        XCTAssertGreaterThan(words.count, 0, "단어 목록이 비어 이 검사가 헛돈다")
    }

    func testSubsetStaysSmall() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "NanumMyeongjo-Subset", withExtension: "ttf")
            ?? Bundle.main.url(forResource: "NanumMyeongjo-Subset", withExtension: "ttf"),
            "번들에서 서브셋 파일을 못 찾았다")
        let bytes = try Data(contentsOf: url).count
        XCTAssertLessThan(bytes, 100_000,
            "폰트가 \(bytes / 1024)KB — 전체 한글이 들어간 것 같다. 서브셋으로 되돌릴 것")
    }

    // MARK: 고운돋움

    private static let fontsDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Shared/Design/Fonts")

    private func sansFont(_ size: CGFloat = 20) throws -> CTFont {
        Face.ensureRegistered()
        return try XCTUnwrap(UIFont(name: Face.sansName, size: size), "\(Face.sansName) 가 등록되지 않았다") as CTFont
    }

    func testBundledSansIsRegisteredFromAppBundle() throws {
        XCTAssertTrue(Face.ensureRegistered())
        XCTAssertNotNil(Bundle.main.url(forResource: "GowunDodum-Hangul", withExtension: "ttf"), "앱엔 한글 2,350자 판")
        XCTAssertNil(Bundle.main.url(forResource: "GowunDodum-Mini", withExtension: "ttf"), "앱에 확장용 판이 섞였다")
        XCTAssertNotNil(Bundle.main.url(forResource: "GowunDodum-OFL", withExtension: "txt"), "OFL 라이선스가 번들에 없다")
        _ = try sansFont()
    }

    // KS X 1001 2,350자만 담는다 — 드문 글자(똠·뷁 등)는 iOS 가 그 글자만 시스템 서체로 대신 그린다.
    func testSansCoversCommonHangulAndAppText() throws {
        let font = try sansFont()
        for s in ["가", "힝", "몽", "돌", "ㅋ", "A", "7", "·", "「", "」"] {
            XCTAssertTrue(glyphExists(s.unicodeScalars.first!, in: font), "\(s) 글리프가 없다")
        }
        let common = try String(contentsOf: Self.fontsDir.appendingPathComponent("gowun-ksx1001.txt"), encoding: .utf8)
        let missing = common.unicodeScalars.filter { !glyphExists($0, in: font) }
        XCTAssertEqual(missing.count, 0, "빠진 한글 \(missing.count)자")
        XCTAssertEqual(common.count, 2350)
    }

    // monospacedDigit() 는 tnum 으로 간다 — 서브셋에서 tnum 이 빠지면 시각이 흔들린다.
    func testSansDigitsAlignWithMonospacedDigit() throws {
        let base = CTFontCopyFontDescriptor(try sansFont(16))
        let attrs: [CFString: Any] = [kCTFontFeatureSettingsAttribute: [[
            kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
            kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector,
        ]]]
        let desc = CTFontDescriptorCreateCopyWithAttributes(base, attrs as CFDictionary)
        let mono = CTFontCreateWithFontDescriptor(desc, 16, nil)
        func width(_ s: String) -> Double {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: mono]))
            return CTLineGetTypographicBounds(line, nil, nil, nil)
        }
        XCTAssertEqual(width("1111"), width("0000"), accuracy: 0.01)
    }

    func testExtensionSansCoversExtensionText() throws {
        let data = try Data(contentsOf: Self.fontsDir.appendingPathComponent("GowunDodum-Mini.ttf"))
        XCTAssertLessThan(data.count, 150_000, "확장용 판이 \(data.count / 1024)KB — 한글 전체가 들어간 것 같다")
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let font = CTFontCreateWithGraphicsFont(try XCTUnwrap(CGFont(provider)), 20, nil, nil)
        let root = Self.fontsDir.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = ["Shared/Capture/CaptureScreen.swift", "Shared/Capture/ShotViewer.swift",
                       "Shared/Capture/CaptureEngine.swift", "ColorMomentsControl/PebbleWidget.swift",
                       "Shared/Widget/WidgetSnapshot.swift", "ColorMomentsCapture/ViewFinder.swift"]
        var needed = Set<Unicode.Scalar>()
        for path in sources {
            let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            needed.formUnion(text.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) })
        }
        XCTAssertGreaterThan(needed.count, 20, "소스를 못 읽어 이 검사가 헛돈다")
        let missing = needed.filter { !glyphExists($0, in: font) }.map(String.init).sorted()
        XCTAssertTrue(missing.isEmpty,
            "확장용 판에 없는 글자 \(missing.joined()) — Shared/Design/Fonts/README.md 대로 다시 구울 것")
    }

    // MARK: 버튼 세미볼드 (IBM Plex Sans KR SemiBold)

    private func actionBoldFont(_ size: CGFloat = 17) throws -> CTFont {
        Face.ensureRegistered()
        return try XCTUnwrap(UIFont(name: Face.actionBoldName, size: size),
                              "\(Face.actionBoldName) 가 등록되지 않았다") as CTFont
    }

    func testBundledActionBoldIsRegisteredFromAppBundle() throws {
        XCTAssertTrue(Face.ensureRegistered())
        XCTAssertNotNil(Bundle.main.url(forResource: "IBMPlexSansKR-SemiBold-Subset", withExtension: "ttf"),
                        "앱 번들에 버튼 세미볼드 서브셋이 없다")
        XCTAssertNotNil(Bundle.main.url(forResource: "IBMPlexSansKR-OFL", withExtension: "txt"),
                        "OFL 라이선스가 번들에 없다")
        _ = try actionBoldFont()
    }

    func testActionBoldSubsetStaysSmall() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "IBMPlexSansKR-SemiBold-Subset", withExtension: "ttf"))
        let bytes = try Data(contentsOf: url).count
        XCTAssertLessThan(bytes, 60_000, "버튼 세미볼드가 \(bytes / 1024)KB — 버튼 문구만 담은 서브셋치고 크다")
    }

    /// PrimaryAction/SecondaryAction/CloudStep(actionTitle:) 로 소스에 박힌 버튼 문구를 실제로 추출해,
    /// 서브셋에 그 글자가 다 있는지 확인한다 — 새 버튼 문구가 추가되고 서브셋을 안 다시 구우면 그 글자만 SF 로 떨어진다.
    func testActionBoldCoversOnboardingButtonText() throws {
        let font = try actionBoldFont()
        let root = Self.fontsDir.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let onboardingSteps = try String(contentsOf: root.appendingPathComponent("ColorMoments/Onboarding/OnboardingSteps.swift"), encoding: .utf8)
        let onboardingView = try String(contentsOf: root.appendingPathComponent("ColorMoments/Onboarding/OnboardingView.swift"), encoding: .utf8)

        func quotedValues(after keyword: String, in text: String) -> [String] {
            let pattern = NSRegularExpression.escapedPattern(for: keyword) + #"\(?\s*"([^"]*)""#
            let regex = try! NSRegularExpression(pattern: pattern)
            let ns = text as NSString
            return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
                ns.substring(with: $0.range(at: 1))
            }
        }

        var titles = quotedValues(after: "PrimaryAction(title:", in: onboardingSteps)
        titles += quotedValues(after: "SecondaryAction(title:", in: onboardingSteps)
        titles += quotedValues(after: "actionTitle:", in: onboardingView)

        XCTAssertGreaterThanOrEqual(titles.count, 10, "온보딩 버튼 문구를 못 읽어 이 검사가 헛돈다")

        var needed = Set<Unicode.Scalar>()
        for t in titles { needed.formUnion(t.unicodeScalars) }
        // 「담기 N」처럼 코드에서 숫자를 이어붙이는 버튼(Face.action 직접 사용)은 문자열 보간이라 정적 추출이 안 된다 —
        // 숫자만 따로 보장한다.
        needed.formUnion("0123456789".unicodeScalars)

        let missing = needed.filter { !glyphExists($0, in: font) }.map(String.init).sorted()
        XCTAssertTrue(missing.isEmpty,
            "버튼 세미볼드 서브셋에 없는 글자 \(missing.joined()) — Shared/Design/Fonts/README.md 대로 다시 구울 것")
    }

    func testActionBoldCoversFixedActionLabels() throws {
        let font = try actionBoldFont()
        // Face.action 을 직접 쓰는 「닫기」「설정 열기」「담기 N」(BadgeCeremony·LibraryPickerView) — 문자열 보간이라 위 테스트가 못 잡는다.
        let labels = ["닫기", "설정 열기", "담기 "]
        var needed = Set<Unicode.Scalar>()
        for l in labels { needed.formUnion(l.unicodeScalars) }
        let missing = needed.filter { !glyphExists($0, in: font) }.map(String.init).sorted()
        XCTAssertTrue(missing.isEmpty,
            "버튼 세미볼드 서브셋에 없는 글자 \(missing.joined()) — Shared/Design/Fonts/README.md 대로 다시 구울 것")
    }
}
